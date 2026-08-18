import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../services/anonymous_session_service.dart';
import '../services/auth_gateway.dart';
import '../services/camino_gateway.dart';
import '../services/device_id_service.dart';
import '../services/profile_gateway.dart';
import '../services/username_storage.dart';
import 'entry_backdrop.dart';
import 'entry_motion.dart';
import 'login_screen.dart';

/// Pantalla de carga inicial (INT-88).
///
/// Crea o recupera la sesión anónima en segundo plano (INT-75) y encamina
/// siempre a la pantalla de entrada (INT-108), que decide internamente si
/// muestra la captura de apodo (primera vez) o la bienvenida de regreso.
/// Sustituye a `ConnectivityScreen`, que era un destino provisional.
///
/// La presentación reproduce el fondo y las animaciones de entrada del mock
/// `[App] - Splash.dc.html` (dirección "1a", INT-107): antes era una
/// composición estática que ignoraba por completo el mock de referencia.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.config,
    this.sessionService,
    this.usernameStorage,
    this.profileGateway,
    this.caminoGateway,
    this.minDuration = const Duration(milliseconds: 1200),
  });

  final AppConfig config;

  /// Inyectables para poder probar la pantalla sin salir a la red ni al
  /// disco — se reenvían a [LoginScreen] al navegar.
  final AnonymousSessionService? sessionService;
  final UsernameStorage? usernameStorage;
  final ProfileGateway? profileGateway;
  final CaminoGateway? caminoGateway;

  /// Tiempo mínimo que el splash permanece visible, aunque la sesión se
  /// resuelva al instante, para evitar un parpadeo.
  final Duration minDuration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final AnonymousSessionService _sessionService =
      widget.sessionService ??
      AnonymousSessionService(
        SupabaseAuthGateway(Supabase.instance.client.auth),
        DeviceIdService(),
      );

  Future<AnonymousSessionResult>? _resolution;

  @override
  void initState() {
    super.initState();
    _run();
  }

  void _run() {
    final pendiente = _resolveWithMinDuration();
    setState(() {
      _resolution = pendiente;
    });
    pendiente.then((result) {
      if (mounted && result is AnonymousSessionReady) {
        _navigateNext();
      }
    });
  }

  /// Espera la sesión y el tiempo mínimo del splash en paralelo, de modo que
  /// el tiempo total sea el mayor de los dos, no la suma.
  Future<AnonymousSessionResult> _resolveWithMinDuration() async {
    final sessionFuture = _sessionService.ensureSession();
    final tiempoMinimo = Future<void>.delayed(widget.minDuration);
    final result = await sessionFuture;
    await tiempoMinimo;
    return result;
  }

  void _navigateNext() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          usernameStorage: widget.usernameStorage,
          profileGateway: widget.profileGateway,
          caminoGateway: widget.caminoGateway,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: entryBg,
      body: EntryBackdrop(
        child: FutureBuilder<AnonymousSessionResult>(
          future: _resolution,
          builder: (context, snapshot) {
            final reason = switch (snapshot.data) {
              AnonymousSessionFailure(:final reason) => reason,
              _ => null,
            };
            return _SplashChrome(errorReason: reason, onRetry: _run);
          },
        ),
      ),
    );
  }
}

/// Presentación del splash: logo, marca y, según el estado, un indicador de
/// carga o el error con opción de reintentar.
class _SplashChrome extends StatelessWidget {
  const _SplashChrome({this.errorReason, required this.onRetry});

  final String? errorReason;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 24),
        child: Column(
          children: [
            const Spacer(flex: 3),
            HaloPulse(
              color: entryTeal.withValues(alpha: 0.5),
              child: HaloPulse(
                color: entryTeal.withValues(alpha: 0.35),
                delay: const Duration(milliseconds: 900),
                child: const PopIn(child: _Logo()),
              ),
            ),
            const SizedBox(height: 26),
            RiseIn(
              delay: const Duration(milliseconds: 150),
              child: Text.rich(
                key: const Key('splash-wordmark'),
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Geo',
                      style: GoogleFonts.baloo2(
                        fontWeight: FontWeight.w800,
                        fontSize: 46,
                        color: Colors.white,
                      ),
                    ),
                    TextSpan(
                      text: 'Quest',
                      style: GoogleFonts.baloo2(
                        fontWeight: FontWeight.w800,
                        fontSize: 46,
                        color: entryTeal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            RiseIn(
              delay: const Duration(milliseconds: 280),
              child: Text(
                'RUTAS · PREGUNTAS · PUNTOS',
                style: GoogleFonts.outfit(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 3,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
            ),
            const Spacer(flex: 4),
            if (errorReason != null)
              _ErrorCard(reason: errorReason!, onRetry: onRetry)
            else
              RiseIn(
                delay: const Duration(milliseconds: 400),
                child: const Column(
                  children: [_LoadingBar(), SizedBox(height: 16), _TipCard()],
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 118,
      height: 118,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(29),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 40,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(29),
        child: Image.asset(
          'assets/branding/geoquest-logo.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

/// Fila "girando… preparando tu partida" + barra con degradado y brillo en
/// bucle, como `gq-spin`/`gq-shine` del mock. No muestra ningún porcentaje:
/// la resolución de sesión es una única operación sin sub-pasos medibles, y
/// un porcentaje inventado sería el mismo tipo de dato falso que motivó
/// este cambio.
class _LoadingBar extends StatefulWidget {
  const _LoadingBar();

  @override
  State<_LoadingBar> createState() => _LoadingBarState();
}

class _LoadingBarState extends State<_LoadingBar>
    with TickerProviderStateMixin {
  final bool _reduceMotion = reduceMotion;

  late final AnimationController _spinController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  late final AnimationController _shineController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void initState() {
    super.initState();
    if (!_reduceMotion) {
      _spinController.repeat();
      _shineController.repeat();
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    _shineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            SizedBox(
              width: 15,
              height: 15,
              child: _reduceMotion
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: entryTeal, width: 2),
                      ),
                    )
                  : AnimatedBuilder(
                      animation: _spinController,
                      builder: (context, child) => Transform.rotate(
                        angle: _spinController.value * 6.28318,
                        child: child,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 2,
                          ),
                        ),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: entryTeal,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 9),
            Text(
              'Preparando tu partida',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: Container(
            height: 10,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              gradient: const LinearGradient(colors: [entryTeal, entryBlue]),
            ),
            child: _reduceMotion
                ? null
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      return AnimatedBuilder(
                        animation: _shineController,
                        builder: (context, _) {
                          final x =
                              -0.4 * width +
                              _shineController.value * 1.4 * width;
                          return Transform.translate(
                            offset: Offset(x, 0),
                            child: Container(
                              width: width * 0.4,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0),
                                    Colors.white.withValues(alpha: 0.55),
                                    Colors.white.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: entryGold.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '?',
              style: GoogleFonts.baloo2(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: entryGold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Acércate a menos de 30 m de cada parada para desbloquear su '
              'pregunta.',
              style: GoogleFonts.outfit(
                fontSize: 12.5,
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.reason, required this.onRetry});

  final String reason;
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
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error, color: Colors.redAccent, size: 40),
          const SizedBox(height: 12),
          Text(
            'No se pudo iniciar sesión',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            reason,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}
