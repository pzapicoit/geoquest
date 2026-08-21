import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_gateway.dart';
import 'device_id_service.dart';
import 'estado_apodo_gateway.dart';
import 'identidad_de_apodo.dart';
import 'player_roster_storage.dart';
import 'profile_gateway.dart';
import 'username_storage.dart';

/// Resultado de intentar entrar en un perfil (INT-128).
sealed class EntradaResult {
  const EntradaResult();
}

/// El jugador está dentro: la sesión activa es la suya.
class EntradaCompletada extends EntradaResult {
  const EntradaCompletada(this.apodo);
  final String apodo;
}

/// El apodo existe con contraseña y la introducida no es la suya.
class ContrasenaIncorrecta extends EntradaResult {
  const ContrasenaIncorrecta();
}

/// El apodo lo tiene otro jugador. Se usa cuando alguien se lo queda entre la
/// consulta de estado y el alta, y cuando ninguna sugerencia de invitado queda
/// libre.
class ApodoOcupado extends EntradaResult {
  const ApodoOcupado();
}

/// El apodo es de otro jugador que **no tiene contraseña**: no hay credencial
/// que comprobar para entrar, y darlo de alta se lo arrebataría a su dueño, que
/// solo puede alcanzarlo desde el móvil donde lo creó. Se distingue de
/// [ApodoOcupado] porque al jugador hay que explicarle por qué no entra.
class ApodoDeJugadorSinContrasena extends EntradaResult {
  const ApodoDeJugadorSinContrasena();
}

/// La contraseña no cumple lo que exige el proyecto.
class ContrasenaDebil extends EntradaResult {
  const ContrasenaDebil();
}

/// Cualquier otro fallo (conexión, servidor). Reintentable.
class EntradaFallida extends EntradaResult {
  const EntradaFallida(this.motivo);
  final String motivo;
}

/// Resultado de pedir un cambio de jugador.
sealed class CambioJugadorResult {
  const CambioJugadorResult();
}

/// La sesión se soltó: la pantalla de acceso puede pedir el siguiente apodo.
class CambioListo extends CambioJugadorResult {
  const CambioListo();
}

/// El jugador activo no tiene contraseña, así que soltar su sesión equivale a
/// perder su perfil: solo se alcanza desde este dispositivo. Hay que ponerle
/// una contraseña antes, o descartarlo a conciencia.
class CambioNecesitaContrasena extends CambioJugadorResult {
  const CambioNecesitaContrasena();
}

class CambioFallido extends CambioJugadorResult {
  const CambioFallido(this.motivo);
  final String motivo;
}

/// Decide qué significa "entrar" en cada caso: crear un perfil, acceder al
/// propio, convertir a un invitado en jugador con contraseña, o cambiar de
/// jugador (INT-128).
///
/// Es la única pieza con esas decisiones. Las pantallas se limitan a pedir
/// datos y a traducir el resultado a un mensaje.
class PlayerSessionService {
  PlayerSessionService({
    required AuthGateway auth,
    required ProfileGateway profile,
    required EstadoApodoGateway estadoApodo,
    required UsernameStorage usernameStorage,
    required PlayerRosterStorage roster,
    DeviceIdService? deviceId,
  }) : // Los parámetros con nombre no admiten `this._campo` (un nombre de
       // parámetro no puede empezar por guion bajo), así que la asignación
       // explícita es la única forma de tener dependencias con nombre y
       // campos privados a la vez.
       // ignore: prefer_initializing_formals
       _auth = auth,
       // ignore: prefer_initializing_formals
       _profile = profile,
       // ignore: prefer_initializing_formals
       _estadoApodo = estadoApodo,
       // ignore: prefer_initializing_formals
       _usernameStorage = usernameStorage,
       // ignore: prefer_initializing_formals
       _roster = roster,
       _deviceId = deviceId ?? DeviceIdService();

  final AuthGateway _auth;
  final ProfileGateway _profile;
  final EstadoApodoGateway _estadoApodo;
  final UsernameStorage _usernameStorage;
  final PlayerRosterStorage _roster;
  final DeviceIdService _deviceId;

  /// Entra con un apodo y una contraseña, resolviendo con una sola acción del
  /// jugador si toca crear el perfil, acceder a él o rechazar el apodo.
  Future<EntradaResult> entrar({
    required String apodo,
    required String contrasena,
  }) async {
    final limpio = apodo.trim();

    final EstadoApodo estado;
    try {
      estado = await _estadoApodo.consultar(limpio);
    } catch (error) {
      return EntradaFallida('No se pudo comprobar el apodo: $error');
    }

    return switch (estado) {
      EstadoApodo.libre => _crearJugador(limpio, contrasena),
      EstadoApodo.conContrasena => _acceder(limpio, contrasena),
      EstadoApodo.sinContrasena => _resolverApodoSinContrasena(
        limpio,
        contrasena,
      ),
    };
  }

  /// Entra sin contraseña con un apodo sugerido. Nunca entra en un perfil que
  /// ya existe: las sugerencias salen de una lista fija y corta, así que pueden
  /// coincidir con el apodo de otro jugador, y entrar ahí sería apropiarse de
  /// una cuenta ajena sin haberlo pedido. Si la primera sugerencia está
  /// ocupada, prueba las siguientes.
  Future<EntradaResult> entrarComoInvitado(Iterable<String> sugerencias) async {
    try {
      await _sesionRecienCreada();
    } catch (error) {
      return EntradaFallida('No se pudo empezar la partida: $error');
    }

    for (final sugerencia in sugerencias) {
      final apodo = sugerencia.trim();
      try {
        await _profile.updateNickname(apodo);
        await _culminarEntrada(apodo);
        return EntradaCompletada(apodo);
      } on AliasEnUsoException {
        continue;
      } catch (error) {
        return EntradaFallida('No se pudo guardar tu apodo: $error');
      }
    }

    return const ApodoOcupado();
  }

