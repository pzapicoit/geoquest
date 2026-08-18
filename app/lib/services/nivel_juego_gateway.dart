import 'package:supabase_flutter/supabase_flutter.dart';

/// Tipo de contenido de un desafío, tal como lo define el enum
/// `tipo_desafio` en Postgres. Cada valor trae exactamente uno de
/// `imagenUrl`/`videoUrl`/`textoPregunta` no nulo — el resto llegan
/// `null` (constraint de exclusividad de `game-data-model`).
enum TipoDesafio {
  imagen,
  video,
  preguntaTexto;

  static TipoDesafio fromString(String value) {
    return switch (value) {
      'imagen' => TipoDesafio.imagen,
      'video' => TipoDesafio.video,
      'pregunta_texto' => TipoDesafio.preguntaTexto,
      _ => throw ArgumentError('Tipo de desafío desconocido: $value'),
    };
  }
}

/// Un desafío de juego tal como lo expone `desafios_para_jugar`: sin
/// `lat_real`, `lng_real` ni `nombre_lugar` (INT-95).
class DesafioJuego {
  const DesafioJuego({
    required this.id,
    required this.tipo,
    required this.activo,
    this.imagenUrl,
    this.videoUrl,
    this.textoPregunta,
  });

  final String id;
  final TipoDesafio tipo;
  final bool activo;
  final String? imagenUrl;
  final String? videoUrl;
  final String? textoPregunta;
}

/// Resultado de arrancar una partida: el intento creado y los desafíos que
/// le tocaron (INT-95: `iniciar_intento_nivel`).
///
/// Desde INT-99 trae también `segundosPorDesafio`, el límite de tiempo del
/// nivel que la pantalla usa para inicializar la cuenta atrás de cada
/// desafío. Con un valor por defecto de 60 —el mismo que trae la columna
/// `niveles.segundos_por_desafio` en Postgres— para no romper los
/// constructores `const` ya existentes en otros tests que no ejercitan el
/// temporizador.
class IntentoNivel {
  const IntentoNivel({
    required this.intentoId,
    required this.desafios,
    this.segundosPorDesafio = 60,
  });

  final String intentoId;
  final List<DesafioJuego> desafios;
  final int segundosPorDesafio;
}

/// Resultado de responder un desafío, tal como lo devuelve la RPC
/// `responder_desafio` (INT-78): la distancia y los puntos los calcula
/// Postgres, la app solo los muestra.
///
/// Desde INT-93 trae también el revelado del desafío respondido —su
/// ubicación real, el nombre del lugar y el puntaje máximo alcanzable—. Ese
/// dato solo viaja en la respuesta a la propia jugada (D2 de `design.md`):
/// RLS lo sigue escondiendo en `desafios`, `desafios_para_jugar` y
/// `iniciar_intento_nivel`.
///
/// Desde INT-99, `responder_desafio` acepta una respuesta sin pin (tiempo
/// agotado sin coordenadas): en ese caso el servidor no tiene distancia que
/// calcular, así que [distanciaKm] llega `null` (D7/D13 de `design.md`). La
/// ubicación real ([latitudReal]/[longitudReal]/[nombreLugar]) se sigue
/// revelando igual, con o sin pin. También trae el desglose del puntaje
/// (D14): [puntosDistancia] es el componente de precisión y [puntosBonus]
/// el bonus por rapidez (`puntos = puntosDistancia + puntosBonus`); ambos
/// llegan en `0` cuando la respuesta es sin pin.
class RespuestaDesafio {
  const RespuestaDesafio({
    required this.distanciaKm,
    required this.puntos,
    required this.latitudReal,
    required this.longitudReal,
    required this.nombreLugar,
    required this.puntosMaximos,
    required this.puntosDistancia,
    required this.puntosBonus,
  });

  /// `null` cuando el tiempo se agotó sin pin colocado: no hay coordenada
  /// adivinada de la que calcular una distancia.
  final double? distanciaKm;
  final int puntos;
  final double latitudReal;
  final double longitudReal;
  final String nombreLugar;

  /// Puntos que se habrían conseguido con un acierto exacto e instantáneo,
  /// calculados por el servidor (D3 de `design.md` de INT-93, ampliado con
  /// el bonus por rapidez en D14 de INT-99): la curva de puntaje vive en
  /// Postgres.
  final int puntosMaximos;

  /// Componente de precisión del puntaje (la curva de distancia, sin el
  /// bonus). `0` en una respuesta sin pin.
  final int puntosDistancia;

  /// Bonus por rapidez (`puntos - puntosDistancia`). `0` en una respuesta
  /// sin pin, o cuando el tiempo se agotó, o cuando la precisión ya estaba
  /// en el suelo de la curva.
  final int puntosBonus;
}

