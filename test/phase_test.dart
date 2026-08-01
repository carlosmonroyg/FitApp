import 'dart:convert';
import 'dart:io';

import 'package:fitapp/models/exercise.dart';
import 'package:fitapp/models/phase.dart';
import 'package:fitapp/models/profile.dart';
import 'package:fitapp/models/routine.dart';
import 'package:fitapp/services/routine_generator.dart';
import 'package:flutter_test/flutter_test.dart';

List<Exercise> loadCatalog() =>
    (jsonDecode(File('assets/data/exercises.json').readAsStringSync()) as List)
        .cast<Map<String, dynamic>>()
        .map(Exercise.fromJson)
        .toList();

const _profile = UserProfile(
  level: Level.intermediate,
  goal: Goal.buildMuscle,
  equipment: EquipmentSetup.gym,
  daysPerWeek: 4,
);

RoutineExercise firstOf(List<WorkoutDay> week) =>
    week.firstWhere((d) => !d.isRest).exercises.first;

void main() {
  final catalog = loadCatalog();

  group('Calendario del programa', () {
    test('las 12 semanas se reparten en tres fases de cuatro', () {
      expect(phaseForWeek(1), TrainingPhase.adaptation);
      expect(phaseForWeek(4), TrainingPhase.adaptation);
      expect(phaseForWeek(5), TrainingPhase.progression);
      expect(phaseForWeek(8), TrainingPhase.progression);
      expect(phaseForWeek(9), TrainingPhase.consolidation);
      expect(phaseForWeek(12), TrainingPhase.consolidation);
    });

    test('al terminar el programa empieza un ciclo nuevo', () {
      expect(phaseForWeek(13), TrainingPhase.adaptation);
      expect(weekInCycle(13), 1);
      expect(cycleOf(13), 2);
      expect(cycleOf(12), 1);
      expect(weekInCycle(25), 1);
      expect(cycleOf(25), 3);
    });

    test('cada fase cubre su rango de semanas', () {
      for (final phase in TrainingPhase.values) {
        expect(phase.lastWeek - phase.firstWeek + 1, weeksPerPhase);
        for (var w = phase.firstWeek; w <= phase.lastWeek; w++) {
          expect(phaseForWeek(w), phase);
        }
      }
    });
  });

  group('La fase cambia la prescripción', () {
    test('el volumen sube de adaptación a consolidación', () {
      final byPhase = {
        for (final phase in TrainingPhase.values)
          phase: firstOf(
              RoutineGenerator(catalog, _profile, phase: phase, seed: 4)
                  .generateWeek()),
      };

      expect(byPhase[TrainingPhase.adaptation]!.sets,
          lessThan(byPhase[TrainingPhase.progression]!.sets));
      expect(byPhase[TrainingPhase.progression]!.sets,
          lessThan(byPhase[TrainingPhase.consolidation]!.sets));
    });

    test('se empieza con repeticiones altas y se acaba con cargas', () {
      for (final goal in Goal.values) {
        final profile = UserProfile(
          level: Level.intermediate,
          goal: goal,
          equipment: EquipmentSetup.gym,
          daysPerWeek: 4,
        );
        int lowerBound(TrainingPhase phase) {
          final reps = firstOf(
                  RoutineGenerator(catalog, profile, phase: phase, seed: 4)
                      .generateWeek())
              .reps;
          return int.parse(reps.split('–').first);
        }

        expect(lowerBound(TrainingPhase.adaptation),
            greaterThan(lowerBound(TrainingPhase.progression)),
            reason: '${goal.label}: adaptación debe ser más ligera');
        expect(lowerBound(TrainingPhase.progression),
            greaterThan(lowerBound(TrainingPhase.consolidation)),
            reason: '${goal.label}: consolidación debe ser más pesada');
      }
    });

    test('la fase de adaptación descansa más que la de progresión', () {
      final adaptation = firstOf(RoutineGenerator(catalog, _profile,
              phase: TrainingPhase.adaptation, seed: 4)
          .generateWeek());
      final progression = firstOf(RoutineGenerator(catalog, _profile,
              phase: TrainingPhase.progression, seed: 4)
          .generateWeek());
      expect(adaptation.restSeconds, greaterThan(progression.restSeconds));
    });

    test('nunca baja de 2 series ni sube de 6, en ninguna combinación', () {
      for (final phase in TrainingPhase.values) {
        for (final goal in Goal.values) {
          for (final activity in ActivityLevel.values) {
            final profile = UserProfile(
              level: Level.beginner,
              goal: goal,
              equipment: EquipmentSetup.none,
              daysPerWeek: 3,
              activity: activity,
            );
            final week = RoutineGenerator(catalog, profile,
                    phase: phase, seed: 8)
                .generateWeek();
            for (final day in week.where((d) => !d.isRest)) {
              for (final re in day.exercises) {
                expect(re.sets, inInclusiveRange(2, 6));
                expect(re.restSeconds, inInclusiveRange(30, 180));
              }
            }
          }
        }
      }
    });
  });
}
