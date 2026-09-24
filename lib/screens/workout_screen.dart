import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/coach.dart';
import '../models/routine.dart';
import '../models/training_log.dart';
import '../services/storage.dart';
import '../theme.dart';
import '../util/translations.dart';
import 'summary_screen.dart';

enum _ExitChoice { finish, later, discard }

/// Reproductor del entrenamiento: un ejercicio por página, GIF protagonista,
/// marcado de series con un toque y temporizador de descanso automático.
class WorkoutScreen extends StatefulWidget {
  final WorkoutDay day;

  const WorkoutScreen({super.key, required this.day});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  late final PageController _controller;
  late final DateTime _startedAt;
  late final List<List<SetLog>> _logs;
  late final List<double?> _kg;
  late final List<int> _reps;
  late final List<int?> _rpe;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    final n = widget.day.exercises.length;
    _kg = List.filled(n, null);
    _reps = List.filled(n, 0);
    _rpe = List.filled(n, null);

    final draft = Storage.draftFor(widget.day);
    _startedAt = draft?.startedAt ?? DateTime.now();
    _logs = draft != null
        ? [for (final l in draft.logs) List.of(l)]
        : List.generate(n, (_) => <SetLog>[]);
    _page = draft == null ? 0 : draft.page.clamp(0, n - 1);
    _controller = PageController(initialPage: _page);

    for (var i = 0; i < n; i++) {
      if (_logs[i].isEmpty) {
        _prefill(i);
      } else {
        // Retomado: la siguiente serie parte de la última que registró.
        final last = _logs[i].last;
        _kg[i] = last.kg;
        _reps[i] = last.reps;
        _rpe[i] = last.rpe;
      }
    }

    if (draft != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Retomamos tu entrenamiento: ${draft.doneSets} series guardadas',
            ),
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Guarda el progreso tras cada cambio para no perderlo si la app se cierra.
  void _saveDraft() {
    Storage.saveWorkoutDraft(
      WorkoutDraft(
        title: widget.day.title,
        exerciseIds: [for (final e in widget.day.exercises) e.exercise.id],
        startedAt: _startedAt,
        logs: _logs,
        page: _page,
      ),
    );
  }

  /// Precarga peso y repeticiones desde la última vez que hizo el ejercicio;
  /// si es la primera vez, usa el mínimo de la prescripción.
  void _prefill(int i) {
    final re = widget.day.exercises[i];
    final last = Storage.lastLogFor(re.exercise.id);
    final done = _logs[i].length;
    if (last != null) {
      final ref =
          last.sets[done < last.sets.length ? done : last.sets.length - 1];
      _kg[i] = ref.kg;
      _reps[i] = ref.reps;
      _rpe[i] = ref.rpe;
      // Progresión que decidió el coach: se aplica solo en la primera serie
      // (el usuario ajusta las demás si hace falta).
      if (done == 0) _applyProgression(i, re.exercise.id);
    } else {
      _kg[i] = null;
      _reps[i] = _minReps(re.reps);
      _rpe[i] = null;
    }
  }

  void _applyProgression(int i, String exerciseId) {
    final action = Storage.activePrescription.progression[exerciseId];
    switch (action) {
      case ProgressionAction.addWeight:
        if (_kg[i] != null) _kg[i] = _kg[i]! + 2.5;
      case ProgressionAction.addRep:
        _reps[i] = _reps[i] + 1;
      case ProgressionAction.deload:
        if (_kg[i] != null) {
          _kg[i] = ((_kg[i]! * 0.9) / 2.5).round() * 2.5;
        }
      case ProgressionAction.hold:
      case null:
        break;
    }
  }

  static int _minReps(String reps) =>
      int.tryParse(RegExp(r'\d+').firstMatch(reps)?.group(0) ?? '') ?? 10;

  int get _totalSets => widget.day.exercises.fold(0, (a, re) => a + re.sets);
  int get _doneSets => _logs.fold(0, (a, l) => a + l.length);

