import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../services/auth_service.dart';
import '../services/cloud_sync.dart';
import '../services/storage.dart';
import '../theme.dart';
import 'onboarding_screen.dart';
import 'shell.dart';

/// Pantalla de inicio de sesión con Google.
///
/// Tras autenticarse: si el usuario ya tiene datos en la nube se descargan;
/// si no, se conserva (y sube) el progreso local previo o se va al onboarding.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;

  Future<void> _signIn() async {
    setState(() => _loading = true);
    try {
      await AuthService.signInWithGoogle();
      final hadCloudData = await CloudSync.pull();
      if (!hadCloudData && Storage.profile != null) {
        // Progreso local de antes de tener cuenta: se respalda en la nube.
        await CloudSync.push();
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) =>
            Storage.profile == null ? const OnboardingScreen() : const Shell(),
      ));
    } on GoogleSignInException catch (e) {
      // Cancelado por el usuario o error de configuración.
      if (!mounted) return;
      if (e.code != GoogleSignInExceptionCode.canceled) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo iniciar sesión: ${e.code.name}')));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se pudo iniciar sesión. Inténtalo de nuevo.')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Center(
                    child: Text('💪', style: TextStyle(fontSize: 48))),
              ),
              const SizedBox(height: 24),
              const Text('FitApp',
                  style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              const Text(
                'Tu rutina personalizada, tu progreso\ny tu racha, siempre contigo.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
              ),
              const Spacer(flex: 3),
              FilledButton.icon(
                onPressed: _loading ? null : _signIn,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1F1F1F),
                ),
                icon: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('G',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF4285F4))),
                label: Text(
                    _loading ? 'Conectando…' : 'Continuar con Google'),
              ),
              const SizedBox(height: 16),
              const Text(
                'Tu progreso se guarda en tu cuenta y se\nsincroniza entre tus dispositivos.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
