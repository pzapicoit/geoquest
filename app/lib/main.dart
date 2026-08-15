import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'services/anonymous_session_service.dart';
import 'services/auth_gateway.dart';
import 'services/connectivity_check.dart';
import 'services/device_id_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // La configuración se valida antes de inicializar nada. Si falta una
  // variable, MissingConfigError sale por aquí nombrándola, en lugar de dejar
  // la app arrancada contra un proyecto inexistente.
  final config = AppConfig.fromEnvironment();

  await Supabase.initialize(
    url: config.supabaseUrl,
    publishableKey: config.supabasePublishableKey,
  );

  runApp(GeoQuestApp(config: config));
}

class GeoQuestApp extends StatelessWidget {
  const GeoQuestApp({super.key, required this.config});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeoQuest',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B6B4C)),
      ),
      home: SessionGate(config: config),
    );
  }
}

/// Garantiza una sesión (anónima o vinculada) antes de mostrar la home
/// (INT-75). Reutiliza el patrón de `ConnectivityScreen`: `FutureBuilder` +
/// `_Status` para progreso/éxito/error con reintento.
class SessionGate extends StatefulWidget {
  const SessionGate({super.key, required this.config, this.sessionService});

  final AppConfig config;

  /// Inyectable para poder probar la pantalla sin salir a la red.
  final AnonymousSessionService? sessionService;

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  late final AnonymousSessionService _service =
      widget.sessionService ??
      AnonymousSessionService(
        SupabaseAuthGateway(Supabase.instance.client.auth),
        DeviceIdService(),
      );
  Future<AnonymousSessionResult>? _session;

  @override
  void initState() {
    super.initState();
    _run();
  }

  void _run() {
    final pendiente = _service.ensureSession();
    setState(() {
      _session = pendiente;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: FutureBuilder<AnonymousSessionResult>(
            future: _session,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const CircularProgressIndicator();
              }
              return switch (snapshot.data) {
                AnonymousSessionReady() => ConnectivityScreen(
                  config: widget.config,
                ),
                AnonymousSessionFailure(:final reason) => _Status(
                  icon: Icons.error,
                  color: Colors.red,
                  title: 'No se pudo iniciar sesión',
                  detail: reason,
                  onRetry: _run,
                ),
                null => _Status(
                  icon: Icons.help,
                  color: Colors.orange,
                  title: 'Sin resultado',
                  detail: '${snapshot.error}',
                  onRetry: _run,
                ),
              };
            },
          ),
        ),
      ),
    );
  }
}

/// Pantalla de verificación del entorno (INT-73).
///
/// Provisional: existe para comprobar que la app alcanza Supabase antes de que
/// haya esquema. La sustituye el splash real en INT-88.
class ConnectivityScreen extends StatefulWidget {
  const ConnectivityScreen({super.key, required this.config, this.check});

  final AppConfig config;

  /// Inyectable para poder probar la pantalla sin salir a la red.
  final ConnectivityCheck? check;

  @override
  State<ConnectivityScreen> createState() => _ConnectivityScreenState();
}

class _ConnectivityScreenState extends State<ConnectivityScreen> {
  late final ConnectivityCheck _checker =
      widget.check ?? ConnectivityCheck(widget.config);
  Future<ConnectivityResult>? _check;

  @override
  void initState() {
    super.initState();
    _run();
  }

  void _run() {
    // Cuerpo de bloque, no flecha: `setState(() => x = future)` devuelve el
    // Future y Flutter lo rechaza con un assert.
    final pendiente = _checker.run();
    setState(() {
      _check = pendiente;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GeoQuest — entorno')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: FutureBuilder<ConnectivityResult>(
            future: _check,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const CircularProgressIndicator();
              }
              return switch (snapshot.data) {
                ConnectivityOk(:final latency) => _Status(
                  icon: Icons.check_circle,
                  color: Colors.green,
                  title: 'Conectado a Supabase',
                  detail:
                      '${widget.config.supabaseUrl}\n'
                      'Auth respondió en ${latency.inMilliseconds} ms',
                  onRetry: _run,
                ),
                ConnectivityFailure(:final reason) => _Status(
                  icon: Icons.error,
                  color: Colors.red,
                  title: 'Sin conexión con Supabase',
                  detail: reason,
                  onRetry: _run,
                ),
                null => _Status(
                  icon: Icons.help,
                  color: Colors.orange,
                  title: 'Sin resultado',
                  detail: '${snapshot.error}',
                  onRetry: _run,
                ),
              };
            },
          ),
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
    required this.onRetry,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 64, color: color),
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text(detail, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
      ],
    );
  }
}
