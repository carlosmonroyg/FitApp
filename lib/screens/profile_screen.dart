import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/storage.dart';
import '../theme.dart';
import '../util/translations.dart';
import '../widgets/avatar_3d.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text(
            'Tu progreso queda guardado en tu cuenta. ¿Quieres salir?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Salir')),
        ],
      ),
    );
    if (confirmed != true) return;
    await AuthService.signOut();
    await Storage.clearAll();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = Storage.profile!;
    final streak = Storage.streak;
    final total = Storage.completedDates.length;
    final user = AuthService.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Avatar3D(sex: profile.sex, bmi: profile.bmi, height: 210),
                const SizedBox(height: 8),
                Text(
                  '${profile.sex.label} · ${profile.heightCm} cm · ${profile.weightKg} kg · IMC ${profile.bmi.toStringAsFixed(1)}',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
                if (profile.focusZones.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final z in profile.focusZones)
                        Chip(
                          label: Text('💪 ${trBodyPart(z)}'),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _StatCard(
                      emoji: '🔥', value: '$streak', label: 'Racha actual')),
              const SizedBox(width: 12),
              Expanded(
                  child: _StatCard(
                      emoji: '🏋️',
                      value: '$total',
                      label: 'Entrenamientos')),
            ],
          ),
          const SizedBox(height: 24),
          _InfoTile(
              icon: profile.activity.emoji,
              title: 'Actividad diaria',
              value: profile.activity.label),
          _InfoTile(
              icon: profile.level.emoji,
              title: 'Nivel',
              value: profile.level.label),
          _InfoTile(
              icon: profile.goal.emoji,
              title: 'Objetivo',
              value: profile.goal.label),
          _InfoTile(
              icon: profile.focus.emoji,
              title: 'Enfoque',
              value: profile.focus.label),
          _InfoTile(
              icon: profile.equipment.emoji,
              title: 'Equipo',
              value: profile.equipment.label),
          _InfoTile(
              icon: '📅',
              title: 'Frecuencia',
              value: '${profile.daysPerWeek} días por semana'),
          if (user != null) ...[
            _InfoTile(
                icon: '👤',
                title: 'Cuenta',
                value: user.email ?? user.displayName ?? 'Google'),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => _signOut(context),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.surfaceHigh),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Cerrar sesión'),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () async {
              await Storage.reset();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                (_) => false,
              );
            },
            icon: const Icon(Icons.tune),
            label: const Text('Reconfigurar mi plan'),
          ),
          const SizedBox(height: 32),
          const Center(
            child: Text(
              'Ejercicios y medios: © Gym visual (gymvisual.com)\nDataset: exercises-dataset (MIT)\nAnatomía corporal: Ryan Graves (CC BY 4.0)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;

  const _StatCard(
      {required this.emoji, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
          Text(label,
              style: const TextStyle(
                  fontSize: 12.5, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String icon;
  final String title;
  final String value;

  const _InfoTile(
      {required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(title,
                  style: const TextStyle(color: AppColors.textSecondary)),
            ),
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}
