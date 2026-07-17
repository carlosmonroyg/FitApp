import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/routine.dart';
import '../theme.dart';
import '../util/translations.dart';
import 'summary_screen.dart';

/// Reproductor del entrenamiento: un ejercicio por página, GIF protagonista,
/// marcado de series con un toque y temporizador de descanso automático.
class WorkoutScreen extends StatefulWidget {
  final WorkoutDay day;

  const WorkoutScreen({super.key, required this.day});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  final _controller = PageController();
  late final List<int> _setsDone;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _setsDone = List.filled(widget.day.exercises.length, 0);
  }

  int get _totalSets =>
      widget.day.exercises.fold(0, (a, re) => a + re.sets);
  int get _doneSets => _setsDone.fold(0, (a, b) => a + b);

  void _tickSet(int index) {
    final re = widget.day.exercises[index];
    if (_setsDone[index] >= re.sets) return;
    setState(() => _setsDone[index]++);
    final finishedExercise = _setsDone[index] >= re.sets;
    if (finishedExercise && index < widget.day.exercises.length - 1) {
      _showRest(re.restSeconds, thenNextPage: true);
    } else if (!finishedExercise) {
      _showRest(re.restSeconds);
    }
  }

  void _showRest(int seconds, {bool thenNextPage = false}) {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      backgroundColor: AppColors.surfaceHigh,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _RestTimer(seconds: seconds),
    ).then((_) {
      if (thenNextPage && mounted) {
        _controller.nextPage(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut);
      }
    });
  }

  void _finish() {
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => SummaryScreen(day: widget.day)));
  }

  @override
  Widget build(BuildContext context) {
    final exercises = widget.day.exercises;
    final progress = _totalSets == 0 ? 0.0 : _doneSets / _totalSets;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.day.title, style: const TextStyle(fontSize: 17)),
        actions: [
          TextButton(
            onPressed: _finish,
            child: const Text('Terminar'),
          ),
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
        onPageChanged: (p) => setState(() => _page = p),
        itemCount: exercises.length,
        itemBuilder: (_, i) => _ExercisePage(
          routineExercise: exercises[i],
          index: i,
          total: exercises.length,
          setsDone: _setsDone[i],
          onTickSet: () => _tickSet(i),
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
                      curve: Curves.easeOut),
                  icon: const Icon(Icons.arrow_back),
                ),
              const Spacer(),
              Text('${_page + 1} / ${exercises.length}',
                  style: const TextStyle(color: AppColors.textSecondary)),
              const Spacer(),
              if (_page < exercises.length - 1)
                IconButton.filledTonal(
                  onPressed: () => _controller.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut),
                  icon: const Icon(Icons.arrow_forward),
                )
              else
                FilledButton(
                  onPressed: _finish,
                  style: FilledButton.styleFrom(
                      minimumSize: const Size(140, 48)),
                  child: const Text('Finalizar 🏁'),
                ),
            ],
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
  final int setsDone;
  final VoidCallback onTickSet;

  const _ExercisePage({
    required this.routineExercise,
    required this.index,
    required this.total,
    required this.setsDone,
    required this.onTickSet,
  });

  @override
  Widget build(BuildContext context) {
    final ex = routineExercise.exercise;
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
                  child: CircularProgressIndicator(strokeWidth: 2)),
              errorWidget: (_, _, _) => const Center(
                  child: Icon(Icons.fitness_center,
                      size: 64, color: Colors.black26)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(ex.name,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: AppColors.textPrimary)),
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
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _Stat(label: 'Series', value: '${routineExercise.sets}'),
                  _Stat(label: 'Reps', value: routineExercise.reps),
                  _Stat(
                      label: 'Descanso',
                      value: '${routineExercise.restSeconds}s'),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var s = 0; s < routineExercise.sets; s++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: s < setsDone
                            ? AppColors.accent
                            : AppColors.surfaceHigh,
                        child: Text('${s + 1}',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: s < setsDone
                                    ? AppColors.onAccent
                                    : AppColors.textSecondary)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed:
                    setsDone < routineExercise.sets ? onTickSet : null,
                icon: const Icon(Icons.check),
                label: Text(setsDone < routineExercise.sets
                    ? 'Serie ${setsDone + 1} completada'
                    : 'Ejercicio completado ✅'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('Cómo hacerlo',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary)),
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
                  child: Text('${i + 1}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.accent)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(ex.steps[i],
                      style: const TextStyle(
                          color: AppColors.textSecondary, height: 1.4)),
                ),
              ],
            ),
          ),
        const SizedBox(height: 60),
      ],
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
        Text(value,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary)),
        Text(label,
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}

/// Temporizador de descanso en hoja inferior con cuenta regresiva circular.
class _RestTimer extends StatefulWidget {
  final int seconds;

  const _RestTimer({required this.seconds});

  @override
  State<_RestTimer> createState() => _RestTimerState();
}

class _RestTimerState extends State<_RestTimer> {
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining <= 1) {
        Navigator.of(context).pop();
      } else {
        setState(() => _remaining--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('DESCANSO',
              style: TextStyle(
                  letterSpacing: 3,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              fit: StackFit.expand,
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: _remaining / widget.seconds,
                  strokeWidth: 8,
                  backgroundColor: AppColors.surface,
                ),
                Center(
                  child: Text('$_remaining',
                      style: const TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Saltar descanso'),
          ),
        ],
      ),
    );
  }
}
