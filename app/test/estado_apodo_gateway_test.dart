import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/services/estado_apodo_gateway.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fakes/fake_estado_apodo_gateway.dart';

/// Responde a la RPC con el valor dado y anota qué se le pidió, para fijar el
/// nombre de la función y el de su parámetro: si la migración y el cliente se
/// separan ahí, el fallo no aparece hasta que alguien intenta entrar.
class _ClienteQueAnota extends http.BaseClient {
  _ClienteQueAnota(this._respuesta);

  final String _respuesta;
  final rutas = <String>[];
  final cuerpos = <String>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    rutas.add(request.url.path);
    cuerpos.add(await (request as http.Request).finalize().bytesToString());

    return http.StreamedResponse(
      Stream.value(utf8.encode(_respuesta)),
      200,
      headers: const {'content-type': 'application/json; charset=utf-8'},
      request: request,
    );
  }
}

SupabaseEstadoApodoGateway _gateway(_ClienteQueAnota cliente) =>
    SupabaseEstadoApodoGateway(
      SupabaseClient(
        'https://example.invalid',
        'clave-de-prueba',
        httpClient: cliente,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SupabaseEstadoApodoGateway', () {
    test('llama a la RPC estado_apodo con el apodo en p_alias', () async {
      final cliente = _ClienteQueAnota('"libre"');

      await _gateway(cliente).consultar('Pablo');

      expect(cliente.rutas.single, endsWith('/rpc/estado_apodo'));
      expect(jsonDecode(cliente.cuerpos.single), {'p_alias': 'Pablo'});
    });

    test('traduce los tres estados que devuelve la migración', () async {
      for (final (crudo, esperado) in [
        ('"libre"', EstadoApodo.libre),
        ('"con_contrasena"', EstadoApodo.conContrasena),
        ('"sin_contrasena"', EstadoApodo.sinContrasena),
      ]) {
        final gateway = _gateway(_ClienteQueAnota(crudo));
        expect(await gateway.consultar('Pablo'), esperado);
      }
    });

    test('un valor desconocido falla en vez de pasar por "libre"', () async {
      // Interpretarlo como libre llevaría a intentar dar de alta un apodo que
      // puede ser de alguien; ante la duda, se falla y se puede reintentar.
      final gateway = _gateway(_ClienteQueAnota('"otra_cosa"'));

      expect(() => gateway.consultar('Pablo'), throwsStateError);
    });
  });

  group('FakeEstadoApodoGateway', () {
    test('devuelve el estado configurado y anota el apodo', () async {
      final gateway = FakeEstadoApodoGateway(estado: EstadoApodo.conContrasena);

      expect(await gateway.consultar('Pablo'), EstadoApodo.conContrasena);
      expect(gateway.lastApodo, 'Pablo');
    });
  });

  test('los tres estados de la RPC tienen representación', () {
    // Si la RPC gana un estado, este test obliga a decidir qué hace la app con
    // él en vez de que caiga en el camino genérico de error.
    expect(EstadoApodo.values, hasLength(3));
  });
}
