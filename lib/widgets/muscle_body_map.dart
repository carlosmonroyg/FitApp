import 'package:flutter/material.dart';
import 'package:flutter_body_atlas/flutter_body_atlas.dart';

/// Mapeo de los nombres de músculo del dataset (inglés coloquial)
/// a los músculos anatómicos del atlas corporal.
const Map<String, List<Muscle>> _datasetToAtlas = {
  // Core
  'abs': [
    Muscle.rectusAbdominis1,
    Muscle.rectusAbdominis2Left,
    Muscle.rectusAbdominis2Right,
    Muscle.rectusAbdominis3Left,
    Muscle.rectusAbdominis3Right,
    Muscle.rectusAbdominis4Left,
    Muscle.rectusAbdominis4Right,
  ],
  'abdominals': [
    Muscle.rectusAbdominis1,
    Muscle.rectusAbdominis2Left,
    Muscle.rectusAbdominis2Right,
    Muscle.rectusAbdominis3Left,
    Muscle.rectusAbdominis3Right,
    Muscle.rectusAbdominis4Left,
    Muscle.rectusAbdominis4Right,
  ],
  'lower abs': [
    Muscle.rectusAbdominis4Left,
    Muscle.rectusAbdominis4Right,
  ],
  'core': [
    Muscle.rectusAbdominis1,
    Muscle.rectusAbdominis2Left,
    Muscle.rectusAbdominis2Right,
    Muscle.externalObliqueLeft,
    Muscle.externalObliqueRight,
  ],
  'obliques': [
    Muscle.externalObliqueLeft,
    Muscle.externalObliqueRight,
    Muscle.externalOblique1Left,
    Muscle.externalOblique1Right,
    Muscle.externalOblique2Left,
    Muscle.externalOblique2Right,
    Muscle.externalOblique3Left,
    Muscle.externalOblique3Right,
    Muscle.externalOblique4Left,
    Muscle.externalOblique4Right,
  ],
  // Pecho
  'pectorals': [Muscle.pectoralisMajorLeft, Muscle.pectoralisMajorRight],
  'chest': [Muscle.pectoralisMajorLeft, Muscle.pectoralisMajorRight],
  'upper chest': [Muscle.pectoralisMajorLeft, Muscle.pectoralisMajorRight],
  // Brazos
  'biceps': [
    Muscle.bicepsBrachiiCaputBreveLeft,
    Muscle.bicepsBrachiiCaputBreveRight,
    Muscle.bicepsBrachiiCaputLongumLeft,
    Muscle.bicepsBrachiiCaputLongumRight,
  ],
  'brachialis': [
    Muscle.bicepsBrachiiCaputBreveLeft,
    Muscle.bicepsBrachiiCaputBreveRight,
  ],
  'triceps': [
    Muscle.tricepsBrachiiCaputLateraleLeft,
    Muscle.tricepsBrachiiCaputLateraleRight,
    Muscle.tricepsBrachiiCaputLongumLeft,
    Muscle.tricepsBrachiiCaputLongumRight,
    Muscle.tricepsBrachiiCaputMedialeLeft,
    Muscle.tricepsBrachiiCaputMedialeRight,
  ],
  'forearms': [
    Muscle.brachioradialisLeft,
    Muscle.brachioradialisRight,
    Muscle.extensorDigitorumLeft,
    Muscle.extensorDigitorumRight,
    Muscle.flexorCarpiUlnarisLeft,
    Muscle.flexorCarpiUlnarisRight,
  ],
  'wrist extensors': [
    Muscle.extensorCarpiUlnarisLeft,
    Muscle.extensorCarpiUlnarisRight,
    Muscle.extensorCarpiRadialisLongusLeft,
    Muscle.extensorCarpiRadialisLongusRight,
  ],
  'wrist flexors': [
    Muscle.flexorCarpiRadialisLeft,
    Muscle.flexorCarpiRadialisRight,
    Muscle.palmarisLongusLeft,
    Muscle.palmarisLongusRight,
  ],
  'grip muscles': [
    Muscle.flexorDigitorumSuperficialisLeft,
    Muscle.flexorDigitorumSuperficialisRight,
    Muscle.brachioradialisLeft,
    Muscle.brachioradialisRight,
  ],
  // Hombros y trapecios
  'delts': [
    Muscle.anteriorDeltoidLeft,
    Muscle.anteriorDeltoidRight,
    Muscle.lateralDeltoidLeft,
    Muscle.lateralDeltoidRight,
    Muscle.posteriorDeltoidLeft,
    Muscle.posteriorDeltoidRight,
  ],
  'deltoids': [
    Muscle.anteriorDeltoidLeft,
    Muscle.anteriorDeltoidRight,
    Muscle.lateralDeltoidLeft,
    Muscle.lateralDeltoidRight,
  ],
  'shoulders': [
    Muscle.anteriorDeltoidLeft,
    Muscle.anteriorDeltoidRight,
    Muscle.lateralDeltoidLeft,
    Muscle.lateralDeltoidRight,
  ],
  'rear deltoids': [
    Muscle.posteriorDeltoidLeft,
    Muscle.posteriorDeltoidRight,
  ],
  'rotator cuff': [Muscle.infraspinatusLeft, Muscle.infraspinatusRight],
  'traps': [
    Muscle.trapeziusUpperLeft,
    Muscle.trapeziusUpperRight,
    Muscle.trapeziusMiddleLeft,
    Muscle.trapeziusMiddleRight,
  ],
  'trapezius': [
    Muscle.trapeziusUpperLeft,
    Muscle.trapeziusUpperRight,
    Muscle.trapeziusMiddleLeft,
    Muscle.trapeziusMiddleRight,
    Muscle.trapeziusLowerLeft,
    Muscle.trapeziusLowerRight,
  ],
  'levator scapulae': [
    Muscle.trapeziusUpperLeft,
    Muscle.trapeziusUpperRight,
  ],
  'rhomboids': [
    Muscle.trapeziusMiddleLeft,
    Muscle.trapeziusMiddleRight,
  ],
  // Espalda
  'lats': [Muscle.latissimusDorsiLeft, Muscle.latissimusDorsiRight],
  'latissimus dorsi': [
    Muscle.latissimusDorsiLeft,
    Muscle.latissimusDorsiRight,
  ],
  'upper back': [
    Muscle.trapeziusMiddleLeft,
    Muscle.trapeziusMiddleRight,
    Muscle.trapeziusLowerLeft,
    Muscle.trapeziusLowerRight,
    Muscle.infraspinatusLeft,
    Muscle.infraspinatusRight,
  ],
  'back': [
    Muscle.latissimusDorsiLeft,
    Muscle.latissimusDorsiRight,
    Muscle.trapeziusMiddleLeft,
    Muscle.trapeziusMiddleRight,
  ],
  // Glúteos y piernas
  'glutes': [
    Muscle.gluteusMaximusLeft,
    Muscle.gluteusMaximusRight,
    Muscle.gluteusMedius1Left,
    Muscle.gluteusMedius1Right,
  ],
  'abductors': [
    Muscle.gluteusMedius1Left,
    Muscle.gluteusMedius1Right,
    Muscle.gluteusMedius2Left,
    Muscle.gluteusMedius2Right,
    Muscle.iliotibialTractLeft,
    Muscle.iliotibialTractRight,
  ],
  'quads': [
    Muscle.rectusFemorisLeft,
    Muscle.rectusFemorisRight,
    Muscle.vastusLateralisLeft,
    Muscle.vastusLateralisRight,
    Muscle.vastusMedialisLeft,
    Muscle.vastusMedialisRight,
  ],
  'quadriceps': [
    Muscle.rectusFemorisLeft,
    Muscle.rectusFemorisRight,
    Muscle.vastusLateralisLeft,
    Muscle.vastusLateralisRight,
  ],
  'hamstrings': [
    Muscle.bicepsFemorisLeft,
    Muscle.bicepsFemorisRight,
    Muscle.semitendinosusLeft,
    Muscle.semitendinosusRight,
    Muscle.semimembranosus1Left,
    Muscle.semimembranosus1Right,
  ],
  'adductors': [
    Muscle.adductorMagnusLeft,
    Muscle.adductorMagnusRight,
    Muscle.adductorLongusLeft,
    Muscle.adductorLongusRight,
  ],
  'inner thighs': [
    Muscle.adductorLongusLeft,
    Muscle.adductorLongusRight,
    Muscle.gracilisLeft,
    Muscle.gracilisRight,
  ],
  'groin': [
    Muscle.adductorLongusLeft,
    Muscle.adductorLongusRight,
    Muscle.pectineusLeft,
    Muscle.pectineusRight,
  ],
  'hip flexors': [
    Muscle.sartorisLeft,
    Muscle.sartorisRight,
    Muscle.pectineusLeft,
    Muscle.pectineusRight,
  ],
  'calves': [Muscle.gastrocnemiusLeft, Muscle.gastrocnemiusRight],
  'soleus': [Muscle.gastrocnemiusLeft, Muscle.gastrocnemiusRight],
  'shins': [Muscle.tibialisAnteriorLeft, Muscle.tibialisAnteriorRight],
  'ankle stabilizers': [
    Muscle.fibularisLongusLeft,
    Muscle.fibularisLongusRight,
  ],
  'ankles': [
    Muscle.fibularisLongusLeft,
    Muscle.fibularisLongusRight,
    Muscle.extensorDigitorumLongusLeft,
    Muscle.extensorDigitorumLongusRight,
  ],
  // Cuello
  'sternocleidomastoid': [
    Muscle.sternocleidomastoidLeft,
    Muscle.sternocleidomastoidRight,
  ],
  'neck': [
    Muscle.sternocleidomastoidLeft,
    Muscle.sternocleidomastoidRight,
  ],
};

