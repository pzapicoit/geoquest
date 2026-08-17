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

  group('encuadre de varias coordenadas', () {
    // Los márgenes del revelado: arriba cabe el HUD y abajo la hoja de
    // resultado, que es mucho más alta.
    const margenes = EdgeInsets.fromLTRB(62, 168, 62, 404);
    const madrid = Coordenada(latitud: 40.4168, longitud: -3.7038);
    const roma = Coordenada(latitud: 41.8902, longitud: 12.4922);

    test('las dos coordenadas caen dentro del área útil', () {
      final controlador = _controlador();

      controlador.aplicarCamara(
        controlador.camaraPara(const [madrid, roma], margenes: margenes),
      );

      // El encuadre deja los pines justo tocando el margen que se le pidió,
      // así que se comprueba con la holgura de un redondeo.
      const holgura = 0.01;
      for (final coordenada in const [madrid, roma]) {
        final punto = controlador.coordenadasAPantalla(coordenada)!;
        expect(punto.dx, greaterThanOrEqualTo(62 - holgura));
        expect(punto.dx, lessThanOrEqualTo(390 - 62 + holgura));
        expect(punto.dy, greaterThanOrEqualTo(168 - holgura));
        expect(punto.dy, lessThanOrEqualTo(844 - 404 + holgura));
      }
    });

    test('el encuadre reparte el margen que se le pide, no uno simétrico', () {
      final controlador = _controlador();

      final camara = controlador.camaraPara(const [
        madrid,
        roma,
      ], margenes: margenes);
      controlador.aplicarCamara(camara);

      // Con 168 arriba y 404 abajo, el centro del par queda en la mitad de
      // la franja que queda libre, muy por encima del centro de la pantalla.
      final centro =
          (controlador.coordenadasAPantalla(madrid)!.dy +
              controlador.coordenadasAPantalla(roma)!.dy) /
          2;
      expect(centro, closeTo(168 + (844 - 168 - 404) / 2, 0.5));
    });

    test('dos coordenadas casi iguales se quedan en el zoom máximo', () {
      final controlador = _controlador();

      final camara = controlador.camaraPara(const [
        Coordenada(latitud: 41.8902, longitud: 12.4922),
        Coordenada(latitud: 41.89021, longitud: 12.49221),
      ]);

      expect(camara.escala, controlador.escalaMaxima);
    });

    test(
      'dos coordenadas en extremos opuestos no bajan de la escala mínima',
      () {
        final controlador = _controlador();

        // Con los márgenes del revelado, meter medio planeta en la franja libre
        // pediría alejar más de lo que el mapa permite.
        final camara = controlador.camaraPara(const [
          Coordenada(latitud: 80, longitud: -179),
          Coordenada(latitud: -80, longitud: 179),
        ], margenes: margenes);

        expect(camara.escala, controlador.escalaMinima);
        // Y el mundo sigue sin dejar hueco a los lados: con la escala mínima
        // llena el ancho justo.
        expect(camara.desplazamiento.dx, 0);
      },
    );

    test('sin tamaño todavía, el encuadre es el que ya había', () {
      final controlador = MapaMundiController();

      expect(controlador.camaraPara(const [madrid, roma]), controlador.camara);
    });

    test('una lista vacía deja el encuadre como está', () {
      final controlador = _controlador();

      expect(controlador.camaraPara(const []), controlador.camara);
    });

    test('aplicar un encuadre absurdo no se salta los topes', () {
      final controlador = _controlador();

      controlador.aplicarCamara(
        const CamaraMapa(escala: 1e9, desplazamiento: Offset(1e9, 1e9)),
      );

      expect(controlador.escala, controlador.escalaMaxima);
      expect(controlador.desplazamiento.dx, lessThanOrEqualTo(0));
      expect(controlador.desplazamiento.dy, lessThanOrEqualTo(0));
    });

    test('aplicar el encuadre que ya había no avisa a nadie', () {
      final controlador = _controlador();
      var avisos = 0;
      controlador.addListener(() => avisos++);

      controlador.aplicarCamara(controlador.camara);

      expect(avisos, 0);
    });

    test('interpolar dos encuadres va de uno a otro', () {
      const desde = CamaraMapa(escala: 100, desplazamiento: Offset(0, 0));
      const hasta = CamaraMapa(escala: 300, desplazamiento: Offset(40, -80));

      expect(CamaraMapa.interpolar(desde, hasta, 0), desde);
      expect(CamaraMapa.interpolar(desde, hasta, 1), hasta);

      final medio = CamaraMapa.interpolar(desde, hasta, 0.5);
      expect(medio.escala, closeTo(200, 1e-9));
      expect(medio.desplazamiento, const Offset(20, -40));
    });

    test('pasar de desafío devuelve el mapa a su encuadre de partida', () {
      final controlador = _controlador();
      controlador.acercar();
      controlador.desplazar(const Offset(-120, -60));

      controlador.reiniciarEncuadre();

      expect(controlador.escala, controlador.escalaInicial);
      expect(controlador.desplazamiento.dx, (390 - 844) / 2);
      expect(controlador.desplazamiento.dy, 0);
    });
  });

  group('revelado', () {
    test('la ubicación real se acota y se normaliza como el pin', () {
      final controlador = _controlador();

      controlador.revelarUbicacion(
        const Coordenada(latitud: 89, longitud: 200),
      );

      expect(controlador.pinReal!.longitud, closeTo(-160, 1e-9));
      expect(
        controlador.pinReal!.latitud,
        closeTo(Mercator.latitudMaxima, 1e-9),
      );
    });

    test('el progreso de la línea se queda entre 0 y 1', () {
      final controlador = _controlador();

      controlador.progresoDeLaLinea = 0.4;
      expect(controlador.progresoDeLaLinea, 0.4);

      controlador.progresoDeLaLinea = 5;
      expect(controlador.progresoDeLaLinea, 1);

      controlador.progresoDeLaLinea = -3;
      expect(controlador.progresoDeLaLinea, 0);
    });

    test('limpiar el revelado quita el pin real y la línea', () {
      final controlador = _controlador();
      controlador.revelarUbicacion(
        const Coordenada(latitud: 41.8902, longitud: 12.4922),
      );
      controlador.progresoDeLaLinea = 1;

      controlador.limpiarRevelado();

      expect(controlador.pinReal, isNull);
      expect(controlador.progresoDeLaLinea, 0);
    });

    test('limpiar un revelado que no existe no avisa a nadie', () {
      final controlador = _controlador();
      var avisos = 0;
      controlador.addListener(() => avisos++);

      controlador.limpiarRevelado();

      expect(avisos, 0);
    });
  });
}
