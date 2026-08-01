/// Plan comercial del usuario (modelo freemium con suscripción).
///
/// El cobro todavía no está integrado: el plan se guarda por usuario y la app
/// ya lo muestra, pero ninguna función se bloquea hasta conectar la
/// facturación de Google Play.
enum Plan { free, premium }

extension PlanX on Plan {
  String get label => switch (this) {
        Plan.free => 'Gratis',
        Plan.premium => 'Premium',
      };

  String get emoji => switch (this) {
        Plan.free => '🌱',
        Plan.premium => '⭐',
      };
}

/// Ventajas que ofrece la suscripción, en el orden en que se muestran.
const premiumBenefits = <(String, String, String)>[
  (
    '🍑',
    'Planes especializados',
    'Enfoque de glúteo y pierna, y los que vengan después',
  ),
  (
    '🔄',
    'Rutinas ilimitadas',
    'Regenera tu semana las veces que quieras',
  ),
  (
    '📈',
    'Historial completo',
    'Cada entrenamiento guardado con sus series y progreso',
  ),
  (
    '🧍',
    'Cuerpo 3D y mapa muscular',
    'Explora tu anatomía y qué músculos trabajaste',
  ),
];