/// Nombre de músculo del dataset al que pertenece un músculo del atlas
/// (mapeo inverso de [_datasetToAtlas]; el primer match gana).
String? datasetNameForAtlasMuscle(Muscle m) {
  for (final entry in _datasetToAtlas.entries) {
    if (entry.value.contains(m)) return entry.key;
  }
  return null;
}

/// Mapa corporal frontal + trasero con los músculos coloreados
/// según su intensidad de trabajo (0..1).
class MuscleBodyMap extends StatelessWidget {
  /// Nombres de músculo del dataset -> intensidad relativa (0..1).
  final Map<String, double> load;
  final double height;

  const MuscleBodyMap({super.key, required this.load, this.height = 340});

  /// Verde (suave) -> ámbar (medio) -> rojo (intenso).
  static Color heatColor(double t) {
    if (t <= 0.5) {
      return Color.lerp(
          const Color(0xFF4ADE80), const Color(0xFFFBBF24), t * 2)!;
    }
    return Color.lerp(
        const Color(0xFFFBBF24), const Color(0xFFF87171), (t - 0.5) * 2)!;
  }

  Map<MuscleInfo, Color?> _buildColorMapping() {
    final byMuscle = <Muscle, double>{};
    load.forEach((name, intensity) {
      for (final m in _datasetToAtlas[name] ?? const <Muscle>[]) {
        final current = byMuscle[m];
        if (current == null || intensity > current) {
          byMuscle[m] = intensity;
        }
      }
    });
    return {
      for (final entry in byMuscle.entries)
        if (MuscleCatalog.byMuscle[entry.key] != null)
          MuscleCatalog.byMuscle[entry.key]!: heatColor(entry.value),
    };
  }

  @override
  Widget build(BuildContext context) {
    final mapping = _buildColorMapping();
    return SizedBox(
      height: height,
      child: Row(
        children: [
          Expanded(
            child: BodyAtlasView<MuscleInfo>(
              view: AtlasAsset.musclesFront,
              resolver: const MuscleResolver(),
              colorMapping: mapping,
            ),
          ),
          Expanded(
            child: BodyAtlasView<MuscleInfo>(
              view: AtlasAsset.musclesBack,
              resolver: const MuscleResolver(),
              colorMapping: mapping,
            ),
          ),
        ],
      ),
    );
  }
}
