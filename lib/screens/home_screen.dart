import 'package:flutter/material.dart';

import '../models/phase.dart';
import '../models/coach.dart';
import '../models/profile.dart';
import '../models/routine.dart';
import '../models/training_log.dart';
import '../services/repository.dart';
import '../services/routine_generator.dart';
import '../services/storage.dart';
import '../theme.dart';
import '../util/translations.dart';
import '../services/coach_service.dart';
import 'checkin_screen.dart';
import 'measurements_screen.dart';
import 'workout_screen.dart';

const _weekdays = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
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
    // Al entrar en una fase nueva la rutina guardada ya no sirve: cambian
    // series, repeticiones y descansos.
    if (week == null || Storage.weekPhase != Storage.currentPhase.name) {
      week = RoutineGenerator(
        repo.all,
        _profile,
        phase: Storage.currentPhase,
        prescription: Storage.activePrescription,
      ).generateWeek();
      Storage.saveWeek(week);
    }
    _week = week;
  }

  /// Regenerar reemplaza toda la semana: se confirma antes.
  Future<void> _confirmRegenerate() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Generar una semana nueva?'),
        content: const Text(
          'Se reemplazarán los ejercicios de toda la semana. '
          'Tu historial y récords no se pierden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Regenerar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _regenerate();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Semana nueva lista')));
  }

  Future<void> _regenerate() async {
    final week = RoutineGenerator(
      ExerciseRepository.instance.all,
      _profile,
      phase: Storage.currentPhase,
      prescription: Storage.activePrescription,
    ).generateWeek();
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
    final upgraded = _profile.copyWith(level: next);
    await Storage.saveProfile(upgraded);
    await Storage.markLevelUpOffered();
    _profile = upgraded;
    await _regenerate();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('¡Ahora eres nivel ${next.label}! Rutina actualizada 💪'),
      ),
    );
  }

  /// Toma de medidas pendiente: nunca midió o pasaron 7 días o más.
  bool get _measurementDue {
    final days = Storage.daysSinceMeasurement;
    return days == null || days >= 7;
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
              label: Text(
                '$streak',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _profile.level.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_profile.level.emoji} ${_profile.level.label}',
                  style: TextStyle(
                    color: _profile.level.color,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
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
                  color: _profile.level.color.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🏆 ¡Completaste toda la semana!',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tu cuerpo está listo para el siguiente reto.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: _levelUp,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                          ),
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
          if (_measurementDue) ...[
            const SizedBox(height: 20),
            _MeasureReminder(
              firstTime: Storage.latestMeasurement == null,
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MeasurementsScreen()),
                );
                setState(() {});
              },
            ),
          ],
          if (CoachService.isAvailable) ...[
            const SizedBox(height: 20),
            _CoachCard(
              checkin: CoachService.thisWeekCheckin,
              due: CoachService.checkinDue(_week),
              completed: Storage.completedThisWeek,
              planned: _week.where((d) => !d.isRest).length,
              onOpen: () async {
                final applied = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) =>
                        CheckinScreen(initial: CoachService.thisWeekCheckin),
                  ),
                );
                if (!mounted) return;
                if (applied == true) _load();
                setState(() {});
              },
            ),
          ],
          const SizedBox(height: 20),
          _PhaseCard(phase: Storage.currentPhase, week: Storage.programWeek),
          const SizedBox(height: 20),
          _TodayCard(
            day: today,
            done: Storage.completedToday,
            draft: today.isRest ? null : Storage.draftFor(today),
            onStart: today.isRest
                ? null
                : () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => WorkoutScreen(day: today),
                      ),
                    );
                    setState(() {});
                  },
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tu semana',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              TextButton.icon(
                onPressed: _confirmRegenerate,
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
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => WorkoutScreen(day: _week[i]),
                        ),
                      );
                      setState(() {});
                    },
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

/// Dónde va el usuario dentro del programa guiado y qué buscar esta fase.
class _PhaseCard extends StatelessWidget {
  final TrainingPhase phase;
  final int week;

  const _PhaseCard({required this.phase, required this.week});

