import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/exercise.dart';
import '../models/profile.dart';
import '../models/routine.dart';
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

  // ---- Rutina semanal ----
  static Future<void> saveWeek(List<WorkoutDay> week) async {
    await _prefs.setString(
        'week', jsonEncode(week.map((d) => d.toJson()).toList()));
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
    final monday =
        DateTime(now.year, now.month, now.day - (now.weekday - 1));
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
    final monday =
        DateTime(now.year, now.month, now.day - (now.weekday - 1));
    return _dayKey(monday);
  }

  static bool get levelUpOfferedThisWeek =>
      _prefs.getString('levelUpOffered') == _weekId;

  static Future<void> markLevelUpOffered() async {
    await _prefs.setString('levelUpOffered', _weekId);
    unawaited(CloudSync.push());
  }

  static Future<void> reset() async {
    await _prefs.remove('profile');
    await _prefs.remove('week');
  }

  /// Borra todos los datos locales (al cerrar sesión, para que el siguiente
  /// usuario del dispositivo no herede el progreso de otra cuenta).
  static Future<void> clearAll() => _prefs.clear();

  // ---- Sincronización con la nube ----

  /// Estado local completo con las mismas claves que usa Firestore.
  /// La semana viaja como JSON crudo (idéntico al formato local).
  static Map<String, dynamic> exportCloudData() => {
        'profile': profile?.toJson(),
        'week': _prefs.getString('week'),
        'completed': completedDates.toList(),
        'levelUpOffered': _prefs.getString('levelUpOffered'),
      };

  /// Vuelca al almacenamiento local lo descargado de Firestore.
  static Future<void> importCloudData(Map<String, dynamic> data) async {
    final profile = data['profile'];
    if (profile is Map) {
      await _prefs.setString(
          'profile', jsonEncode(Map<String, dynamic>.from(profile)));
    }
    final week = data['week'];
    if (week is String) await _prefs.setString('week', week);
    final completed = data['completed'];
    if (completed is List) {
      await _prefs.setStringList('completed', completed.cast<String>());
    }
    final offered = data['levelUpOffered'];
    if (offered is String) await _prefs.setString('levelUpOffered', offered);
  }
}
