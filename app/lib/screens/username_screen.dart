import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/profile_gateway.dart';
import '../services/username_storage.dart';
import 'camino_screen.dart';

const _teal = Color(0xFF2BC0A8);
const _blue = Color(0xFF1B6FA8);
const _ink = Color(0xFF0E1620);
const _cream = Color(0xFFFFFDF8);
const _heroHeight = 300.0;
const _cardOverlap = 34.0;

/// Pantalla "Nombre de usuario" (INT-89): pide un apodo público para la
/// sesión anónima que ya creó el splash (INT-88). No es un login — solo un
/// nombre para el marcador, sin contraseña.
///
/// Reproduce `[App] - Nombre de usuario.dc.html` (Claude Design): hero con
/// degradado y tarjeta blanca superpuesta con borde redondeado, no un
/// simple apilado de secciones.
class UsernameScreen extends StatefulWidget {
  const UsernameScreen({super.key, this.usernameStorage, this.profileGateway});

  /// Inyectables para poder probar la pantalla sin salir a la red ni al disco.
  final UsernameStorage? usernameStorage;
  final ProfileGateway? profileGateway;

  static const minLength = 3;
  static const maxLength = 16;

  @override
  State<UsernameScreen> createState() => _UsernameScreenState();
}

class _UsernameScreenState extends State<UsernameScreen> {
  static const _dicePool = [
    'Explorador42',
    'BrújulaLoca',
    'MapaMaestro',
    'NómadaAzul',
    'CazaAtlas',
    'RutaSalvaje',
    'GeoLince',
    'TrotaMundos',
  ];
  static const _chipSuggestions = ['Explorador42', 'BrújulaLoca', 'GeoLince'];

  late final UsernameStorage _usernameStorage =
      widget.usernameStorage ?? UsernameStorage();
  late final ProfileGateway _profileGateway =
      widget.profileGateway ?? SupabaseProfileGateway(Supabase.instance.client);

  final _controller = TextEditingController();
  final _random = Random();

  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  int get _trimmedLength => _controller.text.trim().length;

  bool get _isValid =>
      _trimmedLength >= UsernameScreen.minLength &&
      _trimmedLength <= UsernameScreen.maxLength;

  void _setNickname(String value) {
    _controller.text = value;
    setState(() => _errorMessage = null);
  }

  void _onDice() => _setNickname(_dicePool[_random.nextInt(_dicePool.length)]);

