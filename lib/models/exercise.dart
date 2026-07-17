class Exercise {
  final String id;
  final String name;
  final String bodyPart;
  final String equipment;
  final String target;
  final List<String> secondaryMuscles;
  final String difficulty; // beginner | intermediate | advanced
  final List<String> steps;
  final String gifUrl;
  final String imageUrl;

  const Exercise({
    required this.id,
    required this.name,
    required this.bodyPart,
    required this.equipment,
    required this.target,
    required this.secondaryMuscles,
    required this.difficulty,
    required this.steps,
    required this.gifUrl,
    required this.imageUrl,
  });

  factory Exercise.fromJson(Map<String, dynamic> j) => Exercise(
        id: j['id'] as String,
        name: j['name'] as String,
        bodyPart: j['bodyPart'] as String,
        equipment: j['equipment'] as String,
        target: j['target'] as String,
        secondaryMuscles: (j['secondaryMuscles'] as List).cast<String>(),
        difficulty: j['difficulty'] as String,
        steps: (j['steps'] as List).cast<String>(),
        gifUrl: j['gifUrl'] as String,
        imageUrl: j['imageUrl'] as String,
      );
}
