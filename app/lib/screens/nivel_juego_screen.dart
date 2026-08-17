import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

import '../services/nivel_juego_gateway.dart';

const _ink = Color(0xFF0E1620);
const _cardBg = Color(0xFF16242F);
const _teal = Color(0xFF2BC0A8);
const _gold = Color(0xFFFFC53D);

/// Fase 1 ("pista") de la pantalla de juego (INT-91): arranca un intento
/// real vía `iniciar_intento_nivel` y muestra su primer desafío en un
/// toast. Cerrar el toast revela el estado de mapa a pantalla completa,
/// que queda como stub hasta que INT-92 lo implemente (ver D1 de
/// `design.md` de `openspec/changes/int-91-pista-toast`).
class NivelJuegoScreen extends StatefulWidget {
  const NivelJuegoScreen({super.key, required this.nivelId, this.gateway});

  final String nivelId;

  /// Inyectable para poder probar la pantalla sin salir a la red.
  final NivelJuegoGateway? gateway;

  @override
  State<NivelJuegoScreen> createState() => _NivelJuegoScreenState();
}

class _NivelJuegoScreenState extends State<NivelJuegoScreen> {
  late final NivelJuegoGateway _gateway =
      widget.gateway ?? SupabaseNivelJuegoGateway(Supabase.instance.client);

  late Future<IntentoNivel> _futuro;

  /// Posición dentro del intento (D4 de `design.md`): arranca en 0 y, tal
  /// cual queda esta pantalla tras INT-91, nunca avanza — eso ocurrirá al
  /// resolver en el mapa (INT-92).
  final int _indice = 0;
  bool _pistaVisible = true;

  @override
  void initState() {
    super.initState();
    _futuro = _gateway.iniciarIntento(widget.nivelId);
  }

  void _cerrarPista() => setState(() => _pistaVisible = false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ink,
      body: SafeArea(
        child: FutureBuilder<IntentoNivel>(
          future: _futuro,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: _teal),
              );
            }
            void reintentar() => setState(() {
              _futuro = _gateway.iniciarIntento(widget.nivelId);
            });

            if (snapshot.hasError) {
              return _ErrorIntento(onRetry: reintentar);
            }

            final desafios = snapshot.data!.desafios;
            if (desafios.isEmpty) {
              return _ErrorIntento(
                mensaje: 'Este nivel todavía no tiene desafíos disponibles',
                onRetry: reintentar,
              );
            }
            final desafioActual = desafios[_indice];

            return Stack(
              children: [
                const Positioned.fill(child: _MapaStub()),
                if (_pistaVisible)
                  Positioned.fill(
                    child: _ToastPista(
                      desafio: desafioActual,
                      posicion: _indice + 1,
                      total: desafios.length,
                      onListo: _cerrarPista,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ErrorIntento extends StatelessWidget {
  const _ErrorIntento({
    required this.onRetry,
    this.mensaje = 'No se pudo arrancar la partida',
  });

  final VoidCallback onRetry;
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
            const SizedBox(height: 12),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

/// Estado de mapa a pantalla completa tras cerrar el toast. Sustituye al
/// antiguo `NivelJuegoPlaceholderScreen`: sigue siendo un stub visual hasta
/// que INT-92 implemente el mapa real.
class _MapaStub extends StatelessWidget {
  const _MapaStub();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _ink,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.map_outlined, color: _teal, size: 48),
              const SizedBox(height: 16),
              Text(
                'Mapa pendiente (INT-92)',
                key: const Key('nivel-juego-mapa-stub'),
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToastPista extends StatelessWidget {
  const _ToastPista({
    required this.desafio,
    required this.posicion,
    required this.total,
    required this.onListo,
  });

  final DesafioJuego desafio;
  final int posicion;
  final int total;
  final VoidCallback onListo;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.55),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CabeceraJuego(posicion: posicion, total: total),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ContenidoPista(desafio: desafio),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const Key('nivel-juego-boton-listo'),
                        onPressed: onListo,
                        style: FilledButton.styleFrom(
                          backgroundColor: _teal,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Listo, voy a adivinar',
                          style: GoogleFonts.baloo2(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CabeceraJuego extends StatelessWidget {
  const _CabeceraJuego({required this.posicion, required this.total});

  final int posicion;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Desafío $posicion de $total',
          key: const Key('nivel-juego-progreso'),
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.16),
            border: Border.all(
              color: _gold.withValues(alpha: 0.45),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '★',
                style: TextStyle(
                  color: _gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                // D3 de `design.md`: un intento recién creado no tiene
                // respuestas todavía, así que el puntaje siempre es 0
                // mientras no exista la resolución de desafíos (INT-92).
                '0',
                key: const Key('nivel-juego-puntaje'),
                style: GoogleFonts.baloo2(
                  color: const Color(0xFFFFE9A8),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContenidoPista extends StatelessWidget {
  const _ContenidoPista({required this.desafio});

  final DesafioJuego desafio;

  @override
  Widget build(BuildContext context) {
    return switch (desafio.tipo) {
      TipoDesafio.imagen => _PistaImagen(url: desafio.imagenUrl!),
      TipoDesafio.video => _PistaVideo(url: desafio.videoUrl!),
      TipoDesafio.preguntaTexto => _PistaTexto(texto: desafio.textoPregunta!),
    };
  }
}

class _PistaImagen extends StatelessWidget {
  const _PistaImagen({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Image.network(
          url,
          key: const Key('nivel-juego-imagen'),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black26),
        ),
      ),
    );
  }
}

class _PistaTexto extends StatelessWidget {
  const _PistaTexto({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        texto,
        key: const Key('nivel-juego-texto-pregunta'),
        textAlign: TextAlign.center,
        style: GoogleFonts.baloo2(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Vídeo de pista en autoplay, en bucle y sin sonido (D5 de
/// `design.md`): son clips ambientales de un lugar, no llevan audio
/// relevante para adivinar.
class _PistaVideo extends StatefulWidget {
  const _PistaVideo({required this.url});

  final String url;

  @override
  State<_PistaVideo> createState() => _PistaVideoState();
}

class _PistaVideoState extends State<_PistaVideo> {
  late final VideoPlayerController _controller;
  late final Future<bool> _inicializacion;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _inicializacion = _controller
        .initialize()
        .then((_) {
          _controller
            ..setVolume(0)
            ..setLooping(true)
            ..play();
          return true;
        })
        // Una URL de vídeo rota, o la ausencia del plugin de plataforma en
        // tests, no debe tumbar la pantalla: se resuelve a `false` y el
        // `builder` muestra un aviso en vez de un `VideoPlayer` sin
        // inicializar (que quedaría en negro sin explicación).
        .catchError((_) => false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: FutureBuilder<bool>(
          key: const Key('nivel-juego-video'),
          future: _inicializacion,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const ColoredBox(
                color: Colors.black26,
                child: Center(child: CircularProgressIndicator(color: _teal)),
              );
            }
            if (snapshot.data != true) {
              return const ColoredBox(
                key: Key('nivel-juego-video-error'),
                color: Colors.black26,
                child: Center(
                  child: Icon(
                    Icons.videocam_off_outlined,
                    color: Colors.white38,
                    size: 32,
                  ),
                ),
              );
            }
            return VideoPlayer(_controller);
          },
        ),
      ),
    );
  }
}
