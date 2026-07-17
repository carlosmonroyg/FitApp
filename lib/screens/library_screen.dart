import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/exercise.dart';
import '../services/repository.dart';
import '../theme.dart';
import '../util/translations.dart';

/// Biblioteca de los 1,324 ejercicios: búsqueda y filtros por parte del cuerpo.
class LibraryScreen extends StatefulWidget {
  /// Filtro inicial por parte del cuerpo (ej. al llegar desde el cuerpo 3D).
  final String? initialBodyPart;

  /// Búsqueda inicial (ej. el músculo tocado en el cuerpo interactivo).
  final String? initialQuery;

  const LibraryScreen({super.key, this.initialBodyPart, this.initialQuery});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late final TextEditingController _searchController;
  String _query = '';
  String? _bodyPart;

  @override
  void initState() {
    super.initState();
    _bodyPart = widget.initialBodyPart;
    _query = widget.initialQuery ?? '';
    _searchController = TextEditingController(text: _query);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = ExerciseRepository.instance.all;
    final parts = all.map((e) => e.bodyPart).toSet().toList()..sort();
    final filtered = all
        .where((e) =>
            (_bodyPart == null || e.bodyPart == _bodyPart) &&
            (_query.isEmpty ||
                e.name.toLowerCase().contains(_query.toLowerCase()) ||
                trMuscle(e.target)
                    .toLowerCase()
                    .contains(_query.toLowerCase())))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Ejercicios')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Buscar ejercicio o músculo…',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('Todos'),
                    selected: _bodyPart == null,
                    onSelected: (_) => setState(() => _bodyPart = null),
                  ),
                ),
                for (final p in parts)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(trBodyPart(p)),
                      selected: _bodyPart == p,
                      onSelected: (_) => setState(
                          () => _bodyPart = _bodyPart == p ? null : p),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _ExerciseTile(exercise: filtered[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  final Exercise exercise;

  const _ExerciseTile({required this.exercise});

  Color get _difficultyColor => switch (exercise.difficulty) {
        'beginner' => const Color(0xFF4ADE80),
        'intermediate' => const Color(0xFFFBBF24),
        _ => const Color(0xFFF87171),
      };

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        builder: (_, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(24),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                color: Colors.white,
                height: 240,
                child: CachedNetworkImage(
                  imageUrl: exercise.gifUrl,
                  fit: BoxFit.contain,
                  placeholder: (_, _) => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  errorWidget: (_, _, _) => const Center(
                      child: Icon(Icons.fitness_center,
                          size: 56, color: Colors.black26)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(exercise.name,
                style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Chip(label: Text('🎯 ${trMuscle(exercise.target)}')),
                Chip(label: Text(trEquipment(exercise.equipment))),
                Chip(label: Text(trDifficulty(exercise.difficulty))),
              ],
            ),
            const SizedBox(height: 18),
            for (var i = 0; i < exercise.steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text('${i + 1}. ${exercise.steps[i]}',
                    style: const TextStyle(
                        color: AppColors.textSecondary, height: 1.4)),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _showDetail(context),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: Colors.white,
                  width: 64,
                  height: 64,
                  child: CachedNetworkImage(
                    imageUrl: exercise.imageUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => const Icon(
                        Icons.fitness_center,
                        color: Colors.black26),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exercise.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text(
                        '${trMuscle(exercise.target)} · ${trEquipment(exercise.equipment)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _difficultyColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
