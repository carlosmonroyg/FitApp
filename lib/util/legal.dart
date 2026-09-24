import 'package:url_launcher/url_launcher.dart';

/// Enlaces y textos legales. La política se publica desde `docs/` del repo.
abstract final class Legal {
  // TODO(carlos): confirmar la URL tras publicar docs/privacy.html y el
  // correo de soporte que aparecerá en Play Store.
  static const privacyUrl =
      'https://carlosmonroyg.github.io/FitApp/privacy.html';

  /// Vacío = la opción de contacto no se muestra.
  static const supportEmail = '';

  /// Se sube si cambian los términos, para volver a pedir la aceptación.
  static const termsVersion = 1;

  static const healthDisclaimer =
      'FitApp ofrece rutinas y sugerencias de entrenamiento con fines '
      'informativos. No es un servicio médico ni sustituye la valoración de '
      'un profesional de la salud. Si tienes lesiones, dolor, estás '
      'embarazada o tienes alguna condición médica, consulta a un profesional '
      'antes de empezar. Detén el ejercicio si sientes dolor, mareo o falta '
      'de aire.';

  static Future<bool> openPrivacy() =>
      launchUrl(Uri.parse(privacyUrl), mode: LaunchMode.externalApplication);

  static Future<bool> emailSupport({String subject = 'FitApp'}) =>
      launchUrl(Uri(
          scheme: 'mailto',
          path: supportEmail,
          queryParameters: {'subject': subject}));
}
