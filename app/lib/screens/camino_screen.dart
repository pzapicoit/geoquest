import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../route_observer.dart';
import '../services/camino_gateway.dart';
import '../services/nivel_juego_gateway.dart';
import '../services/username_storage.dart';
import 'nivel_juego_screen.dart';

const _bgTop = Color(0xFF102A38);
const _bgMid = Color(0xFF0B1B27);
const _bgBottom = Color(0xFF08131C);
const _teal = Color(0xFF2BC0A8);
const _blue = Color(0xFF1B6FA8);
const _gold = Color(0xFFFFC53D);

// Altura de tarjeta igual a `ROW_H` del mock de referencia
// (`[App] - Camino vertical.dc.html`), para respetar sus proporciones.
const _paradaAltura = 208.0;
const _espacioEntre = 16.0;
const _paradaSlot = _paradaAltura + _espacioEntre;

/// Alto reservado para la barra superior y para el botón fijo de jugar
/// (delta-1): el padding del `ListView` siempre reserva al menos esto,
/// para que ninguna parada quede tapada por ellos. `_ctaAltura` ya
/// incluye un pequeño margen entre la última tarjeta y el botón.
const _topBarAltura = 140.0;
const _ctaAltura = 138.0;

/// Ancho de la columna del indicador de cada parada (círculo + estrellas
/// requeridas), usado también para centrar el riel de progreso (INT-105).
const _columnaIndicador = 52.0;
const _railAncho = 6.0;
const _railX = 18 + _columnaIndicador / 2 - _railAncho / 2;

/// Distancia (en px) sobre la que se desvanece/encoge una parada al
/// acercarse a la cabecera o al botón de jugar durante el scroll (D5 de
/// `design.md` de INT-105) — replica la curva del mock, atada a la altura
/// real de una fila en vez de un píxel fijo del mock.
const _animRamp = _paradaSlot;

/// Colores de acento que rotan por `tematicaId`, para variar sutilmente la
/// ambientación entre temáticas sin depender de un asset nuevo (D6 de
/// `design.md`).
const _acentos = [
  _teal,
  Color(0xFFE0A24F),
  Color(0xFFE0715B),
  Color(0xFF8E7CE8),
  Color(0xFF4FB0E0),
];

Color _colorAcento(String tematicaId) =>
    _acentos[tematicaId.hashCode.abs() % _acentos.length];

const _identity = <double>[
  1, 0, 0, 0, 0, //
  0, 1, 0, 0, 0, //
  0, 0, 1, 0, 0, //
  0, 0, 0, 1, 0, //
];

const _grayscale = <double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
];

