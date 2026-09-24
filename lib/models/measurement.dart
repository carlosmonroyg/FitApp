/// Toma de medidas corporales. Todo es opcional salvo la fecha: el usuario
/// registra lo que tenga a mano (a veces solo el peso).
class Measurement {
  /// Clave del día (yyyy-MM-dd). Una toma por día; la última sobrescribe.
  final String dayKey;
  final DateTime date;
  final double? weightKg;
  final double? waistCm;
  final double? hipCm;
  final double? chestCm;
  final double? armCm;
  final double? thighCm;
  final double? calfCm;
  final double? bodyFatPct;

  const Measurement({
    required this.dayKey,
    required this.date,
    this.weightKg,
    this.waistCm,
    this.hipCm,
    this.chestCm,
    this.armCm,
    this.thighCm,
    this.calfCm,
    this.bodyFatPct,
  });

  static String keyFor(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Ratio cintura/cadera: indicador de riesgo metabólico más útil que el IMC.
  double? get waistHipRatio =>
      waistCm == null || hipCm == null || hipCm == 0 ? null : waistCm! / hipCm!;

  double? valueOf(MeasureKind k) => switch (k) {
        MeasureKind.weight => weightKg,
        MeasureKind.waist => waistCm,
        MeasureKind.hip => hipCm,
        MeasureKind.chest => chestCm,
        MeasureKind.arm => armCm,
        MeasureKind.thigh => thighCm,
        MeasureKind.calf => calfCm,
        MeasureKind.bodyFat => bodyFatPct,
      };

  bool get isEmpty => MeasureKind.values.every((k) => valueOf(k) == null);

  Map<String, dynamic> toJson() => {
        'dayKey': dayKey,
        'date': date.toIso8601String(),
        if (weightKg != null) 'weightKg': weightKg,
        if (waistCm != null) 'waistCm': waistCm,
        if (hipCm != null) 'hipCm': hipCm,
        if (chestCm != null) 'chestCm': chestCm,
        if (armCm != null) 'armCm': armCm,
        if (thighCm != null) 'thighCm': thighCm,
        if (calfCm != null) 'calfCm': calfCm,
        if (bodyFatPct != null) 'bodyFatPct': bodyFatPct,
      };

  factory Measurement.fromJson(Map<String, dynamic> j) => Measurement(
        dayKey: j['dayKey'] as String,
        date: DateTime.parse(j['date'] as String),
        weightKg: (j['weightKg'] as num?)?.toDouble(),
        waistCm: (j['waistCm'] as num?)?.toDouble(),
        hipCm: (j['hipCm'] as num?)?.toDouble(),
        chestCm: (j['chestCm'] as num?)?.toDouble(),
        armCm: (j['armCm'] as num?)?.toDouble(),
        thighCm: (j['thighCm'] as num?)?.toDouble(),
        calfCm: (j['calfCm'] as num?)?.toDouble(),
        bodyFatPct: (j['bodyFatPct'] as num?)?.toDouble(),
      );
}

enum MeasureKind { weight, waist, hip, chest, arm, thigh, calf, bodyFat }

extension MeasureKindX on MeasureKind {
  String get label => switch (this) {
        MeasureKind.weight => 'Peso',
        MeasureKind.waist => 'Cintura',
        MeasureKind.hip => 'Cadera',
        MeasureKind.chest => 'Pecho',
        MeasureKind.arm => 'Brazo',
        MeasureKind.thigh => 'Muslo',
        MeasureKind.calf => 'Pantorrilla',
        MeasureKind.bodyFat => 'Grasa corporal',
      };

  String get unit => switch (this) {
        MeasureKind.weight => 'kg',
        MeasureKind.bodyFat => '%',
        _ => 'cm',
      };

  String get emoji => switch (this) {
        MeasureKind.weight => '⚖️',
        MeasureKind.waist => '📏',
        MeasureKind.hip => '🍑',
        MeasureKind.chest => '🫁',
        MeasureKind.arm => '💪',
        MeasureKind.thigh => '🦵',
        MeasureKind.calf => '🦶',
        MeasureKind.bodyFat => '🔬',
      };

  /// Dónde medir, para que las tomas sean comparables entre semanas.
  String get hint => switch (this) {
        MeasureKind.weight => 'En ayunas, sin ropa pesada',
        MeasureKind.waist => 'A la altura del ombligo, sin apretar',
        MeasureKind.hip => 'En la parte más ancha de los glúteos',
        MeasureKind.chest => 'A la altura de los pezones, relajado',
        MeasureKind.arm => 'Brazo flexionado, parte más gruesa',
        MeasureKind.thigh => 'Parte más gruesa, de pie',
        MeasureKind.calf => 'Parte más gruesa, de pie',
        MeasureKind.bodyFat => 'Báscula de bioimpedancia o plicómetro',
      };

  /// Paso de los botones −/+ del formulario.
  double get step => this == MeasureKind.bodyFat ? 0.5 : 0.5;
}

/// Diferencia entre la primera y la última toma que tenga ese dato.
class MeasureTrend {
  final MeasureKind kind;
  final double first;
  final double last;
  final int days;

  const MeasureTrend(
      {required this.kind,
      required this.first,
      required this.last,
      required this.days});

  double get delta => last - first;
}

MeasureTrend? trendFor(List<Measurement> history, MeasureKind kind) {
  final withValue = history.where((m) => m.valueOf(kind) != null).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  if (withValue.length < 2) return null;
  return MeasureTrend(
    kind: kind,
    first: withValue.first.valueOf(kind)!,
    last: withValue.last.valueOf(kind)!,
    days: withValue.last.date.difference(withValue.first.date).inDays,
  );
}
