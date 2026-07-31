import 'dart:convert';
import 'dart:io';

import 'package:fitapp/models/exercise.dart';
import 'package:fitapp/models/profile.dart';
import 'package:fitapp/services/routine_generator.dart';
import 'package:flutter_test/flutter_test.dart';

List<Exercise> loadCatalog() {
  final raw = File('assets/data/exercises.json').readAsStringSync();
  return (jsonDecode(raw) as List)
      .cast<Map<String, dynamic>>()
      .map(Exercise.fromJson)
      .toList();
}

UserProfile profileWith({
  required TrainingFocus focus,
  Level level = Level.intermediate,
  int days = 4,
  EquipmentSetup equipment = EquipmentSetup.gym,
}) =>
    UserProfile(
      level: level,
      goal: Goal.buildMuscle,
      equipment: equipment,
      daysPerWeek: days,
      sex: focus == TrainingFocus.lowerBody ? Sex.female : Sex.male,
      focus: focus,
    );

/// Series semanales dedicadas a un músculo objetivo.
int weeklySetsFor(List<dynamic> week, String target) {
  var sets = 0;
  for (final day in week) {
    for (final re in day.exercises) {
      if (re.exercise.target == target) sets += re.sets as int;
    }
  }
  return sets;
}

void main() {
  final catalog = loadCatalog();

  group('Enfoque glúteo y pierna', () {
    test('entrena glúteo al menos dos veces por semana y con más volumen', () {
      for (final days in [2, 3, 4, 5]) {
        final lower = RoutineGenerator(
                catalog, profileWith(focus: TrainingFocus.lowerBody, days: days),
                seed: 7)
            .generateWeek();
        final balanced = RoutineGenerator(
                catalog, profileWith(focus: TrainingFocus.balanced, days: days),
                seed: 7)
            .generateWeek();

        final daysHittingGlutes = lower
            .where((d) => d.exercises.any((re) => re.exercise.target == 'glutes'))
            .length;

        expect(daysHittingGlutes, greaterThanOrEqualTo(2),
            reason: 'con $days días debería tocar glúteo al menos 2 veces');
        expect(weeklySetsFor(lower, 'glutes'),
            greaterThan(weeklySetsFor(balanced, 'glutes')),
            reason: 'con $days días debería superar el volumen equilibrado');
      }
    });

    test('sube el volumen semanal de glúteo y abdomen', () {
      final lower = RoutineGenerator(
              catalog, profileWith(focus: TrainingFocus.lowerBody), seed: 3)
          .generateWeek();
      final balanced = RoutineGenerator(
              catalog, profileWith(focus: TrainingFocus.balanced), seed: 3)
          .generateWeek();

      expect(weeklySetsFor(lower, 'glutes'),
          greaterThan(weeklySetsFor(balanced, 'glutes')));
      expect(weeklySetsFor(lower, 'abs'),
          greaterThan(weeklySetsFor(balanced, 'abs')));
    });

    test('conserva dos sesiones de tren superior', () {
      final week = RoutineGenerator(
              catalog, profileWith(focus: TrainingFocus.lowerBody), seed: 11)
          .generateWeek();
      const upperParts = {'chest', 'back', 'shoulders', 'upper arms'};
      final upperDays = week
          .where((d) => d.exercises
              .where((re) => upperParts.contains(re.exercise.bodyPart))
              .length >=
              3)
          .length;
      expect(upperDays, greaterThanOrEqualTo(2));
    });

    test('incluye trabajo lateral de abductores en los días de glúteo', () {
      final week = RoutineGenerator(
              catalog, profileWith(focus: TrainingFocus.lowerBody, days: 5),
              seed: 5)
          .generateWeek();
      final lateral = week
          .expand((d) => d.exercises)
          .where((re) =>
              re.exercise.target == 'abductors' ||
              re.exercise.target == 'adductors')
          .length;
      expect(lateral, greaterThanOrEqualTo(1));
    });

    test('funciona sin equipo en casa', () {
      for (final days in [2, 3, 4, 5]) {
        final week = RoutineGenerator(
                catalog,
                profileWith(
                    focus: TrainingFocus.lowerBody,
                    days: days,
                    equipment: EquipmentSetup.none),
                seed: 2)
            .generateWeek();
        for (final day in week.where((d) => !d.isRest)) {
          expect(day.exercises.length, greaterThanOrEqualTo(4),
              reason: '${day.title} con $days días quedó corto');
        }
      }
    });

    test('los principiantes mantienen días de cuerpo completo', () {
      final week = RoutineGenerator(
              catalog,
              profileWith(
                  focus: TrainingFocus.lowerBody, level: Level.beginner),
              seed: 1)
          .generateWeek();
      expect(week.where((d) => d.title.contains('Cuerpo completo')).length,
          greaterThanOrEqualTo(1));
    });
  });

  test('no receta estiramientos como ejercicio de fuerza', () {
    for (final focus in TrainingFocus.values) {
      for (final equipment in EquipmentSetup.values) {
        final week = RoutineGenerator(
                catalog, profileWith(focus: focus, equipment: equipment),
                seed: 13)
            .generateWeek();
        final stretches = week
            .expand((d) => d.exercises)
            .where((re) => re.exercise.isStretch)
            .map((re) => re.exercise.name);
        expect(stretches, isEmpty,
            reason: '${focus.label} / ${equipment.label}');
      }
    }
  });

  test('el plan equilibrado no cambia de comportamiento', () {
    final week = RoutineGenerator(
            catalog, profileWith(focus: TrainingFocus.balanced), seed: 9)
        .generateWeek();
    expect(week.length, 7);
    expect(week.where((d) => !d.isRest).length, 4);
    for (final day in week.where((d) => !d.isRest)) {
      expect(day.exercises.length, 6);
    }
  });
}
