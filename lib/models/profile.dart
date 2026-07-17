import 'package:flutter/material.dart';

enum Sex { male, female }

extension SexX on Sex {
  String get label => switch (this) {
        Sex.male => 'Hombre',
        Sex.female => 'Mujer',
      };

  String get emoji => switch (this) {
        Sex.male => '👨',
        Sex.female => '👩',
      };
}

/// Nivel de actividad del día a día (sedentarismo).
enum ActivityLevel { sedentary, moderate, active }

extension ActivityLevelX on ActivityLevel {
  String get label => switch (this) {
        ActivityLevel.sedentary => 'Sedentario',
        ActivityLevel.moderate => 'Algo activo',
        ActivityLevel.active => 'Muy activo',
      };

  String get emoji => switch (this) {
        ActivityLevel.sedentary => '🪑',
        ActivityLevel.moderate => '🚶',
        ActivityLevel.active => '🏃',
      };
}

enum Level { beginner, intermediate, advanced }

enum Goal { loseWeight, buildMuscle, stayFit }

enum EquipmentSetup { none, basic, gym }

extension LevelX on Level {
  String get label => switch (this) {
        Level.beginner => 'Principiante',
        Level.intermediate => 'Medio',
        Level.advanced => 'Avanzado',
      };

  String get emoji => switch (this) {
        Level.beginner => '🌱',
        Level.intermediate => '🔥',
        Level.advanced => '⚡',
      };

  Color get color => switch (this) {
        Level.beginner => const Color(0xFF4ADE80),
        Level.intermediate => const Color(0xFFFBBF24),
        Level.advanced => const Color(0xFFF87171),
      };
}

extension GoalX on Goal {
  String get label => switch (this) {
        Goal.loseWeight => 'Perder peso',
        Goal.buildMuscle => 'Ganar músculo',
        Goal.stayFit => 'Mantenerme en forma',
      };

  String get emoji => switch (this) {
        Goal.loseWeight => '🏃',
        Goal.buildMuscle => '💪',
        Goal.stayFit => '✨',
      };
}

extension EquipmentSetupX on EquipmentSetup {
  String get label => switch (this) {
        EquipmentSetup.none => 'Sin equipo (en casa)',
        EquipmentSetup.basic => 'Equipo básico',
        EquipmentSetup.gym => 'Gimnasio completo',
      };

  String get emoji => switch (this) {
        EquipmentSetup.none => '🏠',
        EquipmentSetup.basic => '🏋️',
        EquipmentSetup.gym => '🏢',
      };

  /// Equipos del dataset permitidos para esta configuración.
  /// `null` significa todos.
  Set<String>? get allowedEquipment => switch (this) {
        EquipmentSetup.none => {
            'body weight',
            'band',
            'resistance band',
            'roller',
            'wheel roller',
          },
        EquipmentSetup.basic => {
            'body weight',
            'band',
            'resistance band',
            'roller',
            'wheel roller',
            'dumbbell',
            'kettlebell',
            'medicine ball',
            'stability ball',
          },
        EquipmentSetup.gym => null,
      };
}

class UserProfile {
  final Level level;
  final Goal goal;
  final EquipmentSetup equipment;
  final int daysPerWeek;
  final Sex sex;
  final int heightCm;
  final int weightKg;
  final ActivityLevel activity;

  /// Partes del cuerpo (valores del dataset) que el usuario quiere priorizar.
  final List<String> focusZones;

  const UserProfile({
    required this.level,
    required this.goal,
    required this.equipment,
    required this.daysPerWeek,
    this.sex = Sex.male,
    this.heightCm = 170,
    this.weightKg = 70,
    this.activity = ActivityLevel.moderate,
    this.focusZones = const [],
  });

  double get bmi => weightKg / ((heightCm / 100) * (heightCm / 100));

  Map<String, dynamic> toJson() => {
        'level': level.name,
        'goal': goal.name,
        'equipment': equipment.name,
        'daysPerWeek': daysPerWeek,
        'sex': sex.name,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'activity': activity.name,
        'focusZones': focusZones,
      };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        level: Level.values.byName(j['level'] as String),
        goal: Goal.values.byName(j['goal'] as String),
        equipment: EquipmentSetup.values.byName(j['equipment'] as String),
        daysPerWeek: j['daysPerWeek'] as int,
        sex: j['sex'] != null ? Sex.values.byName(j['sex'] as String) : Sex.male,
        heightCm: (j['heightCm'] as int?) ?? 170,
        weightKg: (j['weightKg'] as int?) ?? 70,
        activity: j['activity'] != null
            ? ActivityLevel.values.byName(j['activity'] as String)
            : ActivityLevel.moderate,
        focusZones:
            ((j['focusZones'] as List?) ?? const []).cast<String>(),
      );
}