/// Resultado de cerrar un intento, tal como lo devuelve la RPC
/// `cerrar_intento_nivel` (INT-79, ampliada en INT-94): además del
/// resultado del propio intento, trae lo que el resumen del nivel necesita
/// y que no viaja a ningún otro sitio — el mínimo del nivel y el mejor
/// puntaje que tenía el jugador en ese nivel *antes* de este cierre (D1/D2
/// de `design.md` de INT-94).
class ResultadoIntento {
  const ResultadoIntento({
    required this.puntajeTotal,
    required this.superado,
    required this.estrellas,
    required this.puntajeMinimoSuperar,
    this.mejorPuntajeAnterior,
  });

  final int puntajeTotal;
  final bool superado;
  final int estrellas;
  final int puntajeMinimoSuperar;

  /// `null` cuando el jugador no tenía ningún resultado anterior para este
  /// nivel — no hay un resultado que "mejorar" (D2 de `design.md`).
  final int? mejorPuntajeAnterior;
}

/// Superficie mínima de Supabase para jugar un nivel, para poder probar la
/// pantalla de juego con un falso sin salir a la red.
abstract class NivelJuegoGateway {
  Future<IntentoNivel> iniciarIntento(String nivelId);

  /// `latitud`/`longitud` llegan `null` cuando el tiempo se agota sin pin
  /// colocado (INT-99): la RPC registra una respuesta de 0 puntos sin
  /// coordenadas. Las dos deben ser `null` a la vez, nunca solo una —la RPC
  /// rechaza esa mezcla— así que quien llame nunca debe construir esta
  /// llamada con una sola de ellas en `null`.
  Future<RespuestaDesafio> responderDesafio({
    required String intentoId,
    required String desafioId,
    required double? latitud,
    required double? longitud,
  });

  /// Marca en el servidor el instante en que `desafioId` se vuelve el
  /// desafío actual del intento, para medir el tiempo transcurrido sin
  /// fiarse del reloj del cliente (D1/D2 de `design.md`). Idempotente:
  /// llamarla dos veces para el mismo desafío no reinicia el cronómetro.
  Future<void> marcarDesafioMostrado({
    required String intentoId,
    required String desafioId,
  });

  Future<ResultadoIntento> cerrarIntento(String intentoId);
}

class SupabaseNivelJuegoGateway implements NivelJuegoGateway {
  SupabaseNivelJuegoGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<IntentoNivel> iniciarIntento(String nivelId) async {
    final respuesta = await _client.rpc(
      'iniciar_intento_nivel',
      params: {'p_nivel_id': nivelId},
    );

    return mapearIntentoNivel(respuesta as Map<String, dynamic>);
  }

  @override
  Future<RespuestaDesafio> responderDesafio({
    required String intentoId,
    required String desafioId,
    required double? latitud,
    required double? longitud,
  }) async {
    final respuesta = await _client.rpc(
      'responder_desafio',
      params: {
        'p_intento_id': intentoId,
        'p_desafio_id': desafioId,
        'p_lat_adivinada': latitud,
        'p_lng_adivinada': longitud,
      },
    );

    return mapearRespuestaDesafio(respuesta as Map<String, dynamic>);
  }

  @override
  Future<void> marcarDesafioMostrado({
    required String intentoId,
    required String desafioId,
  }) async {
    await _client.rpc(
      'marcar_desafio_mostrado',
      params: {'p_intento_id': intentoId, 'p_desafio_id': desafioId},
    );
  }

  @override
  Future<ResultadoIntento> cerrarIntento(String intentoId) async {
    final respuesta = await _client.rpc(
      'cerrar_intento_nivel',
      params: {'p_intento_id': intentoId},
    );

    return mapearResultadoIntento(respuesta as Map<String, dynamic>);
  }
}

/// Mapea el jsonb `{"intento_id", "desafios", "segundos_por_desafio"}` que
/// devuelve `iniciar_intento_nivel` a [IntentoNivel]. Función pura, extraída
/// para poder probar el mapeo sin red (INT-91, mismo patrón que
/// `intercalarFronteras` en `camino_gateway.dart`).
///
/// `segundos_por_desafio` viaja desde INT-99 (D11 de `design.md`): sin él la
/// pantalla no sabría cuánto dura la cuenta atrás, así que se exige igual
/// que el resto de campos de esta respuesta.
IntentoNivel mapearIntentoNivel(Map<String, dynamic> data) {
  final desafiosRaw = data['desafios'] as List;

  return IntentoNivel(
    intentoId: data['intento_id'] as String,
    desafios: [
      for (final fila in desafiosRaw)
        _mapearDesafio(fila as Map<String, dynamic>),
    ],
    segundosPorDesafio: _entero(
      data['segundos_por_desafio'],
      'segundos_por_desafio',
    ),
  );
}

