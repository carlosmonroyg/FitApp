import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/coach.dart';
import '../models/exercise.dart';
import '../models/measurement.dart';
import '../models/phase.dart';
import '../models/plan.dart';
import '../models/profile.dart';
import '../models/routine.dart';
import '../models/training_log.dart';
import 'cloud_sync.dart';

/// Persistencia local: perfil, rutina semanal, racha e historial.
/// Cada guardado dispara una copia a la nube si hay sesión iniciada.
class Storage {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ---- Perfil ----
  static UserProfile? get profile {
    final raw = _prefs.getString('profile');
    if (raw == null) return null;
    return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  static Future<void> saveProfile(UserProfile p) async {
    await _prefs.setString('profile', jsonEncode(p.toJson()));
    unawaited(CloudSync.push());
  }

  // ---- Aviso de salud y privacidad ----

  /// Versión de los términos que aceptó el usuario (0 si nunca).
  static int get acceptedTermsVersion =>
      _prefs.getInt('termsAcceptedVersion') ?? 0;

  static Future<void> acceptTerms(int version) async {
    await _prefs.setInt('termsAcceptedVersion', version);
    await _prefs.setString(
        'termsAcceptedAt', DateTime.now().toUtc().toIso8601String());
    unawaited(CloudSync.push());
  }

  // ---- Programa guiado por fases ----

  /// Día en que arrancó el programa. Se fija al crear el perfil.
  static DateTime? get programStart {
    final raw = _prefs.getString('programStart');
    return raw == null ? null : DateTime.tryParse(raw);
  }

  static Future<void> startProgram() async {
    final now = DateTime.now();
    await _prefs.setString(
      'programStart',
      DateTime(now.year, now.month, now.day).toIso8601String(),
    );
    unawaited(CloudSync.push());
  }

  /// Semana del programa, 1-based. Sin fecha de inicio se asume la primera.
  static int get programWeek {
    final start = programStart;
    if (start == null) return 1;
    final days = DateTime.now().difference(start).inDays;
    return days < 0 ? 1 : days ~/ 7 + 1;
  }

  static TrainingPhase get currentPhase => phaseForWeek(programWeek);

  /// Fase con la que se generó la rutina guardada, para detectar el salto.
  static String? get weekPhase => _prefs.getString('weekPhase');

  // ---- Plan comercial ----
  static Plan get plan {
    final raw = _prefs.getString('plan');
    if (raw == null) return Plan.free;
    return Plan.values.asNameMap()[raw] ?? Plan.free;
  }

  static Future<void> savePlan(Plan p) async {
    await _prefs.setString('plan', p.name);
    unawaited(CloudSync.push());
  }

  // ---- Rutina semanal ----
  static Future<void> saveWeek(List<WorkoutDay> week) async {
    await _prefs.setString(
      'week',
      jsonEncode(week.map((d) => d.toJson()).toList()),
    );
    await _prefs.setString('weekPhase', currentPhase.name);
    unawaited(CloudSync.push());
  }

  static List<WorkoutDay>? loadWeek(Exercise Function(String) resolve) {
    final raw = _prefs.getString('week');
    if (raw == null) return null;
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return list.map((j) => WorkoutDay.fromJson(j, resolve)).toList();
    } catch (_) {
      return null; // rutina vieja incompatible: se regenera
    }
  }

  // ---- Entrenamientos completados ----
  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Set<String> get completedDates =>
      (_prefs.getStringList('completed') ?? []).toSet();

  static Future<void> markCompletedToday() async {
    final done = completedDates..add(_dayKey(DateTime.now()));
    await _prefs.setStringList('completed', done.toList());
    unawaited(CloudSync.push());
  }

  static bool get completedToday =>
      completedDates.contains(_dayKey(DateTime.now()));

  /// Racha: días consecutivos con entrenamiento, terminando hoy o ayer.
  static int get streak {
    final done = completedDates;
    if (done.isEmpty) return 0;
    var day = DateTime.now();
    if (!done.contains(_dayKey(day))) {
      day = day.subtract(const Duration(days: 1));
      if (!done.contains(_dayKey(day))) return 0;
    }
    var count = 0;
    while (done.contains(_dayKey(day))) {
      count++;
      day = day.subtract(const Duration(days: 1));
    }
    return count;
  }

