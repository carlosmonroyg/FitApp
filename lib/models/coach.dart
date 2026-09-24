/// Lo que el coach devuelve en el check-in semanal y cómo se aplica al plan.
///
/// El modelo de lenguaje no genera rutinas: emite una [Prescription] acotada
/// (ajustes de series, descanso, sustituciones dentro de alternativas que la
/// app le dio, progresión por ejercicio) y el [RoutineGenerator] la aplica.
/// Todo lo que llega del servidor ya viene validado contra el catálogo.
library;

enum ProgressionAction { addWeight, addRep, hold, deload }

extension ProgressionActionX on ProgressionAction {
  String get wire => switch (this) {
        ProgressionAction.addWeight => 'add_weight',
        ProgressionAction.addRep => 'add_rep',
        ProgressionAction.hold => 'hold',
        ProgressionAction.deload => 'deload',
      };

  static ProgressionAction? parse(String? s) => switch (s) {
        'add_weight' => ProgressionAction.addWeight,
        'add_rep' => ProgressionAction.addRep,
        'hold' => ProgressionAction.hold,
        'deload' => ProgressionAction.deload,
        _ => null,
      };

  String get label => switch (this) {
        ProgressionAction.addWeight => 'Sube el peso',
        ProgressionAction.addRep => 'Suma una repetición',
        ProgressionAction.hold => 'Mantén la carga',
        ProgressionAction.deload => 'Baja la carga (descarga)',
      };
}

/// Un cambio concreto con su razón, para mostrarlo y para aplicarlo.
class CoachChange {
  /// sets · rest · swap · progression · avoid
  final String type;
  final String reason;
  final String? bodyPart;
  final int? delta;
  final String? fromId;
  final String? toId;
  final String? toName;
  final String? exerciseId;
  final String? exerciseName;
  final ProgressionAction? action;

  const CoachChange({
    required this.type,
    required this.reason,
    this.bodyPart,
    this.delta,
    this.fromId,
    this.toId,
    this.toName,
    this.exerciseId,
    this.exerciseName,
    this.action,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'reason': reason,
        if (bodyPart != null) 'bodyPart': bodyPart,
        if (delta != null) 'delta': delta,
        if (fromId != null) 'fromId': fromId,
        if (toId != null) 'toId': toId,
        if (toName != null) 'toName': toName,
        if (exerciseId != null) 'exerciseId': exerciseId,
        if (exerciseName != null) 'exerciseName': exerciseName,
        if (action != null) 'action': action!.wire,
      };

  factory CoachChange.fromJson(Map<String, dynamic> j) => CoachChange(
        type: j['type'] as String,
        reason: (j['reason'] as String?) ?? '',
        bodyPart: j['bodyPart'] as String?,
        delta: (j['delta'] as num?)?.toInt(),
        fromId: j['fromId'] as String?,
        toId: j['toId'] as String?,
        toName: j['toName'] as String?,
        exerciseId: j['exerciseId'] as String?,
        exerciseName: j['exerciseName'] as String?,
        action: ProgressionActionX.parse(j['action'] as String?),
      );
}

/// Prescripción aplicable: derivada de los cambios, ya validada.
class Prescription {
  /// bodyPart del dataset → −1 / 0 / +1 series por ejercicio de esa parte.
  final Map<String, int> setDelta;

  /// Segundos que se suman al descanso de todos los ejercicios (−15/0/+15).
  final int restDeltaSec;

  /// id actual → id sustituto.
  final Map<String, String> swaps;

  /// Ejercicios que deben conservarse al regenerar (los que progresan).
  final Set<String> keep;

  /// Ejercicios que no deben aparecer (dolor, molestia).
  final Set<String> avoid;

  /// id → qué hacer con la carga la próxima vez.
  final Map<String, ProgressionAction> progression;

  const Prescription({
    this.setDelta = const {},
    this.restDeltaSec = 0,
    this.swaps = const {},
    this.keep = const {},
    this.avoid = const {},
    this.progression = const {},
  });

  static const none = Prescription();

  bool get isEmpty =>
      setDelta.isEmpty &&
      restDeltaSec == 0 &&
      swaps.isEmpty &&
      avoid.isEmpty &&
      progression.isEmpty;

