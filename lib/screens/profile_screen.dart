import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/plan.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/repository.dart';
import '../services/routine_generator.dart';
import '../services/storage.dart';
import '../theme.dart';
import '../util/translations.dart';
import '../widgets/avatar_3d.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';

/// Centro de cuenta: identidad de Google, plan comercial, estadísticas y
/// ajustes del entrenamiento que pueden cambiarse sin rehacer el onboarding.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _signOut() async {
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
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  /// Cambia el enfoque y regenera la semana para que el cambio se note hoy.
  Future<void> _changeFocus(UserProfile profile) async {
    final picked = await showModalBottomSheet<TrainingFocus>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 4),
              child: Text('Enfoque de tu plan',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text('Cambiarlo genera una semana nueva.',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ),
            for (final f in TrainingFocus.values)
              ListTile(
                leading: Text(f.emoji, style: const TextStyle(fontSize: 26)),
                title: Text(f.label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                subtitle: Text(f.description,
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.textSecondary)),
                trailing: profile.focus == f
                    ? const Icon(Icons.check_circle, color: AppColors.accent)
                    : null,
                onTap: () => Navigator.of(ctx).pop(f),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (picked == null || picked == profile.focus) return;

    final updated = profile.copyWith(focus: picked);
    await Storage.saveProfile(updated);
    final week = RoutineGenerator(ExerciseRepository.instance.all, updated,
            phase: Storage.currentPhase)
        .generateWeek();
    await Storage.saveWeek(week);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Enfoque ${picked.label} · rutina actualizada '
            '${picked.emoji}')));
  }

  void _showPremium() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('⭐ FitApp Premium',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              const Text('Entrena con todo el potencial de la app.',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 20),
              for (final (emoji, title, detail) in premiumBenefits)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary)),
                            Text(detail,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'La suscripción todavía no está disponible. Mientras tanto '
                  'puedes usar todas las funciones sin costo.',
                  style:
                      TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Entendido'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = Storage.profile!;
    final streak = Storage.streak;
    final total = Storage.completedDates.length;
    final user = AuthService.user;
    final plan = Storage.plan;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (user != null) ...[
            _AccountHeader(
              photoUrl: user.photoURL,
              name: user.displayName ?? 'Tu cuenta',
              email: user.email ?? '',
              plan: plan,
            ),
            const SizedBox(height: 12),
            if (plan == Plan.free) ...[
              _PremiumCard(onTap: _showPremium),
              const SizedBox(height: 16),
            ],
          ],
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
              icon: profile.focus.emoji,
              title: 'Enfoque',
              value: profile.focus.label,
              onTap: () => _changeFocus(profile)),
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
              icon: profile.equipment.emoji,
              title: 'Equipo',
              value: profile.equipment.label),
          _InfoTile(
              icon: '📅',
              title: 'Frecuencia',
              value: '${profile.daysPerWeek} días por semana'),
          const SizedBox(height: 10),
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
          if (user != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _signOut,
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

/// Cabecera con la identidad de Google y el plan vigente.
class _AccountHeader extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final String email;
  final Plan plan;

  const _AccountHeader({
    required this.photoUrl,
    required this.name,
    required this.email,
    required this.plan,
  });

  @override
  Widget build(BuildContext context) {
    final premium = plan == Plan.premium;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          ClipOval(
            child: SizedBox(
              width: 52,
              height: 52,
              child: photoUrl == null
                  ? Container(
                      color: AppColors.surfaceHigh,
                      child: const Icon(Icons.person,
                          color: AppColors.textSecondary))
                  : CachedNetworkImage(
                      imageUrl: photoUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => Container(
                        color: AppColors.surfaceHigh,
                        child: const Icon(Icons.person,
                            color: AppColors.textSecondary),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                if (email.isNotEmpty)
                  Text(email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: premium
                  ? AppColors.accent.withValues(alpha: 0.18)
                  : AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${plan.emoji} ${plan.label}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: premium ? AppColors.accent : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  final VoidCallback onTap;

  const _PremiumCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.accent.withValues(alpha: 0.18),
                AppColors.surface,
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              const Text('⭐', style: TextStyle(fontSize: 26)),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hazte Premium',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                    Text('Planes especializados e historial completo',
                        style: TextStyle(
                            fontSize: 12.5, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.accent),
            ],
          ),
        ),
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
  final VoidCallback? onTap;

  const _InfoTile(
      {required this.icon,
      required this.title,
      required this.value,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(title,
                      style:
                          const TextStyle(color: AppColors.textSecondary)),
                ),
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right,
                      size: 18, color: AppColors.textSecondary),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
