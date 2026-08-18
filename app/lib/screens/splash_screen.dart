import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../services/anonymous_session_service.dart';
import '../services/auth_gateway.dart';
import '../services/camino_gateway.dart';
import '../services/device_id_service.dart';
import '../services/profile_gateway.dart';
import '../services/username_storage.dart';
import 'login_screen.dart';

/// Pantalla de carga inicial (INT-88).
///
/// Crea o recupera la sesión anónima en segundo plano (INT-75) y encamina
/// siempre a la pantalla de entrada (INT-108), que decide internamente si
/// muestra la captura de apodo (primera vez) o la bienvenida de regreso.
/// Sustituye a `ConnectivityScreen`, que era un destino provisional.
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
      backgroundColor: const Color(0xFF0E1620),
      body: FutureBuilder<AnonymousSessionResult>(
        future: _resolution,
        builder: (context, snapshot) {
          final reason = switch (snapshot.data) {
            AnonymousSessionFailure(:final reason) => reason,
            _ => null,
          };
          return _SplashChrome(errorReason: reason, onRetry: _run);
        },
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

  static const _teal = Color(0xFF2BC0A8);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 24),
        child: Column(
          children: [
            const Spacer(flex: 3),
            Container(
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
            ),
            const SizedBox(height: 26),
            Text.rich(
              key: const Key('splash-wordmark'),
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Geo',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 46,
                      color: Colors.white,
                    ),
                  ),
                  TextSpan(
                    text: 'Quest',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 46,
                    ).copyWith(color: _teal),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'RUTAS · PREGUNTAS · PUNTOS',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                letterSpacing: 3,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
            const Spacer(flex: 4),
            if (errorReason != null)
              _ErrorCard(reason: errorReason!, onRetry: onRetry)
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  color: _teal,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error, color: Colors.redAccent, size: 40),
        const SizedBox(height: 12),
        const Text(
          'No se pudo iniciar sesión',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          reason,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
      ],
    );
  }
}
