import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/profile_gateway.dart';
import '../services/username_storage.dart';
import 'camino_screen.dart';
import 'entry_backdrop.dart';
import 'entry_motion.dart';
import 'entry_widgets.dart';

/// Pantalla "Nombre de usuario" (INT-89, rediseñada en INT-108): pide un
/// apodo público para la sesión anónima que ya creó el splash (INT-88). No
/// es un login — solo un nombre para el marcador, sin contraseña.
///
/// Reproduce el estado "primera vez" (12a) de `[App] - Login.dc.html`
/// (Claude Design): fondo oscuro azul-teal con halos y rutas punteadas
/// animadas, tarjeta de apodo con botón de dado, y accesos sociales
/// decorativos "Próximamente" (sin contraseña real, sin login social real).
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
    } on AliasEnUsoException {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = 'Ese apodo ya está en uso. Prueba con otro.';
      });
      return;
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

  /// "Entrar sin cuenta como invitado": asigna un apodo aleatorio y sigue
  /// el mismo flujo de guardado + navegación que el CTA principal, sin
  /// exigir que el jugador escriba nada.
  Future<void> _onGuestStart() async {
    if (_saving) return;
    if (_trimmedLength == 0) {
      _setNickname(_dicePool[_random.nextInt(_dicePool.length)]);
    }
    await _onStart();
  }

  @override
  Widget build(BuildContext context) {
    final belowMinimum =
        _trimmedLength > 0 && _trimmedLength < UsernameScreen.minLength;

    return Scaffold(
      backgroundColor: entryBg,
      body: EntryBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 26),
            child: Column(
              children: [
                _BrandHeader(),
                const SizedBox(height: 36),
                RiseIn(
                  delay: const Duration(milliseconds: 220),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Entra a jugar',
                        style: GoogleFonts.baloo2(
                          fontSize: 31,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        'Con tu nombre es suficiente. Guardaremos tu progreso '
                        'en este dispositivo.',
                        style: GoogleFonts.outfit(
                          fontSize: 14.5,
                          color: Colors.white.withValues(alpha: 0.6),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                RiseIn(
                  delay: const Duration(milliseconds: 300),
                  child: Column(
                    children: [
                      _NicknameField(
                        key: const Key('nickname-field'),
                        controller: _controller,
                        isValid: _isValid,
                        isEmpty: _trimmedLength == 0,
                        onDice: _onDice,
                      ),
                      if (belowMinimum) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Mínimo ${UsernameScreen.minLength} caracteres',
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              color: Colors.redAccent,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              'Sin contraseñas por ahora. Más adelante podrás '
                              'vincular una cuenta.',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.42),
                                height: 1.35,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${_controller.text.length}/${UsernameScreen.maxLength}',
                            key: const Key('nickname-counter'),
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                        ],
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.outfit(
                              color: Colors.redAccent,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                RiseIn(
                  delay: const Duration(milliseconds: 380),
                  child: PrimaryPillButton(
                    label: 'Empezar a jugar',
                    enabled: _isValid,
                    loading: _saving,
                    onPressed: _onStart,
                  ),
                ),
                const SizedBox(height: 22),
                RiseIn(
                  delay: const Duration(milliseconds: 440),
                  child: const SocialPlaceholderRow(),
                ),
                const SizedBox(height: 24),
                RiseIn(
                  delay: const Duration(milliseconds: 500),
                  child: Column(
                    children: [
                      GestureDetector(
                        key: const Key('guest-link'),
                        onTap: _saving ? null : _onGuestStart,
                        child: Text.rich(
                          TextSpan(
                            text: 'Entrar sin cuenta ',
                            style: GoogleFonts.outfit(
                              fontSize: 13.5,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                            children: const [
                              TextSpan(
                                text: 'como invitado',
                                style: TextStyle(
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        'Al continuar aceptas las condiciones de uso de '
                        'GeoQuest.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.26),
                          height: 1.5,
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
    );
  }
}

/// Logo con halo pulsante + wordmark + insignias decorativas del juego
/// (contenido estático de producto, no datos del jugador — igual criterio
/// que ya usaban las insignias "42 CIUDADES"/"+120 PTS" de este hero).
class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PopIn(
          child: HaloPulse(
            color: entryTeal.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(30),
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF040C12).withValues(alpha: 0.6),
                    blurRadius: 34,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.asset(
                  'assets/branding/geoquest-logo.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 13),
        RiseIn(
          delay: const Duration(milliseconds: 100),
          child: Text(
            'GeoQuest',
            style: GoogleFonts.baloo2(
              fontWeight: FontWeight.w800,
              fontSize: 30,
              letterSpacing: -0.4,
              color: Colors.white,
              shadows: const [
                Shadow(color: Color(0xB2040C12), offset: Offset(0, 3)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        RiseIn(
          delay: const Duration(milliseconds: 160),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              FloatLoop(
                duration: Duration(milliseconds: 6000),
                child: _StatBadge(
                  label: '13 NIVELES',
                  background: Color(0x242BC0A8),
                  border: Color(0x6A2BC0A8),
                  textColor: Color(0xFF8FE7D6),
                ),
              ),
              SizedBox(width: 8),
              FloatLoop(
                duration: Duration(milliseconds: 6800),
                delay: Duration(milliseconds: 600),
                child: _StatBadge(
                  label: 'RÉCORD 1.240',
                  background: Color(0x28FFC53D),
                  border: Color(0x80FFC53D),
                  textColor: Color(0xFFFFD98A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({
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
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 10,
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
    final borderColor = !isEmpty && isValid
        ? entryTeal
        : Colors.white.withValues(alpha: 0.12);

    return Container(
      decoration: BoxDecoration(
        color: entryCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 2.5),
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
                color: Colors.white,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Tu apodo',
                hintStyle: GoogleFonts.outfit(
                  color: Colors.white.withValues(alpha: 0.35),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          IconButton(
            key: const Key('dice-button'),
            tooltip: 'Sugerir apodo',
            onPressed: onDice,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              fixedSize: const Size(44, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.refresh, color: entryTeal),
          ),
        ],
      ),
    );
  }
}
