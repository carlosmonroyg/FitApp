/// Programa guiado de 12 semanas dividido en tres fases de cuatro.
///
/// Resuelve el "no sé qué entrenar" de quien empieza: en vez de una semana
/// suelta que se repite, el plan avanza solo y en cada fase cambia el volumen,
/// las repeticiones y lo que hay que buscar en cada sesión.
const weeksPerPhase = 4;
const programWeeks = weeksPerPhase * 3;

enum TrainingPhase { adaptation, progression, consolidation }

extension TrainingPhaseX on TrainingPhase {
  String get label => switch (this) {
        TrainingPhase.adaptation => 'Adaptación',
        TrainingPhase.progression => 'Progresión',
        TrainingPhase.consolidation => 'Consolidación',
      };

  String get emoji => switch (this) {
        TrainingPhase.adaptation => '🌱',
        TrainingPhase.progression => '📈',
        TrainingPhase.consolidation => '🔥',
      };

  /// Qué se busca en la fase, en una línea.
  String get aim => switch (this) {
        TrainingPhase.adaptation => 'Aprender la técnica sin agujetas brutales',
        TrainingPhase.progression => 'Subir peso y series poco a poco',
        TrainingPhase.consolidation => 'Cargas altas y menos repeticiones',
      };

  /// Consejo práctico para quien nunca ha pisado un gimnasio.
  String get guidance => switch (this) {
        TrainingPhase.adaptation =>
          'Empieza con un peso que te deje llegar al final de la serie '
              'hablando. Si dudas, quédate corta: estas cuatro semanas son '
              'para que el movimiento te salga natural.',
        TrainingPhase.progression =>
          'Ya dominas los movimientos. Sube un poco el peso cuando completes '
              'todas las series sin fallar; las últimas dos repeticiones '
              'deben costarte.',
        TrainingPhase.consolidation =>
          'Menos repeticiones y más carga. Descansa lo que marque la app '
              'entre series: aquí el descanso es parte del entrenamiento.',
      };

  int get firstWeek => index * weeksPerPhase + 1;
  int get lastWeek => (index + 1) * weeksPerPhase;
}

/// Fase que corresponde a una semana del programa (1-based).
/// Pasadas las 12 semanas el programa vuelve a empezar en un ciclo nuevo.
TrainingPhase phaseForWeek(int week) {
  final inCycle = ((week - 1) % programWeeks);
  return TrainingPhase.values[inCycle ~/ weeksPerPhase];
}

/// Semana dentro del ciclo actual (1..12).
int weekInCycle(int week) => ((week - 1) % programWeeks) + 1;

/// Número de ciclo completado (1 = primer programa de 12 semanas).
int cycleOf(int week) => ((week - 1) ~/ programWeeks) + 1;
