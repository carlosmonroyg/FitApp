import 'package:flutter/material.dart';

import '../models/routine.dart';
import '../services/storage.dart';
import '../theme.dart';
import '../util/translations.dart';
import '../widgets/muscle_body_map.dart';

/// Resumen post-entrenamiento: celebración, racha y mapa de intensidad
/// por músculo (target = intensidad completa, secundarios = parcial).
class SummaryScreen extends StatefulWidget {
  final WorkoutDay day;

  const SummaryScreen({super.key, required this.day});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    Storage.markCompletedToday().then((_) {
      if (mounted) setState(() => _streak = Storage.streak);
    });
  }

  @override
  Widget build(BuildContext context) {
    final load = widget.day.muscleLoad.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxLoad =
        load.isEmpty ? 1.0 : load.first.value;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 24),
                  const Center(
                      child: Text('🎉', style: TextStyle(fontSize: 64))),
                  const SizedBox(height: 12),
                  const Center(
                    child: Text('¡Entrenamiento completado!',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: AppColors.textPrimary)),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text('${widget.day.title} · racha de $_streak 🔥',
                        style:
                            const TextStyle(color: AppColors.textSecondary)),
                  ),
                  const SizedBox(height: 32),
                  const Text('Músculos trabajados hoy',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        MuscleBodyMap(
                          load: {
                            for (final e in load)
                              e.key: e.value / maxLoad,
                          },
                        ),
                        const SizedBox(height: 6),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Text('Frente',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.black54)),
                            Text('Espalda',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.black54)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  for (final entry in load) ...[
                    _MuscleBar(
                      muscle: trMuscle(entry.key),
                      intensity: entry.value / maxLoad,
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Volver al inicio'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MuscleBar extends StatelessWidget {
  final String muscle;
  final double intensity; // 0..1

  const _MuscleBar({required this.muscle, required this.intensity});

  Color get _color {
    if (intensity > 0.66) return const Color(0xFFF87171);
    if (intensity > 0.33) return const Color(0xFFFBBF24);
    return const Color(0xFF4ADE80);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 130,
          child: Text(muscle,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: intensity),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 12,
                backgroundColor: AppColors.surfaceHigh,
                color: _color,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
