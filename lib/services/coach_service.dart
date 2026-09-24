import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../models/coach.dart';
import '../models/routine.dart';
import 'athlete_snapshot.dart';
import 'auth_service.dart';
import 'repository.dart';
import 'routine_generator.dart';
import 'storage.dart';

/// Error legible del coach para mostrar al usuario.
class CoachException implements Exception {
  final String message;
  const CoachException(this.message);
  @override
  String toString() => message;
}

/// Puente con la Cloud Function `coachCheckin`.
///
/// La app arma el snapshot, el servidor llama al modelo y valida la
/// respuesta, y aquí se guarda el check-in y se aplica la prescripción al
/// plan. La clave de API nunca toca el teléfono.
class CoachService {
  CoachService._();

  /// Host del emulador de Functions. Se fija con
  /// `--dart-define=COACH_EMULATOR_HOST=192.168.1.20` (teléfono físico) o
  /// queda en 10.0.2.2 (emulador Android) en modo debug. Vacío = producción.
  static const _emulatorHost =
      String.fromEnvironment('COACH_EMULATOR_HOST', defaultValue: '');

  static bool _configured = false;

  static FirebaseFunctions get _functions {
    final f = FirebaseFunctions.instanceFor(region: 'us-central1');
    if (!_configured) {
      _configured = true;
      var host = _emulatorHost;
      if (host.isEmpty && kDebugMode && Platform.isAndroid) host = '10.0.2.2';
      if (host.isNotEmpty) f.useFunctionsEmulator(host, 5001);
    }
    return f;
  }

  static bool get isAvailable =>
      AuthService.isAvailable && AuthService.user != null;

  /// ¿Ya hay check-in de esta semana?
  static CoachCheckin? get thisWeekCheckin {
    final c = Storage.lastCheckin;
    return c != null && c.weekId == Storage.currentWeekId ? c : null;
  }

  /// Toca revisión: fin de semana, o ya completó lo planificado.
  static bool checkinDue(List<WorkoutDay> week) {
    if (thisWeekCheckin != null) return false;
    final planned = week.where((d) => !d.isRest).length;
    final weekday = DateTime.now().weekday;
    return weekday >= DateTime.saturday ||
        (planned > 0 && Storage.completedThisWeek >= planned);
  }

  /// Pide el check-in al servidor (o recibe el de esta semana si ya existe).
  static Future<CoachCheckin> requestCheckin({bool force = false}) async {
    if (!isAvailable) {
      throw const CoachException(
          'Inicia sesión con Google para usar el coach.');
    }
    final profile = Storage.profile;
    if (profile == null) throw const CoachException('Falta tu perfil.');
    final repo = ExerciseRepository.instance;
    final week = Storage.loadWeek(repo.byId) ?? const <WorkoutDay>[];

    final snapshot = AthleteSnapshot.build(
      profile: profile,
      week: week,
      catalog: repo.all,
      previousNotes: Storage.coachNotes,
    );

    late final Map<String, dynamic> data;
    try {
      final result = await _functions
          .httpsCallable('coachCheckin',
              options: HttpsCallableOptions(
                  timeout: const Duration(seconds: 120)))
          .call<Map<Object?, Object?>>({'snapshot': snapshot, 'force': force});
      data = Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw CoachException(switch (e.code) {
        'unauthenticated' => 'Inicia sesión para usar el coach.',
        'failed-precondition' =>
          'El coach no está configurado en el servidor (clave de API).',
        'resource-exhausted' => 'El coach está saturado; prueba en un minuto.',
        'unavailable' || 'deadline-exceeded' =>
          'No pude hablar con el coach. ¿Hay conexión? Inténtalo de nuevo.',
        _ => e.message ?? 'El coach no respondió (${e.code}).',
      });
    }

    final checkin = CoachCheckin.fromJson(data);
    await Storage.saveCheckin(checkin);
    await Storage.saveCoachNotes(checkin.coachNotes);
    return checkin;
  }

  /// Aplica la prescripción: guarda los ajustes y regenera la semana con
  /// ellos. Devuelve la semana nueva.
  static Future<List<WorkoutDay>> apply(CoachCheckin checkin) async {
    final profile = Storage.profile!;
    final repo = ExerciseRepository.instance;
    // Continuidad: conserva lo que la persona ya viene entrenando.
    final keep = <String>{
      for (final s in Storage.sessions.take(6))
        for (final e in s.exercises) e.exerciseId,
    };
    final prescription = checkin.prescription(keep: keep);
    await Storage.savePrescription(prescription);
    final week = RoutineGenerator(repo.all, profile,
            phase: Storage.currentPhase, prescription: prescription)
        .generateWeek();
    await Storage.saveWeek(week);
    await Storage.saveCheckin(checkin.copyWith(applied: true));
    return week;
  }
}
