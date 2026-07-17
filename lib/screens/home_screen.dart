import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../models/routine.dart';
import '../services/repository.dart';
import '../services/routine_generator.dart';
import '../services/storage.dart';
import '../theme.dart';
import '../util/translations.dart';
import 'workout_screen.dart';

const _weekdays = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo'
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late List<WorkoutDay> _week;
  late UserProfile _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _profile = Storage.profile!;
    final repo = ExerciseRepository.instance;
    var week = Storage.loadWeek(repo.byId);
    if (week == null) {
      week = RoutineGenerator(repo.all, _profile).generateWeek();
      Storage.saveWeek(week);
    }
    _week = week;
  }

  Future<void> _regenerate() async {
    final week = RoutineGenerator(ExerciseRepository.instance.all, _profile)
        .generateWeek();
    await Storage.saveWeek(week);
    setState(() => _week = week);
  }

  int get _todayIndex => DateTime.now().weekday - 1;

  bool get _weekCompleted {
    final workoutDays = _week.where((d) => !d.isRest).length;
    return workoutDays > 0 && Storage.completedThisWeek >= workoutDays;
  }

  Future<void> _levelUp() async {
    final next = switch (_profile.level) {
      Level.beginner => Level.intermediate,
      _ => Level.advanced,
    };
    final upgraded = UserProfile(
      level: next,
      goal: _profile.goal,
      equipment: _profile.equipment,
      daysPerWeek: _profile.daysPerWeek,
    );
    await Storage.saveProfile(upgraded);
    await Storage.markLevelUpOffered();
    _profile = upgraded;
    await _regenerate();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text('¡Ahora eres nivel ${next.label}! Rutina actualizada 💪')));
  }

  @override
  Widget build(BuildContext context) {
    final today = _week[_todayIndex];
    final streak = Storage.streak;
    final showLevelUp = _weekCompleted &&
        _profile.level != Level.advanced &&
        !Storage.levelUpOfferedThisWeek;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FitApp'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Chip(
              avatar: const Text('🔥'),
              label: Text('$streak',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _regenerate,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _profile.level.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_profile.level.emoji} ${_profile.level.label}',
                    style: TextStyle(
                        color: _profile.level.color,
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                Chip(label: Text(_profile.goal.label)),
              ],
            ),
            if (showLevelUp) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _profile.level.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: _profile.level.color.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🏆 ¡Completaste toda la semana!',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    const Text(
                        'Tu cuerpo está listo para el siguiente reto.',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: _levelUp,
                            style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(44)),
                            child: const Text('Subir de nivel ⬆️'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () async {
                            await Storage.markLevelUpOffered();
                            setState(() {});
                          },
                          child: const Text('Aún no'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            _TodayCard(
              day: today,
              done: Storage.completedToday,
              onStart: today.isRest
                  ? null
                  : () async {
                      await Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => WorkoutScreen(day: today)));
                      setState(() {});
                    },
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tu semana',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                TextButton.icon(
                  onPressed: _regenerate,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Regenerar'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < 7; i++) ...[
              _WeekDayTile(
                weekday: _weekdays[i],
                day: _week[i],
                isToday: i == _todayIndex,
                onTap: _week[i].isRest
                    ? null
                    : () async {
                        await Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => WorkoutScreen(day: _week[i])));
                        setState(() {});
                      },
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  final WorkoutDay day;
  final bool done;
  final VoidCallback? onStart;

  const _TodayCard({required this.day, required this.done, this.onStart});

  @override
  Widget build(BuildContext context) {
    final muscles = day.muscleLoad.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: day.isRest
              ? [AppColors.surface, AppColors.surface]
              : [
                  AppColors.accent.withValues(alpha: 0.16),
                  AppColors.surface,
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: day.isRest
                ? Colors.transparent
                : AppColors.accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('HOY',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Text(day.isRest ? 'Día de descanso 😴' : day.title,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          if (day.isRest)
            const Text('Tus músculos crecen mientras descansas. ¡Vuelve mañana!',
                style: TextStyle(color: AppColors.textSecondary))
          else ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Chip(label: Text('${day.exercises.length} ejercicios')),
                for (final m in muscles.take(3))
                  Chip(label: Text(trMuscle(m.key))),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onStart,
              child: Text(done ? 'Entrenar otra vez ✅' : 'Empezar entrenamiento'),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeekDayTile extends StatelessWidget {
  final String weekday;
  final WorkoutDay day;
  final bool isToday;
  final VoidCallback? onTap;

  const _WeekDayTile({
    required this.weekday,
    required this.day,
    required this.isToday,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isToday ? AppColors.surfaceHigh : AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              SizedBox(
                width: 86,
                child: Text(weekday,
                    style: TextStyle(
                        fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                        color: isToday
                            ? AppColors.accent
                            : AppColors.textSecondary)),
              ),
              Expanded(
                child: Text(
                  day.isRest ? 'Descanso' : day.title,
                  style: TextStyle(
                      color: day.isRest
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w600),
                ),
              ),
              if (!day.isRest)
                const Icon(Icons.chevron_right,
                    color: AppColors.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
