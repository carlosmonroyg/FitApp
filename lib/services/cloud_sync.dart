import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';
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
    return true;
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
    } catch (_) {}
  }
}
