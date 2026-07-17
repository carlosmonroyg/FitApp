import 'package:flutter/material.dart';

import 'screens/onboarding_screen.dart';
import 'screens/shell.dart';
import 'services/repository.dart';
import 'services/storage.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Storage.init();
  await ExerciseRepository.instance.load();
  runApp(const FitApp());
}

class FitApp extends StatelessWidget {
  const FitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitApp',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: Storage.profile == null ? const OnboardingScreen() : const Shell(),
    );
  }
}
