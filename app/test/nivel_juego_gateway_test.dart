import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/services/nivel_juego_gateway.dart';

void main() {
  group('TipoDesafio.fromString', () {
    test('mapea los tres valores del enum de Postgres', () {
      expect(TipoDesafio.fromString('imagen'), TipoDesafio.imagen);
      expect(TipoDesafio.fromString('video'), TipoDesafio.video);
      expect(
        TipoDesafio.fromString('pregunta_texto'),
        TipoDesafio.preguntaTexto,
      );
    });

    test('un valor desconocido lanza ArgumentError', () {
      expect(() => TipoDesafio.fromString('otro'), throwsArgumentError);
    });
  });

  group('DesafioJuego', () {
    test('un desafío de imagen solo trae imagenUrl', () {
      const desafio = DesafioJuego(
        id: 'd1',
        nombre: 'Coliseo de Roma',
        tipo: TipoDesafio.imagen,
        activo: true,
        imagenUrl: 'https://example.com/foto.jpg',
      );

      expect(desafio.imagenUrl, 'https://example.com/foto.jpg');
      expect(desafio.videoUrl, isNull);
      expect(desafio.textoPregunta, isNull);
    });

    test('un desafío de video solo trae videoUrl', () {
      const desafio = DesafioJuego(
        id: 'd2',
        nombre: 'Coliseo de Roma',
        tipo: TipoDesafio.video,
        activo: true,
        videoUrl: 'https://example.com/clip.mp4',
      );

      expect(desafio.videoUrl, 'https://example.com/clip.mp4');
      expect(desafio.imagenUrl, isNull);
      expect(desafio.textoPregunta, isNull);
    });

    test('un desafío de pregunta de texto solo trae textoPregunta', () {
      const desafio = DesafioJuego(
        id: 'd3',
        nombre: 'Coliseo de Roma',
        tipo: TipoDesafio.preguntaTexto,
        activo: true,
        textoPregunta: '¿Dónde está esto?',
      );

      expect(desafio.textoPregunta, '¿Dónde está esto?');
      expect(desafio.imagenUrl, isNull);
      expect(desafio.videoUrl, isNull);
    });
  });

  group('mapearIntentoNivel', () {
    test('mapea el intento_id y cada desafío de la respuesta de la RPC', () {
      final intento = mapearIntentoNivel({
        'intento_id': 'i1',
        'segundos_por_desafio': 60,
        'objetivo_global': '¿Dónde está este monumento?',
        'desafios': [
          {
            'id': 'd1',
            'nombre': 'Torre Eiffel',
            'tipo': 'imagen',
            'imagen_url': 'https://example.com/foto.jpg',
            'video_url': null,
            'texto_pregunta': null,
            'activo': true,
          },
          {
            'id': 'd2',
            'nombre': 'Big Ben',
            'tipo': 'video',
            'imagen_url': null,
            'video_url': 'https://example.com/clip.mp4',
            'texto_pregunta': null,
            'activo': true,
          },
          {
            'id': 'd3',
            'nombre': 'Charles Darwin',
            'tipo': 'pregunta_texto',
            'imagen_url': null,
            'video_url': null,
            'texto_pregunta': '¿Dónde está esto?',
            'activo': true,
          },
        ],
      });

      expect(intento.intentoId, 'i1');
      expect(intento.desafios, hasLength(3));
      expect(intento.desafios[0].tipo, TipoDesafio.imagen);
      expect(intento.desafios[0].nombre, 'Torre Eiffel');
      expect(intento.desafios[0].imagenUrl, 'https://example.com/foto.jpg');
      expect(intento.desafios[1].tipo, TipoDesafio.video);
      expect(intento.desafios[1].nombre, 'Big Ben');
      expect(intento.desafios[1].videoUrl, 'https://example.com/clip.mp4');
      expect(intento.desafios[2].tipo, TipoDesafio.preguntaTexto);
      expect(intento.desafios[2].nombre, 'Charles Darwin');
      expect(intento.desafios[2].textoPregunta, '¿Dónde está esto?');
      expect(intento.segundosPorDesafio, 60);
      expect(intento.objetivoGlobal, '¿Dónde está este monumento?');
    });

    test('un intento sin desafíos mapea una lista vacía', () {
      final intento = mapearIntentoNivel({
        'intento_id': 'i2',
        'segundos_por_desafio': 90,
        'objetivo_global': '¿Dónde está este monumento?',
        'desafios': [],
      });

      expect(intento.desafios, isEmpty);
      expect(intento.segundosPorDesafio, 90);
    });

    test('sin segundos_por_desafio falla en vez de asumir un valor', () {
      // INT-99: la pantalla necesita este límite para inicializar la cuenta
      // atrás, así que una respuesta sin él es incompleta, no "sin límite".
      expect(
        () => mapearIntentoNivel({
          'intento_id': 'i3',
          'objetivo_global': '¿Dónde está este monumento?',
          'desafios': [],
        }),
        throwsArgumentError,
      );
    });

    test('sin objetivo_global falla en vez de asumir un valor', () {
      // INT-116: el toast de pista necesita este texto para mostrarlo junto
      // al nombre de cada desafío, así que una respuesta sin él es
      // incompleta.
      expect(
        () => mapearIntentoNivel({
          'intento_id': 'i4',
          'segundos_por_desafio': 60,
          'desafios': [],
        }),
        throwsArgumentError,
      );
    });
  });

  group('mapearRespuestaDesafio', () {
    test('lee lo que calculó el servidor y el revelado del desafío', () {
      final respuesta = mapearRespuestaDesafio({
        'id': 'r1',
        'intento_id': 'i1',
        'desafio_id': 'd1',
        'lat_adivinada': 40.4,
        'lng_adivinada': -3.7,
        'distancia_km': 247.5,
        'puntos': 4381,
        'puntos_distancia': 4301,
        'puntos_bonus': 80,
        'respondido_en': '2026-08-17T12:00:00Z',
        'lat_real': 41.8902,
        'lng_real': 12.4922,
        'nombre_lugar': 'Coliseo de Roma',
        'ciudad': 'Roma',
        'puntos_maximos': 5500,
      });

      expect(respuesta.distanciaKm, closeTo(247.5, 1e-9));
      expect(respuesta.puntos, 4381);
      expect(respuesta.puntosDistancia, 4301);
      expect(respuesta.puntosBonus, 80);
      expect(respuesta.latitudReal, closeTo(41.8902, 1e-9));
      expect(respuesta.longitudReal, closeTo(12.4922, 1e-9));
      expect(respuesta.nombreLugar, 'Coliseo de Roma');
      expect(respuesta.ciudad, 'Roma');
      expect(respuesta.puntosMaximos, 5500);
    });

    test('ciudad null es un desafío sin ciudad registrada, no un error', () {
      // El backend guarda "sin ciudad real" como NULL a propósito (INT-122):
      // un yacimiento en descampado, un naufragio en alta mar.
      final respuesta = mapearRespuestaDesafio({
        'distancia_km': 10.0,
        'puntos': 100,
        'puntos_distancia': 100,
        'puntos_bonus': 0,
        'lat_real': 51.1789,
        'lng_real': -1.8262,
        'nombre_lugar': 'Stonehenge, Inglaterra',
        'ciudad': null,
        'puntos_maximos': 5500,
      });

      expect(respuesta.ciudad, isNull);
      expect(respuesta.nombreLugar, 'Stonehenge, Inglaterra');
    });

    test('ciudad ausente del todo también mapea a null', () {
      // Una app con INT-122 contra un backend anterior: la clave no viaja.
      // No es una respuesta incompleta, es la de siempre.
      final respuesta = mapearRespuestaDesafio({
        'distancia_km': 10.0,
        'puntos': 100,
        'puntos_distancia': 100,
        'puntos_bonus': 0,
        'lat_real': 41.8902,
        'lng_real': 12.4922,
        'nombre_lugar': 'Coliseo de Roma',
        'puntos_maximos': 5500,
      });

      expect(respuesta.ciudad, isNull);
    });

    test('una ciudad en blanco se normaliza a null', () {
      // No debería llegar —el panel guarda '' como NULL—, pero si llega, un
      // rótulo en blanco es peor que caer a nombre_lugar.
      final respuesta = mapearRespuestaDesafio({
        'distancia_km': 10.0,
        'puntos': 100,
        'puntos_distancia': 100,
        'puntos_bonus': 0,
        'lat_real': 41.8902,
        'lng_real': 12.4922,
        'nombre_lugar': 'Coliseo de Roma',
        'ciudad': '   ',
        'puntos_maximos': 5500,
      });

      expect(respuesta.ciudad, isNull);
    });

    test('acepta una distancia serializada como texto', () {
      // `distancia_km` es `numeric` en Postgres, así que PostgREST puede
      // mandarla como cadena para no perder precisión.
      final respuesta = mapearRespuestaDesafio({
        'distancia_km': '1234.5678',
        'puntos': 0,
        'puntos_distancia': 0,
        'puntos_bonus': 0,
        'lat_real': 0,
        'lng_real': 0,
        'nombre_lugar': 'Isla nula',
        'puntos_maximos': 5500,
      });

      expect(respuesta.distanciaKm, closeTo(1234.5678, 1e-9));
      expect(respuesta.puntos, 0);
    });

    test('acepta lat_real/lng_real serializadas como texto', () {
      // Mismo motivo que `distancia_km`: son `numeric` en Postgres.
      final respuesta = mapearRespuestaDesafio({
        'distancia_km': 10,
        'puntos': 100,
        'puntos_distancia': 100,
        'puntos_bonus': 0,
        'lat_real': '41.8902',
        'lng_real': '12.4922',
        'nombre_lugar': 'Coliseo de Roma',
        'puntos_maximos': 5500,
      });

      expect(respuesta.latitudReal, closeTo(41.8902, 1e-9));
      expect(respuesta.longitudReal, closeTo(12.4922, 1e-9));
    });

    test('distancia_km con un tipo inesperado falla en vez de ignorarlo', () {
      expect(
        () => mapearRespuestaDesafio({
          'distancia_km': true,
          'puntos': 0,
          'puntos_distancia': 0,
          'puntos_bonus': 0,
          'lat_real': 0,
          'lng_real': 0,
          'nombre_lugar': 'Isla nula',
          'puntos_maximos': 5500,
        }),
        throwsArgumentError,
      );
    });

    test('una respuesta sin revelado falla en vez de dejarlo a medias', () {
      // Si la RPC dejara de mandar el revelado, la pantalla no podría
      // enseñarlo: mejor fallar al mapear que pintar una hoja de resultado
      // con un lugar vacío en el 0,0 del Atlántico.
      expect(
        () => mapearRespuestaDesafio({
          'distancia_km': 10,
          'puntos': 100,
          'puntos_distancia': 100,
          'puntos_bonus': 0,
          'lat_real': 41.8902,
          'lng_real': 12.4922,
          'puntos_maximos': 5500,
        }),
        throwsArgumentError,
      );
    });

    test('sin puntos_distancia/puntos_bonus falla en vez de asumir 0', () {
      expect(
        () => mapearRespuestaDesafio({
          'distancia_km': 10,
          'puntos': 100,
          'lat_real': 41.8902,
          'lng_real': 12.4922,
          'nombre_lugar': 'Coliseo de Roma',
          'puntos_maximos': 5500,
        }),
        throwsArgumentError,
      );
    });

    test('una respuesta sin pin llega con distancia null y desglose en 0', () {
      // INT-99: el tiempo se agotó sin que el jugador colocara ningún pin.
      // El servidor no tiene coordenada adivinada de la que calcular una
      // distancia, así que la manda `null` a propósito, no por omisión.
      final respuesta = mapearRespuestaDesafio({
        'distancia_km': null,
        'puntos': 0,
        'puntos_distancia': 0,
        'puntos_bonus': 0,
        'lat_real': 41.8902,
        'lng_real': 12.4922,
        'nombre_lugar': 'Coliseo de Roma',
        'puntos_maximos': 5500,
      });

      expect(respuesta.distanciaKm, isNull);
      expect(respuesta.puntos, 0);
      expect(respuesta.puntosDistancia, 0);
      expect(respuesta.puntosBonus, 0);
      // La ubicación real se revela igual, con o sin pin.
      expect(respuesta.nombreLugar, 'Coliseo de Roma');
    });

    test('distancia_km ausente del todo también mapea a null', () {
      final respuesta = mapearRespuestaDesafio({
        'puntos': 0,
        'puntos_distancia': 0,
        'puntos_bonus': 0,
        'lat_real': 0,
        'lng_real': 0,
        'nombre_lugar': 'Isla nula',
        'puntos_maximos': 5500,
      });

      expect(respuesta.distanciaKm, isNull);
    });
  });

  group('mapearResultadoIntento', () {
    test('con un mejor puntaje anterior registrado', () {
      final resultado = mapearResultadoIntento({
        'puntaje_total': 2140,
        'superado': true,
        'estrellas_obtenidas': 3,
        'puntaje_minimo_superar': 1500,
        'mejor_puntaje_anterior': 1820,
      });

      expect(resultado.puntajeTotal, 2140);
      expect(resultado.superado, isTrue);
      expect(resultado.estrellas, 3);
      expect(resultado.puntajeMinimoSuperar, 1500);
      expect(resultado.mejorPuntajeAnterior, 1820);
    });

    test('sin resultado anterior el mejor puntaje llega null, no 0', () {
      // D2 de `design.md` de INT-94: sin fila previa en
      // `progreso_usuario_nivel`, la RPC manda `null`. Tratarlo como 0
      // anunciaría "récord" en el primer despeje del nivel.
      final resultado = mapearResultadoIntento({
        'puntaje_total': 900,
        'superado': false,
        'estrellas_obtenidas': 0,
        'puntaje_minimo_superar': 1500,
        'mejor_puntaje_anterior': null,
      });

      expect(resultado.mejorPuntajeAnterior, isNull);
    });

    test('un intento no superado no trae estrellas', () {
      final resultado = mapearResultadoIntento({
        'puntaje_total': 1350,
        'superado': false,
        'estrellas_obtenidas': 0,
        'puntaje_minimo_superar': 1500,
        'mejor_puntaje_anterior': 1200,
      });

      expect(resultado.superado, isFalse);
      expect(resultado.estrellas, 0);
    });
  });
}
