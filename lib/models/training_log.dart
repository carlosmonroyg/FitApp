/// Registro real de lo que el usuario hizo en cada serie: peso, repeticiones
/// y esfuerzo percibido (RPE 1-10). Es la materia prima del coach: sin esto
/// solo sabríamos que "entrenó", no cómo le fue.
class SetLog {
  /// Kilos usados. Nulo en ejercicios con el peso corporal.
  final double? kg;
  final int reps;

  /// Esfuerzo percibido 1-10 (10 = no podía hacer ni una más). Opcional.
  final int? rpe;

  const SetLog({this.kg, required this.reps, this.rpe});

  /// Tonelaje de la serie (kg × reps). Cero si no hay peso.
  double get volume => (kg ?? 0) * reps;

  /// 1RM estimado con la fórmula de Epley. Nulo sin peso.
  double? get estimated1RM =>
      kg == null || reps <= 0 ? null : kg! * (1 + reps / 30);

  Map<String, dynamic> toJson() => {
        if (kg != null) 'kg': kg,
        'reps': reps,
        if (rpe != null) 'rpe': rpe,
      };

  factory SetLog.fromJson(Map<String, dynamic> j) => SetLog(
        kg: (j['kg'] as num?)?.toDouble(),
        reps: j['reps'] as int,
        rpe: j['rpe'] as int?,
      );
}

class ExerciseLog {
  final String exerciseId;
  final String exerciseName;
  final List<SetLog> sets;

  const ExerciseLog({
    required this.exerciseId,
    required this.exerciseName,
    required this.sets,
  });

  double get volume => sets.fold(0, (a, s) => a + s.volume);

  /// Mejor 1RM estimado entre las series de la sesión.
  double? get best1RM {
    double? best;
    for (final s in sets) {
      final e = s.estimated1RM;
      if (e != null && (best == null || e > best)) best = e;
    }
    return best;
  }

  /// Serie más pesada (para mostrar "40 kg × 10").
  SetLog? get heaviest {
    SetLog? best;
    for (final s in sets) {
      if (s.kg == null) continue;
      if (best == null ||
          s.kg! > best.kg! ||
          (s.kg == best.kg && s.reps > best.reps)) {
        best = s;
      }
    }
    return best;
  }

  Map<String, dynamic> toJson() => {
        'id': exerciseId,
        'name': exerciseName,
        'sets': sets.map((s) => s.toJson()).toList(),
      };

  factory ExerciseLog.fromJson(Map<String, dynamic> j) => ExerciseLog(
        exerciseId: j['id'] as String,
        exerciseName: (j['name'] as String?) ?? '',
        sets: (j['sets'] as List)
            .map((s) => SetLog.fromJson(Map<String, dynamic>.from(s as Map)))
            .toList(),
      );
}

/// Una sesión de entrenamiento completada.
class WorkoutSession {
  /// Identificador estable: fecha-hora de inicio en ISO 8601.
  final String id;
  final DateTime date;
  final String title;
  final List<ExerciseLog> exercises;
  final int durationMin;

  /// Cómo se sintió la sesión, 1 (fatal) a 5 (genial). Opcional.
  final int? feeling;
  final String? note;

  const WorkoutSession({
    required this.id,
    required this.date,
    required this.title,
    required this.exercises,
    required this.durationMin,
    this.feeling,
    this.note,
  });

  double get volume => exercises.fold(0, (a, e) => a + e.volume);
  int get totalSets => exercises.fold(0, (a, e) => a + e.sets.length);

  /// RPE medio de la sesión (solo series con RPE).
  double? get avgRpe {
    final values = [
      for (final e in exercises)
        for (final s in e.sets)
          if (s.rpe != null) s.rpe!,
    ];
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  WorkoutSession copyWith({int? feeling, String? note}) => WorkoutSession(
        id: id,
        date: date,
        title: title,
        exercises: exercises,
        durationMin: durationMin,
        feeling: feeling ?? this.feeling,
        note: note ?? this.note,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'title': title,
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'durationMin': durationMin,
        if (feeling != null) 'feeling': feeling,
        if (note != null) 'note': note,
      };

  factory WorkoutSession.fromJson(Map<String, dynamic> j) => WorkoutSession(
        id: j['id'] as String,
        date: DateTime.parse(j['date'] as String),
        title: (j['title'] as String?) ?? '',
        exercises: (j['exercises'] as List)
            .map((e) =>
                ExerciseLog.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        durationMin: (j['durationMin'] as int?) ?? 0,
        feeling: j['feeling'] as int?,
        note: j['note'] as String?,
      );
}

/// Entrenamiento a medias, guardado tras cada serie para poder retomarlo si
/// el usuario sale o el sistema cierra la app.
class WorkoutDraft {
  final String title;

  /// Ejercicios del día en orden: identifica que el borrador es de esta rutina.
  final List<String> exerciseIds;
  final DateTime startedAt;

  /// Series hechas por ejercicio, en el mismo orden que [exerciseIds].
  final List<List<SetLog>> logs;
  final int page;

  /// Pasado este tiempo el borrador ya no se ofrece para retomar.
  static const maxAge = Duration(hours: 12);

  const WorkoutDraft({
    required this.title,
    required this.exerciseIds,
    required this.startedAt,
    required this.logs,
    this.page = 0,
  });

  bool get isStale => DateTime.now().difference(startedAt) > maxAge;

  int get doneSets => logs.fold(0, (a, l) => a + l.length);

  /// Si pertenece a la rutina [title] con estos ejercicios, en el mismo orden.
  bool matches(String title, List<String> exerciseIds) =>
      this.title == title &&
      this.exerciseIds.length == exerciseIds.length &&
      Iterable.generate(
        exerciseIds.length,
      ).every((i) => this.exerciseIds[i] == exerciseIds[i]);

  Map<String, dynamic> toJson() => {
        'title': title,
        'exerciseIds': exerciseIds,
        'startedAt': startedAt.toIso8601String(),
        'logs': [
          for (final l in logs) [for (final s in l) s.toJson()],
        ],
        'page': page,
      };

  factory WorkoutDraft.fromJson(Map<String, dynamic> j) => WorkoutDraft(
        title: j['title'] as String,
        exerciseIds: (j['exerciseIds'] as List).cast<String>(),
        startedAt: DateTime.parse(j['startedAt'] as String),
        logs: [
          for (final l in j['logs'] as List)
            [
              for (final s in l as List)
                SetLog.fromJson(Map<String, dynamic>.from(s as Map)),
            ],
        ],
        page: (j['page'] as int?) ?? 0,
      );
}

/// Récord personal detectado al comparar una sesión con el historial.
class PersonalRecord {
  final String exerciseId;
  final String exerciseName;
  final SetLog set;

  /// 1RM estimado anterior (nulo si es la primera vez con peso).
  final double? previous1RM;

  const PersonalRecord({
    required this.exerciseId,
    required this.exerciseName,
    required this.set,
    this.previous1RM,
  });
}
