import 'package:supabase_flutter/supabase_flutter.dart';

/// Catálogo cerrado de tipos de comodín (INT-119, D1 de `design.md`):
/// siempre estos 4, en este orden — el mismo que usa la bandeja de la
/// pantalla de juego y la pantalla Comodines. `mis_comodines()` siempre
/// devuelve las 4 filas, nunca un tipo desconocido ni ausente.
enum ComodinTipo {
  tiempo,
  pais,
  km1000,
  km500;

  /// Texto tal como lo espera/devuelve Postgrest (`p_tipo`, el enum
  /// `tipo_comodin` de Postgres).
  String get aTexto => switch (this) {
    ComodinTipo.tiempo => 'tiempo',
    ComodinTipo.pais => 'pais',
    ComodinTipo.km1000 => 'km1000',
    ComodinTipo.km500 => 'km500',
  };

  static ComodinTipo fromString(String value) => switch (value) {
    'tiempo' => ComodinTipo.tiempo,
    'pais' => ComodinTipo.pais,
    'km1000' => ComodinTipo.km1000,
    'km500' => ComodinTipo.km500,
    _ => throw ArgumentError('Tipo de comodín desconocido: $value'),
  };
}

/// Inventario del jugador: una cantidad para cada uno de los 4 tipos, nunca
/// un tipo ausente (requirement "Catálogo cerrado de tipos de comodín" de
/// `comodines/spec.md`).
class InventarioComodines {
  const InventarioComodines({required this.cantidades});

  final Map<ComodinTipo, int> cantidades;

  int cantidadDe(ComodinTipo tipo) => cantidades[tipo] ?? 0;

  /// Suma de los 4 tipos, para el pill de la Home
  /// (`app-player-path-home/spec.md`) y el subtítulo de la pantalla
  /// Comodines.
  int get total => cantidades.values.fold(0, (total, n) => total + n);
}

/// Resultado de consumir un comodín con éxito, con el payload propio de cada
/// tipo (D3/D4/D7 de `design.md`). Clase sellada en vez de campos opcionales
/// sueltos: así quien consume la respuesta hace un `switch` exhaustivo, sin
/// tener que decidir a mano qué combinación de campos nulos corresponde a
/// qué tipo.
sealed class ResultadoUsoComodin {
  const ResultadoUsoComodin();
}

/// `tiempo`: cuántos segundos extender el margen antes del auto-envío
/// (`CuentaAtrasDeDesafio.extender`, D3 de `design.md`).
class ResultadoTiempo extends ResultadoUsoComodin {
  const ResultadoTiempo({required this.extraSegundos});

  final int extraSegundos;
}

/// `pais`: el nombre del país real del objetivo, sin `nombre_lugar` ni
/// coordenadas (D4 de `design.md`).
class ResultadoPais extends ResultadoUsoComodin {
  const ResultadoPais({required this.pais});

  final String pais;
}

/// `km1000`/`km500`: la coordenada real del objetivo y el radio a dibujar
/// sobre el mapa (D7 de `design.md`).
class ResultadoRadio extends ResultadoUsoComodin {
  const ResultadoRadio({
    required this.tipo,
    required this.lat,
    required this.lng,
    required this.radioKm,
  });

  final ComodinTipo tipo;
  final double lat;
  final double lng;
  final double radioKm;
}

/// Por qué `usar_comodin`/`conceder_comodin_por_anuncio` rechazó la
/// operación. Se traduce el `message` de la `PostgrestException` a este enum
/// en vez de dejar el string suelto en la UI (decisión de esta historia,
/// D5/D6 de `design.md`): así quien consume la excepción hace un `switch`
/// exhaustivo para dar feedback específico sin volver a acoplarse al texto
/// exacto que manda Postgres, y un mensaje nuevo o inesperado cae en
/// [desconocido] en vez de romper.
enum MotivoRechazoComodin {
  /// `usar_comodin`: el intento no es del usuario, no existe, o el desafío
  /// ya está respondido.
  intentoODesafioInvalido,

  /// `usar_comodin` con `pais`: el desafío actual tiene `pais` nulo (D4). No
  /// descuenta inventario ni marca el intento — es un hueco de contenido
  /// esperable, no un error de programa.
  paisNoDisponible,

  /// `usar_comodin`: el jugador no tiene unidades de ese tipo.
  sinComodinesDisponibles,

  /// `usar_comodin`: ya se consumió un comodín (de cualquier tipo) en este
  /// intento (D2).
  comodinYaUsadoEnEsteIntento,

  /// `conceder_comodin_por_anuncio`: ya se alcanzó el tope diario (D6).
  topeDiarioAlcanzado,

  /// Cualquier mensaje que no sea uno de los anteriores — no debería pasar
  /// contra el backend actual, pero así un mensaje nuevo no rompe la app.
  desconocido;

  static MotivoRechazoComodin desde(String? mensaje) => switch (mensaje) {
    'intento_o_desafio_invalido' =>
      MotivoRechazoComodin.intentoODesafioInvalido,
    'pais_no_disponible' => MotivoRechazoComodin.paisNoDisponible,
    'sin_comodines_disponibles' => MotivoRechazoComodin.sinComodinesDisponibles,
    'comodin_ya_usado_en_este_intento' =>
      MotivoRechazoComodin.comodinYaUsadoEnEsteIntento,
    'tope_diario_alcanzado' => MotivoRechazoComodin.topeDiarioAlcanzado,
    _ => MotivoRechazoComodin.desconocido,
  };
}