  /// Entrenamientos completados en la semana actual (lunes a domingo).
  static int get completedThisWeek {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final done = completedDates;
    var count = 0;
    for (var i = 0; i < 7; i++) {
      if (done.contains(_dayKey(monday.add(Duration(days: i))))) count++;
    }
    return count;
  }

  /// Marca que ya se ofreció subir de nivel esta semana (para no insistir).
  static String get _weekId {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    return _dayKey(monday);
  }

  static bool get levelUpOfferedThisWeek =>
      _prefs.getString('levelUpOffered') == _weekId;

  static Future<void> markLevelUpOffered() async {
    await _prefs.setString('levelUpOffered', _weekId);
    unawaited(CloudSync.push());
  }

  // ---- Registro de entrenamientos (series reales) ----

  static List<WorkoutSession>? _sessionsCache;

  /// Sesiones registradas, de la más reciente a la más antigua.
  static List<WorkoutSession> get sessions {
    if (_sessionsCache != null) return _sessionsCache!;
    final raw = _prefs.getString('sessions');
    if (raw == null) return _sessionsCache = [];
    try {
      final list = (jsonDecode(raw) as List)
          .map((j) => WorkoutSession.fromJson(Map<String, dynamic>.from(j)))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      return _sessionsCache = list;
    } catch (_) {
      return _sessionsCache = [];
    }
  }

  static Future<void> _persistSessions(List<WorkoutSession> list) async {
    list.sort((a, b) => b.date.compareTo(a.date));
    _sessionsCache = list;
    await _prefs.setString(
      'sessions',
      jsonEncode(list.map((s) => s.toJson()).toList()),
    );
  }

  /// Guarda (o reemplaza por id) una sesión y la sube a la nube.
  static Future<void> saveSession(WorkoutSession s) async {
    final list = sessions.where((x) => x.id != s.id).toList()..add(s);
    await _persistSessions(list);
    unawaited(CloudSync.pushSession(s));
  }

  // ---- Entrenamiento en curso ----
  // Solo local: es un estado de minutos, no hace falta en la nube.

  /// Borrador del entrenamiento a medias, o nulo si no hay o ya caducó.
  static WorkoutDraft? get workoutDraft {
    final raw = _prefs.getString('workoutDraft');
    if (raw == null) return null;
    try {
      final d = WorkoutDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      return d.isStale ? null : d;
    } catch (_) {
      return null;
    }
  }

  /// Borrador para retomar la rutina [day], si es de ella.
  static WorkoutDraft? draftFor(WorkoutDay day) {
    final d = workoutDraft;
    if (d == null || d.doneSets == 0) return null;
    return d.matches(day.title, [for (final e in day.exercises) e.exercise.id])
        ? d
        : null;
  }

  static Future<void> saveWorkoutDraft(WorkoutDraft d) =>
      _prefs.setString('workoutDraft', jsonEncode(d.toJson()));

  static Future<void> clearWorkoutDraft() => _prefs.remove('workoutDraft');

  /// Último registro de un ejercicio, para precargar peso y repeticiones.
  static ExerciseLog? lastLogFor(String exerciseId) {
    for (final s in sessions) {
      for (final e in s.exercises) {
        if (e.exerciseId == exerciseId && e.sets.isNotEmpty) return e;
      }
    }
    return null;
  }

  /// Mejor 1RM estimado histórico de un ejercicio, ignorando [excludeId].
  static double? best1RMFor(String exerciseId, {String? excludeId}) {
    double? best;
    for (final s in sessions) {
      if (s.id == excludeId) continue;
      for (final e in s.exercises) {
        if (e.exerciseId != exerciseId) continue;
        final b = e.best1RM;
        if (b != null && (best == null || b > best)) best = b;
      }
    }
    return best;
  }

