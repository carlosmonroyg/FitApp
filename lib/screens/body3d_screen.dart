import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'package:flutter_body_atlas/flutter_body_atlas.dart';

import '../theme.dart';
import '../util/translations.dart';
import '../widgets/muscle_body_map.dart';
import 'library_screen.dart';

/// Explorador corporal con dos modos:
/// - Interactivo: atlas anatómico tocable — tocas un músculo y ves sus
///   ejercicios (con resaltado del músculo tocado).
/// - 3D: modelo muscular rotable (Z-Anatomy, CC BY-SA 4.0).
class Body3DScreen extends StatefulWidget {
  const Body3DScreen({super.key});

  @override
  State<Body3DScreen> createState() => _Body3DScreenState();
}

class _Body3DScreenState extends State<Body3DScreen> {
  final _controller3d = Flutter3DController();
  bool _mode3d = false;
  MuscleInfo? _tapped;

  void _onTapMuscle(MuscleInfo info) {
    final datasetName = datasetNameForAtlasMuscle(info.muscle);
    setState(() => _tapped = info);
    if (datasetName == null) return;
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      Navigator.of(context)
          .push(MaterialPageRoute(
              builder: (_) =>
                  LibraryScreen(initialQuery: trMuscle(datasetName))))
          .then((_) => setState(() => _tapped = null));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tu cuerpo'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Interactivo')),
                ButtonSegment(value: true, label: Text('3D')),
              ],
              selected: {_mode3d},
              onSelectionChanged: (s) => setState(() => _mode3d = s.first),
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                backgroundColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.selected)
                        ? AppColors.accent.withValues(alpha: 0.2)
                        : AppColors.surface),
                foregroundColor:
                    WidgetStateProperty.all(AppColors.textPrimary),
              ),
            ),
          ),
        ],
      ),
      body: _mode3d ? _build3d() : _buildInteractive(),
    );
  }

  // ---- Modo interactivo: atlas tocable ----
  Widget _buildInteractive() {
    final highlight = <MuscleInfo, Color?>{
      ?_tapped: AppColors.accent,
    };
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Text('👆 Toca un músculo para ver sus ejercicios',
              style:
                  TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: BodyAtlasView<MuscleInfo>(
                          view: AtlasAsset.musclesFront,
                          resolver: const MuscleResolver(),
                          colorMapping: highlight,
                          onTapElement: _onTapMuscle,
                        ),
                      ),
                      const Text('Frente',
                          style: TextStyle(
                              fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: BodyAtlasView<MuscleInfo>(
                          view: AtlasAsset.musclesBack,
                          resolver: const MuscleResolver(),
                          colorMapping: highlight,
                          onTapElement: _onTapMuscle,
                        ),
                      ),
                      const Text('Espalda',
                          style: TextStyle(
                              fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_tapped != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Chip(
              label: Text(
                _tapped!.displayName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              backgroundColor: AppColors.accent.withValues(alpha: 0.2),
            ),
          )
        else
          const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('Anatomía: Ryan Graves · CC BY 4.0',
              style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ),
      ],
    );
  }

  // ---- Modo 3D: modelo rotable ----
  Widget _build3d() {
    return Column(
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1B2230), Color(0xFF10141D)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            clipBehavior: Clip.antiAlias,
            child: Flutter3DViewer(
              src: 'assets/models/muscles.glb',
              controller: _controller3d,
              progressBarColor: AppColors.accent,
              onError: (e) => debugPrint('Error modelo 3D: $e'),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 10, 20, 4),
          child: Text('🔄 Gíralo con el dedo · pellizca para acercar',
              style:
                  TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('Modelo: Z-Anatomy · CC BY-SA 4.0',
              style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ),
      ],
    );
  }
}
