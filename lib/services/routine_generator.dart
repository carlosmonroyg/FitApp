import 'dart:math';

import '../models/exercise.dart';
import '../models/profile.dart';
import '../models/routine.dart';

/// Un bloque de un día de entrenamiento: qué partes/músculos y cuántos ejercicios.
class _Slot {
  final Set<String> bodyParts;
  final Set<String>? targets; // filtro fino opcional (ej. solo tríceps)
  final int count;

  const _Slot(this.bodyParts, this.count, {this.targets});
}

class _DayTemplate {
  final String title;
  final List<_Slot> slots;

  const _DayTemplate(this.title, this.slots);
}

class RoutineGenerator {
  final List<Exercise> catalog;
  final UserProfile profile;
  final Random _rand;

  RoutineGenerator(this.catalog, this.profile, {int? seed})
      : _rand = Random(seed ?? DateTime.now().millisecondsSinceEpoch);

  /// Semana completa: 7 entradas (lunes a domingo), con días de descanso.
  List<WorkoutDay> generateWeek() {
    final templates = _weekTemplates();
    final slotsByDay = _spreadOverWeek(templates.length);
    final week = <WorkoutDay>[];
    var t = 0;
    for (var d = 0; d < 7; d++) {
      if (slotsByDay.contains(d)) {
        week.add(_buildDay(templates[t++]));
      } else {
        week.add(const WorkoutDay(title: 'Descanso', exercises: []));
      }
    }
    return week;
  }

  /// Índices de la semana (0=lunes) donde caen los entrenamientos.
  Set<int> _spreadOverWeek(int n) => switch (n) {
        2 => {0, 3},
        3 => {0, 2, 4},
        4 => {0, 1, 3, 4},
        5 => {0, 1, 2, 4, 5},
        _ => {for (var i = 0; i < n && i < 7; i++) i},
      };

  List<_DayTemplate> _weekTemplates() {
    final days = profile.daysPerWeek.clamp(2, 5);
    final beginner = profile.level == Level.beginner;

    const full = _DayTemplate('Cuerpo completo', [
      _Slot({'chest'}, 1),
      _Slot({'back'}, 1),
      _Slot({'upper legs'}, 1),
      _Slot({'shoulders'}, 1),
      _Slot({'waist'}, 1),
      _Slot({'upper arms'}, 1),
      _Slot({'lower legs'}, 1),
    ]);
    const push = _DayTemplate('Empuje · Pecho y hombros', [
      _Slot({'chest'}, 3),
      _Slot({'shoulders'}, 2),
      _Slot({'upper arms'}, 2, targets: {'triceps'}),
    ]);
    const pull = _DayTemplate('Tirón · Espalda y bíceps', [
      _Slot({'back'}, 3),
      _Slot({'upper arms'}, 2, targets: {'biceps', 'brachialis'}),
      _Slot({'lower arms'}, 1),
      _Slot({'back'}, 1),
    ]);
    // Los targets van explícitos: en el dataset "upper legs" es 63% glúteo,
    // así que sin filtro un día de pierna saldría casi todo glúteo.
    const legs = _DayTemplate('Piernas y core', [
      _Slot({'upper legs'}, 1, targets: {'quads'}),
      _Slot({'upper legs'}, 1, targets: {'hamstrings'}),
      _Slot({'upper legs'}, 1, targets: {'glutes'}),
      _Slot({'lower legs'}, 1),
      _Slot({'waist'}, 2),
      _Slot({'upper legs'}, 1),
    ]);
    const upper = _DayTemplate('Tren superior', [
      _Slot({'chest'}, 2),
      _Slot({'back'}, 2),
      _Slot({'shoulders'}, 1),
      _Slot({'upper arms'}, 2),
    ]);
    const lower = _DayTemplate('Tren inferior', [
      _Slot({'upper legs'}, 1, targets: {'quads'}),
      _Slot({'upper legs'}, 1, targets: {'hamstrings'}),
      _Slot({'upper legs'}, 1, targets: {'glutes'}),
      _Slot({'lower legs'}, 1),
      _Slot({'waist'}, 2),
      _Slot({'upper legs'}, 1),
    ]);

    if (profile.focus == TrainingFocus.lowerBody) {
      return _lowerBodyTemplates(days, beginner, upper);
    }

    if (beginner) {
      return List.filled(days, full);
    }
    return switch (days) {
      2 => const [full, full],
      3 => const [push, pull, legs],
      4 => const [upper, lower, upper, lower],
      _ => const [push, pull, legs, upper, lower],
    };
  }