  /// Pone contraseña al jugador activo, que hasta ahora entraba como invitado.
  /// Conserva el mismo usuario y, con él, todo su progreso.
  Future<EntradaResult> ponerContrasena({
    required String apodo,
    required String contrasena,
  }) async {
    final limpio = apodo.trim();
    try {
      await _auth.updateUser(
        email: identidadDeApodo(limpio),
        password: contrasena,
      );
    } on AuthException catch (error) {
      if (_esContrasenaDebil(error)) return const ContrasenaDebil();
      return EntradaFallida(error.message);
    } catch (error) {
      return EntradaFallida('No se pudo guardar la contraseña: $error');
    }

    await _culminarEntrada(limpio);
    return EntradaCompletada(limpio);
  }

  /// Suelta la sesión activa para que entre otro jugador. Se niega a hacerlo
  /// mientras el jugador activo no tenga con qué volver.
  Future<CambioJugadorResult> cambiarDeJugador() async {
    if (!tieneCredenciales) return const CambioNecesitaContrasena();

    try {
      await _auth.signOut();
    } catch (error) {
      return CambioFallido('No se pudo cerrar la sesión: $error');
    }

    await _usernameStorage.clear();
    return const CambioListo();
  }

  /// Suelta la sesión de un jugador sin contraseña, a sabiendas de que su
  /// progreso no se podrá recuperar. Solo debe llamarse tras confirmarlo.
  Future<CambioJugadorResult> descartarJugador() async {
    try {
      await _auth.signOut();
    } catch (error) {
      return CambioFallido('No se pudo cerrar la sesión: $error');
    }

    await _usernameStorage.clear();
    return const CambioListo();
  }

  /// Si el jugador activo tiene con qué volver a entrar desde otro sitio. Un
  /// usuario anónimo no tiene identidad ni contraseña, así que su `email` es
  /// nulo hasta que se convierte (D8).
  bool get tieneCredenciales {
    final email = _auth.currentUser?.email;
    return email != null && email.isNotEmpty;
  }

  Future<EntradaResult> _crearJugador(String apodo, String contrasena) async {
    // Sesión nueva siempre, aunque ya hubiera una. Reutilizar la existente
    // haría que `updateNickname` renombrase el perfil que hubiera detrás — que
    // es exactamente el fallo que este cambio viene a arreglar. Así el perfil
    // que se renombra acaba de nacer y no puede ser el de nadie.
    try {
      await _sesionRecienCreada();
    } catch (error) {
      return EntradaFallida('No se pudo crear tu perfil: $error');
    }

    try {
      await _profile.updateNickname(apodo);
    } on AliasEnUsoException {
      // Carrera: entre la consulta de estado y este momento, alguien se quedó
      // con el apodo.
      return const ApodoOcupado();
    } catch (error) {
      return EntradaFallida('No se pudo guardar tu apodo: $error');
    }

    // Si esto falla, el jugador se queda como invitado con su apodo ya puesto;
    // volver a intentarlo con el mismo apodo entra por
    // `_resolverApodoSinContrasena`, que reconoce que el perfil es suyo y le
    // pone la contraseña sin crear nada nuevo.
    return ponerContrasena(apodo: apodo, contrasena: contrasena);
  }

  Future<EntradaResult> _acceder(String apodo, String contrasena) async {
    try {
      await _auth.signInWithPassword(
        email: identidadDeApodo(apodo),
        password: contrasena,
      );
    } on AuthException catch (error) {
      if (_esCredencialInvalida(error)) return const ContrasenaIncorrecta();
      return EntradaFallida(error.message);
    } catch (error) {
      return EntradaFallida('No se pudo entrar: $error');
    }

    await _culminarEntrada(apodo);
    return EntradaCompletada(apodo);
  }

  /// Un apodo sin contraseña puede ser de otro jugador —y entonces está
  /// ocupado— o **del propio jugador activo**, que entró como invitado o cuyo
  /// alta se quedó a medias. En ese segundo caso lo que pide es ponerle
  /// contraseña, no rechazarlo.
  Future<EntradaResult> _resolverApodoSinContrasena(
    String apodo,
    String contrasena,
  ) async {
    final String? mio;
    try {
      mio = await _profile.currentNickname();
    } catch (error) {
      return EntradaFallida('No se pudo comprobar tu perfil: $error');
    }

    if (mio != null && mio.trim().toLowerCase() == apodo.toLowerCase()) {
      return ponerContrasena(apodo: apodo, contrasena: contrasena);
    }

    return const ApodoDeJugadorSinContrasena();
  }

  Future<void> _sesionRecienCreada() async {
    await _auth.signOut();
    await _auth.signInAnonymously(
      data: {'device_id': await _deviceId.getOrCreate()},
    );
  }

  Future<void> _culminarEntrada(String apodo) async {
    await _usernameStorage.save(apodo);
    await _roster.registrar(apodo);
  }

  bool _esCredencialInvalida(AuthException error) =>
      error.code == 'invalid_credentials' ||
      error.message.toLowerCase().contains('invalid login credentials');

  bool _esContrasenaDebil(AuthException error) =>
      error.code == 'weak_password' ||
      // Respaldo por si el codigo no viene, acotado a la frase concreta: un
      // `contains('password')` a secas clasificaria como contraseña debil
      // cualquier fallo que mencione la palabra.
      error.message.toLowerCase().contains('password should be');
}
