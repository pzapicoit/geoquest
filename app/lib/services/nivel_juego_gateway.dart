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
class IntentoNivel {
  const IntentoNivel({required this.intentoId, required this.desafios});

  final String intentoId;
  final List<DesafioJuego> desafios;
}

/// Superficie mínima de Supabase para arrancar un intento de nivel, para
/// poder probar la pantalla de juego con un falso sin salir a la red.
abstract class NivelJuegoGateway {
  Future<IntentoNivel> iniciarIntento(String nivelId);
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
}

/// Mapea el jsonb `{"intento_id", "desafios"}` que devuelve
/// `iniciar_intento_nivel` a [IntentoNivel]. Función pura, extraída para
/// poder probar el mapeo sin red (INT-91, mismo patrón que
/// `intercalarFronteras` en `camino_gateway.dart`).
IntentoNivel mapearIntentoNivel(Map<String, dynamic> data) {
  final desafiosRaw = data['desafios'] as List;

  return IntentoNivel(
    intentoId: data['intento_id'] as String,
    desafios: [
      for (final fila in desafiosRaw)
        _mapearDesafio(fila as Map<String, dynamic>),
    ],
  );
}

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