/// Lo que lanzan `usarComodin`/`concederComodinPorAnuncio` cuando Postgrest
/// devuelve un 400 con un motivo identificable (ver [MotivoRechazoComodin]).
/// Cualquier otro fallo (red, 500, etc.) se deja propagar tal cual —solo se
/// traducen los rechazos de negocio, no los errores de transporte—.
class ComodinRechazadoException implements Exception {
  const ComodinRechazadoException(this.motivo, [this.mensajeOriginal]);

  final MotivoRechazoComodin motivo;

  /// El `message` original de Postgrest, por si hace falta para depurar.
  final String? mensajeOriginal;

  @override
  String toString() => 'ComodinRechazadoException($motivo, $mensajeOriginal)';
}

/// Superficie mínima de Supabase para el inventario y uso de comodines, para
/// poder probar la bandeja de juego y la pantalla Comodines con un falso sin
/// salir a la red (mismo patrón que `CaminoGateway`/`NivelJuegoGateway`).
abstract class ComodinesGateway {
  Future<InventarioComodines> misComodines();

  /// Lanza [ComodinRechazadoException] si el servidor rechaza el consumo
  /// (ver [MotivoRechazoComodin]).
  Future<ResultadoUsoComodin> usarComodin({
    required String intentoId,
    required String desafioId,
    required ComodinTipo tipo,
  });

  /// Devuelve el tipo concedido. Lanza [ComodinRechazadoException] con
  /// [MotivoRechazoComodin.topeDiarioAlcanzado] si ya se alcanzó el tope de
  /// hoy.
  Future<ComodinTipo> concederComodinPorAnuncio();
}

class SupabaseComodinesGateway implements ComodinesGateway {
  SupabaseComodinesGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<InventarioComodines> misComodines() async {
    final filas = await _client.rpc('mis_comodines') as List;
    return mapearInventario(filas.cast<Map<String, dynamic>>());
  }

  @override
  Future<ResultadoUsoComodin> usarComodin({
    required String intentoId,
    required String desafioId,
    required ComodinTipo tipo,
  }) async {
    try {
      final respuesta = await _client.rpc(
        'usar_comodin',
        params: {
          'p_intento_id': intentoId,
          'p_desafio_id': desafioId,
          'p_tipo': tipo.aTexto,
        },
      );
      return mapearResultadoUsoComodin(respuesta as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      throw ComodinRechazadoException(
        MotivoRechazoComodin.desde(e.message),
        e.message,
      );
    }
  }

  @override
  Future<ComodinTipo> concederComodinPorAnuncio() async {
    try {
      // Sin argumentos desde la app: `p_tope_diario` tiene un default en el
      // servidor (5) y no es algo que el cliente deba decidir.
      final respuesta = await _client.rpc('conceder_comodin_por_anuncio');
      return ComodinTipo.fromString(
        (respuesta as Map<String, dynamic>)['tipo'] as String,
      );
    } on PostgrestException catch (e) {
      throw ComodinRechazadoException(
        MotivoRechazoComodin.desde(e.message),
        e.message,
      );
    }
  }
}

/// Mapea las filas `{tipo, cantidad}` que devuelve `mis_comodines()` a
/// [InventarioComodines]. Función pura, extraída para poder probar el mapeo
/// sin red (mismo patrón que `mapearIntentoNivel` en `nivel_juego_gateway`).
///
/// Rellena con `0` cualquier tipo que el servidor no trajera —no debería
/// pasar (D1 de `design.md`: siempre las 4 filas), pero así un hueco no
/// tumba la app con un `null` inesperado en [InventarioComodines.cantidadDe].
InventarioComodines mapearInventario(List<Map<String, dynamic>> filas) {
  final cantidades = <ComodinTipo, int>{
    for (final fila in filas)
      ComodinTipo.fromString(fila['tipo'] as String): _entero(
        fila['cantidad'],
        'cantidad',
      ),
  };
  for (final tipo in ComodinTipo.values) {
    cantidades.putIfAbsent(tipo, () => 0);
  }
  return InventarioComodines(cantidades: cantidades);
}

/// Mapea el `jsonb` que devuelve `usar_comodin` a [ResultadoUsoComodin],
/// eligiendo la subclase según `tipo`. Función pura, mismo motivo que
/// [mapearInventario].
ResultadoUsoComodin mapearResultadoUsoComodin(Map<String, dynamic> data) {
  final tipo = ComodinTipo.fromString(data['tipo'] as String);
  return switch (tipo) {
    ComodinTipo.tiempo => ResultadoTiempo(
      extraSegundos: _entero(data['extra_segundos'], 'extra_segundos'),
    ),
    ComodinTipo.pais => ResultadoPais(pais: _texto(data['pais'], 'pais')),
    ComodinTipo.km1000 || ComodinTipo.km500 => ResultadoRadio(
      tipo: tipo,
      lat: _decimal(data['lat'], 'lat'),
      lng: _decimal(data['lng'], 'lng'),
      radioKm: _decimal(data['radio_km'], 'radio_km'),
    ),
  };
}

int _entero(Object? valor, String campo) => switch (valor) {
  final num numero => numero.toInt(),
  final String texto => int.parse(texto),
  _ => throw ArgumentError('$campo ausente en la respuesta'),
};

/// `numeric`/`double precision` en Postgres llegan como número, pero
/// PostgREST los serializa como texto cuando no caben en un `double` sin
/// perder precisión (mismo motivo que `_decimal` en `nivel_juego_gateway`).
double _decimal(Object? valor, String campo) => switch (valor) {
  final num numero => numero.toDouble(),
  final String texto => double.parse(texto),
  _ => throw ArgumentError('$campo ausente en la respuesta'),
};

String _texto(Object? valor, String campo) => switch (valor) {
  final String texto => texto,
  _ => throw ArgumentError('$campo ausente en la respuesta'),
};
