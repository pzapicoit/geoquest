import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/services/profile_gateway.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Responde a la consulta del perfil propio y anota la URL pedida, para fijar
/// que se lee `nombre` filtrando por el id de la sesión y nada más.
class _ClienteQueAnota extends http.BaseClient {
  _ClienteQueAnota(this._respuesta);

  final String _respuesta;
  final urls = <Uri>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    urls.add(request.url);

    return http.StreamedResponse(
      Stream.value(utf8.encode(_respuesta)),
      200,
      headers: const {'content-type': 'application/json; charset=utf-8'},
      request: request,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SupabaseProfileGateway.currentNickname', () {
    test('sin sesión no consulta nada y devuelve null', () async {
      final cliente = _ClienteQueAnota('[]');
      final gateway = SupabaseProfileGateway(
        SupabaseClient(
          'https://example.invalid',
          'clave-de-prueba',
          httpClient: cliente,
        ),
      );

      expect(await gateway.currentNickname(), isNull);
      expect(cliente.urls, isEmpty);
    });
  });

  group('esViolacionDeAliasUnico', () {
    test('true cuando el codigo es 23505 (unique_violation)', () {
      const error = PostgrestException(
        message: 'duplicate key value violates unique constraint',
        code: '23505',
      );

      expect(esViolacionDeAliasUnico(error), isTrue);
    });

    test('false para otros codigos de Postgrest', () {
      const error = PostgrestException(
        message: 'permission denied',
        code: '42501',
      );

      expect(esViolacionDeAliasUnico(error), isFalse);
    });

    test('false cuando no hay codigo', () {
      const error = PostgrestException(message: 'fallo de red');

      expect(esViolacionDeAliasUnico(error), isFalse);
    });
  });
}
