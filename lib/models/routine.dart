import 'exercise.dart';

class RoutineExercise {
  final Exercise exercise;
  final int sets;
  final String reps;
  final int restSeconds;

  const RoutineExercise({
    required this.exercise,
    required this.sets,
    required this.reps,
    required this.restSeconds,
  });

  Map<String, dynamic> toJson() => {
        'id': exercise.id,
        'sets': sets,
        'reps': reps,
        'rest': restSeconds,
      };
}

class WorkoutDay {
  final String title;
  final List<RoutineExercise> exercises;

  const WorkoutDay({required this.title, required this.exercises});

  bool get isRest => exercises.isEmpty;

  /// Músculo -> intensidad relativa (target suma 1.0, secundario 0.4).
  Map<String, double> get muscleLoad {
    final map = <String, double>{};
    for (final re in exercises) {
      map[re.exercise.target] = (map[re.exercise.target] ?? 0) + 1.0;
      for (final m in re.exercise.secondaryMuscles) {
        map[m] = (map[m] ?? 0) + 0.4;
      }
    }
    return map;
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'items': exercises.map((e) => e.toJson()).toList(),
      };

  factory WorkoutDay.fromJson(
      Map<String, dynamic> j, Exercise Function(String id) resolve) {
    return WorkoutDay(
      title: j['title'] as String,
      exercises: (j['items'] as List)
          .map((it) => RoutineExercise(
                exercise: resolve(it['id'] as String),
                sets: it['sets'] as int,
                reps: it['reps'] as String,
                restSeconds: it['rest'] as int,
              ))
          .toList(),
    );
  }
}
