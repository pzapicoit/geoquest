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
    required this.mejorPuntaje,
    required this.puntosAcumulados,
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

  /// Puntaje del **mejor intento** del jugador sobre esta parada, tal cual lo
  /// da `camino_jugador.mejor_puntaje` (0 si nunca la jugó). Repetir la parada
  /// solo puede subirlo, nunca acumular: el `greatest(...)` de
  /// `cerrar_intento_parada` lo garantiza en el servidor (INT-123).
  final int mejorPuntaje;

  /// Puntos acumulados **hasta esta parada incluida**: la suma de
  /// [mejorPuntaje] de todas las paradas de `orden` menor o igual al de esta.
  ///
  /// Es el valor que pinta el indicador del riel, así que crece a lo largo del
  /// camino y el de la última parada coincide con
  /// [CaminoJugador.puntosTotales] (INT-123).
  final int puntosAcumulados;

  final String? imagenPortadaUrl;
}

/// El camino completo del jugador, listo para pintar: paradas en orden
/// ascendente de `orden`, más los puntos totales del jugador.
class CaminoJugador {
  const CaminoJugador({required this.entradas, required this.puntosTotales});

  final List<ParadaCamino> entradas;

  /// Suma del mejor intento de todas las paradas del camino — igual al
  /// [ParadaCamino.puntosAcumulados] de la última parada, por construcción
  /// (ver [construirCaminoJugador]).
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
    // camino llega en orden inverso. Y el orden aquí no es cosmético: el
    // acumulado por parada de `construirCaminoJugador` se calcula recorriendo
    // esta lista, así que depende de que llegue por `orden` ascendente.
    final caminoRows = await _client
        .from('camino_jugador')
        .select()
        .order('orden', ascending: true);

    final tematicaIds = <String>{
      for (final row in caminoRows) row['tematica_id'] as String,
    }.toList();

    // Hasta INT-123 aquí había una segunda consulta en paralelo que se traía
    // TODAS las filas de `respuestas_desafio` del jugador para sumar sus
    // `puntos` en cliente. Ya no hace falta: la puntuación sale de
    // `camino_jugador.mejor_puntaje`, que además es la cifra correcta (el
    // mejor intento por parada, no el histórico acumulado).
    final portadaRows = tematicaIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : await _client
              .from('tematicas')
              .select('id, imagen_portada')
              .inFilter('id', tematicaIds);

    // `tematicas.imagen_portada` ya guarda la URL pública completa (el
    // panel la resuelve una vez con `getPublicUrl` al subir la portada y
    // persiste esa URL, no la ruta dentro del bucket) — usarla tal cual,
    // sin volver a resolverla.
    final portadaPorTematica = <String, String>{
      for (final row in portadaRows)
        if (row['imagen_portada'] != null)
          row['id'] as String: row['imagen_portada'] as String,
    };

    return construirCaminoJugador(caminoRows, portadaPorTematica);
  }
}

/// Construye el camino del jugador a partir de las filas de `camino_jugador`
/// **ya ordenadas por `orden` ascendente**, resolviendo de una pasada el
/// acumulado de cada parada y el total del jugador.
///
/// D3 de `design.md` (INT-123): el acumulado de cada parada y el total salen
/// del mismo recorrido sobre la misma lista, así que el acumulado de la última
/// parada *es* el total y no pueden divergir. Esa es la razón de calcularlo
/// aquí y no con una `window function` en la vista: con el acumulado viniendo
/// del servidor y el total de otra suma aparte serían dos cálculos que hay que
/// mantener de acuerdo, y el criterio de aceptación es justamente que
/// coincidan.
///
/// Función pura (no toca la red) para poder probarla con filas de mentira,
/// igual que hacía `sumarPuntos` antes de INT-123.
CaminoJugador construirCaminoJugador(
  List<Map<String, dynamic>> caminoRows,
  Map<String, String> portadaPorTematica,
) {
  var acumulado = 0;
  final paradas = <ParadaCamino>[];

  for (final row in caminoRows) {
    // `camino_jugador` ya devuelve la columna con `coalesce(..., 0)`, así que
    // el `?? 0` cubre solo el caso de una fila que no la traiga en absoluto
    // (un cliente contra una base sin la migración de INT-123 aplicada).
    final mejorPuntaje = (row['mejor_puntaje'] as num?)?.toInt() ?? 0;
    acumulado += mejorPuntaje;
    paradas.add(
      _mapearParada(row, portadaPorTematica, mejorPuntaje, acumulado),
    );
  }

  return CaminoJugador(entradas: paradas, puntosTotales: acumulado);
}

ParadaCamino _mapearParada(
  Map<String, dynamic> row,
  Map<String, String> portadaPorTematica,
  int mejorPuntaje,
  int puntosAcumulados,
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
    mejorPuntaje: mejorPuntaje,
    puntosAcumulados: puntosAcumulados,
    imagenPortadaUrl: portadaPorTematica[row['tematica_id'] as String],
  );
}
