import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_gateway.dart';
import '../services/camino_gateway.dart';
import '../services/estado_apodo_gateway.dart';
import '../services/player_roster_storage.dart';
import '../services/player_session_service.dart';
import '../services/profile_gateway.dart';
import '../services/username_storage.dart';
import 'camino_screen.dart';
import 'entry_backdrop.dart';
import 'entry_motion.dart';
import 'entry_widgets.dart';
import 'username_screen.dart';

/// Pantalla de entrada (INT-108): decide entre el estado "primera vez"
/// ([UsernameScreen]) y el estado "regreso" ([_ReturningWelcome]) según si
/// el dispositivo ya tiene un apodo guardado. Sustituye al salto directo
/// que hacía el splash (INT-88) a `CaminoScreen` cuando ya había apodo.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.usernameStorage,
    this.profileGateway,
    this.caminoGateway,
    this.sessionService,
    this.rosterStorage,
  });

  /// Inyectables para poder probar la pantalla sin salir a la red ni al disco.
  final UsernameStorage? usernameStorage;
  final ProfileGateway? profileGateway;
  final CaminoGateway? caminoGateway;
  final PlayerSessionService? sessionService;
  final PlayerRosterStorage? rosterStorage;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final UsernameStorage _usernameStorage =
      widget.usernameStorage ?? UsernameStorage();
  // `late` para no tocar `Supabase.instance` (y así no exigir que esté
  // inicializado) salvo que de verdad se llegue al estado "regreso".
  late final CaminoGateway _caminoGateway =
      widget.caminoGateway ?? SupabaseCaminoGateway(Supabase.instance.client);

  late final PlayerRosterStorage _rosterStorage =
      widget.rosterStorage ?? PlayerRosterStorage();
  late final PlayerSessionService _sessionService =
      widget.sessionService ?? _defaultSessionService();

  late Future<String?> _savedNameFuture = _usernameStorage.read();

  PlayerSessionService _defaultSessionService() {
    final client = Supabase.instance.client;
    return PlayerSessionService(
      auth: SupabaseAuthGateway(client.auth),
      profile: widget.profileGateway ?? SupabaseProfileGateway(client),
      estadoApodo: SupabaseEstadoApodoGateway(client),
      usernameStorage: _usernameStorage,
      roster: _rosterStorage,
    );
  }

  /// "Cambiar de jugador": suelta la sesión del jugador activo y vuelve al
  /// estado "primera vez" sin pasar de nuevo por el splash.
  ///
  /// Soltar la sesión es lo que hace que el apodo que se introduzca después
  /// entre en su propio perfil en vez de renombrar el del jugador anterior
  /// (INT-128) — antes solo se borraba el apodo local y por eso "cambiar de
  /// jugador" acababa renombrando.
  Future<void> _onSwitchPlayer() async {
    final resultado = await _sessionService.cambiarDeJugador();
    if (!mounted) return;

    switch (resultado) {
      case CambioListo():
        setState(() {
          _savedNameFuture = Future.value(null);
        });
      case CambioNecesitaContrasena():
        // Este perfil solo existe en este móvil: soltarlo sin contraseña lo
        // pierde para siempre. Se pide una antes de dejar sitio a otro.
        await _pedirContrasenaAntesDeCambiar();
      case CambioFallido(:final motivo):
        _avisar(motivo);
    }
  }

  Future<void> _pedirContrasenaAntesDeCambiar() async {
    final savedName = await _savedNameFuture;
    if (!mounted || savedName == null) return;

    final decision = await showDialog<_DecisionSinContrasena>(
      context: context,
      builder: (_) => _ProtegerAntesDeCambiarDialog(apodo: savedName),
    );
    if (!mounted || decision == null) return;

    switch (decision) {
      case _PonerContrasena(:final contrasena):
        final resultado = await _sessionService.ponerContrasena(
          apodo: savedName,
          contrasena: contrasena,
        );
        if (!mounted) return;
        if (resultado is EntradaCompletada) {
          await _onSwitchPlayer();
        } else {
          _avisar('No se pudo guardar la contraseña. Inténtalo de nuevo.');
        }
      case _Descartar():
        final resultado = await _sessionService.descartarJugador();
        if (!mounted) return;
        if (resultado is CambioListo) {
          setState(() {
            _savedNameFuture = Future.value(null);
          });
        }
    }
  }

  void _avisar(String mensaje) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: entryBg,
      body: FutureBuilder<String?>(
        future: _savedNameFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox.shrink();
          }
          final savedName = snapshot.data;
          if (savedName == null) {
            // Se reenvía `widget.profileGateway` tal cual (no un valor ya
            // resuelto): así, si es null, `UsernameScreen` solo construye su
            // `SupabaseProfileGateway` por defecto al guardar el apodo, no
            // al renderizar — igual que antes de existir `LoginScreen`.
            return UsernameScreen(
              key: const ValueKey('first-time'),
              usernameStorage: _usernameStorage,
              profileGateway: widget.profileGateway,
              sessionService: widget.sessionService,
              rosterStorage: widget.rosterStorage,
            );
          }
          return _ReturningWelcome(
            // La clave incluye el apodo para que, al cambiar de jugador, el
            // estado (y con él el `Future` del progreso) se reconstruya en vez
            // de reutilizar los datos del jugador anterior.
            key: ValueKey('returning-$savedName'),
            savedName: savedName,
            caminoGateway: _caminoGateway,
            onSwitchPlayer: _onSwitchPlayer,
            tieneContrasena: _sessionService.tieneCredenciales,
            onProtegerProgreso: _pedirContrasenaAntesDeCambiar,
          );
        },
      ),
    );
  }
}

