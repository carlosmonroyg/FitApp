import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/auth_service.dart';
import '../services/crash_reporter.dart';
import '../services/storage.dart';
import '../theme.dart';
import '../util/legal.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';

/// Privacidad, aviso de salud, créditos y control de los datos del usuario,
/// incluida la eliminación de la cuenta que exige Google Play.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  final _info = PackageInfo.fromPlatform();

  Future<void> _deleteAccount() async {
    final signedIn = AuthService.user != null;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(signedIn ? '¿Eliminar tu cuenta?' : '¿Borrar tus datos?'),
        content: Text(signedIn
            ? 'Se borrarán para siempre tu perfil, tus entrenamientos, '
                'récords, medidas y las revisiones del coach, en este '
                'teléfono y en la nube.\n\nTe pediremos confirmar con Google. '
                'Esta acción no se puede deshacer.'
            : 'Se borrarán de este teléfono tu perfil, entrenamientos, '
                'récords y medidas. Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 44)),
            child: const Text('Eliminar para siempre'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (signedIn) {
      _showProgress();
      try {
        await AuthService.deleteAccount().timeout(const Duration(seconds: 45));
      } on GoogleSignInException catch (e) {
        navigator.pop(); // progreso
        if (e.code != GoogleSignInExceptionCode.canceled) {
          CrashReporter.record(e, null, reason: 'account.delete.reauth');
        }
        messenger.showSnackBar(const SnackBar(
            content: Text('Cancelado: no se borró ningún dato.')));
        return;
      } catch (e, st) {
        navigator.pop();
        CrashReporter.record(e, st, reason: 'account.delete');
        messenger.showSnackBar(const SnackBar(
            content: Text('No se pudo eliminar la cuenta. Revisa tu '
                'conexión e inténtalo de nuevo.')));
        return;
      }
    }
    await Storage.clearAll();
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
          builder: (_) => AuthService.isAvailable
              ? const LoginScreen()
              : const OnboardingScreen()),
      (_) => false,
    );
    messenger.showSnackBar(SnackBar(
        content: Text(signedIn
            ? 'Tu cuenta y tus datos fueron eliminados.'
            : 'Tus datos fueron borrados.')));
  }

  void _showProgress() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 3)),
              SizedBox(width: 20),
              Expanded(child: Text('Eliminando tu cuenta…')),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = AuthService.user != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Privacidad y datos')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.asset('assets/icon/icon.png',
                      width: 72, height: 72),
                ),
                const SizedBox(height: 10),
                const Text('FitApp',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                FutureBuilder(
                  future: _info,
                  builder: (_, snap) => Text(
                      snap.hasData
                          ? 'Versión ${snap.data!.version} '
                              '(${snap.data!.buildNumber})'
                          : ' ',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Salud'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.health_and_safety_outlined, color: AppColors.accent),
                SizedBox(width: 12),
                Expanded(
                  child: Text(Legal.healthDisclaimer,
                      style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: AppColors.textSecondary)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Legal'),
          _LinkTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Política de privacidad',
            onTap: Legal.openPrivacy,
          ),
          if (Legal.supportEmail.isNotEmpty)
            _LinkTile(
              icon: Icons.mail_outline,
              title: 'Contactar a soporte',
              onTap: () => Legal.emailSupport(subject: 'Soporte FitApp'),
            ),
          _LinkTile(
            icon: Icons.description_outlined,
            title: 'Licencias de código abierto',
            onTap: () async {
              final info = await _info;
              if (!context.mounted) return;
              showLicensePage(
                  context: context,
                  applicationName: 'FitApp',
                  applicationVersion: info.version);
            },
          ),
          const SizedBox(height: 12),
          const Text(
            'Ejercicios y medios: © Gym visual (gymvisual.com)\n'
            'Dataset: exercises-dataset (MIT)\n'
            'Anatomía corporal: Ryan Graves (CC BY 4.0)',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 28),
          const _SectionTitle('Tus datos'),
          _LinkTile(
            icon: Icons.delete_forever_outlined,
            title: signedIn ? 'Eliminar mi cuenta' : 'Borrar mis datos',
            subtitle: signedIn
                ? 'Borra tu cuenta y todo tu progreso, aquí y en la nube'
                : 'Borra tu progreso de este teléfono',
            danger: true,
            onTap: _deleteAccount,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(text.toUpperCase(),
          style: const TextStyle(
              fontSize: 12,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary)),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool danger;
  final VoidCallback onTap;

  const _LinkTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? Colors.redAccent : AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          onTap: onTap,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: Icon(icon, color: color),
          title: Text(title,
              style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          subtitle: subtitle == null
              ? null
              : Text(subtitle!,
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.textSecondary)),
          trailing:
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
