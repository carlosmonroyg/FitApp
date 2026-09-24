import 'dart:convert';
import 'dart:io';

import 'package:fitapp/models/coach.dart';
import 'package:fitapp/models/exercise.dart';
import 'package:fitapp/models/phase.dart';
import 'package:fitapp/models/profile.dart';
import 'package:fitapp/models/routine.dart';
import 'package:fitapp/services/routine_generator.dart';
import 'package:flutter_test/flutter_test.dart';

List<Exercise> loadCatalog() {
  final raw = File('assets/data/exercises.json').readAsStringSync();
  return (jsonDecode(raw) as List)
      .cast<Map<String, dynamic>>()
      .map(Exercise.fromJson)
      .toList();
}

const profile = UserProfile(
  level: Level.intermediate,
  goal: Goal.buildMuscle,
  equipment: EquipmentSetup.gym,
  daysPerWeek: 3,
);

void main() {
  final catalog = loadCatalog();

  List<WorkoutDay> weekWith(Prescription p, {int seed = 3}) => RoutineGenerator(
        catalog,
        profile,
        phase: TrainingPhase.progression,
        prescription: p,
        seed: seed,
      ).generateWeek();

  test('sin prescripción, el generador no cambia', () {
    final a = weekWith(Prescription.none);
    final b = RoutineGenerator(catalog, profile,
            phase: TrainingPhase.progression, seed: 3)
        .generateWeek();
    for (var d = 0; d < 7; d++) {
      expect(a[d].exercises.map((re) => re.exercise.id).toList(),
          b[d].exercises.map((re) => re.exercise.id).toList());
    }
  });

  test('+1 serie en pecho y descanso +15 s, dentro de límites', () {
    final base = weekWith(Prescription.none);
    final adjusted = weekWith(
        const Prescription(setDelta: {'chest': 1}, restDeltaSec: 15));
    final baseChest = base
        .expand((d) => d.exercises)
        .firstWhere((re) => re.exercise.bodyPart == 'chest');
    final adjChest = adjusted
        .expand((d) => d.exercises)
        .firstWhere((re) => re.exercise.bodyPart == 'chest');
    expect(adjChest.sets, (baseChest.sets + 1).clamp(2, 6));
    expect(adjChest.restSeconds, baseChest.restSeconds + 15);
    // Otras partes no cambian de series.
    final baseBack = base
        .expand((d) => d.exercises)
        .firstWhere((re) => re.exercise.bodyPart == 'back');
    final adjBack = adjusted
        .expand((d) => d.exercises)
        .firstWhere((re) => re.exercise.bodyPart == 'back');
    expect(adjBack.sets, baseBack.sets);
  });

  test('sustitución: el sustituto reemplaza al original', () {
    final base = weekWith(Prescription.none);
    final target = base.expand((d) => d.exercises).first.exercise;
    final alt = catalog.firstWhere((e) =>
        e.id != target.id &&
        e.bodyPart == target.bodyPart &&
        e.target == target.target &&
        !base.any((d) => d.exercises.any((re) => re.exercise.id == e.id)));
    final swapped = weekWith(Prescription(swaps: {target.id: alt.id}));
    final ids = swapped.expand((d) => d.exercises).map((re) => re.exercise.id);
    expect(ids, contains(alt.id));
    expect(ids, isNot(contains(target.id)));
  });

  test('evitar: el ejercicio no aparece aunque el azar lo elija', () {
    final base = weekWith(Prescription.none);
    final banned = base.expand((d) => d.exercises).first.exercise.id;
    final week = weekWith(Prescription(avoid: {banned}));
    expect(
        week.expand((d) => d.exercises).map((re) => re.exercise.id),
        isNot(contains(banned)));
  });

  test('conservar: los ejercicios con progreso se mantienen entre semanas',
      () {
    final base = weekWith(Prescription.none, seed: 1);
    final keep = base
        .expand((d) => d.exercises)
        .map((re) => re.exercise.id)
        .take(3)
        .toSet();
    // Otra semilla cambiaría todo; con keep, esos tres siguen.
    final next = weekWith(Prescription(keep: keep), seed: 99);
    final ids = next.expand((d) => d.exercises).map((re) => re.exercise.id).toSet();
    expect(ids.containsAll(keep), isTrue);
  });

  test('la prescripción se arma desde los cambios y sobrevive a JSON', () {
    final checkin = CoachCheckin(
      weekId: '2026-09-07',
      createdAt: DateTime(2026, 9, 13),
      summary: 's',
      highlights: const [],
      weekFocus: 'f',
      coachNotes: const ['prefiere mañanas'],
      changes: const [
        CoachChange(type: 'sets', reason: 'r', bodyPart: 'back', delta: 3),
        CoachChange(type: 'rest', reason: 'r', delta: -15),
        CoachChange(type: 'swap', reason: 'r', fromId: 'a', toId: 'b'),
        CoachChange(
            type: 'progression',
            reason: 'r',
            exerciseId: 'c',
            action: ProgressionAction.addWeight),
        CoachChange(type: 'avoid', reason: 'r', exerciseId: 'd'),
      ],
    );
    final p = checkin.prescription(keep: {'d', 'z'});
    expect(p.setDelta['back'], 1); // se acota a ±1
    expect(p.restDeltaSec, -15);
    expect(p.swaps['a'], 'b');
    expect(p.progression['c'], ProgressionAction.addWeight);
    expect(p.avoid, {'d'});
    expect(p.keep, {'z', 'c'}); // lo evitado nunca se conserva

    final back = Prescription.fromJson(
        jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
    expect(back.setDelta, p.setDelta);
    expect(back.progression, p.progression);
    expect(back.keep, p.keep);

    final c2 = CoachCheckin.fromJson(
        jsonDecode(jsonEncode(checkin.toJson())) as Map<String, dynamic>);
    expect(c2.changes.length, 5);
    expect(c2.changes[3].action, ProgressionAction.addWeight);
  });
}