/// Mapea el `jsonb` que devuelve `responder_desafio`: la fila registrada en
/// `respuestas_desafio` más el revelado del desafío (INT-93). Función pura,
/// extraída por el mismo motivo que [mapearIntentoNivel]: poder probar el
/// mapeo sin red.
///
/// `distancia_km` es el único campo que se relaja a opcional (INT-99): en
/// una respuesta sin pin (tiempo agotado sin coordenadas) el servidor no
/// tiene ninguna distancia que calcular y manda `null` a propósito, no por
/// omisión. El resto de campos —incluidos `lat_real`/`lng_real`, que siguen
/// revelando la ubicación real haya o no pin— se mantienen exigidos: si
/// faltan, es una respuesta incompleta, no un caso sin pin.
RespuestaDesafio mapearRespuestaDesafio(Map<String, dynamic> fila) {
  return RespuestaDesafio(
    distanciaKm: _decimalOpcional(fila['distancia_km']),
    puntos: _entero(fila['puntos'], 'puntos'),
    latitudReal: _decimal(fila['lat_real'], 'lat_real'),
    longitudReal: _decimal(fila['lng_real'], 'lng_real'),
    nombreLugar: _texto(fila['nombre_lugar'], 'nombre_lugar'),
    puntosMaximos: _entero(fila['puntos_maximos'], 'puntos_maximos'),
    puntosDistancia: _entero(fila['puntos_distancia'], 'puntos_distancia'),
    puntosBonus: _entero(fila['puntos_bonus'], 'puntos_bonus'),
  );
}

/// Mapea el `jsonb` que devuelve `cerrar_intento_nivel` (INT-94). Función
/// pura, extraída por el mismo motivo que [mapearIntentoNivel]: poder
/// probar el mapeo sin red.
ResultadoIntento mapearResultadoIntento(Map<String, dynamic> fila) {
  return ResultadoIntento(
    puntajeTotal: _entero(fila['puntaje_total'], 'puntaje_total'),
    superado: _booleano(fila['superado'], 'superado'),
    estrellas: _entero(fila['estrellas_obtenidas'], 'estrellas_obtenidas'),
    puntajeMinimoSuperar: _entero(
      fila['puntaje_minimo_superar'],
      'puntaje_minimo_superar',
    ),
    mejorPuntajeAnterior: fila['mejor_puntaje_anterior'] == null
        ? null
        : _entero(fila['mejor_puntaje_anterior'], 'mejor_puntaje_anterior'),
  );
}

/// `distancia_km` es `numeric` en Postgres: llega como número, pero PostgREST
/// lo serializa como texto cuando el valor no cabe en un double sin perder
/// precisión, así que se acepta cualquiera de las dos formas.
double _decimal(Object? valor, String campo) => switch (valor) {
  final num numero => numero.toDouble(),
  final String texto => double.parse(texto),
  _ => throw ArgumentError('$campo ausente en la respuesta'),
};

/// Igual que [_decimal], pero sin lanzar cuando el campo llega `null` a
/// propósito —el caso de `distancia_km` en una respuesta sin pin (INT-99)—
/// en vez de estar simplemente ausente.
double? _decimalOpcional(Object? valor) => switch (valor) {
  null => null,
  final num numero => numero.toDouble(),
  final String texto => double.parse(texto),
  _ => throw ArgumentError('distancia_km con un tipo inesperado: $valor'),
};

int _entero(Object? valor, String campo) => switch (valor) {
  final num numero => numero.toInt(),
  final String texto => int.parse(texto),
  _ => throw ArgumentError('$campo ausente en la respuesta'),
};

String _texto(Object? valor, String campo) => switch (valor) {
  final String texto => texto,
  _ => throw ArgumentError('$campo ausente en la respuesta'),
};

bool _booleano(Object? valor, String campo) => switch (valor) {
  final bool booleano => booleano,
  _ => throw ArgumentError('$campo ausente en la respuesta'),
};

DesafioJuego _mapearDesafio(Map<String, dynamic> fila) {
  return DesafioJuego(
    id: fila['id'] as String,
    tipo: TipoDesafio.fromString(fila['tipo'] as String),
    activo: fila['activo'] as bool,
    imagenUrl: fila['imagen_url'] as String?,
    videoUrl: fila['video_url'] as String?,
    textoPregunta: fila['texto_pregunta'] as String?,
  );
}
