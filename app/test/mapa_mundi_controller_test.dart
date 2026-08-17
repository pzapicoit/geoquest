import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/mapa/mapa_mundi_controller.dart';
import 'package:geoquest/mapa/mercator.dart';

const _movil = Size(390, 844);

MapaMundiController _controlador([Size tamano = _movil]) =>
    MapaMundiController()..ajustarTamano(tamano);

void main() {
  group('encuadre inicial', () {
    test('el mundo llena la altura y queda centrado a lo ancho', () {
      final controlador = _controlador();

      expect(controlador.escala, 844);
      expect(controlador.desplazamiento.dx, (390 - 844) / 2);
      expect(controlador.desplazamiento.dy, 0);
    });

    test('los límites salen del tamaño de la pantalla', () {
      final controlador = _controlador();

      // Alejar deja ver el mundo entero; acercar llega a 14× el encuadre
      // inicial, unos 3,5 km por píxel.
      expect(controlador.escalaMinima, 390);
      expect(controlador.escalaInicial, 844);
      expect(controlador.escalaMaxima, 844 * 14);
    });

    test('sin tamaño todavía, no hay nada que proyectar', () {
      final controlador = MapaMundiController();

      expect(controlador.listo, isFalse);
      expect(controlador.pantallaACoordenadas(Offset.zero), isNull);
      expect(
        controlador.coordenadasAPantalla(
          const Coordenada(latitud: 0, longitud: 0),
        ),
        isNull,
      );
    });
  });

  group('límites de zoom', () {
    test('alejar se detiene con el mundo entero en pantalla', () {
      final controlador = _controlador();

      for (var i = 0; i < 20; i++) {
        controlador.alejar();
      }

      expect(controlador.escala, controlador.escalaMinima);
    });

    test('acercar se detiene en 14× el encuadre inicial', () {
      final controlador = _controlador();

      for (var i = 0; i < 40; i++) {
        controlador.acercar();
      }

      expect(controlador.escala, controlador.escalaMaxima);
    });

    test('el zoom mantiene quieto el punto enfocado', () {
      final controlador = _controlador();
      const foco = Offset(195, 400);
      final antes = controlador.pantallaACoordenadas(foco)!;

      controlador.zoomEn(2.5, foco);

      final despues = controlador.pantallaACoordenadas(foco)!;
      expect(despues.latitud, closeTo(antes.latitud, 1e-9));
      expect(despues.longitud, closeTo(antes.longitud, 1e-9));
    });

    test('un factor absurdo no se salta los topes', () {
      final controlador = _controlador();

      controlador.zoomEn(1000, const Offset(195, 400));
      expect(controlador.escala, controlador.escalaMaxima);

      controlador.zoomEn(0.0001, const Offset(195, 400));
      expect(controlador.escala, controlador.escalaMinima);
    });
  });

  group('desplazamiento', () {
    test('arrastrar más allá del borde deja el mundo pegado al borde', () {
      final controlador = _controlador();

      controlador.desplazar(const Offset(10000, 0));
      expect(controlador.desplazamiento.dx, 0);

      controlador.desplazar(const Offset(-100000, 0));
      expect(controlador.desplazamiento.dx, 390 - controlador.escala);
    });

    test('con el mundo más pequeño que la pantalla, queda centrado', () {
      final controlador = _controlador();
      for (var i = 0; i < 20; i++) {
        controlador.alejar();
      }

      final centrado = Offset(
        (390 - controlador.escala) / 2,
        (844 - controlador.escala) / 2,
      );
      expect(controlador.desplazamiento, centrado);

      controlador.desplazar(const Offset(120, 120));
      expect(controlador.desplazamiento, centrado);
    });

    test('rotar la pantalla conserva el centro y respeta los topes', () {
      final controlador = _controlador();
      final centroAntes = controlador.pantallaACoordenadas(
        const Offset(195, 422),
      )!;

      controlador.ajustarTamano(const Size(844, 390));

      final centroDespues = controlador.pantallaACoordenadas(
        const Offset(422, 195),
      )!;
      expect(centroDespues.longitud, closeTo(centroAntes.longitud, 1e-6));
      expect(controlador.escala, lessThanOrEqualTo(controlador.escalaMaxima));
      expect(
        controlador.escala,
        greaterThanOrEqualTo(controlador.escalaMinima),
      );
    });
  });

  group('pin', () {
    test('un toque sobre el mundo coloca el pin en esa coordenada', () {
      final controlador = _controlador();
      const punto = Offset(195, 422);

      expect(controlador.colocarPinEn(punto), isTrue);

      final esperada = controlador.pantallaACoordenadas(punto)!;
      expect(controlador.pin, esperada);
      expect(controlador.tienePin, isTrue);
    });

    test('un segundo toque lo mueve, no añade otro', () {
      final controlador = _controlador();
      controlador.colocarPinEn(const Offset(195, 422));
      final primero = controlador.pin!;

      controlador.colocarPinEn(const Offset(240, 500));

      expect(controlador.pin, isNot(primero));
      expect(
        controlador.pin,
        controlador.pantallaACoordenadas(const Offset(240, 500)),
      );
    });

    test('un toque fuera del mundo no coloca nada', () {
      final controlador = _controlador();
      for (var i = 0; i < 20; i++) {
        controlador.alejar();
      }

      // Alejado del todo sobran franjas arriba y abajo: ahí no hay planeta.
      expect(controlador.colocarPinEn(const Offset(195, 4)), isFalse);
      expect(controlador.pin, isNull);
    });

    test('el pin y la pantalla son la misma ida y vuelta', () {
      final controlador = _controlador();
      const madrid = Coordenada(latitud: 40.4168, longitud: -3.7038);

      controlador.colocarPin(madrid);
      final punto = controlador.coordenadasAPantalla(madrid)!;
      final vuelta = controlador.pantallaACoordenadas(punto)!;

      expect(vuelta.latitud, closeTo(madrid.latitud, 1e-6));
      expect(vuelta.longitud, closeTo(madrid.longitud, 1e-6));
    });

    test('la longitud se normaliza y la latitud se acota', () {
      final controlador = _controlador();

      controlador.colocarPin(const Coordenada(latitud: 89, longitud: 200));

      expect(controlador.pin!.longitud, closeTo(-160, 1e-9));
      expect(controlador.pin!.latitud, closeTo(Mercator.latitudMaxima, 1e-9));
    });

    test('limpiar el pin lo quita', () {
      final controlador = _controlador();
      controlador.colocarPinEn(const Offset(195, 422));

      controlador.limpiarPin();

      expect(controlador.pin, isNull);
      expect(controlador.tienePin, isFalse);
    });

    test('avisa a quien escucha cada vez que cambia algo', () {
      final controlador = _controlador();
      var avisos = 0;
      controlador.addListener(() => avisos++);

      controlador.colocarPinEn(const Offset(195, 422));
      controlador.desplazar(const Offset(10, 0));
      controlador.acercar();
      controlador.limpiarPin();

      expect(avisos, 4);
    });
  });
}
