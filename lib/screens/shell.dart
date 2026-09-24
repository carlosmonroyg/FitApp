import 'package:flutter/material.dart';

import '../services/storage.dart';
import '../theme.dart';
import '../util/legal.dart';
import 'body3d_screen.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'profile_screen.dart';

/// Contenedor con la navegación inferior: Hoy · Cuerpo · Ejercicios · Perfil.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Quien creó su perfil antes del aviso (o antes de una versión nueva de
    // los términos) lo acepta una vez aquí.
    if (Storage.acceptedTermsVersion < Legal.termsVersion) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _askTerms());
    }
  }

  Future<void> _askTerms() async {
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceHigh,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => PopScope(
        canPop: false,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.health_and_safety_outlined,
                    size: 40, color: AppColors.accent),
                const SizedBox(height: 12),
                const Text('Antes de seguir',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                const Text(Legal.healthDisclaimer,
                    style: TextStyle(
                        fontSize: 13.5,
                        height: 1.5,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: Legal.openPrivacy,
                  child: const Text('Leer la política de privacidad'),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () async {
                    await Storage.acceptTerms(Legal.termsVersion);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  child: const Text('Entiendo y acepto'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          Body3DScreen(),
          LibraryScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.today_outlined),
              selectedIcon: Icon(Icons.today),
              label: 'Hoy'),
          NavigationDestination(
              icon: Icon(Icons.accessibility_new_outlined),
              selectedIcon: Icon(Icons.accessibility_new),
              label: 'Cuerpo'),
          NavigationDestination(
              icon: Icon(Icons.fitness_center_outlined),
              selectedIcon: Icon(Icons.fitness_center),
              label: 'Ejercicios'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Perfil'),
        ],
      ),
    );
  }
}