  Future<void> _onStart() async {
    if (!_isValid || _saving) return;
    final nombre = _controller.text.trim();

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    await _usernameStorage.save(nombre);

    try {
      await _profileGateway.updateNickname(nombre);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage =
            'No se pudo guardar tu apodo. Comprueba tu conexión e '
            'inténtalo de nuevo.';
      });
      return;
    }

    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const CaminoScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final belowMinimum =
        _trimmedLength > 0 && _trimmedLength < UsernameScreen.minLength;

    return Scaffold(
      backgroundColor: _cream,
      body: Stack(
        children: [
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: _heroHeight,
            child: _Hero(),
          ),
          Positioned(
            top: _heroHeight - _cardOverlap,
            left: 0,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _cream,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(34),
                ),
                boxShadow: [
                  BoxShadow(
                    color: _ink.withValues(alpha: 0.12),
                    blurRadius: 30,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 34, 28, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '¿Cómo te llamamos?',
                        style: GoogleFonts.baloo2(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                          height: 1.1,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Elige un apodo para aparecer en el marcador. Puedes '
                        'cambiarlo cuando quieras.',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          color: _ink.withValues(alpha: 0.6),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 26),
                      _NicknameField(
                        key: const Key('nickname-field'),
                        controller: _controller,
                        isValid: _isValid,
                        isEmpty: _trimmedLength == 0,
                        onDice: _onDice,
                      ),
                      if (belowMinimum) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Mínimo ${UsernameScreen.minLength} caracteres',
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              'Sin contraseñas. Podrás vincular una cuenta '
                              'más adelante para no perder tu progreso.',
                              style: GoogleFonts.outfit(
                                fontSize: 12.5,
                                color: _ink.withValues(alpha: 0.5),
                                height: 1.35,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Cuenta caracteres sin recortar (igual que el
                          // diseño): la validación sí recorta espacios, así
                          // que "  Ana  " cuenta 7/16 pero valida como 3.
                          Text(
                            '${_controller.text.length}/${UsernameScreen.maxLength}',
                            key: const Key('nickname-counter'),
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _ink.withValues(alpha: 0.35),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'O PRUEBA UNO DE ESTOS',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.6,
                          color: _ink.withValues(alpha: 0.35),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final suggestion in _chipSuggestions)
                            _SuggestionChip(
                              label: suggestion,
                              onTap: () => _setNickname(suggestion),
                            ),
                        ],
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 22),
                        Text(
                          _errorMessage!,
                          style: GoogleFonts.outfit(
                            color: Colors.redAccent,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                      _StartButton(
                        enabled: _isValid,
                        saving: _saving,
                        onPressed: _onStart,
                      ),
                      const SizedBox(height: 18),
                      Center(
                        child: GestureDetector(
                          key: const Key('login-link'),
                          onTap: () {},
                          child: Text.rich(
                            TextSpan(
                              text: '¿Ya tienes una cuenta? ',
                              style: GoogleFonts.outfit(
                                fontSize: 13.5,
                                color: _ink.withValues(alpha: 0.42),
                              ),
                              children: const [
                                TextSpan(
                                  text: 'Iniciar sesión',
                                  style: TextStyle(
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
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

/// Cabecera de marca: degradado a todo lo ancho con el logo, el wordmark y
/// dos insignias decorativas, tal como en el diseño de Claude Design. El
/// logo aparece con un "pop", el wordmark sube con fade (`gq-rise`/`gq-pop`
/// del diseño) y las dos insignias flotan en bucle (`gq-float`).
class _Hero extends StatefulWidget {
  const _Hero();

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> with TickerProviderStateMixin {
  // Respeta "reducir movimiento" del sistema — y de paso evita que los
  // widget tests se cuelguen en pumpAndSettle() con animaciones infinitas.
  final bool _reduceMotion = WidgetsBinding
      .instance
      .platformDispatcher
      .accessibilityFeatures
      .disableAnimations;

  late final AnimationController _logoController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
    value: _reduceMotion ? 1 : 0,
  );
  late final AnimationController _wordmarkController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
    value: _reduceMotion ? 1 : 0,
  );
  late final AnimationController _badge1Controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );
  late final AnimationController _badge2Controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3300),
  );
  late final AnimationController _routeController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
    value: _reduceMotion ? 1 : 0,
  );

  late final Animation<double> _logoScale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.84, end: 1.04), weight: 60),
    TweenSequenceItem(tween: Tween(begin: 1.04, end: 1.0), weight: 40),
  ]).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeOut));

  late final Animation<double> _logoOpacity = CurvedAnimation(
    parent: _logoController,
    curve: const Interval(0, 0.6),
  );

  late final Animation<double> _wordmarkRise = Tween<double>(begin: 14, end: 0)
      .animate(
        CurvedAnimation(parent: _wordmarkController, curve: Curves.easeOut),
      );

  late final Animation<double> _badgeFloat1 = Tween<double>(begin: 0, end: -11)
      .animate(
        CurvedAnimation(parent: _badge1Controller, curve: Curves.easeInOut),
      );

  late final Animation<double> _badgeFloat2 = Tween<double>(begin: 0, end: -11)
      .animate(
        CurvedAnimation(parent: _badge2Controller, curve: Curves.easeInOut),
      );

  @override
  void initState() {
    super.initState();
    if (_reduceMotion) return;

    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) _wordmarkController.forward();
    });
    _badge1Controller.repeat(reverse: true);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) _badge2Controller.repeat(reverse: true);
    });
    _routeController.repeat();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _wordmarkController.dispose();
    _badge1Controller.dispose();
    _badge2Controller.dispose();
    _routeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    // El logo+wordmark se centra respecto al hero completo; el offset del
    // bloque de insignias solo necesita despejar la isla dinámica/notch.
    final badgeTop = topInset < 12 ? 44.0 : topInset + 8;

    return SizedBox(
      width: double.infinity,
      height: _heroHeight,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2BC0A8), Color(0xFF1B8FA8), Color(0xFF1B6FA8)],
            stops: [0, 0.48, 1],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _routeController,
                builder: (context, child) => CustomPaint(
                  painter: _RoutesPainter(phase: -300 * _routeController.value),
                ),
              ),
            ),
            Positioned(
              top: badgeTop,
              left: 8,
              child: AnimatedBuilder(
                animation: _badgeFloat1,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, _badgeFloat1.value),
                  child: child,
                ),
                child: Transform.rotate(
                  angle: -0.08,
                  child: const _FloatingBadge(
                    label: '✦ 42 CIUDADES',
                    background: Color(0x2AFFFFFF),
                    border: Color(0x57FFFFFF),
                    textColor: Colors.white,
                  ),
                ),
              ),
            ),
            Positioned(
              top: _heroHeight - _cardOverlap - 54,
              right: 8,
              child: AnimatedBuilder(
                animation: _badgeFloat2,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, _badgeFloat2.value),
                  child: child,
                ),
                child: Transform.rotate(
                  angle: 0.08,
                  child: const _FloatingBadge(
                    label: '+120 PTS',
                    background: Color(0x38FFC53D),
                    border: Color(0x99FFC53D),
                    textColor: Color(0xFFFFF3D1),
                  ),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FadeTransition(
                    opacity: _logoOpacity,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(19),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF092D4A)
                                  .withValues(alpha: 0.42),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(19),
                          child: Image.asset(
                            'assets/branding/geoquest-logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AnimatedBuilder(
                    animation: _wordmarkController,
                    builder: (context, child) => Opacity(
                      opacity: _wordmarkController.value,
                      child: Transform.translate(
                        offset: Offset(0, _wordmarkRise.value),
                        child: child,
                      ),
                    ),
                    child: Text(
                      'GeoQuest',
                      style: GoogleFonts.baloo2(
                        fontWeight: FontWeight.w800,
                        fontSize: 26,
                        letterSpacing: -0.4,
                        color: Colors.white,
                        shadows: const [
                          Shadow(
                            color: Color(0x470B4266),
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Las dos rutas de fondo del hero, sobre un lienzo de 390x328 (el viewBox
/// del diseño): una fluye (se desplaza el patrón de guiones), la otra es
/// fija. `phase` desplaza el guión de la ruta que fluye.
class _RoutesPainter extends CustomPainter {
  const _RoutesPainter({required this.phase});

  final double phase;

  static final Path _flowPath = Path()
    ..moveTo(-10, 250)
    ..cubicTo(70, 210, 110, 250, 170, 200)
    ..cubicTo(230, 150, 300, 150, 400, 190);

  static final Path _staticPath = Path()
    ..moveTo(-20, 120)
    ..cubicTo(60, 150, 130, 90, 210, 120)
    ..cubicTo(290, 150, 340, 60, 410, 100);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 390, size.height / 328);

    canvas.drawPath(
      _dashedPath(_staticPath, on: 6, off: 12, phase: 0),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawPath(
      _dashedPath(_flowPath, on: 9, off: 13, phase: phase),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RoutesPainter oldDelegate) =>
      oldDelegate.phase != phase;

  static Path _dashedPath(
    Path source, {
    required double on,
    required double off,
    required double phase,
  }) {
    final dest = Path();
    final cycle = on + off;
    var normalizedPhase = phase % cycle;
    if (normalizedPhase < 0) normalizedPhase += cycle;

    for (final metric in source.computeMetrics()) {
      var distance = -normalizedPhase;
      var drawing = normalizedPhase < on;
      while (distance < metric.length) {
        final segmentLength = drawing ? on : off;
        final segmentEnd = distance + segmentLength;
        if (drawing) {
          final start = distance.clamp(0.0, metric.length);
          final end = segmentEnd.clamp(0.0, metric.length);
          if (end > start) {
            dest.addPath(metric.extractPath(start, end), Offset.zero);
          }
        }
        distance = segmentEnd;
        drawing = !drawing;
      }
    }
    return dest;
  }
}

class _FloatingBadge extends StatelessWidget {
  const _FloatingBadge({
    required this.label,
    required this.background,
    required this.border,
    required this.textColor,
  });

  final String label;
  final Color background;
  final Color border;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: textColor,
        ),
      ),
    );
  }
}

class _NicknameField extends StatelessWidget {
  const _NicknameField({
    super.key,
    required this.controller,
    required this.isValid,
    required this.isEmpty,
    required this.onDice,
  });

  final TextEditingController controller;
  final bool isValid;
  final bool isEmpty;
  final VoidCallback onDice;

  @override
  Widget build(BuildContext context) {
    final borderColor = !isEmpty && isValid ? _teal : const Color(0xFFDCE7E4);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: _ink.withValues(alpha: 0.06),
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.only(left: 18, right: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLength: UsernameScreen.maxLength,
              buildCounter: (
                _, {
                required currentLength,
                required isFocused,
                maxLength,
              }) => null,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Tu nombre de jugador',
                hintStyle: GoogleFonts.outfit(),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          IconButton(
            key: const Key('dice-button'),
            tooltip: 'Sugerir apodo',
            onPressed: onDice,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF0F5F3),
              fixedSize: const Size(46, 46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.refresh, color: _blue),
          ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: _ink.withValues(alpha: 0.7),
        side: const BorderSide(color: Color(0xFFDCE7E4)),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      child: Text(label, style: GoogleFonts.outfit(fontSize: 13)),
    );
  }
}

/// Botón "grueso" con sombra sólida (sin difuminado) imitando el estilo de
/// juego del diseño, envolviendo un `FilledButton` transparente para
/// conservar la semántica de habilitado/deshabilitado y la accesibilidad.
class _StartButton extends StatelessWidget {
  const _StartButton({
    required this.enabled,
    required this.saving,
    required this.onPressed,
  });

  final bool enabled;
  final bool saving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: enabled
                ? const Color(0xFF0B4266).withValues(alpha: 0.55)
                : const Color(0xFF788C91).withValues(alpha: 0.6),
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FilledButton(
        onPressed: enabled && !saving ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: enabled
                ? const LinearGradient(colors: [_teal, _blue])
                : null,
            color: enabled ? null : const Color(0xFF9FB4B8),
          ),
          child: saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : Text(
                  'Empezar a jugar',
                  style: GoogleFonts.baloo2(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
      ),
    );
  }
}