String _formatMiles(int n) {
  final texto = n.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < texto.length; i++) {
    if (i > 0 && (texto.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(texto[i]);
  }
  return buffer.toString();
}

/// Home del jugador (INT-90): camino vertical con todos los niveles como
/// paradas, agrupadas visualmente por temática. Reproduce
/// `[App] - Camino vertical.dc.html` (Claude Design) como especificación
/// visual/de interacción — ver `design.md` de
/// `openspec/changes/int-90-camino-niveles-home` para las decisiones que se
/// apartan del mock (frontera, arte por temática, puntos totales).
class CaminoScreen extends StatefulWidget {
  const CaminoScreen({
    super.key,
    this.caminoGateway,
    this.usernameStorage,
    this.nivelJuegoGateway,
  });

  /// Inyectables para poder probar la pantalla sin salir a la red ni al
  /// disco. `nivelJuegoGateway` se reenvía a `NivelJuegoScreen` al navegar
  /// a ella (INT-91).
  final CaminoGateway? caminoGateway;
  final UsernameStorage? usernameStorage;
  final NivelJuegoGateway? nivelJuegoGateway;

  @override
  State<CaminoScreen> createState() => _CaminoScreenState();
}

class _CaminoScreenState extends State<CaminoScreen> with RouteAware {
  late final CaminoGateway _caminoGateway =
      widget.caminoGateway ?? SupabaseCaminoGateway(Supabase.instance.client);
  late final UsernameStorage _usernameStorage =
      widget.usernameStorage ?? UsernameStorage();

  final _controller = ScrollController();

  late Future<CaminoJugador> _futuro;
  String _nickname = 'Explorador';
  bool _autoScrolled = false;
  bool _mostrarBotonMiNivel = false;
  double _offsetObjetivo = 0;

  @override
  void initState() {
    super.initState();
    _futuro = _cargar();
    _controller.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // `didChangeDependencies` puede llamarse más de una vez (p. ej. si
    // cambia un `InheritedWidget` del que depende `build`, como
    // `MediaQuery`); desuscribirse antes de cada suscripción evita
    // depender de que `RouteObserver` deduplique por identidad.
    routeObserver.unsubscribe(this);
    routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  /// El camino puede haber cambiado (estrellas, desbloqueos) al volver de
  /// jugar, con o sin terminar el nivel (D6 de `design.md` de INT-94) — se
  /// recarga siempre, sin distinguir casos. Se dispara cuando esta pantalla
  /// vuelve a ser la visible, sea cual sea la cadena de `push`/
  /// `pushReplacement` que haya habido por encima (p. ej. "Reintentar" desde
  /// el resumen), no solo al volver de la primera pantalla empujada.
  @override
  void didPopNext() {
    setState(() {
      _futuro = _cargar();
    });
  }

  Future<CaminoJugador> _cargar() async {
    final nombre = await _usernameStorage.read();
    if (mounted && nombre != null) setState(() => _nickname = nombre);
    return _caminoGateway.fetchCamino();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final lejos = (_controller.offset - _offsetObjetivo).abs() > 220;
    if (lejos != _mostrarBotonMiNivel) {
      setState(() => _mostrarBotonMiNivel = lejos);
    }
  }

  void _irAMiNivel() {
    if (!_controller.hasClients) return;
    _controller.animateTo(
      _offsetObjetivo,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  /// Centra el scroll en la parada `esActual` al montar (o al final del
  /// camino si ya está todo superado). `tops` trae, para cada parada, su
  /// posición absoluta ya calculada en `build` (D5 de `design.md` de
  /// INT-105) — SHALL usar exactamente esos valores, o el centrado se
  /// desincroniza de lo que se pinta.
  void _autoScroll(List<ParadaCamino> entradas, List<double> tops) {
    if (_autoScrolled) return;
    _autoScrolled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;

      final maxOffset = _controller.position.maxScrollExtent;
      final indiceActual = entradas.indexWhere((e) => e.esActual);
      final viewport = MediaQuery.sizeOf(context).height;

      final offset = indiceActual == -1
          ? maxOffset
          : (tops[indiceActual] + _paradaAltura / 2 - viewport / 2).clamp(
              0.0,
              maxOffset,
            );

      _offsetObjetivo = offset;
      _controller.jumpTo(offset);
    });
  }

  /// Solo se invoca para paradas desbloqueadas: una bloqueada recibe
  /// `onTap: null` desde el `builder` (ver más abajo), así que su
  /// `GestureDetector` queda inerte y no SHALL responder a toques en
  /// absoluto.
  void _onTapParada(ParadaCamino parada) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NivelJuegoScreen(
          caminoId: parada.caminoId,
          // El HUD de la pantalla de juego necesita un nombre que enseñar y
          // el camino ya lo tiene cargado (D9 de `design.md` de INT-92): la
          // temática hace de reserva para los niveles sin nombre propio.
          nivelNombre: parada.nivelNombre ?? parada.tematicaNombre,
          // El pill del resumen del nivel necesita ambos (D4 de `design.md`
          // de INT-94); el camino ya los tiene cargados.
          nivelOrden: parada.orden,
          tematicaNombre: parada.tematicaNombre,
          gateway: widget.nivelJuegoGateway,
        ),
      ),
    );
  }

  /// Posiciona una parada en `top` y le aplica la animación de aparición
  /// ligada al scroll (D5 de `design.md` de INT-105): opacidad, escala y
  /// traslación derivadas de su distancia a la cabecera/botón de jugar,
  /// con la misma curva smoothstep del mock de referencia.
  Widget _buildParadaAnimada(
    ParadaCamino parada,
    double top,
    double offset,
    double viewport,
    int puntosTotales,
  ) {
    final vt = top - offset;
    final vb = vt + _paradaAltura;
    final bottomEdge = viewport - _ctaAltura;

    final fueraDeZonaSegura = [
      0.0,
      _topBarAltura - vt,
      vb - bottomEdge,
    ].reduce((a, b) => a > b ? a : b);
    final p = (1 - fueraDeZonaSegura / _animRamp).clamp(0.0, 1.0);
    final ease = p * p * (3 - 2 * p);
    final direccion = (vb - bottomEdge) >= (_topBarAltura - vt) ? 1.0 : -1.0;

    return Positioned(
      key: ValueKey(parada.caminoId),
      top: top,
      left: 18,
      right: 18,
      height: _paradaAltura,
      child: Opacity(
        opacity: ease,
        child: Transform(
          alignment: const Alignment(-0.56, 0),
          transform: Matrix4.identity()
            ..translateByDouble(0.0, (1 - ease) * 34 * direccion, 0.0, 1.0)
            ..scaleByDouble(0.93 + 0.07 * ease, 0.93 + 0.07 * ease, 1.0, 1.0),
          child: _ParadaTile(
            parada: parada,
            puntosTotales: puntosTotales,
            onTap: parada.desbloqueado ? () => _onTapParada(parada) : null,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgMid, _bgBottom],
          ),
        ),
        child: FutureBuilder<CaminoJugador>(
          future: _futuro,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: _teal),
              );
            }
            if (snapshot.hasError) {
              return _ErrorCamino(
                onRetry: () => setState(() {
                  _autoScrolled = false;
                  _futuro = _cargar();
                }),
              );
            }

            final camino = snapshot.data!;
            final entradas = camino.entradas;

            // D2 del delta-1: si el camino no llena el espacio visible entre
            // la barra superior y el botón de jugar, todo el sobrante se
            // añade ARRIBA del grupo de paradas — igual que en el mock, el
            // camino sigue apoyado justo encima del botón (con el margen
            // fijo de `_ctaAltura`), y lo que falta por "construirse" queda
            // como hueco hacia la barra superior, no partido en dos huecos.
            final contenidoAltura = entradas.length * _paradaSlot;
            final viewport = MediaQuery.sizeOf(context).height;
            final disponible = viewport - _topBarAltura - _ctaAltura;
            final extra = disponible > contenidoAltura
                ? disponible - contenidoAltura
                : 0.0;
            final paddingTop = _topBarAltura + extra;
            const paddingBottom = _ctaAltura;
            final alturaTotal = paddingTop + contenidoAltura + paddingBottom;

            // Posición absoluta de cada parada dentro del contenido
            // scrolleable (D3/D5 de `design.md` de INT-105): se recorren en
            // orden DESCENDENTE de `orden` acumulando `y` desde arriba, así
            // que el nivel 1 (primero de `entradas`, orden ascendente) es el
            // último en asignarse y queda con el `top` más grande — el más
            // abajo del camino —, replicando `layout()` del mock de
            // referencia sin necesitar `ListView(reverse: true)`.
            final tops = List<double>.filled(entradas.length, 0);
            var y = paddingTop;
            for (var i = entradas.length - 1; i >= 0; i--) {
              tops[i] = y;
              y += _paradaSlot;
            }

            ParadaCamino? paradaActual;
            final indiceActual = entradas.indexWhere((e) => e.esActual);
            if (indiceActual != -1) paradaActual = entradas[indiceActual];

            final railRellenoTop = indiceActual == -1
                ? 0.0
                : tops[indiceActual] + _paradaAltura / 2;

            _autoScroll(entradas, tops);

            return Stack(
              children: [
                Positioned.fill(
                  child: ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (rect) {
                      final topFrac = (_topBarAltura / rect.height).clamp(
                        0.0,
                        1.0,
                      );
                      final bottomFrac =
                          1 - (_ctaAltura / rect.height).clamp(0.0, 1.0);
                      return LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: const [
                          Colors.transparent,
                          Colors.black,
                          Colors.black,
                          Colors.transparent,
                        ],
                        stops: [0, topFrac, bottomFrac, 1],
                      ).createShader(rect);
                    },
                    child: SingleChildScrollView(
                      controller: _controller,
                      child: SizedBox(
                        height: alturaTotal,
                        child: AnimatedBuilder(
                          animation: _controller,
                          builder: (context, _) {
                            final offset = _controller.hasClients
                                ? _controller.offset
                                : 0.0;
                            return Stack(
                              children: [
                                Positioned(
                                  key: const Key('camino-riel-pista'),
                                  left: _railX,
                                  top: 0,
                                  bottom: 0,
                                  width: _railAncho,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.08,
                                      ),
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  key: const Key('camino-riel-relleno'),
                                  left: _railX,
                                  top: railRellenoTop,
                                  height: alturaTotal - railRellenoTop,
                                  width: _railAncho,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(99),
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          _teal.withValues(alpha: 0.25),
                                          _teal,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                for (var i = 0; i < entradas.length; i++)
                                  _buildParadaAnimada(
                                    entradas[i],
                                    tops[i],
                                    offset,
                                    viewport,
                                    camino.puntosTotales,
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _BarraSuperior(nickname: _nickname, camino: camino),
                ),
                if (_mostrarBotonMiNivel)
                  Positioned(
                    right: 16,
                    bottom: _ctaAltura + 16,
                    child: SafeArea(
                      top: false,
                      child: _BotonMiNivel(onTap: _irAMiNivel),
                    ),
                  ),
                if (paradaActual != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _BotonJugar(
                      key: const Key('camino-boton-jugar'),
                      parada: paradaActual,
                      onTap: () => _onTapParada(paradaActual!),
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

class _BarraSuperior extends StatelessWidget {
  const _BarraSuperior({required this.nickname, required this.camino});

  final String nickname;
  final CaminoJugador camino;

  @override
  Widget build(BuildContext context) {
    final paradas = camino.entradas;
    final total = paradas.length;
    final indiceActual = paradas.indexWhere((p) => p.esActual);
    final posicion = indiceActual == -1 ? total : indiceActual + 1;
    final estrellasGanadas = paradas.fold<int>(
      0,
      (t, p) => t + p.estrellasObtenidas,
    );
    final estrellasPosibles = total * 3;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _bgBottom.withValues(alpha: 0.98),
            _bgBottom.withValues(alpha: 0.7),
            _bgBottom.withValues(alpha: 0),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _BotonPerfil(nickname: nickname),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      nickname,
                      key: const Key('camino-nickname'),
                      style: GoogleFonts.baloo2(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Nivel $posicion de $total · $estrellasGanadas/$estrellasPosibles ★',
                      key: const Key('camino-progreso'),
                      style: GoogleFonts.outfit(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _PildoraPuntos(puntos: camino.puntosTotales),
            ],
          ),
        ),
      ),
    );
  }
}

class _BotonPerfil extends StatelessWidget {
  const _BotonPerfil({required this.nickname});

  final String nickname;

  @override
  Widget build(BuildContext context) {
    final trimmed = nickname.trim();
    final iniciales = trimmed.isEmpty
        ? '?'
        : trimmed
              .substring(0, trimmed.length < 2 ? trimmed.length : 2)
              .toUpperCase();

    return GestureDetector(
      key: const Key('camino-perfil-boton'),
      onTap: () => ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Perfil — pendiente'))),
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: const LinearGradient(colors: [_teal, _blue]),
        ),
        child: Text(
          iniciales,
          style: GoogleFonts.baloo2(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

class _PildoraPuntos extends StatelessWidget {
  const _PildoraPuntos({required this.puntos});

  final int puntos;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.16),
        border: Border.all(color: _gold.withValues(alpha: 0.45), width: 1.5),
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
            _formatMiles(puntos),
            key: const Key('camino-puntos'),
            style: GoogleFonts.baloo2(
              color: const Color(0xFFFFE9A8),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ParadaTile extends StatelessWidget {
  const _ParadaTile({
    required this.parada,
    required this.puntosTotales,
    required this.onTap,
  });

  final ParadaCamino parada;

  /// Puntos totales acumulados del jugador (no de esta parada en
  /// concreto): se repite igual en todas las paradas del camino, igual
  /// que en la píldora de la cabecera (INT-112).
  final int puntosTotales;

  /// `null` cuando la parada está bloqueada: no SHALL responder a toques en
  /// absoluto, así que ni se le adjunta un `GestureDetector`.
  final VoidCallback? onTap;

  String get _meta {
    if (!parada.desbloqueado) {
      return 'Bloqueado · mín. ${parada.estrellasRequeridas} ★';
    }
    if (parada.esActual) {
      return '¡Es tu turno! · mín. ${parada.estrellasRequeridas} ★';
    }
    return '${parada.estrellasObtenidas}/3 ★ · mejor intento';
  }

  @override
  Widget build(BuildContext context) {
    final acento = _colorAcento(parada.tematicaId);
    final bloqueado = !parada.desbloqueado;

    return SizedBox(
      height: _paradaAltura,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 52,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: parada.esActual ? 18 : 14,
                  height: parada.esActual ? 18 : 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: bloqueado
                        ? Colors.white24
                        : (parada.esActual ? _gold : acento),
                    border: Border.all(color: Colors.white70, width: 2),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _formatMiles(puntosTotales),
                  key: Key('parada-puntos-${parada.caminoId}'),
                  style: GoogleFonts.baloo2(
                    color: Colors.white.withValues(
                      alpha: bloqueado ? 0.4 : 0.85,
                    ),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GestureDetector(
              key: Key('parada-${parada.caminoId}'),
              onTap: onTap,
              child: Container(
                key: Key('parada-borde-${parada.caminoId}'),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: bloqueado
                        ? Colors.white12
                        : (parada.esActual
                              ? _gold
                              : acento.withValues(alpha: 0.5)),
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColorFiltered(
                        colorFilter: ColorFilter.matrix(
                          bloqueado ? _grayscale : _identity,
                        ),
                        child: parada.imagenPortadaUrl == null
                            ? ColoredBox(color: acento.withValues(alpha: 0.35))
                            : Image.network(
                                parada.imagenPortadaUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => ColoredBox(
                                  color: acento.withValues(alpha: 0.35),
                                ),
                              ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              _bgBottom.withValues(alpha: 0.92),
                              _bgBottom.withValues(alpha: 0.08),
                            ],
                          ),
                        ),
                      ),
                      if (bloqueado)
                        const Positioned(
                          top: 10,
                          right: 10,
                          child: _CandadoBadge(),
                        )
                      else if (parada.esActual)
                        const Positioned(
                          top: 10,
                          right: 10,
                          child: _JuegaAquiBadge(),
                        ),
                      Positioned(
                        left: 14,
                        right: 14,
                        bottom: 12,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _NumeroBadge(
                              numero: parada.orden,
                              resaltado: parada.esActual,
                              bloqueado: bloqueado,
                              acento: acento,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    parada.tematicaNombre,
                                    style: GoogleFonts.baloo2(
                                      color: Colors.white.withValues(
                                        alpha: bloqueado ? 0.62 : 1,
                                      ),
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      _EstrellasFila(
                                        cantidad: parada.estrellasObtenidas,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _meta,
                                          style: GoogleFonts.outfit(
                                            color: Colors.white.withValues(
                                              alpha: 0.65,
                                            ),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EstrellasFila extends StatelessWidget {
  const _EstrellasFila({required this.cantidad});

  final int cantidad;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Text(
            '★',
            style: TextStyle(
              fontSize: 13,
              color: i < cantidad ? _gold : Colors.white24,
            ),
          ),
      ],
    );
  }
}

class _NumeroBadge extends StatelessWidget {
  const _NumeroBadge({
    required this.numero,
    required this.resaltado,
    required this.bloqueado,
    required this.acento,
  });

  final int numero;
  final bool resaltado;
  final bool bloqueado;
  final Color acento;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bloqueado
            ? Colors.white.withValues(alpha: 0.1)
            : (resaltado ? _gold : acento),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: bloqueado ? Colors.white24 : Colors.white,
          width: 2,
        ),
      ),
      child: Text(
        '$numero',
        style: GoogleFonts.baloo2(
          color: bloqueado
              ? Colors.white.withValues(alpha: 0.4)
              : (resaltado ? const Color(0xFF3A2A00) : Colors.white),
          fontWeight: FontWeight.w800,
          fontSize: 17,
        ),
      ),
    );
  }
}

class _CandadoBadge extends StatelessWidget {
  const _CandadoBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white24),
      ),
      child: const Icon(Icons.lock_rounded, color: Colors.white70, size: 16),
    );
  }
}

class _JuegaAquiBadge extends StatelessWidget {
  const _JuegaAquiBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _gold,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        '¡JUEGA AQUÍ!',
        style: GoogleFonts.baloo2(
          color: const Color(0xFF3A2A00),
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _BotonMiNivel extends StatelessWidget {
  const _BotonMiNivel({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('camino-mi-nivel'),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _bgBottom.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _teal.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.my_location, color: _teal, size: 16),
            const SizedBox(width: 8),
            Text(
              'Mi nivel',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// CTA fijo para jugar la parada actual (delta-1 de INT-90): "Jugar nivel
/// N · Tema", igual que `{{ onPlay }}` en el mock de referencia. Estilo
/// consistente con `PrimaryPillButton` de `entry_widgets.dart`.
class _BotonJugar extends StatelessWidget {
  const _BotonJugar({super.key, required this.parada, required this.onTap});

  final ParadaCamino parada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _bgBottom.withValues(alpha: 0),
            _bgBottom.withValues(alpha: 0.97),
          ],
          stops: const [0, 0.55],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0B4266).withValues(alpha: 0.55),
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                elevation: 0,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 19),
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                  gradient: LinearGradient(colors: [_teal, _blue]),
                ),
                child: Text(
                  'Jugar nivel ${parada.orden} · ${parada.tematicaNombre}',
                  style: GoogleFonts.baloo2(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorCamino extends StatelessWidget {
  const _ErrorCamino({required this.onRetry});

  final VoidCallback onRetry;

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
              'No se pudo cargar tu camino',
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
