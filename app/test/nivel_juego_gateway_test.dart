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
        'desafios': [
          {
            'id': 'd1',
            'tipo': 'imagen',
            'imagen_url': 'https://example.com/foto.jpg',
            'video_url': null,
            'texto_pregunta': null,
            'activo': true,
          },
          {
            'id': 'd2',
            'tipo': 'video',
            'imagen_url': null,
            'video_url': 'https://example.com/clip.mp4',
            'texto_pregunta': null,
            'activo': true,
          },
          {
            'id': 'd3',
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
      expect(intento.desafios[0].imagenUrl, 'https://example.com/foto.jpg');
      expect(intento.desafios[1].tipo, TipoDesafio.video);
      expect(intento.desafios[1].videoUrl, 'https://example.com/clip.mp4');
      expect(intento.desafios[2].tipo, TipoDesafio.preguntaTexto);
      expect(intento.desafios[2].textoPregunta, '¿Dónde está esto?');
    });

    test('un intento sin desafíos mapea una lista vacía', () {
      final intento = mapearIntentoNivel({'intento_id': 'i2', 'desafios': []});

      expect(intento.desafios, isEmpty);
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
        'respondido_en': '2026-08-17T12:00:00Z',
        'lat_real': 41.8902,
        'lng_real': 12.4922,
        'nombre_lugar': 'Coliseo de Roma',
        'puntos_maximos': 5000,
      });

      expect(respuesta.distanciaKm, closeTo(247.5, 1e-9));
      expect(respuesta.puntos, 4381);
      expect(respuesta.latitudReal, closeTo(41.8902, 1e-9));
      expect(respuesta.longitudReal, closeTo(12.4922, 1e-9));
      expect(respuesta.nombreLugar, 'Coliseo de Roma');
      expect(respuesta.puntosMaximos, 5000);
    });

    test('acepta una distancia serializada como texto', () {
      // `distancia_km` es `numeric` en Postgres, así que PostgREST puede
      // mandarla como cadena para no perder precisión.
      final respuesta = mapearRespuestaDesafio({
        'distancia_km': '1234.5678',
        'puntos': 0,
        'lat_real': 0,
        'lng_real': 0,
        'nombre_lugar': 'Isla nula',
        'puntos_maximos': 5000,
      });

      expect(respuesta.distanciaKm, closeTo(1234.5678, 1e-9));
      expect(respuesta.puntos, 0);
    });

    test('una respuesta sin distancia falla en vez de inventarse un 0', () {
      expect(() => mapearRespuestaDesafio({'puntos': 10}), throwsArgumentError);
    });

    test('una respuesta sin revelado falla en vez de dejarlo a medias', () {
      // Si la RPC dejara de mandar el revelado, la pantalla no podría
      // enseñarlo: mejor fallar al mapear que pintar una hoja de resultado
      // con un lugar vacío en el 0,0 del Atlántico.
      expect(
        () => mapearRespuestaDesafio({
          'distancia_km': 10,
          'puntos': 100,
          'lat_real': 41.8902,
          'lng_real': 12.4922,
          'puntos_maximos': 5000,
        }),
        throwsArgumentError,
      );
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
