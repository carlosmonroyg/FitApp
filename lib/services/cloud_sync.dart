import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/measurement.dart';
import '../models/training_log.dart';
import 'auth_service.dart';
import 'crash_reporter.dart';
import 'storage.dart';

/// Sincroniza los datos locales ([Storage]) con Firestore en `users/{uid}`.
///
/// Estrategia local-first: la app siempre lee y escribe en el teléfono;
/// tras cada guardado se sube una copia a la nube y, al iniciar sesión,
/// se descarga lo que exista para ese usuario.
class CloudSync {
  CloudSync._();

  static DocumentReference<Map<String, dynamic>>? get _doc {
    final user = AuthService.user;
    if (user == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(user.uid);
  }

  /// Descarga los datos del usuario y los vuelca al almacenamiento local.
  /// Devuelve `true` si había datos en la nube.
  static Future<bool> pull() async {
    final doc = _doc;
    if (doc == null) return false;
    final snap = await doc.get();
    final data = snap.data();
    if (data == null || data['profile'] == null) return false;
    await Storage.importCloudData(data);
    await _pullHistory(doc);
    return true;
  }

  /// Sesiones y medidas viven en subcolecciones: crecen sin límite y el
  /// documento principal se mantiene pequeño.
  static Future<void> _pullHistory(
      DocumentReference<Map<String, dynamic>> doc) async {
    try {
      final sessions = await doc.collection('sessions').get();
      final measurements = await doc.collection('measurements').get();
      await Storage.importHistory(
        sessions: sessions.docs.map((d) => d.data()).toList(),
        measurements: measurements.docs.map((d) => d.data()).toList(),
      );
    } catch (e, st) {
      CrashReporter.record(e, st, reason: 'sync.pullHistory');
    }
  }

  static Future<void> pushSession(WorkoutSession s) async {
    final doc = _doc;
    if (doc == null) return;
    try {
      await doc.collection('sessions').doc(s.id).set(s.toJson());
    } catch (e, st) {
      CrashReporter.record(e, st, reason: 'sync.pushSession');
    }
  }

  static Future<void> pushMeasurement(Measurement m) async {
    final doc = _doc;
    if (doc == null) return;
    try {
      await doc.collection('measurements').doc(m.dayKey).set(m.toJson());
    } catch (e, st) {
      CrashReporter.record(e, st, reason: 'sync.pushMeasurement');
    }
  }

  /// Borra todo lo del usuario en Firestore: subcolecciones primero (borrar
  /// un documento no borra lo que cuelga de él) y el documento al final.
  static Future<void> deleteAll() async {
    final doc = _doc;
    if (doc == null) return;
    final checkins = doc.collection('coach').doc('checkins');
    for (final col in [
      doc.collection('sessions'),
      doc.collection('measurements'),
      checkins.collection('items'),
    ]) {
      await _deleteCollection(col);
    }
    final batch = FirebaseFirestore.instance.batch()
      ..delete(checkins)
      ..delete(doc.collection('coach').doc('notes'))
      ..delete(doc);
    await batch.commit();
  }

  static Future<void> _deleteCollection(
      CollectionReference<Map<String, dynamic>> col) async {
    // Un lote admite 500 operaciones: se borra por tandas.
    while (true) {
      final snap = await col.limit(400).get();
      if (snap.docs.isEmpty) return;
      final batch = FirebaseFirestore.instance.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
  }

  /// Sube el estado local completo. Si falla (sin conexión), no interrumpe
  /// la app: Firestore reintenta con su cola offline.
  static Future<void> push() async {
    final doc = _doc;
    if (doc == null) return;
    try {
      await doc.set({
        ...Storage.exportCloudData(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e, st) {
      CrashReporter.record(e, st, reason: 'sync.push');
    }
  }
}
