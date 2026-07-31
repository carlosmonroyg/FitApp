import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../firebase_options.dart';

/// Autenticación con Firebase + Google Sign-In.
///
/// Si Firebase aún no está configurado (falta `flutterfire configure`),
/// [isAvailable] queda en `false` y la app funciona en modo local sin login.
class AuthService {
  AuthService._();

  static bool _ready = false;

  static bool get isAvailable => _ready;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
      await GoogleSignIn.instance.initialize();
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  /// Usuario con sesión iniciada, o `null`.
  static User? get user => _ready ? FirebaseAuth.instance.currentUser : null;

  static Future<User> signInWithGoogle() async {
    final account = await GoogleSignIn.instance.authenticate();
    final credential = GoogleAuthProvider.credential(
        idToken: account.authentication.idToken);
    final result =
        await FirebaseAuth.instance.signInWithCredential(credential);
    return result.user!;
  }

  static Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    await FirebaseAuth.instance.signOut();
  }
}
