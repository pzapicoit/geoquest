import 'package:supabase_flutter/supabase_flutter.dart';

/// Una fila de cualquiera de las tres clasificaciones (`clasificacion_global`,
/// `clasificacion_por_camino`, `clasificacion_por_tematica`) de INT-109.
///
/// [nivelesSuperados] solo llega en Global y Temática; [superado] solo llega
/// en Nivel (ver `player-ranking` spec) — ambos son opcionales porque cada
/// clasificación rellena uno u otro, nunca los dos a la vez.
///
/// [posicion] llega `null` cuando el jugador que llama no tiene ninguna
/// puntuación agregable todavía en esa clasificación (D5 de `player-ranking`),
/// no cuando falta un dato.
class EntradaRanking {
  const EntradaRanking({
    required this.usuarioId,
    required this.nombre,
    this.avatarUrl,
    required this.puntuacion,
    this.nivelesSuperados,
    this.superado,
    required this.posicion,
    required this.esUsuarioActual,
  });

  final String usuarioId;
  final String nombre;
  final String? avatarUrl;
  final int puntuacion;
  final int? nivelesSuperados;
  final bool? superado;
  final int? posicion;
  final bool esUsuarioActual;
}

/// Superficie mínima de Supabase para leer las tres clasificaciones entre
/// jugadores (INT-109), para poder probar la pantalla de Ranking con un
/// falso sin salir a la red.
abstract class RankingGateway {
  Future<List<EntradaRanking>> fetchClasificacionGlobal({int limite = 50});

  Future<List<EntradaRanking>> fetchClasificacionPorCamino(
    String caminoId, {
    int limite = 50,
  });

  Future<List<EntradaRanking>> fetchClasificacionPorTematica(
    String tematicaId, {
    int limite = 50,
  });
}

class SupabaseRankingGateway implements RankingGateway {
  SupabaseRankingGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<List<EntradaRanking>> fetchClasificacionGlobal({
    int limite = 50,
  }) async {
    final filas = await _client.rpc(
      'clasificacion_global',
      params: {'p_limite': limite},
    );
    return _mapearFilas(filas);
  }

  @override
  Future<List<EntradaRanking>> fetchClasificacionPorCamino(
    String caminoId, {
    int limite = 50,
  }) async {
    final filas = await _client.rpc(
      'clasificacion_por_camino',
      params: {'p_camino_id': caminoId, 'p_limite': limite},
    );
    return _mapearFilas(filas);
  }

  @override
  Future<List<EntradaRanking>> fetchClasificacionPorTematica(
    String tematicaId, {
    int limite = 50,
  }) async {
    final filas = await _client.rpc(
      'clasificacion_por_tematica',
      params: {'p_tematica_id': tematicaId, 'p_limite': limite},
    );
    return _mapearFilas(filas);
  }

  List<EntradaRanking> _mapearFilas(Object? filas) => [
    for (final fila in filas as List)
      mapearEntradaRanking(fila as Map<String, dynamic>),
  ];
}

/// Mapea una fila jsonb de cualquiera de las tres funciones de clasificación
/// a [EntradaRanking]. Función pura, extraída para poder probar el mapeo sin
/// red (mismo patrón que `mapearIntentoNivel` en `nivel_juego_gateway.dart`).
EntradaRanking mapearEntradaRanking(Map<String, dynamic> fila) {
  return EntradaRanking(
    usuarioId: fila['usuario_id'] as String,
    nombre: fila['nombre'] as String,
    avatarUrl: fila['avatar_url'] as String?,
    puntuacion: _entero(fila['puntuacion'], 'puntuacion'),
    nivelesSuperados: fila['niveles_superados'] == null
        ? null
        : _entero(fila['niveles_superados'], 'niveles_superados'),
    superado: fila['superado'] as bool?,
    posicion: fila['posicion'] == null
        ? null
        : _entero(fila['posicion'], 'posicion'),
    esUsuarioActual: fila['es_usuario_actual'] as bool,
  );
}

/// `puntuacion` y `posicion` son `bigint`/`integer` en Postgres: llegan como
/// número, pero PostgREST los serializa como texto cuando el valor no cabe en
/// un double sin perder precisión (mismo motivo que `_entero` en
/// `nivel_juego_gateway.dart`), así que se acepta cualquiera de las dos formas.
int _entero(Object? valor, String campo) => switch (valor) {
  final num numero => numero.toInt(),
  final String texto => int.parse(texto),
  _ => throw ArgumentError('$campo ausente en la respuesta'),
};
