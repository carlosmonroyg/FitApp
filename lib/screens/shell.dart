import 'package:flutter/material.dart';

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
