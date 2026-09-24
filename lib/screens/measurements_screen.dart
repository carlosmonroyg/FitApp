import 'package:flutter/material.dart';

import '../models/measurement.dart';
import '../services/storage.dart';
import '../theme.dart';
import '../widgets/trend_chart.dart';

/// "Mi cuerpo": historial de medidas con tendencia por medida y formulario
/// de toma. Es la segunda fuente de datos del coach (la primera es el
/// registro por serie).
class MeasurementsScreen extends StatefulWidget {
  const MeasurementsScreen({super.key});

  @override
  State<MeasurementsScreen> createState() => _MeasurementsScreenState();
}

class _MeasurementsScreenState extends State<MeasurementsScreen> {
  MeasureKind _kind = MeasureKind.weight;

  Future<void> _addMeasurement() async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const MeasurementFormScreen(),
    ));
    if (saved == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final history = Storage.measurements;
    final latest = Storage.latestMeasurement;
    final available = MeasureKind.values
        .where((k) => history.any((m) => m.valueOf(k) != null))
        .toList();
    if (available.isNotEmpty && !available.contains(_kind)) {
      _kind = available.first;
    }
    final points = [
      for (final m in history)
        if (m.valueOf(_kind) != null) TrendPoint(m.date, m.valueOf(_kind)!),
    ];
    final trend = trendFor(history, _kind);
    final whr = latest?.waistHipRatio;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi cuerpo')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (latest == null)
            _EmptyState(onTap: _addMeasurement)
          else ...[
            Text(
              'Última toma: ${_fmtDate(latest.date)}',
              style:
                  const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final k in MeasureKind.values)
                  if (Storage.latestValue(k) != null)
                    _MeasureTile(
                      kind: k,
                      value: Storage.latestValue(k)!,
                      trend: trendFor(history, k),
                      selected: k == _kind,
                      onTap: () => setState(() => _kind = k),
                    ),
              ],
            ),
            if (whr != null) ...[
              const SizedBox(height: 12),
              _WhrNote(ratio: whr),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Text(
                  '${_kind.emoji} ${_kind.label}',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary),
                ),
                const Spacer(),
                if (trend != null)
                  Text(
                    _trendText(trend),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: TrendChart(points: points, unit: _kind.unit),
            ),
            const SizedBox(height: 24),
            const Text('Historial',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            for (final m in history) ...[
              _HistoryTile(measurement: m),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 80),
          ],
        ],
      ),
      floatingActionButton: latest == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _addMeasurement,
              icon: const Icon(Icons.straighten),
              label: const Text('Registrar medidas'),
            ),
    );
  }

  static String _trendText(MeasureTrend t) {
    final d = t.delta;
    final sign = d > 0 ? '+' : '';
    final val = d == d.roundToDouble()
        ? d.toInt().toString()
        : d.toStringAsFixed(1);
    final weeks = (t.days / 7).round();
    final period = weeks >= 2 ? '$weeks sem' : '${t.days} días';
    return '$sign$val ${t.kind.unit} en $period';
  }
}

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _fmtNum(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

class _EmptyState extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyState({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Text('📏', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text('Tu punto de partida',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text(
            'Peso y medidas una vez por semana, el mismo día y en ayunas. '
            'Con dos tomas ya verás la tendencia; con cuatro, tu coach '
            'tendrá con qué trabajar.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.straighten),
            label: const Text('Registrar mi primera toma'),
          ),
        ],
      ),
    );
  }
}

class _MeasureTile extends StatelessWidget {
  final MeasureKind kind;
  final double value;
  final MeasureTrend? trend;
  final bool selected;
  final VoidCallback onTap;

  const _MeasureTile({
    required this.kind,
    required this.value,
    required this.trend,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final d = trend?.delta;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 104,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.14)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? AppColors.accent : Colors.transparent),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(kind.label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 2),
            Text('${_fmtNum(value)} ${kind.unit}',
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            if (d != null && d.abs() >= 0.05)
              Text(
                '${d > 0 ? '▲' : '▼'} ${_fmtNum(d.abs())}',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: d > 0
                        ? const Color(0xFFFBBF24)
                        : const Color(0xFF4ADE80)),
              ),
          ],
        ),
      ),
    );
  }
}

