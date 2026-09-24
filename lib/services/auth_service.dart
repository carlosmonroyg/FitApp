import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../firebase_options.dart';
import 'cloud_sync.dart';

class AuthService {
  AuthService._();

  static bool _ready = false;

  static bool get isAvailable => _ready;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await GoogleSignIn.instance.initialize();
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  static User? get user => _ready ? FirebaseAuth.instance.currentUser : null;

  static Future<User> signInWithGoogle() async {
    final account = await GoogleSignIn.instance.authenticate();
    final credential = GoogleAuthProvider.credential(
      idToken: account.authentication.idToken,
    );
    final result = await FirebaseAuth.instance.signInWithCredential(credential);
    return result.user!;
  }

  /// Elimina la cuenta y todos sus datos en la nube (requisito de Google
  /// Play). Firebase exige un inicio de sesión reciente para borrar la
  /// cuenta, así que se vuelve a pedir Google antes de tocar nada: si el
  /// usuario cancela, no se ha borrado ningún dato.
  static Future<void> deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final account = await GoogleSignIn.instance.authenticate();
    await user.reauthenticateWithCredential(GoogleAuthProvider.credential(
        idToken: account.authentication.idToken));
    await CloudSync.deleteAll();
    await user.delete();
    try {
      // Revoca también el acceso concedido a la app en la cuenta de Google.
      await GoogleSignIn.instance.disconnect();
    } catch (_) {}
  }

  static Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    await FirebaseAuth.instance.signOut();
  }
}
