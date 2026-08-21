import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/services/identidad_de_apodo.dart';

void main() {
  group('identidadDeApodo', () {
    test('es determinista', () {
      expect(identidadDeApodo('Pablo'), identidadDeApodo('Pablo'));
    });

    test('no distingue mayúsculas ni espacios sobrantes', () {
      final referencia = identidadDeApodo('Pablo');

      expect(identidadDeApodo('pablo'), referencia);
      expect(identidadDeApodo('PABLO'), referencia);
      expect(identidadDeApodo('  Pablo  '), referencia);
    });

    test('apodos distintos dan identidades distintas', () {
      expect(identidadDeApodo('Pablo'), isNot(identidadDeApodo('Pablito')));
    });

    test('admite acentos, espacios interiores y emoji', () {
      // El campo de apodo no restringe el juego de caracteres, y la propia
      // lista de sugerencias trae acentos: si la identidad no los tolerase,
      // esos jugadores no podrían tener contraseña.
      for (final apodo in ['BrújulaLoca', 'Nómada Azul', 'Geo🌍Lince']) {
        final identidad = identidadDeApodo(apodo);
        expect(identidad, endsWith('@$dominioIdentidadSintetica'));
        expect(identidad.split('@').first, matches(RegExp(r'^[0-9a-f]{64}$')));
      }
    });

    test('usa un dominio que no puede recibir correo', () {
      // `.invalid` está reservado por la RFC 2606: es la garantía de que este
      // proyecto no manda correo a ninguna parte.
      expect(dominioIdentidadSintetica, endsWith('.invalid'));
    });
  });
}
