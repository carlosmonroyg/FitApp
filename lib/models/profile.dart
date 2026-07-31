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

  /// Enfoque sugerido de partida; el usuario siempre puede cambiarlo.
  TrainingFocus get suggestedFocus => switch (this) {
        Sex.male => TrainingFocus.balanced,
        Sex.female => TrainingFocus.lowerBody,
      };
}

/// Énfasis del plan semanal.
enum TrainingFocus { balanced, lowerBody }

extension TrainingFocusX on TrainingFocus {
  String get label => switch (this) {
        TrainingFocus.balanced => 'Equilibrado',
        TrainingFocus.lowerBody => 'Glúteo y pierna',
      };

  String get emoji => switch (this) {
        TrainingFocus.balanced => '⚖️',
        TrainingFocus.lowerBody => '🍑',
      };

  String get description => switch (this) {
        TrainingFocus.balanced =>
          'Reparte el volumen entre todo el cuerpo por igual',
        TrainingFocus.lowerBody =>
          'Más días y series de glúteo, pierna y abdomen',
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
  final TrainingFocus focus;

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
    this.focus = TrainingFocus.balanced,
    this.focusZones = const [],
  });

  double get bmi => weightKg / ((heightCm / 100) * (heightCm / 100));

  UserProfile copyWith({
    Level? level,
    Goal? goal,
    EquipmentSetup? equipment,
    int? daysPerWeek,
    Sex? sex,
    int? heightCm,
    int? weightKg,
    ActivityLevel? activity,
    TrainingFocus? focus,
    List<String>? focusZones,
  }) =>
      UserProfile(
        level: level ?? this.level,
        goal: goal ?? this.goal,
        equipment: equipment ?? this.equipment,
        daysPerWeek: daysPerWeek ?? this.daysPerWeek,
        sex: sex ?? this.sex,
        heightCm: heightCm ?? this.heightCm,
        weightKg: weightKg ?? this.weightKg,
        activity: activity ?? this.activity,
        focus: focus ?? this.focus,
        focusZones: focusZones ?? this.focusZones,
      );

  Map<String, dynamic> toJson() => {
        'level': level.name,
        'goal': goal.name,
        'equipment': equipment.name,
        'daysPerWeek': daysPerWeek,
        'sex': sex.name,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'activity': activity.name,
        'focus': focus.name,
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
        focus: j['focus'] != null
            ? TrainingFocus.values.byName(j['focus'] as String)
            : TrainingFocus.balanced,
        focusZones:
            ((j['focusZones'] as List?) ?? const []).cast<String>(),
      );
}
