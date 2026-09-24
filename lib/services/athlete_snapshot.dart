import 'dart:math';

import '../models/exercise.dart';
import '../models/measurement.dart';
import '../models/phase.dart';
import '../models/profile.dart';
import '../models/routine.dart';
import '../models/training_log.dart';
import 'storage.dart';

/// Resumen compacto del atleta que viaja al coach en cada check-in.
///
/// Se calcula en el teléfono, por código (nada de pedirle al modelo que
/// resuma): perfil, fase, adherencia, tendencias de medidas, progreso por
/// ejercicio y la semana actual con alternativas válidas para cada ejercicio.
/// Así el modelo solo puede sustituir por opciones que ya pasaron el filtro
/// de equipo y nivel, y el servidor lo verifica de nuevo.
class AthleteSnapshot {
  AthleteSnapshot._();

  static const _weekdays = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo'
  ];

  static Map<String, dynamic> build({
    required UserProfile profile,
    required List<WorkoutDay> week,
    required List<Exercise> catalog,
    required List<String> previousNotes,
    Random? random,
  }) {
    final now = DateTime.now();
    final sessions = Storage.sessions;
    final measurements = Storage.measurements;
    final rand = random ?? Random(now.millisecondsSinceEpoch);

    return {
      'today': _day(now),
      'profile': {
        'sex': profile.sex.name,
        'heightCm': profile.heightCm,
        'weightKg': profile.weightKg,
        'bmi': double.parse(profile.bmi.toStringAsFixed(1)),
        'level': profile.level.name,
        'goal': profile.goal.name,
        'equipment': profile.equipment.name,
        'daysPerWeek': profile.daysPerWeek,
        'activity': profile.activity.name,
        'focus': profile.focus.name,
        'focusZones': profile.focusZones,
      },
      'program': {
        'week': Storage.programWeek,
        'weekInCycle': weekInCycle(Storage.programWeek),
        'phase': Storage.currentPhase.name,
        'phaseLabel': Storage.currentPhase.label,
      },
      'adherence': _adherence(week, sessions, now),
      'measurements': _measurements(measurements),
      'week': [
        for (var i = 0; i < week.length; i++)
          if (!week[i].isRest)
            {
              'day': _weekdays[i],
              'title': week[i].title,
              'exercises': [
                for (final re in week[i].exercises)
                  {
                    'id': re.exercise.id,
                    'name': re.exercise.name,
                    'bodyPart': re.exercise.bodyPart,
                    'target': re.exercise.target,
                    'equipment': re.exercise.equipment,
                    'sets': re.sets,
                    'reps': re.reps,
                    'restSec': re.restSeconds,
                  },
              ],
            },
      ],
      'recentSessions': [
        for (final s in sessions.take(8)) _session(s),
      ],
      'progress': _progress(sessions),
      'alternatives': _alternatives(week, catalog, profile, rand),
      'previousNotes': previousNotes,
    };
  }

  static String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime _monday(DateTime d) =>
      DateTime(d.year, d.month, d.day - (d.weekday - 1));

  static Map<String, dynamic> _adherence(
      List<WorkoutDay> week, List<WorkoutSession> sessions, DateTime now) {
    final planned = week.where((d) => !d.isRest).length;
    final thisMonday = _monday(now);
    final weeks = <Map<String, dynamic>>[];
    for (var w = 0; w < 4; w++) {
      final start = thisMonday.subtract(Duration(days: 7 * w));
      final end = start.add(const Duration(days: 7));
      final done = sessions
          .where((s) => !s.date.isBefore(start) && s.date.isBefore(end))
          .length;
      weeks.add({'weekStarting': _day(start), 'planned': planned, 'done': done});
    }
    final feelings = [
      for (final s in sessions.take(6))
        if (s.feeling != null) s.feeling!,
    ];
    return {
      'plannedPerWeek': planned,
      'last4Weeks': weeks,
      'streak': Storage.streak,
      'avgFeelingRecent': feelings.isEmpty
          ? null
          : double.parse(
              (feelings.reduce((a, b) => a + b) / feelings.length)
                  .toStringAsFixed(1)),
    };
  }

  static Map<String, dynamic> _measurements(List<Measurement> history) {
    final latest = history.isEmpty ? null : history.first;
    return {
      'count': history.length,
      'latestDate': latest == null ? null : _day(latest.date),
      'latest': latest == null
          ? null
          : {
              for (final k in MeasureKind.values)
                if (latest.valueOf(k) != null) k.name: latest.valueOf(k),
              if (latest.waistHipRatio != null)
                'waistHipRatio':
                    double.parse(latest.waistHipRatio!.toStringAsFixed(2)),
            },
      'trends': [
        for (final k in MeasureKind.values)
          if (trendFor(history, k) case final t?)
            {
              'kind': k.name,
              'unit': k.unit,
              'first': t.first,
              'last': t.last,
              'delta': double.parse(t.delta.toStringAsFixed(1)),
              'days': t.days,
            },
      ],
    };
  }

  static Map<String, dynamic> _session(WorkoutSession s) => {
        'date': _day(s.date),
        'title': s.title,
        'durationMin': s.durationMin,
        'feeling': s.feeling,
        'avgRpe': s.avgRpe == null
            ? null
            : double.parse(s.avgRpe!.toStringAsFixed(1)),
        'volumeKg': s.volume.round(),
        'exercises': [
          for (final e in s.exercises)
            {
              'id': e.exerciseId,
              'name': e.exerciseName,
              'sets': [
                for (final set in e.sets)
                  [set.kg, set.reps, set.rpe],
              ],
            },
        ],
      };

  /// Historial de 1RM estimado por ejercicio (los 12 más entrenados).
  static List<Map<String, dynamic>> _progress(List<WorkoutSession> sessions) {
    final byId = <String, List<(DateTime, double)>>{};
    final names = <String, String>{};
    for (final s in sessions) {
      for (final e in s.exercises) {
        final b = e.best1RM;
        if (b == null) continue;
        names[e.exerciseId] = e.exerciseName;
        (byId[e.exerciseId] ??= []).add((s.date, b));
      }
    }
    final ids = byId.keys.toList()
      ..sort((a, b) => byId[b]!.length.compareTo(byId[a]!.length));
    return [
      for (final id in ids.take(12))
        {
          'id': id,
          'name': names[id],
          'best1RM': byId[id]!
              .map((p) => p.$2)
              .reduce(max)
              .toStringAsFixed(1),
          'history': [
            for (final p in (byId[id]!..sort((a, b) => a.$1.compareTo(b.$1)))
                .take(8))
              {'date': _day(p.$1), 'e1rm': double.parse(p.$2.toStringAsFixed(1))},
          ],
        },
    ];
  }

  /// Hasta 4 sustitutos válidos por ejercicio de la semana: misma parte y
  /// músculo, equipo permitido, sin estiramientos, sin repetir los ya usados.
  static Map<String, List<Map<String, String>>> _alternatives(
      List<WorkoutDay> week,
      List<Exercise> catalog,
      UserProfile profile,
      Random rand) {
    final allowedEquipment = profile.equipment.allowedEquipment;
    final inWeek = {
      for (final d in week)
        for (final re in d.exercises) re.exercise.id,
    };
    final result = <String, List<Map<String, String>>>{};
    for (final d in week) {
      for (final re in d.exercises) {
        final ex = re.exercise;
        final pool = catalog
            .where((e) =>
                e.id != ex.id &&
                !e.isStretch &&
                !inWeek.contains(e.id) &&
                e.bodyPart == ex.bodyPart &&
                e.target == ex.target &&
                (allowedEquipment == null ||
                    allowedEquipment.contains(e.equipment)))
            .toList()
          ..shuffle(rand);
        result[ex.id] = [
          for (final e in pool.take(4)) {'id': e.id, 'name': e.name},
        ];
      }
    }
    return result;
  }
}
