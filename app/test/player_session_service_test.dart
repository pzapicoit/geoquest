import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/services/estado_apodo_gateway.dart';
import 'package:geoquest/services/identidad_de_apodo.dart';
import 'package:geoquest/services/player_roster_storage.dart';
import 'package:geoquest/services/player_session_service.dart';
import 'package:geoquest/services/profile_gateway.dart';
import 'package:geoquest/services/username_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fakes/fake_auth_gateway.dart';
import 'fakes/fake_estado_apodo_gateway.dart';
import 'fakes/fake_profile_gateway.dart';

late FakeAuthGateway auth;
late FakeProfileGateway profile;
late FakeEstadoApodoGateway estadoApodo;
late UsernameStorage usernameStorage;
late PlayerRosterStorage roster;

PlayerSessionService _servicio() => PlayerSessionService(
  auth: auth,
  profile: profile,
  estadoApodo: estadoApodo,
  usernameStorage: usernameStorage,
  roster: roster,
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    auth = FakeAuthGateway();
    profile = FakeProfileGateway();
    estadoApodo = FakeEstadoApodoGateway();
    usernameStorage = UsernameStorage();
    roster = PlayerRosterStorage();
  });

  group('entrar con un apodo libre', () {
    setUp(() => estadoApodo.estado = EstadoApodo.libre);

    test('crea el perfil, le pone el apodo y luego la contraseña', () async {
      final resultado = await _servicio().entrar(
        apodo: 'Pablo',
        contrasena: 'secreta123',
      );

      expect(resultado, isA<EntradaCompletada>());
      expect(profile.lastNickname, 'Pablo');
      expect(auth.lastEmail, identidadDeApodo('Pablo'));
      expect(auth.lastPassword, 'secreta123');
    });

    test('pone el apodo ANTES que la contraseña', () async {
      // No es un detalle de estilo: el trigger que hace inmutable el apodo
      // rechaza renombrar a un jugador que ya tiene credenciales, así que en
      // el orden inverso ningún jugador podría registrarse (D6).
      await _servicio().entrar(apodo: 'Pablo', contrasena: 'secreta123');

      expect(
        auth.calls.indexOf('updateUser'),
        greaterThan(auth.calls.indexOf('signInAnonymously')),
      );
    });

    test('crea sesión nueva aunque ya hubiera una', () async {
      // La garantía central del cambio: el perfil que se renombra acaba de
      // nacer, así que no puede ser el de otro jugador.
      auth = FakeAuthGateway()..initialSession = null;
      await auth.signInAnonymously();
      auth.calls.clear();

      await _servicio().entrar(apodo: 'Pablo', contrasena: 'secreta123');

      expect(auth.calls, ['signOut', 'signInAnonymously', 'updateUser']);
    });

    test('guarda el apodo y lo registra en el roster al culminar', () async {
      await _servicio().entrar(apodo: 'Pablo', contrasena: 'secreta123');

      expect(await usernameStorage.read(), 'Pablo');
      expect(await roster.read(), ['Pablo']);
    });

    test(
      'si el apodo se ocupa en la carrera, no deja al jugador dentro',
      () async {
        profile.throwOnNextCall = const AliasEnUsoException();

        final resultado = await _servicio().entrar(
          apodo: 'Pablo',
          contrasena: 'secreta123',
        );

        expect(resultado, isA<ApodoOcupado>());
        expect(auth.updateUserCalls, 0);
        expect(await usernameStorage.read(), isNull);
      },
    );
  });

  group('entrar con un apodo que ya tiene contraseña', () {
    setUp(() => estadoApodo.estado = EstadoApodo.conContrasena);

    test('entra sin renombrar nada', () async {
      final resultado = await _servicio().entrar(
        apodo: 'Pablo',
        contrasena: 'secreta123',
      );

      expect(resultado, isA<EntradaCompletada>());
      expect(auth.signInWithPasswordCalls, 1);
      expect(auth.lastEmail, identidadDeApodo('Pablo'));
      // Lo que garantiza que no se pisa el perfil de otro jugador.
      expect(profile.updateNicknameCalls, 0);
    });

    test('con la contraseña equivocada, ni entra ni toca la sesión', () async {
      auth.throwOnSignInWithPassword = const AuthException(
        'Invalid login credentials',
        statusCode: '400',
        code: 'invalid_credentials',
      );

      final resultado = await _servicio().entrar(
        apodo: 'Pablo',
        contrasena: 'la-que-no-es',
      );

      expect(resultado, isA<ContrasenaIncorrecta>());
      expect(await usernameStorage.read(), isNull);
      expect(await roster.read(), isEmpty);
    });

    test('un fallo de red se distingue de la contraseña incorrecta', () async {
      auth.throwOnSignInWithPassword = const AuthException('sin conexión');

      final resultado = await _servicio().entrar(
        apodo: 'Pablo',
        contrasena: 'secreta123',
      );

      expect(resultado, isA<EntradaFallida>());
    });
  });

  group('entrar con un apodo sin contraseña', () {
    setUp(() => estadoApodo.estado = EstadoApodo.sinContrasena);

    test('si es de otro jugador, se rechaza explicando por qué', () async {
      profile.nicknameActual = 'Otro';

      final resultado = await _servicio().entrar(
        apodo: 'Pablo',
        contrasena: 'secreta123',
      );

      expect(resultado, isA<ApodoDeJugadorSinContrasena>());
      expect(auth.updateUserCalls, 0);
      expect(profile.updateNicknameCalls, 0);
    });

    test(
      'si es el del propio jugador, le pone la contraseña sin crear nada',
      () async {
        // Cubre al invitado que quiere proteger su perfil y también el alta que
        // se quedó a medias tras renombrar pero antes de la contraseña.
        profile.nicknameActual = 'Pablo';

        final resultado = await _servicio().entrar(
          apodo: 'Pablo',
          contrasena: 'secreta123',
        );

        expect(resultado, isA<EntradaCompletada>());
        expect(auth.updateUserCalls, 1);
        expect(auth.signInAnonymouslyCalls, 0);
        expect(profile.updateNicknameCalls, 0);
      },
    );
  });

  group('entrar como invitado', () {
    test('se queda con la primera sugerencia libre', () async {
      final resultado = await _servicio().entrarComoInvitado([
        'GeoLince',
        'TrotaMundos',
      ]);

      expect(resultado, isA<EntradaCompletada>());
      expect(profile.lastNickname, 'GeoLince');
      expect(
        auth.updateUserCalls,
        0,
        reason: 'un invitado no tiene contraseña',
      );
    });

    test('si la sugerencia está ocupada, prueba la siguiente en vez de entrar '
        'en ese perfil', () async {
      profile.throwOnNextCall = const AliasEnUsoException();

      final resultado = await _servicio().entrarComoInvitado([
        'GeoLince',
        'TrotaMundos',
      ]);

      expect(resultado, isA<EntradaCompletada>());
      expect(profile.lastNickname, 'TrotaMundos');
    });
  });

  group('cambiar de jugador', () {
    test('con contraseña, suelta la sesión y olvida el apodo local', () async {
      await usernameStorage.save('Pablo');
      estadoApodo.estado = EstadoApodo.libre;
      await _servicio().entrar(apodo: 'Pablo', contrasena: 'secreta123');

      final resultado = await _servicio().cambiarDeJugador();

      expect(resultado, isA<CambioListo>());
      expect(auth.currentSession, isNull);
      expect(await usernameStorage.read(), isNull);
    });

    test('sin contraseña, no suelta la sesión', () async {
      await auth.signInAnonymously();
      await usernameStorage.save('GeoLince');

      final resultado = await _servicio().cambiarDeJugador();

      expect(resultado, isA<CambioNecesitaContrasena>());
      expect(auth.currentSession, isNotNull);
      expect(await usernameStorage.read(), 'GeoLince');
    });

    test(
      'descartar sí suelta la sesión de un jugador sin contraseña',
      () async {
        await auth.signInAnonymously();
        await usernameStorage.save('GeoLince');

        final resultado = await _servicio().descartarJugador();

        expect(resultado, isA<CambioListo>());
        expect(auth.currentSession, isNull);
        expect(await usernameStorage.read(), isNull);
      },
    );
  });

  test('un fallo al consultar el estado no cambia nada', () async {
    estadoApodo.throwOnNextCall = StateError('sin conexión');

    final resultado = await _servicio().entrar(
      apodo: 'Pablo',
      contrasena: 'secreta123',
    );

    expect(resultado, isA<EntradaFallida>());
    expect(auth.calls, isEmpty);
    expect(profile.updateNicknameCalls, 0);
  });

  group('ramas de fallo', () {
    test('una contraseña débil se distingue del resto de fallos', () async {
      estadoApodo.estado = EstadoApodo.libre;
      auth.throwOnUpdateUser = const AuthException(
        'Password should be at least 6 characters',
        statusCode: '422',
        code: 'weak_password',
      );

      final resultado = await _servicio().entrar(
        apodo: 'Pablo',
        contrasena: '123',
      );

      expect(resultado, isA<ContrasenaDebil>());
    });

    test(
      'si falla al poner la contraseña, el apodo ya puesto se puede rescatar '
      'reintentando',
      () async {
        // El alta se queda a medias: perfil renombrado, sin contraseña. El
        // reintento tiene que reconocerlo como propio y terminar el trabajo,
        // no rechazarlo como apodo ocupado.
        estadoApodo.estado = EstadoApodo.libre;
        auth.throwOnUpdateUser = const AuthException('sin conexión');

        final aMedias = await _servicio().entrar(
          apodo: 'Pablo',
          contrasena: 'secreta123',
        );
        expect(aMedias, isA<EntradaFallida>());
        expect(await usernameStorage.read(), isNull);

        estadoApodo.estado = EstadoApodo.sinContrasena;
        final reintento = await _servicio().entrar(
          apodo: 'Pablo',
          contrasena: 'secreta123',
        );

        expect(reintento, isA<EntradaCompletada>());
        expect(await usernameStorage.read(), 'Pablo');
      },
    );

    test(
      'si no se puede cerrar la sesión, no se olvida el apodo local',
      () async {
        await auth.signInWithPassword(
          email: 'x@geoquest.invalid',
          password: 'y',
        );
        await usernameStorage.save('Pablo');
        auth.throwOnSignOut = const AuthException('sin conexión');

        final resultado = await _servicio().cambiarDeJugador();

        expect(resultado, isA<CambioFallido>());
        expect(await usernameStorage.read(), 'Pablo');
      },
    );

    test('descartar tampoco olvida el apodo si el cierre falla', () async {
      await auth.signInAnonymously();
      await usernameStorage.save('GeoLince');
      auth.throwOnSignOut = const AuthException('sin conexión');

      final resultado = await _servicio().descartarJugador();

      expect(resultado, isA<CambioFallido>());
      expect(await usernameStorage.read(), 'GeoLince');
    });

    test(
      'un invitado sin ninguna sugerencia libre no entra en un perfil ajeno',
      () async {
        profile.throwOnNextCall = const AliasEnUsoException();

        final resultado = await _servicio().entrarComoInvitado(['GeoLince']);

        expect(resultado, isA<ApodoOcupado>());
        expect(await usernameStorage.read(), isNull);
      },
    );

    test('un fallo al guardar el apodo del invitado se reporta', () async {
      profile.throwOnNextCall = Exception('sin conexión');

      final resultado = await _servicio().entrarComoInvitado(['GeoLince']);

      expect(resultado, isA<EntradaFallida>());
    });

    test(
      'si no se puede leer el perfil propio, no se decide a ciegas',
      () async {
        estadoApodo.estado = EstadoApodo.sinContrasena;
        profile.throwOnNextCall = Exception('sin conexión');

        final resultado = await _servicio().entrar(
          apodo: 'Pablo',
          contrasena: 'secreta123',
        );

        expect(resultado, isA<EntradaFallida>());
        expect(auth.updateUserCalls, 0);
      },
    );

    test('si falla el alta anónima, no se toca ningún perfil', () async {
      estadoApodo.estado = EstadoApodo.libre;
      auth.throwOnNextCall = const AuthException('proveedor deshabilitado');

      final resultado = await _servicio().entrar(
        apodo: 'Pablo',
        contrasena: 'secreta123',
      );

      expect(resultado, isA<EntradaFallida>());
      expect(profile.updateNicknameCalls, 0);
    });

    test(
      'un fallo que no es de Auth también se reporta, no revienta',
      () async {
        // Un `Exception` pelado (p. ej. de la capa de red) no es AuthException:
        // sin el catch genérico se escaparía como excepción sin controlar.
        estadoApodo.estado = EstadoApodo.libre;
        auth.throwOnUpdateUser = Exception('socket cerrado');

        final resultado = await _servicio().entrar(
          apodo: 'Pablo',
          contrasena: 'secreta123',
        );

        expect(resultado, isA<EntradaFallida>());
      },
    );

    test('un fallo no-Auth al acceder tampoco revienta', () async {
      estadoApodo.estado = EstadoApodo.conContrasena;
      auth.throwOnSignInWithPassword = Exception('socket cerrado');

      final resultado = await _servicio().entrar(
        apodo: 'Pablo',
        contrasena: 'secreta123',
      );

      expect(resultado, isA<EntradaFallida>());
    });

    test('un fallo no-Auth al renombrar tampoco revienta', () async {
      estadoApodo.estado = EstadoApodo.libre;
      profile.throwOnNextCall = Exception('socket cerrado');

      final resultado = await _servicio().entrar(
        apodo: 'Pablo',
        contrasena: 'secreta123',
      );

      expect(resultado, isA<EntradaFallida>());
    });

    test('si el invitado no consigue sesión, se reporta', () async {
      auth.throwOnNextCall = const AuthException('proveedor deshabilitado');

      final resultado = await _servicio().entrarComoInvitado(['GeoLince']);

      expect(resultado, isA<EntradaFallida>());
      expect(profile.updateNicknameCalls, 0);
    });
  });

  test('el apodo ocupado en la carrera no se confunde con el del invitado sin '
      'contraseña', () async {
    // Son dos situaciones distintas y el jugador necesita saber cuál le pasa:
    // una es "prueba otro apodo", la otra es "ese perfil solo vive en otro
    // móvil".
    estadoApodo.estado = EstadoApodo.libre;
    profile.throwOnNextCall = const AliasEnUsoException();

    final carrera = await _servicio().entrar(
      apodo: 'Pablo',
      contrasena: 'secreta123',
    );

    expect(carrera, isA<ApodoOcupado>());
    expect(carrera, isNot(isA<ApodoDeJugadorSinContrasena>()));
  });
}