/// El ratio cintura/cadera es más útil que el IMC para ver salud metabólica
/// y responde rápido al entrenamiento.
class _WhrNote extends StatelessWidget {
  final double ratio;
  const _WhrNote({required this.ratio});

  @override
  Widget build(BuildContext context) {
    final sex = Storage.profile?.sex.name ?? 'male';
    final high = sex == 'female' ? ratio >= 0.85 : ratio >= 0.90;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Text('🧭', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Cintura/cadera ${ratio.toStringAsFixed(2)} · '
              '${high ? 'por encima del rango saludable; buen objetivo para bajarlo' : 'dentro del rango saludable'}',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final Measurement measurement;
  const _HistoryTile({required this.measurement});

  @override
  Widget build(BuildContext context) {
    final m = measurement;
    final parts = [
      for (final k in MeasureKind.values)
        if (m.valueOf(k) != null)
          '${k.label} ${_fmtNum(m.valueOf(k)!)} ${k.unit}',
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_fmtDate(m.date),
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(parts.join(' · '),
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
        ],
      ),
    );
  }
}

/// Formulario de toma: todos los campos opcionales, precargados con el
/// último valor conocido; −/+ de 0.5 o escribir directamente.
class MeasurementFormScreen extends StatefulWidget {
  const MeasurementFormScreen({super.key});

  @override
  State<MeasurementFormScreen> createState() => _MeasurementFormScreenState();
}

class _MeasurementFormScreenState extends State<MeasurementFormScreen> {
  late final Map<MeasureKind, TextEditingController> _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = {
      for (final k in MeasureKind.values)
        k: TextEditingController(
            text: k == MeasureKind.weight
                ? _fmtNum(Storage.latestValue(k) ??
                    Storage.profile?.weightKg.toDouble() ??
                    0)
                : (Storage.latestValue(k) == null
                    ? ''
                    : _fmtNum(Storage.latestValue(k)!))),
    };
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  double? _value(MeasureKind k) {
    final t = _ctrl[k]!.text.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    final v = double.tryParse(t);
    return v == null || v <= 0 ? null : v;
  }

  void _bump(MeasureKind k, double delta) {
    final v = (_value(k) ?? 0) + delta;
    setState(() => _ctrl[k]!.text = v <= 0 ? '' : _fmtNum(v));
  }

  Future<void> _save() async {
    final now = DateTime.now();
    final m = Measurement(
      dayKey: Measurement.keyFor(now),
      date: now,
      weightKg: _value(MeasureKind.weight),
      waistCm: _value(MeasureKind.waist),
      hipCm: _value(MeasureKind.hip),
      chestCm: _value(MeasureKind.chest),
      armCm: _value(MeasureKind.arm),
      thighCm: _value(MeasureKind.thigh),
      calfCm: _value(MeasureKind.calf),
      bodyFatPct: _value(MeasureKind.bodyFat),
    );
    if (m.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Anota al menos una medida')));
      return;
    }
    await Storage.saveMeasurement(m);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar medidas', style: TextStyle(fontSize: 18)),
        actions: [
          TextButton(onPressed: _save, child: const Text('Guardar')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Solo lo que tengas a mano. Para comparar entre semanas, mide '
            'siempre en el mismo sitio y a la misma hora.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),
          for (final k in MeasureKind.values) ...[
            _FieldRow(
              kind: k,
              controller: _ctrl[k]!,
              onMinus: () => _bump(k, -k.step),
              onPlus: () => _bump(k, k.step),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 12),
          FilledButton(onPressed: _save, child: const Text('Guardar toma')),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final MeasureKind kind;
  final TextEditingController controller;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _FieldRow({
    required this.kind,
    required this.controller,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Text(kind.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(kind.label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                Text(kind.hint,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          IconButton(
              onPressed: onMinus,
              iconSize: 18,
              icon: const Icon(Icons.remove)),
          SizedBox(
            width: 64,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                hintText: '—',
                suffixText: kind.unit,
                suffixStyle: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                filled: true,
                fillColor: AppColors.surfaceHigh,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          IconButton(
              onPressed: onPlus, iconSize: 18, icon: const Icon(Icons.add)),
        ],
      ),
    );
  }
}