  /// Récords personales logrados en [session] frente al historial previo.
  static List<PersonalRecord> recordsIn(WorkoutSession session) {
    final records = <PersonalRecord>[];
    for (final e in session.exercises) {
      final now = e.best1RM;
      if (now == null) continue;
      final before = best1RMFor(e.exerciseId, excludeId: session.id);
      if (before == null || now > before + 0.01) {
        records.add(
          PersonalRecord(
            exerciseId: e.exerciseId,
            exerciseName: e.exerciseName,
            set: e.heaviest!,
            previous1RM: before,
          ),
        );
      }
    }
    return records;
  }

  /// Sesión anterior con el mismo título (mismo día del split), si existe.
  static WorkoutSession? previousSessionLike(WorkoutSession s) {
    for (final x in sessions) {
      if (x.id != s.id && x.title == s.title && x.date.isBefore(s.date)) {
        return x;
      }
    }
    return null;
  }

  // ---- Medidas corporales ----

  static List<Measurement>? _measurementsCache;

  /// Tomas de medidas, de la más reciente a la más antigua.
  static List<Measurement> get measurements {
    if (_measurementsCache != null) return _measurementsCache!;
    final raw = _prefs.getString('measurements');
    if (raw == null) return _measurementsCache = [];
    try {
      final list = (jsonDecode(raw) as List)
          .map((j) => Measurement.fromJson(Map<String, dynamic>.from(j)))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      return _measurementsCache = list;
    } catch (_) {
      return _measurementsCache = [];
    }
  }

  static Future<void> _persistMeasurements(List<Measurement> list) async {
    list.sort((a, b) => b.date.compareTo(a.date));
    _measurementsCache = list;
    await _prefs.setString(
      'measurements',
      jsonEncode(list.map((m) => m.toJson()).toList()),
    );
  }

  /// Guarda una toma (una por día; la nueva reemplaza la del mismo día).
  /// Si trae peso, actualiza también el perfil para que IMC y rutina lo usen.
  static Future<void> saveMeasurement(Measurement m) async {
    final list = measurements.where((x) => x.dayKey != m.dayKey).toList()
      ..add(m);
    await _persistMeasurements(list);
    final p = profile;
    if (m.weightKg != null && p != null && m.weightKg!.round() != p.weightKg) {
      await saveProfile(p.copyWith(weightKg: m.weightKg!.round()));
    }
    unawaited(CloudSync.pushMeasurement(m));
  }

  static Measurement? get latestMeasurement =>
      measurements.isEmpty ? null : measurements.first;

  /// Último valor conocido de cada medida (para precargar el formulario).
  static double? latestValue(MeasureKind k) {
    for (final m in measurements) {
      final v = m.valueOf(k);
      if (v != null) return v;
    }
    return null;
  }

  /// Días desde la última toma; nulo si nunca midió.
  static int? get daysSinceMeasurement {
    final last = latestMeasurement;
    return last == null ? null : DateTime.now().difference(last.date).inDays;
  }

  // ---- Coach ----