  /// Semana con prioridad en glúteo, pierna y abdomen.
  ///
  /// Sigue la "regla de los tercios" del entrenamiento de glúteo: cada día
  /// inferior combina empuje de cadera (glutes), patrón de sentadilla/zancada
  /// (quads/hamstrings) y trabajo lateral (abductores/aductores). Se conservan
  /// dos exposiciones semanales de tren superior para no desbalancear.
  List<_DayTemplate> _lowerBodyTemplates(
      int days, bool beginner, _DayTemplate upper) {
    const gluteDay = _DayTemplate('Glúteo y core', [
      _Slot({'upper legs'}, 3, targets: {'glutes'}),
      _Slot({'upper legs'}, 1, targets: {'abductors', 'adductors'}),
      _Slot({'waist'}, 2),
      _Slot({'upper legs'}, 1, targets: {'glutes'}),
      _Slot({'upper legs'}, 1, targets: {'hamstrings'}),
    ]);
    const legDay = _DayTemplate('Pierna completa y abs', [
      _Slot({'upper legs'}, 2, targets: {'quads'}),
      _Slot({'upper legs'}, 1, targets: {'glutes'}),
      _Slot({'upper legs'}, 1, targets: {'hamstrings'}),
      _Slot({'waist'}, 2),
      _Slot({'lower legs'}, 1),
    ]);
    const gluteAbs = _DayTemplate('Glúteo, abductores y abs', [
      _Slot({'upper legs'}, 2, targets: {'glutes'}),
      _Slot({'upper legs'}, 1, targets: {'abductors', 'adductors'}),
      _Slot({'waist'}, 3),
      _Slot({'lower legs'}, 1),
    ]);
    const upperCore = _DayTemplate('Tren superior y core', [
      _Slot({'back'}, 2),
      _Slot({'chest'}, 1),
      _Slot({'shoulders'}, 1),
      _Slot({'waist'}, 2),
      _Slot({'upper arms'}, 1),
    ]);
    const fullLower = _DayTemplate('Cuerpo completo · énfasis glúteo', [
      _Slot({'upper legs'}, 2, targets: {'glutes'}),
      _Slot({'upper legs'}, 1, targets: {'quads', 'hamstrings'}),
      _Slot({'waist'}, 1),
      _Slot({'back'}, 1),
      _Slot({'chest'}, 1),
      _Slot({'shoulders'}, 1),
      _Slot({'upper legs'}, 1, targets: {'abductors', 'adductors'}),
    ]);

    if (beginner) {
      // Cuerpo completo para aprender los patrones, con glúteo de protagonista
      // y un día dedicado a partir de la tercera sesión.
      const week = [fullLower, fullLower, gluteDay, fullLower, gluteDay];
      return week.take(days).toList();
    }
    return switch (days) {
      2 => const [fullLower, gluteDay],
      3 => const [gluteDay, upperCore, legDay],
      4 => [gluteDay, upperCore, legDay, upper],
      _ => [gluteDay, upperCore, legDay, upper, gluteAbs],
    };
  }

