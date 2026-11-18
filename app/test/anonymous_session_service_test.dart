import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show ClientException;
import 'package:geoquest/services/anonymous_session_service.dart';
import 'package:geoquest/services/device_id_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fakes/fake_auth_gateway.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AnonymousSessionService', () {
    test(
      'crea sesión anónima con el UUID del dispositivo cuando no hay sesión',
      () async {
        final auth = FakeAuthGateway();
        final service = AnonymousSessionService(auth, DeviceIdService());

        final result = await service.ensureSession();

        expect(result, isA<AnonymousSessionReady>());
        expect(auth.signInAnonymouslyCalls, 1);
        expect(auth.lastSignInData?['device_id'], isNotEmpty);
      },
    );

    test(
      'no vuelve a dar de alta si ya existe una sesión restaurada',
      () async {
        final auth = FakeAuthGateway(
          initialSession: Session(
            accessToken: 'token-existente',
            tokenType: 'bearer',
            user: const User(
              id: 'usuario-existente',
              appMetadata: {},
              userMetadata: {},
              aud: 'authenticated',
              createdAt: '2026-08-15T00:00:00Z',
              isAnonymous: true,
            ),
          ),
        );
        final service = AnonymousSessionService(auth, DeviceIdService());

        final result = await service.ensureSession();

        expect(result, isA<AnonymousSessionReady>());
        expect(auth.signInAnonymouslyCalls, 0);
      },
    );

    test('devuelve fallo explícito cuando el alta anónima falla', () async {
      final auth = FakeAuthGateway()
        ..throwOnNextCall = const AuthException(
          'Proveedor anónimo deshabilitado',
        );
      final service = AnonymousSessionService(auth, DeviceIdService());

      final result = await service.ensureSession();

      expect(result, isA<AnonymousSessionFailure>());
      final fallo = result as AnonymousSessionFailure;
      expect(fallo.causa, CausaFalloSesion.otra);
      expect(fallo.detalle, contains('Proveedor anónimo deshabilitado'));
    });

    test(
      'no propaga excepciones inesperadas, las convierte en fallo',
      () async {
        final auth = FakeAuthGateway()
          ..throwOnNextCall = Exception('red caída');
        final service = AnonymousSessionService(auth, DeviceIdService());

        final result = await service.ensureSession();

        expect(result, isA<AnonymousSessionFailure>());
      },
    );
  });

  group('clasificarFalloSesion (INT-145)', () {
    test('un 5xx de Auth es un fallo del servidor', () {
      expect(
        clasificarFalloSesion(
          const AuthException('Unexpected failure', statusCode: '500'),
        ),
        CausaFalloSesion.servidor,
      );
      expect(
        clasificarFalloSesion(
          AuthRetryableFetchException(message: 'down', statusCode: '521'),
        ),
        CausaFalloSesion.servidor,
      );
    });

    test('un fallo de red sin respuesta es sinRespuesta', () {
      expect(
        clasificarFalloSesion(
          AuthRetryableFetchException(message: 'Failed to fetch'),
        ),
        CausaFalloSesion.sinRespuesta,
      );
      expect(
        clasificarFalloSesion(ClientException('Failed to fetch')),
        CausaFalloSesion.sinRespuesta,
      );
      expect(
        clasificarFalloSesion(TimeoutException('lento')),
        CausaFalloSesion.sinRespuesta,
      );
    });

    test('un error de Auth 4xx o sin código es otra causa', () {
      expect(
        clasificarFalloSesion(
          const AuthException('anónimo deshabilitado', statusCode: '422'),
        ),
        CausaFalloSesion.otra,
      );
      expect(
        clasificarFalloSesion(const AuthException('sin código')),
        CausaFalloSesion.otra,
      );
      expect(clasificarFalloSesion(Exception('raro')), CausaFalloSesion.otra);
    });
  });
}
