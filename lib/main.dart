import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/shell.dart';
import 'services/auth_service.dart';
import 'services/crash_reporter.dart';
import 'services/repository.dart';
import 'services/storage.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Independientes entre sí: en paralelo para acortar el splash.
  await Future.wait([
    Storage.init(),
    ExerciseRepository.instance.load(),
    AuthService.init(),
  ]);
  await CrashReporter.init();
  runApp(const FitApp());
}

class FitApp extends StatelessWidget {
  const FitApp({super.key});

  /// Login solo cuando Firebase está configurado y no hay sesión;
  /// sin configurar, la app sigue funcionando en modo local.
  Widget get _home {
    if (AuthService.isAvailable && AuthService.user == null) {
      return const LoginScreen();
    }
    return Storage.profile == null ? const OnboardingScreen() : const Shell();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitApp',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: _home,
    );
  }
}
