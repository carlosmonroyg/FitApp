import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/exercise.dart';

/// Ejercicios con video propio (Blender, sin licencias de terceros), por id del
/// catálogo. El resto sigue usando el GIF remoto hasta tener su video.
const _ownVideos = {
  '1760': 'assets/videos/goblet_squat.mp4',
  '0289': 'assets/videos/dumbbell_bench_press.mp4',
  '0292': 'assets/videos/one_arm_dumbbell_row.mp4',
};

// Degradado del estudio medido en el borde de los clips: las bandas laterales
// del recuadro continúan el fondo del video.
const _videoBackdrop = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0xFF333842),
    Color(0xFF48515F),
    Color(0xFF444E5E),
    Color(0xFF828E9E),
    Color(0xFFADB3BB),
  ],
  stops: [0.0, 0.25, 0.5, 0.75, 1.0],
);

bool hasOwnVideo(Exercise exercise) => _ownVideos.containsKey(exercise.id);

/// Demostración del ejercicio: video propio en bucle si existe, si no el GIF.
class ExerciseMedia extends StatelessWidget {
  final Exercise exercise;
  final double height;

  const ExerciseMedia({super.key, required this.exercise, required this.height});

  @override
  Widget build(BuildContext context) {
    final asset = _ownVideos[exercise.id];
    if (asset != null) {
      return Container(
        decoration: const BoxDecoration(gradient: _videoBackdrop),
        height: height,
        child: _LoopingVideo(key: ValueKey(asset), asset: asset),
      );
    }
    return Container(
      color: Colors.white,
      height: height,
      child: CachedNetworkImage(
        imageUrl: exercise.gifUrl,
        fit: BoxFit.contain,
        placeholder: (_, _) =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorWidget: (_, _, _) => const Center(
          child: Icon(Icons.fitness_center, size: 56, color: Colors.black26),
        ),
      ),
    );
  }
}

class _LoopingVideo extends StatefulWidget {
  final String asset;
  const _LoopingVideo({super.key, required this.asset});

  @override
  State<_LoopingVideo> createState() => _LoopingVideoState();
}

class _LoopingVideoState extends State<_LoopingVideo> {
  late final VideoPlayerController _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(
      widget.asset,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _controller.setLooping(true);
    _controller.setVolume(0);
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      _controller.play();
    }).catchError((Object _) {
      if (mounted) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const Center(
        child: Icon(Icons.fitness_center, size: 56, color: Colors.white38),
      );
    }
    if (!_controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    return Center(
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: VideoPlayer(_controller),
      ),
    );
  }
}
