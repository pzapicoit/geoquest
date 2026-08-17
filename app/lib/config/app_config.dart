/// Configuración de la app, inyectada en tiempo de compilación.
///
/// Los valores llegan por `--dart-define-from-file=dart_define.json`. Ese
/// fichero está gitignorado; la plantilla versionada es
/// `dart_define.example.json`.
///
/// No se usa un `.env` como asset: eso lo empaquetaría legible dentro del
/// `.apk`/`.ipa`. Para la clave publicable no sería grave —está pensada para ser
/// pública— pero fija un patrón que sí sería grave con cualquier otro valor.
library;

import 'package:flutter/foundation.dart';

/// Falta una variable de compilación obligatoria.
class MissingConfigError extends Error {
  MissingConfigError(this.variable);

  final String variable;

  @override
  String toString() =>
      'Falta la variable de compilación $variable.\n'
      'Copia dart_define.example.json a dart_define.json, rellénalo y ejecuta:\n'
      '  flutter run --dart-define-from-file=dart_define.json';
}

class AppConfig {
  const AppConfig._({
    required this.supabaseUrl,
    required this.supabasePublishableKey,
  });

  final String supabaseUrl;
  final String supabasePublishableKey;

  static const _url = String.fromEnvironment('SUPABASE_URL');
  static const _publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  /// Lee y valida la configuración.
  ///
  /// Lanza [MissingConfigError] nombrando la primera variable ausente, en lugar
  /// de dejar la app en un estado a medias que reventaría más tarde en una
  /// pantalla cualquiera.
  factory AppConfig.fromEnvironment() {
    if (_url.isEmpty) {
      throw MissingConfigError('SUPABASE_URL');
    }
    if (_publishableKey.isEmpty) {
      throw MissingConfigError('SUPABASE_PUBLISHABLE_KEY');
    }
    return AppConfig._(
      supabaseUrl: _url,
      supabasePublishableKey: _publishableKey,
    );
  }

  /// Construye una config sin pasar por las variables de compilación, que en el
  /// entorno de test no están definidas.
  @visibleForTesting
  const AppConfig.forTesting({
    required this.supabaseUrl,
    required this.supabasePublishableKey,
  });
}