  @override
  Widget build(BuildContext context) {
    final inCycle = weekInCycle(week);
    final cycle = cycleOf(week);
    final weekInPhase = inCycle - phase.firstWeek + 1;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(phase.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fase ${phase.index + 1} · ${phase.label}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      phase.aim,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                cycle > 1
                    ? 'Sem $inCycle/$programWeeks · ciclo $cycle'
                    : 'Sem $inCycle/$programWeeks',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 1; i <= weeksPerPhase; i++)
                Expanded(
                  child: Container(
                    height: 5,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: i <= weekInPhase
                          ? AppColors.accent
                          : AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            phase.guidance,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  final WorkoutDay day;
  final bool done;

  /// Entrenamiento de hoy a medias, para ofrecer continuarlo.
  final WorkoutDraft? draft;
  final VoidCallback? onStart;

  const _TodayCard({
    required this.day,
    required this.done,
    this.draft,
    this.onStart,
  });

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
              : [AppColors.accent.withValues(alpha: 0.16), AppColors.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: day.isRest
              ? Colors.transparent
              : AppColors.accent.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HOY',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            day.isRest ? 'Día de descanso 😴' : day.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          if (day.isRest)
            const Text(
              'Tus músculos crecen mientras descansas. ¡Vuelve mañana!',
              style: TextStyle(color: AppColors.textSecondary),
            )
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
            if (draft != null) ...[
              Text(
                'Tienes un entrenamiento a medias: '
                '${draft!.doneSets} series registradas.',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
            ],
            FilledButton(
              onPressed: onStart,
              child: Text(
                draft != null
                    ? 'Continuar entrenamiento'
                    : done
                        ? 'Entrenar otra vez ✅'
                        : 'Empezar entrenamiento',
              ),
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
                child: Text(
                  weekday,
                  style: TextStyle(
                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                    color: isToday ? AppColors.accent : AppColors.textSecondary,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  day.isRest ? 'Descanso' : day.title,
                  style: TextStyle(
                    color: day.isRest
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!day.isRest)
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Recordatorio semanal de medidas: sin datos de cuerpo el coach va a ciegas.
class _MeasureReminder extends StatelessWidget {
  final bool firstTime;
  final VoidCallback onTap;
  const _MeasureReminder({required this.firstTime, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Text('📏', style: TextStyle(fontSize: 26)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    firstTime
                        ? 'Registra tu punto de partida'
                        : 'Toca medirse esta semana',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    firstTime
                        ? 'Peso y medidas: 1 minuto, una vez por semana.'
                        : 'Mismo día, en ayunas, para comparar bien.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// Estado del coach esta semana: foco vigente, revisión lista para pedir,
/// o cuántas sesiones faltan para que tenga algo que revisar.
class _CoachCard extends StatelessWidget {
  final CoachCheckin? checkin;
  final bool due;
  final int completed;
  final int planned;
  final VoidCallback onOpen;

  const _CoachCard({
    required this.checkin,
    required this.due,
    required this.completed,
    required this.planned,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final c = checkin;
    final String title;
    final String body;
    final String action;
    if (c != null) {
      title = c.weekFocus.isNotEmpty ? c.weekFocus : 'Revisión de esta semana';
      body = c.applied
          ? 'Cambios aplicados a tu semana.'
          : c.changes.isEmpty
              ? 'Tu coach revisó la semana: el plan sigue igual.'
              : '${c.changes.length} cambio${c.changes.length == 1 ? '' : 's'} propuestos para tu próxima semana.';
      action = 'Ver revisión';
    } else if (due) {
      title = 'Tu revisión semanal está lista';
      body = 'Tu coach revisa lo que hiciste y ajusta la próxima semana.';
      action = 'Pedir revisión';
    } else {
      title = 'Tu coach';
      body =
          '$completed de $planned sesiones esta semana. La revisión llega el fin de semana.';
      action = 'Pedir ahora';
    }
    final highlight = due && c == null;
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: highlight
              ? AppColors.accent.withValues(alpha: 0.14)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: highlight
                ? AppColors.accent.withValues(alpha: 0.6)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.auto_awesome, color: AppColors.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      height: 1.25,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    body,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    action,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
