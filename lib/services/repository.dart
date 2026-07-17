import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/exercise.dart';

/// Carga y expone el catálogo de 1,324 ejercicios embebido en assets.
class ExerciseRepository {
  ExerciseRepository._();

  static final ExerciseRepository instance = ExerciseRepository._();

  List<Exercise> _all = const [];
  Map<String, Exercise> _byId = const {};

  bool get isLoaded => _all.isNotEmpty;
  List<Exercise> get all => _all;

  Future<void> load() async {
    if (isLoaded) return;
    final raw = await rootBundle.loadString('assets/data/exercises.json');
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    _all = list.map(Exercise.fromJson).toList();
    _byId = {for (final e in _all) e.id: e};
  }

  Exercise byId(String id) => _byId[id]!;
}