  /// Último check-in recibido (se guarda entero para mostrarlo sin red).
  static CoachCheckin? get lastCheckin {
    final raw = _prefs.getString('coachCheckin');
    if (raw == null) return null;
    try {
      return CoachCheckin.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveCheckin(CoachCheckin c) async {
    await _prefs.setString('coachCheckin', jsonEncode(c.toJson()));
    unawaited(CloudSync.push());
  }

  /// Prescripción vigente: la aplica el generador al (re)generar la semana y
  /// la pantalla de entrenamiento al precargar la carga.
  static Prescription get activePrescription {
    final raw = _prefs.getString('prescription');
    if (raw == null) return Prescription.none;
    try {
      return Prescription.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return Prescription.none;
    }
  }

  static Future<void> savePrescription(Prescription p) async {
    await _prefs.setString('prescription', jsonEncode(p.toJson()));
    unawaited(CloudSync.push());
  }

  /// Memoria del coach sobre esta persona (la devuelve el servidor).
  static List<String> get coachNotes =>
      _prefs.getStringList('coachNotes') ?? const [];

  static Future<void> saveCoachNotes(List<String> notes) =>
      _prefs.setStringList('coachNotes', notes);

  /// Lunes de la semana actual (yyyy-MM-dd): identifica el check-in semanal.
  static String get currentWeekId => _weekId;

  static Future<void> reset() async {
    await _prefs.remove('profile');
    await _prefs.remove('week');
    await _prefs.remove('prescription');
    await _prefs.remove('workoutDraft');
  }

  /// Borra todos los datos locales (al cerrar sesión, para que el siguiente
  /// usuario del dispositivo no herede el progreso de otra cuenta).
  static Future<void> clearAll() {
    _sessionsCache = null;
    _measurementsCache = null;
    return _prefs.clear();
  }

  /// Vuelca sesiones y medidas descargadas de la nube (sin volver a subirlas).
  static Future<void> importHistory({
    required List<Map<String, dynamic>> sessions,
    required List<Map<String, dynamic>> measurements,
  }) async {
    if (sessions.isNotEmpty) {
      final byId = {for (final s in Storage.sessions) s.id: s};
      for (final j in sessions) {
        try {
          final s = WorkoutSession.fromJson(j);
          byId[s.id] = s;
        } catch (_) {}
      }
      await _persistSessions(byId.values.toList());
    }
    if (measurements.isNotEmpty) {
      final byDay = {for (final m in Storage.measurements) m.dayKey: m};
      for (final j in measurements) {
        try {
          final m = Measurement.fromJson(j);
          byDay[m.dayKey] = m;
        } catch (_) {}
      }
      await _persistMeasurements(byDay.values.toList());
    }
  }

  // ---- Sincronización con la nube ----

  /// Estado local completo con las mismas claves que usa Firestore.
  /// La semana viaja como JSON crudo (idéntico al formato local).
  static Map<String, dynamic> exportCloudData() => {
        'profile': profile?.toJson(),
        'week': _prefs.getString('week'),
        'completed': completedDates.toList(),
        'levelUpOffered': _prefs.getString('levelUpOffered'),
        'plan': plan.name,
        'programStart': _prefs.getString('programStart'),
        'weekPhase': weekPhase,
        'coachCheckin': _prefs.getString('coachCheckin'),
        'prescription': _prefs.getString('prescription'),
        'coachNotes': coachNotes,
        'termsAcceptedVersion': acceptedTermsVersion,
        'termsAcceptedAt': _prefs.getString('termsAcceptedAt'),
      };

  /// Vuelca al almacenamiento local lo descargado de Firestore.
  static Future<void> importCloudData(Map<String, dynamic> data) async {
    final profile = data['profile'];
    if (profile is Map) {
      await _prefs.setString(
        'profile',
        jsonEncode(Map<String, dynamic>.from(profile)),
      );
    }
    final week = data['week'];
    if (week is String) await _prefs.setString('week', week);
    final completed = data['completed'];
    if (completed is List) {
      await _prefs.setStringList('completed', completed.cast<String>());
    }
    final offered = data['levelUpOffered'];
    if (offered is String) await _prefs.setString('levelUpOffered', offered);
    final plan = data['plan'];
    if (plan is String) await _prefs.setString('plan', plan);
    final start = data['programStart'];
    if (start is String) await _prefs.setString('programStart', start);
    final phase = data['weekPhase'];
    if (phase is String) await _prefs.setString('weekPhase', phase);
    final checkin = data['coachCheckin'];
    if (checkin is String) await _prefs.setString('coachCheckin', checkin);
    final prescription = data['prescription'];
    if (prescription is String) {
      await _prefs.setString('prescription', prescription);
    }
    final terms = data['termsAcceptedVersion'];
    if (terms is int && terms > 0) {
      await _prefs.setInt('termsAcceptedVersion', terms);
    }
    final termsAt = data['termsAcceptedAt'];
    if (termsAt is String) await _prefs.setString('termsAcceptedAt', termsAt);
    final notes = data['coachNotes'];
    if (notes is List) {
      await _prefs.setStringList('coachNotes', notes.cast<String>());
    }
  }
}
