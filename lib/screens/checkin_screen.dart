import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/coach.dart';
import '../services/coach_service.dart';
import '../theme.dart';
import '../util/translations.dart';

/// Revisión semanal del coach: qué pasó, qué cambia y por qué. El usuario
/// decide si aplica los cambios a su próxima semana.
class CheckinScreen extends StatefulWidget {
  /// Check-in ya recibido; si es nulo, se pide al servidor al abrir.
  final CoachCheckin? initial;

  const CheckinScreen({super.key, this.initial});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  CoachCheckin? _checkin;
  String? _error;
  bool _loading = false;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _checkin = widget.initial;
    if (_checkin == null) _request();
  }

  Future<void> _request({bool force = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final c = await CoachService.requestCheckin(force: force);
      if (mounted) setState(() => _checkin = c);
    } on CoachException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Algo falló: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _apply() async {
    final c = _checkin;
    if (c == null) return;
    setState(() => _applying = true);
    await CoachService.apply(c);
    if (!mounted) return;
    setState(() {
      _checkin = c.copyWith(applied: true);
      _applying = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Semana actualizada con tu coach 💪')));
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tu coach'),
        actions: [
          if (kDebugMode && !_loading)
            IconButton(
              tooltip: 'Volver a pedir (desarrollo)',
              onPressed: () => _request(force: true),
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: _loading
          ? const _Thinking()
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _request)
              : _CheckinView(
                  checkin: _checkin!,
                  applying: _applying,
                  onApply: _apply,
                ),
    );
  }
}

class _Thinking extends StatefulWidget {
  const _Thinking();

  @override
  State<_Thinking> createState() => _ThinkingState();
}

class _ThinkingState extends State<_Thinking> {
  static const _steps = [
    'Leyendo tus sesiones…',
    'Comparando con la semana pasada…',
    'Revisando tus medidas…',
    'Decidiendo qué ajustar…',
  ];
  int _i = 0;

  @override
  void initState() {
    super.initState();
    _tick();
  }

  Future<void> _tick() async {
    while (mounted) {
      await Future<void>.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      setState(() => _i = (_i + 1) % _steps.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(strokeWidth: 3)),
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _steps[_i],
              key: ValueKey(_i),
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Tu coach está revisando tu semana',
              style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🤕', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 16, height: 1.4)),
          const SizedBox(height: 24),
          FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}

class _CheckinView extends StatelessWidget {
  final CoachCheckin checkin;
  final bool applying;
  final VoidCallback onApply;

  const _CheckinView({
    required this.checkin,
    required this.applying,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final c = checkin;
    final canApply = c.changes.isNotEmpty && !c.applied && !c.seekProfessional;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (c.weekFocus.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('FOCO DE LA SEMANA',
                          style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w800,
                              color: AppColors.accent)),
                      const SizedBox(height: 6),
                      Text(c.weekFocus,
                          style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              height: 1.25,
                              color: AppColors.textPrimary)),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              Text(c.summary,
                  style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: AppColors.textPrimary)),
              if (c.highlights.isNotEmpty) ...[
                const SizedBox(height: 18),
                for (final h in c.highlights)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 7),
                          child: CircleAvatar(
                              radius: 3, backgroundColor: AppColors.accent),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(h,
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  height: 1.4)),
                        ),
                      ],
                    ),
                  ),
              ],
              if (c.seekProfessional) ...[
                const SizedBox(height: 16),
                _Warning(
                    text: c.seekProfessionalReason ??
                        'Por lo que registraste, conviene que te vea un profesional antes de seguir cargando.'),
              ],
              const SizedBox(height: 24),
              Text(
                c.changes.isEmpty
                    ? 'Sin cambios esta semana'
                    : 'Cambios para la próxima semana',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),
              if (c.changes.isEmpty)
                const Text(
                    'Tu plan sigue igual: cuando el plan funciona, no se toca.',
                    style: TextStyle(color: AppColors.textSecondary)),
              for (final ch in c.changes) ...[
                _ChangeTile(change: ch),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 90),
            ],
          ),
        ),
        if (canApply || c.applied)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: c.applied
                  ? const _AppliedBadge()
                  : FilledButton.icon(
                      onPressed: applying ? null : onApply,
                      icon: applying
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.onAccent))
                          : const Icon(Icons.auto_awesome),
                      label: const Text('Aplicar a mi próxima semana'),
                    ),
            ),
          ),
      ],
    );
  }
}

class _AppliedBadge extends StatelessWidget {
  const _AppliedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, color: AppColors.accent, size: 20),
          SizedBox(width: 8),
          Text('Aplicado a tu semana',
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _Warning extends StatelessWidget {
  final String text;
  const _Warning({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFBBF24).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: AppColors.textPrimary, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _ChangeTile extends StatelessWidget {
  final CoachChange change;
  const _ChangeTile({required this.change});

  (String, String) _describe() => switch (change.type) {
        'sets' => (
            change.delta! > 0 ? '➕' : '➖',
            '${change.delta! > 0 ? '+1' : '−1'} serie en ${trBodyPart(change.bodyPart ?? '')}',
          ),
        'rest' => (
            '⏱️',
            'Descanso ${change.delta! > 0 ? '+' : '−'}${change.delta!.abs()} s',
          ),
        'swap' => ('🔁', 'Cambia a ${change.toName ?? change.toId}'),
        'progression' => (
            '📈',
            '${change.action?.label ?? ''} · ${change.exerciseName ?? ''}',
          ),
        'avoid' => ('🚫', 'Fuera del plan: ${change.exerciseName ?? ''}'),
        _ => ('•', change.type),
      };

  @override
  Widget build(BuildContext context) {
    final (emoji, title) = _describe();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 3),
                Text(change.reason,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
