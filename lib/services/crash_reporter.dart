import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';

/// Reporte de fallos con Firebase Crashlytics.
///
/// Sin Firebase configurado todo es no-op, y en debug no se envía nada para
/// no mezclar los errores de desarrollo con los de usuarios reales.
class CrashReporter {
  CrashReporter._();

  static bool _enabled = false;

  /// Se llama después de [AuthService.init], que es quien inicializa Firebase.
  static Future<void> init() async {
    if (!AuthService.isAvailable) return;
    try {
      final c = FirebaseCrashlytics.instance;
      await c.setCrashlyticsCollectionEnabled(!kDebugMode);
      _enabled = !kDebugMode;
      FlutterError.onError = c.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        c.recordError(error, stack, fatal: true);
        return true;
      };
    } catch (_) {
      _enabled = false;
    }
  }

  /// Error recuperable: la app sigue, pero queremos saber que pasó.
  static void record(Object error, StackTrace? stack, {String? reason}) {
    if (kDebugMode) debugPrint('[$reason] $error');
    if (!_enabled) return;
    FirebaseCrashlytics.instance.recordError(error, stack, reason: reason);
  }
}
