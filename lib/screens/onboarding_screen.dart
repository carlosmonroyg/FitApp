import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../services/repository.dart';
import '../services/routine_generator.dart';
import '../services/storage.dart';
import '../theme.dart';
import '../util/translations.dart';
import '../widgets/avatar_3d.dart';
import 'shell.dart';

/// Onboarding en 6 pasos: avatar y medidas → nivel → objetivo → equipo →
/// días por semana → zonas prioritarias.
/// Termina generando la primera rutina, lista para entrenar hoy.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  static const _pageCount = 8;
  int _page = 0;

  Sex _sex = Sex.male;
  int _heightCm = 170;
  int _weightKg = 70;
  ActivityLevel? _activity;
  Level? _level;
  Goal? _goal;
  EquipmentSetup? _equipment;
  int _days = 3;
  TrainingFocus _focus = TrainingFocus.balanced;

  /// El enfoque se sugiere según el sexo hasta que el usuario lo elige a mano.
  bool _focusChosen = false;
  final Set<String> _focusZones = {};

  double get _bmi => _weightKg / ((_heightCm / 100) * (_heightCm / 100));

  bool get _canContinue => switch (_page) {
        1 => _activity != null,
        2 => _level != null,
        3 => _goal != null,
        5 => _equipment != null,
        _ => true,
      };

  Future<void> _finish() async {
    final profile = UserProfile(
      level: _level!,
      goal: _goal!,
      equipment: _equipment!,
      daysPerWeek: _days,
      sex: _sex,
      heightCm: _heightCm,
      weightKg: _weightKg,
      activity: _activity ?? ActivityLevel.moderate,
      focus: _focus,
      focusZones: _focusZones.toList(),
    );
    await Storage.saveProfile(profile);
    await Storage.startProgram();
    final week = RoutineGenerator(ExerciseRepository.instance.all, profile,
            phase: Storage.currentPhase)
        .generateWeek();
    await Storage.saveWeek(week);
    if (!mounted) return;
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => const Shell()));
  }

  void _next() {
    if (_page == _pageCount - 1) {
      _finish();
    } else {
      _controller.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  for (var i = 0; i < _pageCount; i++)
                    Expanded(
                      child: Container(
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: i <= _page
                              ? AppColors.accent
                              : AppColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (p) => setState(() => _page = p),
                children: [
                  _avatarStep(),
                  _step(
                    title: '¿Cómo es tu día a día?',
                    subtitle:
                        'Ajustamos el volumen inicial para que tu cuerpo se adapte sin lesiones.',
                    options: [
                      for (final a in ActivityLevel.values)
                        _OptionCard(
                          emoji: a.emoji,
                          label: a.label,
                          description: switch (a) {
                            ActivityLevel.sedentary =>
                              'Paso la mayor parte del día sentado',
                            ActivityLevel.moderate =>
                              'Camino a diario, algo de movimiento',
                            ActivityLevel.active =>
                              'Trabajo físico o me muevo constantemente',
                          },
                          selected: _activity == a,
                          onTap: () => setState(() => _activity = a),
                        ),
                    ],
                  ),
                  _step(
                    title: '¿Cuál es tu nivel?',
                    subtitle: 'Adaptamos cada ejercicio a tu experiencia.',
                    options: [
                      for (final l in Level.values)
                        _OptionCard(
                          emoji: l.emoji,
                          label: l.label,
                          description: switch (l) {
                            Level.beginner => 'Estoy empezando o vuelvo tras una pausa',
                            Level.intermediate => 'Entreno de forma regular',
                            Level.advanced => 'Domino la técnica y busco reto',
                          },
                          selected: _level == l,
                          accent: l.color,
                          onTap: () => setState(() => _level = l),
                        ),
                    ],
                  ),
                  _step(
                    title: '¿Cuál es tu objetivo?',
                    subtitle: 'Define series, repeticiones y descansos.',
                    options: [
                      for (final g in Goal.values)
                        _OptionCard(
                          emoji: g.emoji,
                          label: g.label,
                          description: switch (g) {
                            Goal.loseWeight => 'Más repeticiones, menos descanso',
                            Goal.buildMuscle => 'Más series, cargas progresivas',
                            Goal.stayFit => 'Equilibrio entre fuerza y resistencia',
                          },
                          selected: _goal == g,
                          onTap: () => setState(() => _goal = g),
                        ),
                    ],
                  ),
                  _step(
                    title: '¿Cómo quieres repartir el esfuerzo?',
                    subtitle:
                        'Define qué zonas reciben más días y más series cada semana.',
                    options: [
                      for (final f in TrainingFocus.values)
                        _OptionCard(
                          emoji: f.emoji,
                          label: f.label,
                          description: f.description,
                          selected: _focus == f,
                          onTap: () => setState(() {
                            _focus = f;
                            _focusChosen = true;
                          }),
                        ),
                    ],
                  ),
                  _step(
                    title: '¿Con qué equipo cuentas?',
                    subtitle: 'Solo te propondremos ejercicios que puedas hacer.',
                    options: [
                      for (final eq in EquipmentSetup.values)
                        _OptionCard(
                          emoji: eq.emoji,
                          label: eq.label,
                          description: switch (eq) {
                            EquipmentSetup.none =>
                              'Peso corporal y bandas elásticas',
                            EquipmentSetup.basic =>
                              'Mancuernas, pesas rusas, balones',
                            EquipmentSetup.gym => 'Barras, poleas y máquinas',
                          },
                          selected: _equipment == eq,
                          onTap: () => setState(() => _equipment = eq),
                        ),
                    ],
                  ),
                  _step(
                    title: '¿Cuántos días a la semana?',
                    subtitle: 'Distribuimos los músculos para que se recuperen.',
                    options: [
                      for (final d in [2, 3, 4, 5])
                        _OptionCard(
                          emoji: '📅',
                          label: '$d días',
                          description: switch (d) {
                            2 => 'Cuerpo completo cada sesión',
                            3 => 'Empuje · Tirón · Piernas',
                            4 => 'Tren superior / inferior alternado',
                            _ => 'Split completo de 5 días',
                          },
                          selected: _days == d,
                          onTap: () => setState(() => _days = d),
                        ),
                    ],
                  ),
                  _zonesStep(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: FilledButton(
                onPressed: _canContinue ? _next : null,
                child: Text(_page == _pageCount - 1
                    ? 'Crear mi rutina 🚀'
                    : 'Continuar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Paso 1: avatar en vivo — sexo + estatura + peso.
  Widget _avatarStep() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        const SizedBox(height: 12),
        const Text('Crea tu avatar',
            style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
                color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        const Text('Tu silueta cambia con tus medidas reales.',
            style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Center(
          child: Avatar3D(
            key: ValueKey('$_sex-$_heightCm-$_weightKg'),
            sex: _sex,
            bmi: _bmi,
            height: 230,
          ),
        ),
        const SizedBox(height: 10),
        SegmentedButton<Sex>(
          segments: [
            for (final s in Sex.values)
              ButtonSegment(value: s, label: Text('${s.emoji} ${s.label}')),
          ],
          selected: {_sex},
          onSelectionChanged: (sel) => setState(() {
            _sex = sel.first;
            if (!_focusChosen) _focus = _sex.suggestedFocus;
          }),
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? AppColors.accent.withValues(alpha: 0.18)
                    : AppColors.surface),
            foregroundColor:
                WidgetStateProperty.all(AppColors.textPrimary),
          ),
        ),
        const SizedBox(height: 12),
        _sliderRow(
          label: 'Estatura',
          value: '$_heightCm cm',
          child: Slider(
            value: _heightCm.toDouble(),
            min: 140,
            max: 210,
            divisions: 70,
            onChanged: (v) => setState(() => _heightCm = v.round()),
          ),
        ),
        _sliderRow(
          label: 'Peso',
          value: '$_weightKg kg',
          child: Slider(
            value: _weightKg.toDouble(),
            min: 40,
            max: 150,
            divisions: 110,
            onChanged: (v) => setState(() => _weightKg = v.round()),
          ),
        ),
      ],
    );
  }

  Widget _sliderRow(
      {required String label, required String value, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600)),
            Text(value,
                style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 16)),
          ],
        ),
        child,
      ],
    );
  }

  /// Paso 6: zonas del cuerpo a priorizar (opcional, máximo 3).
  Widget _zonesStep() {
    const zones = [
      'chest',
      'back',
      'shoulders',
      'upper arms',
      'waist',
      'upper legs',
      'lower legs',
    ];
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 16),
        const Text('¿Qué zonas quieres priorizar?',
            style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
                color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        const Text(
            'Les daremos mayor intensidad en tus rutinas. Elige hasta 3 (opcional).',
            style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
        const SizedBox(height: 24),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final z in zones)
              FilterChip(
                label: Text(trBodyPart(z),
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _focusZones.contains(z)
                            ? AppColors.onAccent
                            : AppColors.textPrimary)),
                selected: _focusZones.contains(z),
                selectedColor: AppColors.accent,
                checkmarkColor: AppColors.onAccent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                onSelected: (sel) => setState(() {
                  if (sel && _focusZones.length < 3) {
                    _focusZones.add(z);
                  } else {
                    _focusZones.remove(z);
                  }
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_focusZones.isNotEmpty)
          Text(
            '💪 ${_focusZones.map(trBodyPart).join(", ")} tendrán ejercicios extra.',
            style: const TextStyle(color: AppColors.accent, fontSize: 14),
          ),
      ],
    );
  }

  Widget _step({
    required String title,
    required String subtitle,
    required List<Widget> options,
  }) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 16),
        Text(title,
            style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
                color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Text(subtitle,
            style: const TextStyle(fontSize: 15, color: AppColors.textSecondary)),
        const SizedBox(height: 24),
        ...options.map((o) => Padding(
            padding: const EdgeInsets.only(bottom: 12), child: o)),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  final String emoji;
  final String label;
  final String description;
  final bool selected;
  final Color? accent;
  final VoidCallback onTap;

  const _OptionCard({
    required this.emoji,
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.accent;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.12) : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? color : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(description,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              if (selected) Icon(Icons.check_circle, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
