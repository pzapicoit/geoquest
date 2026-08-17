import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/mapa/mercator.dart';

/// La proyección es lo que convierte un dedo en una coordenada que viaja a
/// `responder_desafio`, así que se prueba sola, sin widgets (D4/D5 de
/// `design.md` de INT-92).
void main() {
  group('proyectar e invertir', () {
    const lugares = {
      'Madrid': (40.4168, -3.7038),
      'Sídney': (-33.8688, 151.2093),
      'Reikiavik': (64.1466, -21.9426),
      'Quito': (-0.1807, -78.4678),
      'isla Nula': (0.0, 0.0),
    };

    for (final lugar in lugares.entries) {
      test('${lugar.key} vuelve a su sitio', () {
        final (latitud, longitud) = lugar.value;

        final x = Mercator.xDeLongitud(longitud);
        final y = Mercator.yDeLatitud(latitud);

        expect(Mercator.longitudDeX(x), closeTo(longitud, 1e-9));
        expect(Mercator.latitudDeY(y), closeTo(latitud, 1e-9));
      });
    }

    test('el mundo entero cae dentro del cuadrado [0,1]', () {
      expect(Mercator.xDeLongitud(-180), closeTo(0, 1e-12));
      expect(Mercator.xDeLongitud(180), closeTo(1, 1e-12));
      expect(Mercator.yDeLatitud(Mercator.latitudMaxima), closeTo(0, 1e-9));
      expect(Mercator.yDeLatitud(-Mercator.latitudMaxima), closeTo(1, 1e-9));
      expect(Mercator.yDeLatitud(0), closeTo(0.5, 1e-12));
    });
  });

  test('la latitud se acota al límite de la proyección', () {
    // Más allá de ±85,05° Mercator se dispara al infinito: se recorta en vez
    // de devolver un valor sin sentido.
    expect(
      Mercator.yDeLatitud(89.9),
      closeTo(Mercator.yDeLatitud(Mercator.latitudMaxima), 1e-12),
    );
    expect(
      Mercator.yDeLatitud(-90),
      closeTo(Mercator.yDeLatitud(-Mercator.latitudMaxima), 1e-12),
    );
  });

  group('normalizar longitud', () {
    test('deja intacto lo que ya está en rango', () {
      expect(Mercator.normalizarLongitud(0), 0);
      expect(Mercator.normalizarLongitud(-3.7), closeTo(-3.7, 1e-12));
      expect(Mercator.normalizarLongitud(179.9), closeTo(179.9, 1e-12));
    });

    test('da la vuelta al pasar el meridiano 180', () {
      expect(Mercator.normalizarLongitud(200), closeTo(-160, 1e-12));
      expect(Mercator.normalizarLongitud(-200), closeTo(160, 1e-12));
      expect(Mercator.normalizarLongitud(540), closeTo(-180, 1e-12));
    });
  });
}