  factory Prescription.fromChanges(List<CoachChange> changes,
      {Set<String> keep = const {}}) {
    final setDelta = <String, int>{};
    var rest = 0;
    final swaps = <String, String>{};
    final avoid = <String>{};
    final progression = <String, ProgressionAction>{};
    for (final c in changes) {
      switch (c.type) {
        case 'sets':
          if (c.bodyPart != null && c.delta != null) {
            setDelta[c.bodyPart!] = c.delta!.clamp(-1, 1);
          }
        case 'rest':
          if (c.delta != null) rest = c.delta!.clamp(-15, 15);
        case 'swap':
          if (c.fromId != null && c.toId != null) swaps[c.fromId!] = c.toId!;
        case 'avoid':
          if (c.exerciseId != null) avoid.add(c.exerciseId!);
        case 'progression':
          if (c.exerciseId != null && c.action != null) {
            progression[c.exerciseId!] = c.action!;
          }
      }
    }
    return Prescription(
      setDelta: setDelta,
      restDeltaSec: rest,
      swaps: swaps,
      keep: {...keep, ...progression.keys}..removeAll(avoid),
      avoid: avoid,
      progression: progression,
    );
  }

  Map<String, dynamic> toJson() => {
        'setDelta': setDelta,
        'restDeltaSec': restDeltaSec,
        'swaps': swaps,
        'keep': keep.toList(),
        'avoid': avoid.toList(),
        'progression': {for (final e in progression.entries) e.key: e.value.wire},
      };

  factory Prescription.fromJson(Map<String, dynamic> j) => Prescription(
        setDelta: Map<String, int>.from(
            (j['setDelta'] as Map? ?? {}).map((k, v) => MapEntry(k, (v as num).toInt()))),
        restDeltaSec: (j['restDeltaSec'] as num?)?.toInt() ?? 0,
        swaps: Map<String, String>.from(j['swaps'] as Map? ?? {}),
        keep: Set<String>.from(j['keep'] as List? ?? []),
        avoid: Set<String>.from(j['avoid'] as List? ?? []),
        progression: {
          for (final e in (j['progression'] as Map? ?? {}).entries)
            if (ProgressionActionX.parse(e.value as String?) != null)
              e.key as String: ProgressionActionX.parse(e.value as String)!,
        },
      );
}

/// Resultado completo de un check-in semanal.
class CoachCheckin {
  /// Lunes de la semana revisada (yyyy-MM-dd).
  final String weekId;
  final DateTime createdAt;
  final String summary;
  final List<String> highlights;
  final List<CoachChange> changes;
  final String weekFocus;
  final List<String> coachNotes;
  final bool seekProfessional;
  final String? seekProfessionalReason;
  final bool applied;

  const CoachCheckin({
    required this.weekId,
    required this.createdAt,
    required this.summary,
    required this.highlights,
    required this.changes,
    required this.weekFocus,
    required this.coachNotes,
    this.seekProfessional = false,
    this.seekProfessionalReason,
    this.applied = false,
  });

  Prescription prescription({Set<String> keep = const {}}) =>
      Prescription.fromChanges(changes, keep: keep);

  CoachCheckin copyWith({bool? applied}) => CoachCheckin(
        weekId: weekId,
        createdAt: createdAt,
        summary: summary,
        highlights: highlights,
        changes: changes,
        weekFocus: weekFocus,
        coachNotes: coachNotes,
        seekProfessional: seekProfessional,
        seekProfessionalReason: seekProfessionalReason,
        applied: applied ?? this.applied,
      );

  Map<String, dynamic> toJson() => {
        'weekId': weekId,
        'createdAt': createdAt.toIso8601String(),
        'summary': summary,
        'highlights': highlights,
        'changes': changes.map((c) => c.toJson()).toList(),
        'weekFocus': weekFocus,
        'coachNotes': coachNotes,
        'seekProfessional': seekProfessional,
        if (seekProfessionalReason != null)
          'seekProfessionalReason': seekProfessionalReason,
        'applied': applied,
      };

  factory CoachCheckin.fromJson(Map<String, dynamic> j) => CoachCheckin(
        weekId: j['weekId'] as String,
        createdAt: DateTime.tryParse((j['createdAt'] as String?) ?? '') ??
            DateTime.now(),
        summary: (j['summary'] as String?) ?? '',
        highlights: List<String>.from(j['highlights'] as List? ?? []),
        changes: (j['changes'] as List? ?? [])
            .map((c) => CoachChange.fromJson(Map<String, dynamic>.from(c)))
            .toList(),
        weekFocus: (j['weekFocus'] as String?) ?? '',
        coachNotes: List<String>.from(j['coachNotes'] as List? ?? []),
        seekProfessional: (j['seekProfessional'] as bool?) ?? false,
        seekProfessionalReason: j['seekProfessionalReason'] as String?,
        applied: (j['applied'] as bool?) ?? false,
      );
}
