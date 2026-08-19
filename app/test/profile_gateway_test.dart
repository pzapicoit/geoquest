import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/services/profile_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('esViolacionDeAliasUnico', () {
    test('true cuando el codigo es 23505 (unique_violation)', () {
      const error = PostgrestException(
        message: 'duplicate key value violates unique constraint',
        code: '23505',
      );

      expect(esViolacionDeAliasUnico(error), isTrue);
    });

    test('false para otros codigos de Postgrest', () {
      const error = PostgrestException(
        message: 'permission denied',
        code: '42501',
      );

      expect(esViolacionDeAliasUnico(error), isFalse);
    });

    test('false cuando no hay codigo', () {
      const error = PostgrestException(message: 'fallo de red');

      expect(esViolacionDeAliasUnico(error), isFalse);
    });
  });
}