  void _tickSet(int index) {
    final re = widget.day.exercises[index];
    if (_logs[index].length >= re.sets) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _logs[index].add(
        SetLog(kg: _kg[index], reps: _reps[index], rpe: _rpe[index]),
      );
    });
    _saveDraft();
    final finishedExercise = _logs[index].length >= re.sets;
    if (finishedExercise && index < widget.day.exercises.length - 1) {
      _showRest(re.restSeconds, thenNextPage: true);
    } else if (!finishedExercise) {
      _showRest(re.restSeconds);
    }
  }

  void _undoSet(int index) {
    if (_logs[index].isEmpty) return;
    setState(() {
      final last = _logs[index].removeLast();
      _kg[index] = last.kg;
      _reps[index] = last.reps;
      _rpe[index] = last.rpe;
    });
    _saveDraft();
  }

  void _showRest(int seconds, {bool thenNextPage = false}) {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      backgroundColor: AppColors.surfaceHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _RestTimer(seconds: seconds),
    ).then((_) {
      if (thenNextPage && mounted) {
        _controller.nextPage(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Construye la sesión con lo registrado. Nula si no se registró nada.
  WorkoutSession? _buildSession() {
    final logs = <ExerciseLog>[
      for (var i = 0; i < widget.day.exercises.length; i++)
        if (_logs[i].isNotEmpty)
          ExerciseLog(
            exerciseId: widget.day.exercises[i].exercise.id,
            exerciseName: widget.day.exercises[i].exercise.name,
            sets: List.unmodifiable(_logs[i]),
          ),
    ];
    if (logs.isEmpty) return null;
    final minutes = DateTime.now().difference(_startedAt).inMinutes;
    return WorkoutSession(
      id: _startedAt.toIso8601String().replaceAll(RegExp(r'[:.]'), ''),
      date: _startedAt,
      title: widget.day.title,
      exercises: logs,
      durationMin: minutes < 1 ? 1 : minutes,
    );
  }

  /// Guarda la sesión y va al resumen. Sin series registradas no hay nada
  /// que guardar: se ofrece salir en vez de contar el día como entrenado.
  Future<void> _finish() async {
    final session = _buildSession();
    if (session == null) {
      final leave = await _confirm(
        title: 'No registraste ninguna serie',
        body: 'Marca al menos una serie para guardar el entrenamiento.',
        confirm: 'Salir sin guardar',
        cancel: 'Seguir entrenando',
      );
      if (leave == true) await _discard();
      return;
    }
    final pending = _totalSets - _doneSets;
    if (pending > 0) {
      final ok = await _confirm(
        title: '¿Terminar el entrenamiento?',
        body: 'Te faltan $pending serie${pending == 1 ? '' : 's'}. '
            'Se guardará lo que registraste.',
        confirm: 'Terminar',
        cancel: 'Seguir entrenando',
      );
      if (ok != true) return;
    }
    await Storage.saveSession(session);
    await Storage.clearWorkoutDraft();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SummaryScreen(day: widget.day, session: session),
      ),
    );
  }

  Future<void> _discard() async {
    await Storage.clearWorkoutDraft();
    if (mounted) Navigator.of(context).pop();
  }

  Future<bool?> _confirm({
    required String title,
    required String body,
    required String confirm,
    required String cancel,
  }) =>
      showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(confirm),
            ),
          ],
        ),
      );

  /// Atrás con series registradas: el progreso ya está guardado como
  /// borrador, así que se puede salir y retomar, terminar o descartar.
  Future<void> _onBack() async {
    final choice = await showModalBottomSheet<_ExitChoice>(
      context: context,
      backgroundColor: AppColors.surfaceHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '¿Salir del entrenamiento?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Llevas $_doneSets de $_totalSets series. '
                'Tu progreso está guardado.',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(_ExitChoice.finish),
                child: const Text('Terminar y guardar'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop(_ExitChoice.later),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('Salir y retomar después'),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(_ExitChoice.discard),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Descartar entrenamiento'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case _ExitChoice.finish:
        await _finish();
      case _ExitChoice.later:
        Navigator.of(context).pop();
      case _ExitChoice.discard:
        final ok = await _confirm(
          title: '¿Descartar el entrenamiento?',
          body: 'Se borrarán las $_doneSets series registradas.',
          confirm: 'Descartar',
          cancel: 'Cancelar',
        );
        if (ok == true) await _discard();
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercises = widget.day.exercises;
    final progress = _totalSets == 0 ? 0.0 : _doneSets / _totalSets;

    return PopScope(
      // Sin series no hay nada que perder: se sale directo.
      canPop: _doneSets == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.day.title, style: const TextStyle(fontSize: 17)),
          actions: [
            TextButton(onPressed: _finish, child: const Text('Terminar')),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: AppColors.surfaceHigh,
                ),
              ),
            ),
          ),
        ),
        body: PageView.builder(
          controller: _controller,
          onPageChanged: (p) {
            setState(() => _page = p);
            if (_doneSets > 0) _saveDraft();
          },
          itemCount: exercises.length,
          itemBuilder: (_, i) => _ExercisePage(
            routineExercise: exercises[i],
            index: i,
            total: exercises.length,
            logs: _logs[i],
            kg: _kg[i],
            reps: _reps[i],
            rpe: _rpe[i],
            onKg: (v) => setState(() => _kg[i] = v),
            onReps: (v) => setState(() => _reps[i] = v),
            onRpe: (v) => setState(() => _rpe[i] = v),
            onTickSet: () => _tickSet(i),
            onUndo: () => _undoSet(i),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                if (_page > 0)
                  IconButton.filledTonal(
                    onPressed: () => _controller.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    ),
                    icon: const Icon(Icons.arrow_back),
                  ),
                const Spacer(),
                Text(
                  '${_page + 1} / ${exercises.length}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const Spacer(),
                if (_page < exercises.length - 1)
                  IconButton.filledTonal(
                    onPressed: () => _controller.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    ),
                    icon: const Icon(Icons.arrow_forward),
                  )
                else
                  FilledButton(
                    onPressed: _finish,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(140, 48),
                    ),
                    child: const Text('Finalizar 🏁'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExercisePage extends StatelessWidget {
  final RoutineExercise routineExercise;
  final int index;
  final int total;
  final List<SetLog> logs;
  final double? kg;
  final int reps;
  final int? rpe;
  final ValueChanged<double?> onKg;
  final ValueChanged<int> onReps;
  final ValueChanged<int?> onRpe;
  final VoidCallback onTickSet;
  final VoidCallback onUndo;

  const _ExercisePage({
    required this.routineExercise,
    required this.index,
    required this.total,
    required this.logs,
    required this.kg,
    required this.reps,
    required this.rpe,
    required this.onKg,
    required this.onReps,
    required this.onRpe,
    required this.onTickSet,
    required this.onUndo,
  });

  @override
  Widget build(BuildContext context) {
    final ex = routineExercise.exercise;
    final setsDone = logs.length;
    final last = Storage.lastLogFor(ex.id);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            color: Colors.white,
            height: 280,
            child: CachedNetworkImage(
              imageUrl: ex.gifUrl,
              fit: BoxFit.contain,
              placeholder: (_, _) => const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              errorWidget: (_, _, _) => const Center(
                child: Icon(
                  Icons.fitness_center,
                  size: 64,
                  color: Colors.black26,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          ex.name,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            Chip(label: Text('🎯 ${trMuscle(ex.target)}')),
            Chip(label: Text(trEquipment(ex.equipment))),
            Chip(label: Text(trDifficulty(ex.difficulty))),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _Stat(label: 'Series', value: '${routineExercise.sets}'),
                  _Stat(label: 'Reps', value: routineExercise.reps),
                  _Stat(
                    label: 'Descanso',
                    value: '${routineExercise.restSeconds}s',
                  ),
                ],
              ),
              if (last != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Última vez: ${_describe(last)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              for (var s = 0; s < routineExercise.sets; s++) ...[
                if (s < setsDone)
                  _DoneSetRow(number: s + 1, log: logs[s])
                else if (s == setsDone)
                  _ActiveSetRow(
                    number: s + 1,
                    bodyweight: ex.equipment == 'body weight',
                    kg: kg,
                    reps: reps,
                    rpe: rpe,
                    onKg: onKg,
                    onReps: onReps,
                    onRpe: onRpe,
                  )
                else
                  _PendingSetRow(number: s + 1, reps: routineExercise.reps),
                const SizedBox(height: 6),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  if (setsDone > 0) ...[
                    IconButton.filledTonal(
                      onPressed: onUndo,
                      tooltip: 'Deshacer última serie',
                      icon: const Icon(Icons.undo),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: FilledButton.icon(
                      onPressed:
                          setsDone < routineExercise.sets ? onTickSet : null,
                      icon: const Icon(Icons.check),
                      label: Text(
                        setsDone < routineExercise.sets
                            ? 'Serie ${setsDone + 1} completada'
                            : 'Ejercicio completado ✅',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Cómo hacerlo',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < ex.steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 11,
                  backgroundColor: AppColors.surfaceHigh,
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ex.steps[i],
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 60),
      ],
    );
  }

  static String _describe(ExerciseLog log) {
    final h = log.heaviest;
    if (h != null) {
      return '${fmtKg(h.kg!)} kg × ${h.reps} · ${log.sets.length} series';
    }
    final reps = log.sets.map((s) => s.reps).join('/');
    return '$reps reps · ${log.sets.length} series';
  }
}

/// "40" o "42.5": sin decimales cuando son cero.
String fmtKg(double kg) =>
    kg == kg.roundToDouble() ? kg.toInt().toString() : kg.toStringAsFixed(1);

/// Serie ya registrada: solo lectura, en acento.
class _DoneSetRow extends StatelessWidget {
  final int number;
  final SetLog log;
  const _DoneSetRow({required this.number, required this.log});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _SetBadge(number: number, done: true),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              log.kg == null
                  ? '${log.reps} reps'
                  : '${fmtKg(log.kg!)} kg × ${log.reps}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (log.rpe != null)
            Text(
              'RPE ${log.rpe}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

/// Serie pendiente: muestra la prescripción, atenuada.
class _PendingSetRow extends StatelessWidget {
  final int number;
  final String reps;
  const _PendingSetRow({required this.number, required this.reps});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          _SetBadge(number: number, done: false),
          const SizedBox(width: 12),
          Text(
            '$reps reps',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Serie en curso: kg y reps con −/+ (o escribir al tocar) y RPE.
class _ActiveSetRow extends StatelessWidget {
  final int number;
  final bool bodyweight;
  final double? kg;
  final int reps;
  final int? rpe;
  final ValueChanged<double?> onKg;
  final ValueChanged<int> onReps;
  final ValueChanged<int?> onRpe;

  const _ActiveSetRow({
    required this.number,
    required this.bodyweight,
    required this.kg,
    required this.reps,
    required this.rpe,
    required this.onKg,
    required this.onReps,
    required this.onRpe,
  });

  Future<void> _typeValue(
    BuildContext context, {
    required String title,
    required String initial,
    required ValueChanged<String> onSubmit,
  }) async {
    final ctrl = TextEditingController(text: initial);
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: const Text('Listo'),
          ),
        ],
      ),
    );
    if (value != null) onSubmit(value);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _SetBadge(number: number, done: false, active: true),
              const SizedBox(width: 8),
              Expanded(
                child: _Stepper(
                  label: bodyweight ? 'kg (opcional)' : 'kg',
                  value:
                      kg == null ? (bodyweight ? 'Corporal' : '—') : fmtKg(kg!),
                  onMinus: kg == null
                      ? null
                      : () => onKg(kg! - 2.5 <= 0 ? null : kg! - 2.5),
                  onPlus: () => onKg((kg ?? 0) + 2.5),
                  onTap: () => _typeValue(
                    context,
                    title: 'Peso (kg)',
                    initial: kg == null ? '' : fmtKg(kg!),
                    onSubmit: (v) =>
                        onKg(double.tryParse(v.replaceAll(',', '.'))),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Stepper(
                  label: 'reps',
                  value: '$reps',
                  onMinus: reps > 1 ? () => onReps(reps - 1) : null,
                  onPlus: () => onReps(reps + 1),
                  onTap: () => _typeValue(
                    context,
                    title: 'Repeticiones',
                    initial: '$reps',
                    onSubmit: (v) {
                      final n = int.tryParse(v);
                      if (n != null && n > 0) onReps(n);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                'Esfuerzo',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  children: [
                    for (final r in const [6, 7, 8, 9, 10])
                      ChoiceChip(
                        label: Text('$r'),
                        selected: rpe == r,
                        visualDensity: VisualDensity.compact,
                        onSelected: (sel) => onRpe(sel ? r : null),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            _rpeHint(rpe),
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  static String _rpeHint(int? rpe) => switch (rpe) {
        null => 'RPE: cuánto te costó (10 = no podías ni una más)',
        6 => 'Fácil, podías hacer 4 o más',
        7 => 'Podías hacer 3 más',
        8 => 'Podías hacer 2 más',
        9 => 'Podías hacer 1 más',
        _ => 'Al fallo, ni una más',
      };
}

class _Stepper extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onMinus;
  final VoidCallback onPlus;
  final VoidCallback onTap;

  const _Stepper({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            _RoundBtn(icon: Icons.remove, onTap: onMinus),
            Expanded(
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    value,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
            _RoundBtn(icon: Icons.add, onTap: onPlus),
          ],
        ),
      ],
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _RoundBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton.filledTonal(
        onPressed: onTap,
        padding: EdgeInsets.zero,
        iconSize: 18,
        icon: Icon(icon),
      ),
    );
  }
}

class _SetBadge extends StatelessWidget {
  final int number;
  final bool done;
  final bool active;
  const _SetBadge({
    required this.number,
    required this.done,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 14,
      backgroundColor: done
          ? AppColors.accent
          : active
              ? AppColors.surface
              : AppColors.surfaceHigh,
      child: done
          ? const Icon(Icons.check, size: 16, color: AppColors.onAccent)
          : Text(
              '$number',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: active ? AppColors.accent : AppColors.textSecondary,
              ),
            ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// Temporizador de descanso en hoja inferior con cuenta regresiva circular.
///
/// Cuenta contra una hora de fin (no por ticks), así sigue exacto aunque la
/// app pase a segundo plano. Al terminar vibra y muestra el aviso antes de
/// cerrarse, para que el usuario note que toca la siguiente serie.
class _RestTimer extends StatefulWidget {
  final int seconds;

  const _RestTimer({required this.seconds});

  @override
  State<_RestTimer> createState() => _RestTimerState();
}

class _RestTimerState extends State<_RestTimer> {
  static const _step = 15;

  late DateTime _endsAt;
  late int _total;
  int _remaining = 0;
  bool _finished = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _total = widget.seconds;
    _endsAt = DateTime.now().add(Duration(seconds: widget.seconds));
    _remaining = widget.seconds;
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
  }

  void _tick() {
    final left = (_endsAt.difference(DateTime.now()).inMilliseconds / 1000)
        .ceil()
        .clamp(0, 1 << 20);
    if (left == _remaining) return;
    // Cuenta atrás táctil en los últimos 3 segundos.
    if (left > 0 && left <= 3) HapticFeedback.selectionClick();
    setState(() => _remaining = left);
    if (left == 0) _finish();
  }

  Future<void> _finish() async {
    _timer?.cancel();
    setState(() => _finished = true);
    SystemSound.play(SystemSoundType.alert);
    for (var i = 0; i < 3; i++) {
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 180));
    }
    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) Navigator.of(context).pop();
  }

  void _adjust(int delta) {
    if (_finished) return;
    final next = _remaining + delta;
    if (next <= 0) {
      Navigator.of(context).pop();
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _endsAt = _endsAt.add(Duration(seconds: delta));
      _remaining = next;
      if (next > _total) _total = next;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static String _format(int s) =>
      s >= 60 ? '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}' : '$s';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _finished ? '¡A LA SIGUIENTE SERIE!' : 'DESCANSO',
              style: TextStyle(
                letterSpacing: 3,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _finished ? AppColors.accent : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _AdjustButton(
                  label: '−$_step',
                  onTap: _finished ? null : () => _adjust(-_step),
                ),
                const SizedBox(width: 20),
                SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    fit: StackFit.expand,
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: _total == 0 ? 0 : _remaining / _total,
                        strokeWidth: 8,
                        backgroundColor: AppColors.surface,
                      ),
                      Center(
                        child: _finished
                            ? const Icon(
                                Icons.check_rounded,
                                size: 56,
                                color: AppColors.accent,
                              )
                            : Text(
                                _format(_remaining),
                                style: const TextStyle(
                                  fontSize: 44,
                                  fontWeight: FontWeight.w800,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                  color: AppColors.textPrimary,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                _AdjustButton(
                  label: '+$_step',
                  onTap: _finished ? null : () => _adjust(_step),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_finished ? 'Continuar' : 'Saltar descanso'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdjustButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _AdjustButton({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: IconButton.filledTonal(
        onPressed: onTap,
        icon: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
