import 'package:flutter/material.dart';

import '../models/routine.dart';
import '../models/training_log.dart';
import '../services/storage.dart';
import '../theme.dart';
import '../util/translations.dart';
import '../widgets/muscle_body_map.dart';

/// Resumen post-entrenamiento: celebración, racha y mapa de intensidad
/// por músculo (target = intensidad completa, secundarios = parcial).
class SummaryScreen extends StatefulWidget {
  final WorkoutDay day;

  /// Sesión registrada (nula si el usuario no anotó ninguna serie).
  final WorkoutSession? session;

  const SummaryScreen({super.key, required this.day, this.session});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  int _streak = 0;
  int? _feeling;
  late final List<PersonalRecord> _records;
  late final WorkoutSession? _previous;

  @override
  void initState() {
    super.initState();
    final s = widget.session;
    _records = s == null ? const [] : Storage.recordsIn(s);
    _previous = s == null ? null : Storage.previousSessionLike(s);
    // Solo cuenta como entrenado si registró al menos una serie.
    if (s != null) {
      Storage.markCompletedToday().then((_) {
        if (mounted) setState(() => _streak = Storage.streak);
      });
    }
  }

  Future<void> _setFeeling(int f) async {
    setState(() => _feeling = f);
    final s = widget.session;
    if (s != null) await Storage.saveSession(s.copyWith(feeling: f));
  }

  @override
  Widget build(BuildContext context) {
    final load = widget.day.muscleLoad.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxLoad = load.isEmpty ? 1.0 : load.first.value;

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
                    child: Text('🎉', style: TextStyle(fontSize: 64)),
                  ),
                  const SizedBox(height: 12),
                  const Center(
                    child: Text(
                      '¡Entrenamiento completado!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      '${widget.day.title} · racha de $_streak 🔥',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  if (widget.session != null) ...[
                    const SizedBox(height: 28),
                    _SessionStats(
                      session: widget.session!,
                      previous: _previous,
                    ),
                  ],
                  if (_records.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    for (final r in _records) ...[
                      _RecordTile(record: r),
                      const SizedBox(height: 8),
                    ],
                  ],
                  if (widget.session != null) ...[
                    const SizedBox(height: 20),
                    _FeelingPicker(value: _feeling, onChanged: _setFeeling),
                  ],
                  const SizedBox(height: 32),
                  const Text(
                    'Músculos trabajados hoy',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
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
                            for (final e in load) e.key: e.value / maxLoad,
                          },
                        ),
                        const SizedBox(height: 6),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Text(
                              'Frente',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                            Text(
                              'Espalda',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
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
          child: Text(
            muscle,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
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

/// Tonelaje, series y duración de la sesión, comparados con la anterior
/// del mismo día del split cuando existe.
class _SessionStats extends StatelessWidget {
  final WorkoutSession session;
  final WorkoutSession? previous;

  const _SessionStats({required this.session, required this.previous});

  @override
  Widget build(BuildContext context) {
    final prev = previous;
    final delta = prev == null || prev.volume == 0
        ? null
        : (session.volume - prev.volume) / prev.volume;
    return Container(
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
              _Big(
                value: session.volume >= 1000
                    ? '${(session.volume / 1000).toStringAsFixed(1)} t'
                    : '${session.volume.round()} kg',
                label: 'Levantado',
              ),
              _Big(value: '${session.totalSets}', label: 'Series'),
              _Big(value: '${session.durationMin} min', label: 'Duración'),
            ],
          ),
          if (delta != null) ...[
            const SizedBox(height: 12),
            Text(
              delta >= 0
                  ? '▲ ${(delta * 100).round()} % más volumen que la última vez'
                  : '▼ ${(-delta * 100).round()} % menos volumen que la última vez',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: delta >= 0
                    ? const Color(0xFF4ADE80)
                    : AppColors.textSecondary,
              ),
            ),
          ] else if (session.volume > 0) ...[
            const SizedBox(height: 12),
            const Text(
              'Primera sesión registrada de este día: tu punto de partida.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _Big extends StatelessWidget {
  final String value;
  final String label;
  const _Big({required this.value, required this.label});

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

class _RecordTile extends StatelessWidget {
  final PersonalRecord record;
  const _RecordTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final kg = record.set.kg!;
    final kgText = kg == kg.roundToDouble()
        ? kg.toInt().toString()
        : kg.toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.previous1RM == null
                      ? 'Primer registro con peso'
                      : '¡Nuevo récord personal!',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${record.exerciseName} · $kgText kg × ${record.set.reps}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Cómo se sintió la sesión (1-5). Dato clave para que el coach module
/// la carga: dos semanas de "fatal" valen más que cualquier número.
class _FeelingPicker extends StatelessWidget {
  final int? value;
  final ValueChanged<int> onChanged;
  const _FeelingPicker({required this.value, required this.onChanged});

  static const _faces = ['😫', '😕', '😐', '🙂', '🤩'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '¿Cómo te sentiste?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < 5; i++)
              InkWell(
                onTap: () => onChanged(i + 1),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: value == i + 1
                        ? AppColors.accent.withValues(alpha: 0.2)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: value == i + 1
                          ? AppColors.accent
                          : Colors.transparent,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _faces[i],
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
