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
    test('lee la distancia y los puntos que calculó el servidor', () {
      final respuesta = mapearRespuestaDesafio({
        'id': 'r1',
        'intento_id': 'i1',
        'desafio_id': 'd1',
        'lat_adivinada': 40.4,
        'lng_adivinada': -3.7,
        'distancia_km': 247.5,
        'puntos': 4381,
        'respondido_en': '2026-08-17T12:00:00Z',
      });

      expect(respuesta.distanciaKm, closeTo(247.5, 1e-9));
      expect(respuesta.puntos, 4381);
    });

    test('acepta una distancia serializada como texto', () {
      // `distancia_km` es `numeric` en Postgres, así que PostgREST puede
      // mandarla como cadena para no perder precisión.
      final respuesta = mapearRespuestaDesafio({
        'distancia_km': '1234.5678',
        'puntos': 0,
      });

      expect(respuesta.distanciaKm, closeTo(1234.5678, 1e-9));
      expect(respuesta.puntos, 0);
    });

    test('una respuesta sin distancia falla en vez de inventarse un 0', () {
      expect(() => mapearRespuestaDesafio({'puntos': 10}), throwsArgumentError);
    });
  });
}
