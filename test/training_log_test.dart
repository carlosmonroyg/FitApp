import 'package:fitapp/models/measurement.dart';
import 'package:fitapp/models/training_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SetLog', () {
    test('volumen y 1RM (Epley)', () {
      const s = SetLog(kg: 60, reps: 10, rpe: 8);
      expect(s.volume, 600);
      expect(s.estimated1RM, closeTo(80, 0.001));
    });

    test('sin peso no hay 1RM ni volumen', () {
      const s = SetLog(reps: 15);
      expect(s.volume, 0);
      expect(s.estimated1RM, isNull);
    });

    test('serializa ida y vuelta', () {
      const s = SetLog(kg: 42.5, reps: 8, rpe: 9);
      final back = SetLog.fromJson(s.toJson());
      expect(back.kg, 42.5);
      expect(back.reps, 8);
      expect(back.rpe, 9);
    });
  });

  group('ExerciseLog', () {
    const log = ExerciseLog(exerciseId: 'x', exerciseName: 'Press', sets: [
      SetLog(kg: 40, reps: 12),
      SetLog(kg: 50, reps: 8),
      SetLog(kg: 50, reps: 10),
    ]);

    test('serie más pesada prioriza kg y luego reps', () {
      expect(log.heaviest!.kg, 50);
      expect(log.heaviest!.reps, 10);
    });

    test('mejor 1RM entre series', () {
      // 50 × 10 → 66.7; 50 × 8 → 63.3; 40 × 12 → 56
      expect(log.best1RM, closeTo(66.67, 0.01));
    });

    test('volumen total', () {
      expect(log.volume, 40 * 12 + 50 * 8 + 50 * 10);
    });
  });

  group('WorkoutSession', () {
    test('RPE medio ignora series sin RPE y serializa', () {
      final s = WorkoutSession(
        id: 'a',
        date: DateTime(2026, 9, 10, 8),
        title: 'Empuje',
        durationMin: 45,
        exercises: const [
          ExerciseLog(exerciseId: 'x', exerciseName: 'A', sets: [
            SetLog(kg: 20, reps: 10, rpe: 7),
            SetLog(kg: 20, reps: 10),
            SetLog(kg: 20, reps: 10, rpe: 9),
          ]),
        ],
        feeling: 4,
      );
      expect(s.avgRpe, 8);
      expect(s.totalSets, 3);
      final back = WorkoutSession.fromJson(s.toJson());
      expect(back.feeling, 4);
      expect(back.exercises.single.sets.length, 3);
      expect(back.date, s.date);
    });
  });

  group('Medidas', () {
    test('tendencia usa primera y última toma con dato', () {
      final history = [
        Measurement(
            dayKey: '2026-08-01',
            date: DateTime(2026, 8, 1),
            weightKg: 80,
            waistCm: 92),
        Measurement(
            dayKey: '2026-08-08', date: DateTime(2026, 8, 8), weightKg: 79),
        Measurement(
            dayKey: '2026-08-15',
            date: DateTime(2026, 8, 15),
            weightKg: 78.5,
            waistCm: 90),
      ];
      final w = trendFor(history, MeasureKind.weight)!;
      expect(w.delta, closeTo(-1.5, 0.001));
      expect(w.days, 14);
      final waist = trendFor(history, MeasureKind.waist)!;
      expect(waist.delta, -2);
      expect(trendFor(history, MeasureKind.hip), isNull);
    });

    test('ratio cintura/cadera', () {
      final m = Measurement(
          dayKey: '2026-08-01',
          date: DateTime(2026, 8, 1),
          waistCm: 85,
          hipCm: 100);
      expect(m.waistHipRatio, closeTo(0.85, 0.001));
      expect(m.isEmpty, isFalse);
      expect(
          Measurement(dayKey: 'k', date: DateTime(2026)).isEmpty, isTrue);
    });
  });

  group('WorkoutDraft', () {
    final draft = WorkoutDraft(
      title: 'Empuje',
      exerciseIds: const ['a', 'b'],
      startedAt: DateTime.now().subtract(const Duration(minutes: 20)),
      logs: const [
        [SetLog(kg: 40, reps: 10, rpe: 8), SetLog(kg: 40, reps: 9)],
        [],
      ],
      page: 1,
    );

    test('ida y vuelta por JSON conserva series y página', () {
      final back = WorkoutDraft.fromJson(draft.toJson());
      expect(back.title, 'Empuje');
      expect(back.doneSets, 2);
      expect(back.page, 1);
      expect(back.logs[0][1].reps, 9);
      expect(back.logs[1], isEmpty);
      expect(back.startedAt, draft.startedAt);
    });

    test('solo coincide con la misma rutina en el mismo orden', () {
      expect(draft.matches('Empuje', ['a', 'b']), isTrue);
      expect(draft.matches('Empuje', ['b', 'a']), isFalse);
      expect(draft.matches('Empuje', ['a']), isFalse);
      expect(draft.matches('Tirón', ['a', 'b']), isFalse);
    });

    test('caduca a las 12 horas', () {
      expect(draft.isStale, isFalse);
      final old = WorkoutDraft(
        title: 'Empuje',
        exerciseIds: const ['a'],
        startedAt: DateTime.now().subtract(const Duration(hours: 13)),
        logs: const [[]],
      );
      expect(old.isStale, isTrue);
    });
  });
}