  WorkoutDay _buildDay(_DayTemplate template) {
    // El énfasis inferior suma un ejercicio: el trabajo de abductores y abdomen
    // es de aislamiento y alarga poco la sesión.
    final perDay = switch (profile.level) {
          Level.beginner => 5,
          Level.intermediate => 6,
          Level.advanced => 7,
        } +
        (profile.focus == TrainingFocus.lowerBody ? 1 : 0);
    final (sets, reps, rest) = _prescription();

    final used = <String>{};
    final picked = <Exercise>[];
    for (final slot in template.slots) {
      if (picked.length >= perDay) break;
      final take = min(slot.count, perDay - picked.length);
      picked.addAll(_pick(slot, take, used));
    }
    // Relleno por si algún slot no encontró suficientes candidatos.
    if (picked.length < perDay) {
      final parts = template.slots.expand((s) => s.bodyParts).toSet();
      picked.addAll(
          _pick(_Slot(parts, perDay - picked.length), perDay - picked.length, used));
    }

    // Zonas prioritarias del usuario: un ejercicio extra por zona presente
    // en este día (máximo 2 extras para no alargar la sesión).
    final dayParts = template.slots.expand((s) => s.bodyParts).toSet();
    for (final zone in profile.focusZones) {
      if (picked.length >= perDay + 2) break;
      if (dayParts.contains(zone)) {
        picked.addAll(_pick(_Slot({zone}, 1), 1, used));
      }
    }

    return WorkoutDay(
      title: template.title,
      exercises: [
        for (final e in picked)
          RoutineExercise(exercise: e, sets: sets, reps: reps, restSeconds: rest),
      ],
    );
  }

  /// Series, repeticiones y descanso según objetivo, sedentarismo e IMC.
  ///
  /// Fórmula de arranque suave: una vida sedentaria (o un IMC alto) reduce
  /// el volumen inicial y alarga el descanso para evitar lesiones y abandono;
  /// una vida muy activa lo acorta.
  (int, String, int) _prescription() {
    var (sets, reps, rest) = switch (profile.goal) {
      Goal.buildMuscle => (4, '8–12', 90),
      Goal.loseWeight => (3, '12–15', 45),
      Goal.stayFit => (3, '10–12', 60),
    };
    switch (profile.activity) {
      case ActivityLevel.sedentary:
        sets = (sets - 1).clamp(2, 5);
        rest += 15;
      case ActivityLevel.moderate:
        break;
      case ActivityLevel.active:
        rest = (rest - 10).clamp(30, 120);
    }
    if (profile.bmi >= 30) rest += 15;
    return (sets, reps, rest);
  }

  List<Exercise> _pick(_Slot slot, int count, Set<String> used) {
    final allowedEquipment = profile.equipment.allowedEquipment;
    final (preferred, allowed) = switch (profile.level) {
      Level.beginner => ('beginner', {'beginner'}),
      Level.intermediate => ('intermediate', {'beginner', 'intermediate'}),
      Level.advanced => ('advanced', {'intermediate', 'advanced'}),
    };

    List<Exercise> candidates(Set<String> difficulties) => catalog
        .where((e) =>
            !e.isStretch &&
            slot.bodyParts.contains(e.bodyPart) &&
            (slot.targets == null || slot.targets!.contains(e.target)) &&
            difficulties.contains(e.difficulty) &&
            (allowedEquipment == null || allowedEquipment.contains(e.equipment)) &&
            !used.contains(e.id))
        .toList();

    var pool = candidates(allowed);
    if (pool.length < count) {
      // Relaja la dificultad si el filtro de equipo dejó pocos candidatos.
      pool = candidates({'beginner', 'intermediate', 'advanced'});
    }
    pool.shuffle(_rand);
    // Prioriza la dificultad del nivel del usuario manteniendo el orden aleatorio.
    pool.sort((a, b) => (a.difficulty == preferred ? 0 : 1)
        .compareTo(b.difficulty == preferred ? 0 : 1));

    final picked = pool.take(count).toList();
    used.addAll(picked.map((e) => e.id));
    return picked;
  }
}