/// Estado "regreso" (12b del mock): saludo al jugador reconocido, resumen
/// de progreso con datos reales de [CaminoGateway], y las acciones
/// "Seguir jugando" / "Cambiar de jugador".
class _ReturningWelcome extends StatefulWidget {
  const _ReturningWelcome({
    super.key,
    required this.savedName,
    required this.caminoGateway,
    required this.onSwitchPlayer,
    required this.tieneContrasena,
    required this.onProtegerProgreso,
  });

  final String savedName;
  final CaminoGateway caminoGateway;
  final Future<void> Function() onSwitchPlayer;

  /// Si el jugador activo tiene con qué volver a entrar desde otro móvil.
  /// Decide si el enlace de abajo ofrece algo real o sigue siendo el hueco
  /// preparado para la vinculación de cuenta.
  final bool tieneContrasena;
  final Future<void> Function() onProtegerProgreso;

  @override
  State<_ReturningWelcome> createState() => _ReturningWelcomeState();
}

class _ReturningWelcomeState extends State<_ReturningWelcome> {
  late Future<CaminoJugador> _camino = widget.caminoGateway.fetchCamino();

  void _reloadCamino() {
    setState(() {
      _camino = widget.caminoGateway.fetchCamino();
    });
  }

  void _onContinue() {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const CaminoScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return EntryBackdrop(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 26),
          child: Column(
            children: [
              PopIn(
                duration: const Duration(milliseconds: 800),
                child: Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(17),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF040C12).withValues(alpha: 0.6),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(17),
                    child: Image.asset(
                      'assets/branding/geoquest-logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 11),
              RiseIn(
                delay: const Duration(milliseconds: 100),
                child: Text(
                  'GeoQuest',
                  style: GoogleFonts.baloo2(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    letterSpacing: -0.2,
                    color: Colors.white.withValues(alpha: 0.9),
                    shadows: const [
                      Shadow(color: Color(0x99040C12), offset: Offset(0, 2)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              RiseIn(
                delay: const Duration(milliseconds: 180),
                child: Column(
                  children: [
                    Text(
                      'BIENVENIDO DE VUELTA',
                      style: GoogleFonts.outfit(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                        color: entryTeal.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      '¡Hola, ${widget.savedName}!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.baloo2(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        shadows: const [
                          Shadow(
                            color: Color(0xB2040C12),
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              RiseIn(
                delay: const Duration(milliseconds: 260),
                child: FutureBuilder<CaminoJugador>(
                  future: _camino,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _ProgressCardError(onRetry: _reloadCamino);
                    }
                    if (!snapshot.hasData) {
                      return const _ProgressCardSkeleton();
                    }
                    return _ProgressCard(
                      savedName: widget.savedName,
                      camino: snapshot.data!,
                    );
                  },
                ),
              ),
              const SizedBox(height: 22),
              RiseIn(
                delay: const Duration(milliseconds: 340),
                child: Column(
                  children: [
                    PrimaryPillButton(
                      key: const Key('continue-button'),
                      label: 'Seguir jugando',
                      onPressed: _onContinue,
                    ),
                    const SizedBox(height: 12),
                    OutlinePillButton(
                      key: const Key('switch-player-button'),
                      label: 'Cambiar de jugador',
                      onPressed: () => widget.onSwitchPlayer(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              RiseIn(
                delay: const Duration(milliseconds: 420),
                child: widget.tieneContrasena
                    ? const GhostLink(
                        key: Key('link-account'),
                        label: 'Vincular una cuenta para no perder el progreso',
                      )
                    : GhostLink(
                        // El propio GhostLink trae `onTap`; envolverlo en otro
                        // GestureDetector no funciona, porque el suyo consume
                        // el toque aunque no se le pase nada.
                        key: const Key('protect-progress'),
                        label:
                            'Ponle una contraseña para no perder tu progreso',
                        onTap: () => widget.onProtegerProgreso(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.savedName, required this.camino});

  final String savedName;
  final CaminoJugador camino;

  @override
  Widget build(BuildContext context) {
    final nivelesSuperados = camino.entradas.where((e) => e.superado).length;
    final estrellas = camino.entradas.fold<int>(
      0,
      (total, e) => total + e.estrellasObtenidas,
    );

    ParadaCamino? siguienteBloqueado;
    for (final entrada in camino.entradas) {
      if (!entrada.desbloqueado) {
        siguienteBloqueado = entrada;
        break;
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: entryCard,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: entryTeal.withValues(alpha: 0.4), width: 2.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0C584C).withValues(alpha: 0.6),
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              HaloPulse(
                color: entryTeal.withValues(alpha: 0.45),
                inset: -6,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [entryTeal, entryBlue],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 2.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initialOf(savedName),
                    style: GoogleFonts.baloo2(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF04202A),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  savedName,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.baloo2(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  value: '${camino.puntosTotales}',
                  label: 'PUNTOS',
                  color: const Color(0xFFFFD98A),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _StatTile(
                  value: '$nivelesSuperados',
                  label: 'NIVELES',
                  color: const Color(0xFF8FE7D6),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _StatTile(
                  value: '$estrellas',
                  label: 'ESTRELLAS',
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (siguienteBloqueado != null)
            _NextLevelProgress(parada: siguienteBloqueado)
          else
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Has desbloqueado todos los niveles disponibles',
                style: GoogleFonts.outfit(
                  fontSize: 11.5,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NextLevelProgress extends StatelessWidget {
  const _NextLevelProgress({required this.parada});

  final ParadaCamino parada;

  @override
  Widget build(BuildContext context) {
    final requeridas = parada.estrellasRequeridas;
    final progreso = requeridas <= 0
        ? 1.0
        : clampProgress(parada.estrellasAcumuladasUsuario / requeridas);
    final nombreNivel = parada.nivelNombre ?? parada.tematicaNombre;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Siguiente: $nombreNivel · ${parada.tematicaNombre}',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ),
            Text(
              '${parada.estrellasAcumuladasUsuario}/$requeridas ★',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFFFD98A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: progreso,
            minHeight: 9,
            backgroundColor: Colors.white.withValues(alpha: 0.09),
            color: entryTeal,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.baloo2(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
              color: Colors.white.withValues(alpha: 0.42),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressCardSkeleton extends StatelessWidget {
  const _ProgressCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 176,
      decoration: BoxDecoration(
        color: entryCard,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 26,
        height: 26,
        child: CircularProgressIndicator(strokeWidth: 2.4, color: entryTeal),
      ),
    );
  }
}

/// Se muestra si falla la carga del progreso (p. ej. sin conectividad) —
/// evita que la tarjeta quede en el spinner de carga indefinidamente.
class _ProgressCardError extends StatelessWidget {
  const _ProgressCardError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
      decoration: BoxDecoration(
        color: entryCard,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Text(
            'No se pudo cargar tu progreso',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            key: const Key('retry-progress'),
            onTap: onRetry,
            child: Text(
              'Reintentar',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: entryTeal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Qué decide el jugador cuando quiere cambiar de jugador desde un perfil sin
/// contraseña (INT-128, D7): ese perfil solo es alcanzable desde este móvil,
/// así que soltarlo sin más lo pierde para siempre.
sealed class _DecisionSinContrasena {
  const _DecisionSinContrasena();
}

class _PonerContrasena extends _DecisionSinContrasena {
  const _PonerContrasena(this.contrasena);
  final String contrasena;
}

class _Descartar extends _DecisionSinContrasena {
  const _Descartar();
}

/// Pide una contraseña para poder volver a este perfil, y ofrece descartarlo
/// como una decisión explícita en vez de como un efecto secundario.
class _ProtegerAntesDeCambiarDialog extends StatefulWidget {
  const _ProtegerAntesDeCambiarDialog({required this.apodo});

  final String apodo;

  @override
  State<_ProtegerAntesDeCambiarDialog> createState() =>
      _ProtegerAntesDeCambiarDialogState();
}

class _ProtegerAntesDeCambiarDialogState
    extends State<_ProtegerAntesDeCambiarDialog> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _valida =>
      _controller.text.length >= UsernameScreen.minPasswordLength;

  Future<void> _confirmarDescarte() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: entryCard,
        title: Text(
          '¿Descartar a ${widget.apodo}?',
          style: GoogleFonts.baloo2(color: Colors.white),
        ),
        content: Text(
          'Sin contraseña, este jugador solo existe en este móvil. Si lo '
          'descartas, su progreso no se podrá recuperar.',
          style: GoogleFonts.outfit(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            key: const Key('confirm-discard'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );

    if (!mounted || confirmado != true) return;
    Navigator.of(context).pop(const _Descartar());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: entryCard,
      title: Text(
        'Ponle una contraseña a ${widget.apodo}',
        style: GoogleFonts.baloo2(color: Colors.white, fontSize: 20),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Este jugador todavía no tiene contraseña, así que solo existe en '
            'este móvil. Con una podrás volver a entrar cuando quieras.',
            style: GoogleFonts.outfit(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('protect-password-field'),
            controller: _controller,
            obscureText: true,
            autofocus: true,
            style: GoogleFonts.outfit(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Contraseña',
              hintStyle: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('discard-player'),
          onPressed: _confirmarDescarte,
          child: const Text('Descartar este jugador'),
        ),
        TextButton(
          key: const Key('save-password'),
          onPressed: _valida
              ? () =>
                    Navigator.of(context)
                        .pop(_PonerContrasena(_controller.text))
              : null,
          child: const Text('Guardar y cambiar'),
        ),
      ],
    );
  }
}
