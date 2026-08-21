import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/services/camino_gateway.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cliente HTTP que anota cada ruta pedida y responde con el JSON que le
/// corresponda, para poder afirmar **qué tablas consulta** el gateway sin
/// salir a la red.
///
/// Es el único sitio de la suite que mira el tráfico de un gateway real: el
/// escenario "El total se calcula sin consultar las respuestas" de
/// `app-player-path-home` (INT-123) habla justamente de una consulta que ya no
/// debe existir, y una ausencia no se puede comprobar con un
/// `FakeCaminoGateway`.
class _ClienteQueAnota extends http.BaseClient {
  _ClienteQueAnota(this._cuerpoPorTabla);

  final Map<String, List<Map<String, dynamic>>> _cuerpoPorTabla;
  final rutas = <String>[];

  /// URL completa de cada peticion, con query string: hace falta para poder
  /// afirmar el `order=orden.asc` del que depende el acumulado.
  final urls = <Uri>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final ruta = request.url.path;
    rutas.add(ruta);
    urls.add(request.url);

    final tabla = ruta.split('/').last;
    final cuerpo = jsonEncode(_cuerpoPorTabla[tabla] ?? const []);

    return http.StreamedResponse(
      Stream.value(utf8.encode(cuerpo)),
      200,
      headers: const {'content-type': 'application/json; charset=utf-8'},
      request: request,
    );
  }
}

Map<String, dynamic> _fila({required int orden, required int mejorPuntaje}) => {
  'camino_id': 'nivel-$orden',
  'orden': orden,
  'nombre': 'Parada $orden',
  'tematica_id': 'monumentos',
  'tematica_nombre': 'Monumentos',
  'superado': mejorPuntaje > 0,
  'estrellas_obtenidas': 0,
  'estrellas_requeridas': 0,
  'estrellas_acumuladas_usuario': 0,
  'desbloqueado': true,
  'es_actual': false,
  'mejor_puntaje': mejorPuntaje,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SupabaseCaminoGateway.fetchCamino', () {
    late _ClienteQueAnota cliente;
    late SupabaseCaminoGateway gateway;

    setUp(() {
      cliente = _ClienteQueAnota({
        'camino_jugador': [
          _fila(orden: 1, mejorPuntaje: 300),
          _fila(orden: 2, mejorPuntaje: 500),
        ],
        'tematicas': [
          {'id': 'monumentos', 'imagen_portada': 'https://cdn/monumentos.png'},
        ],
      });
      gateway = SupabaseCaminoGateway(
        SupabaseClient(
          'https://example.invalid',
          'clave-de-prueba',
          httpClient: cliente,
        ),
      );
    });

    test('no consulta respuestas_desafio (INT-123)', () async {
      await gateway.fetchCamino();

      expect(
        cliente.rutas.where((r) => r.contains('respuestas_desafio')),
        isEmpty,
        reason:
            'el total sale de camino_jugador.mejor_puntaje; volver a pedir '
            'respuestas_desafio traería la tabla entera del jugador',
      );
    });

    test('lee camino_jugador y tematicas, y nada más', () async {
      await gateway.fetchCamino();

      final tablas = cliente.rutas.map((r) => r.split('/').last).toSet();
      expect(tablas, {'camino_jugador', 'tematicas'});
    });

    test('el total sale de los mejores puntajes de la vista', () async {
      final camino = await gateway.fetchCamino();

      expect(camino.puntosTotales, 800);
      expect(camino.entradas.last.puntosAcumulados, 800);
    });

    test('pide el camino ordenado por orden ascendente', () async {
      // No es cosmetico: `construirCaminoJugador` acumula recorriendo la lista
      // tal como llega, asi que si el orden se perdiera los indicadores del
      // riel saldrian mal sin que ningun test puro lo notara. Y el cliente
      // Dart de postgrest usa `ascending: false` por defecto, al reves que
      // SQL, asi que quitar el parametro rompe esto en silencio.
      await gateway.fetchCamino();

      final consulta = cliente.urls.firstWhere(
        (u) => u.path.endsWith('camino_jugador'),
      );
      // `startsWith` y no igualdad: postgrest añade su propio sufijo de
      // tratamiento de nulos (`.nullslast`), que es detalle suyo. Lo que este
      // test fija es el `asc`.
      expect(consulta.queryParameters['order'], startsWith('orden.asc'));
    });

    test('sin ninguna parada no consulta tematicas', () async {
      cliente = _ClienteQueAnota({'camino_jugador': const []});
      gateway = SupabaseCaminoGateway(
        SupabaseClient(
          'https://example.invalid',
          'clave-de-prueba',
          httpClient: cliente,
        ),
      );

      final camino = await gateway.fetchCamino();

      expect(camino.entradas, isEmpty);
      expect(camino.puntosTotales, 0);
      expect(cliente.rutas.where((r) => r.endsWith('tematicas')), isEmpty);
    });
  });
}
