import 'package:supabase_flutter/supabase_flutter.dart';

/// Una posición de `camino_jugador`, con la portada de su temática ya
/// resuelta a URL pública.
///
/// Desde INT-106, una parada ya no referencia un `nivel_id` curado a mano:
/// `caminoId` (la propia fila de `camino`) es su único identificador, y
/// `nivelNombre` pasa a leerse de `camino.nombre` directamente en vez de vía
/// un join a `niveles`.
class ParadaCamino {
  const ParadaCamino({
    required this.caminoId,
    required this.orden,
    this.nivelNombre,
    required this.tematicaId,
    required this.tematicaNombre,
    required this.superado,
    required this.estrellasObtenidas,
    required this.estrellasRequeridas,
    required this.estrellasAcumuladasUsuario,
    required this.desbloqueado,
    required this.esActual,
    this.imagenPortadaUrl,
  });

  final String caminoId;
  final int orden;
  final String? nivelNombre;
  final String tematicaId;
  final String tematicaNombre;
  final bool superado;
  final int estrellasObtenidas;
  final int estrellasRequeridas;
  final int estrellasAcumuladasUsuario;
  final bool desbloqueado;
  final bool esActual;
  final String? imagenPortadaUrl;
}

/// El camino completo del jugador, listo para pintar: paradas en orden
/// ascendente de `orden`, más los puntos totales acumulados.
class CaminoJugador {
  const CaminoJugador({required this.entradas, required this.puntosTotales});

  final List<ParadaCamino> entradas;
  final int puntosTotales;
}

/// Superficie mínima de Supabase para leer la Home del jugador, para poder
/// probarla con un falso sin salir a la red (INT-90).
abstract class CaminoGateway {
  Future<CaminoJugador> fetchCamino();
}

class SupabaseCaminoGateway implements CaminoGateway {
  SupabaseCaminoGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<CaminoJugador> fetchCamino() async {
    // `ascending` por defecto es `false` en el cliente Dart de postgrest (al
    // revés que en SQL y en postgrest-js) -- sin pasarlo explícito, el
    // camino llega en orden inverso.
    final caminoRows = await _client
        .from('camino_jugador')
        .select()
        .order('orden', ascending: true);

    final tematicaIds = <String>{
      for (final row in caminoRows) row['tematica_id'] as String,
    }.toList();

    final portadasFuture = tematicaIds.isEmpty
        ? Future.value(<Map<String, dynamic>>[])
        : _client
              .from('tematicas')
              .select('id, imagen_portada')
              .inFilter('id', tematicaIds);
    final puntosFuture = _client.from('respuestas_desafio').select('puntos');

    final resultados = await Future.wait([portadasFuture, puntosFuture]);
    final portadaRows = resultados[0];
    final puntosRows = resultados[1];

    // `tematicas.imagen_portada` ya guarda la URL pública completa (el
    // panel la resuelve una vez con `getPublicUrl` al subir la portada y
    // persiste esa URL, no la ruta dentro del bucket) — usarla tal cual,
    // sin volver a resolverla.
    final portadaPorTematica = <String, String>{
      for (final row in portadaRows)
        if (row['imagen_portada'] != null)
          row['id'] as String: row['imagen_portada'] as String,
    };

    final paradas = [
      for (final row in caminoRows) _mapearParada(row, portadaPorTematica),
    ];

    return CaminoJugador(
      entradas: paradas,
      puntosTotales: sumarPuntos(puntosRows),
    );
  }

  ParadaCamino _mapearParada(
    Map<String, dynamic> row,
    Map<String, String> portadaPorTematica,
  ) {
    return ParadaCamino(
      caminoId: row['camino_id'] as String,
      orden: row['orden'] as int,
      nivelNombre: row['nombre'] as String?,
      tematicaId: row['tematica_id'] as String,
      tematicaNombre: row['tematica_nombre'] as String,
      superado: row['superado'] as bool,
      estrellasObtenidas: row['estrellas_obtenidas'] as int,
      estrellasRequeridas: row['estrellas_requeridas'] as int,
      estrellasAcumuladasUsuario: row['estrellas_acumuladas_usuario'] as int,
      desbloqueado: row['desbloqueado'] as bool,
      esActual: row['es_actual'] as bool,
      imagenPortadaUrl: portadaPorTematica[row['tematica_id'] as String],
    );
  }
}

/// Suma el campo `puntos` de las filas de `respuestas_desafio`. Función pura
/// para poder probarla sin red (INT-90).
int sumarPuntos(List<Map<String, dynamic>> respuestas) {
  return respuestas.fold(
    0,
    (total, row) => total + (row['puntos'] as num).toInt(),
  );
}
