import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_gateway.dart';
import '../services/estado_apodo_gateway.dart';
import '../services/player_roster_storage.dart';
import '../services/player_session_service.dart';
import '../services/profile_gateway.dart';
import '../services/username_storage.dart';
import 'camino_screen.dart';
import 'entry_backdrop.dart';
import 'entry_motion.dart';
import 'entry_widgets.dart';

/// Pantalla de acceso (INT-89, rediseñada en INT-108, convertida en login real
/// en INT-128): apodo y contraseña, con un solo botón que crea el perfil si el
/// apodo está libre y entra en él si ya es de alguien.
///
/// La contraseña no es un trámite: es lo único que permite recuperar el
/// progreso desde otro móvil, y lo que hace posible que dos jugadores compartan
/// un teléfono sin pisarse. No hay email en ningún punto del flujo.
class UsernameScreen extends StatefulWidget {
  const UsernameScreen({
    super.key,
    this.usernameStorage,
    this.profileGateway,
    this.sessionService,
    this.rosterStorage,
  });

  /// Inyectables para poder probar la pantalla sin salir a la red ni al disco.
  final UsernameStorage? usernameStorage;
  final ProfileGateway? profileGateway;
  final PlayerSessionService? sessionService;
  final PlayerRosterStorage? rosterStorage;

  static const minLength = 3;
  static const maxLength = 16;

  /// Mínimo que exige el proyecto Supabase (`minimum_password_length`).
  static const minPasswordLength = 6;

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
  late final PlayerRosterStorage _rosterStorage =
      widget.rosterStorage ?? PlayerRosterStorage();
  late final PlayerSessionService _sessionService =
      widget.sessionService ?? _defaultSessionService();

  final _controller = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();
  final _random = Random();

  bool _saving = false;
  bool _passwordVisible = false;
  String? _errorMessage;
  List<String> _roster = const [];

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

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _passwordController.addListener(_onTextChanged);
    _cargarRoster();
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _passwordController.removeListener(_onTextChanged);
    _controller.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _cargarRoster() async {
    final apodos = await _rosterStorage.read();
    if (!mounted) return;
    setState(() => _roster = apodos);
  }

  void _onTextChanged() => setState(() {});

  int get _trimmedLength => _controller.text.trim().length;

  bool get _nicknameIsValid =>
      _trimmedLength >= UsernameScreen.minLength &&
      _trimmedLength <= UsernameScreen.maxLength;

  bool get _passwordIsValid =>
      _passwordController.text.length >= UsernameScreen.minPasswordLength;

  bool get _isValid => _nicknameIsValid && _passwordIsValid;

  void _setNickname(String value) {
    _controller.text = value;
    setState(() => _errorMessage = null);
  }

  void _onDice() => _setNickname(_dicePool[_random.nextInt(_dicePool.length)]);

  /// Elegir un apodo recordado rellena el campo y deja al jugador escribiendo
  /// su contraseña. No entra por sí solo: seguir haciendo falta la contraseña
  /// es lo que evita que compartir un móvil sea compartir las cuentas.
  void _onRosterTap(String apodo) {
    _setNickname(apodo);
    _passwordFocus.requestFocus();
  }

  Future<void> _onRosterForget(String apodo) async {
    await _rosterStorage.olvidar(apodo);
    await _cargarRoster();
  }

  Future<void> _onStart() async {
    if (!_isValid || _saving) return;

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final resultado = await _sessionService.entrar(
      apodo: _controller.text.trim(),
      contrasena: _passwordController.text,
    );

    if (!mounted) return;
    _resolver(resultado);
  }

  /// "Entrar sin cuenta como invitado": perfil nuevo sin contraseña, con un
  /// apodo sugerido. Nunca entra en un perfil que ya existe.
  Future<void> _onGuestStart() async {
    if (_saving) return;

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    // Se empieza por lo que el jugador tenga escrito, si es válido, y se sigue
    // por las sugerencias barajadas: si la primera está ocupada, se prueba otra
    // en vez de dejarlo fuera.
    final sugerencias = <String>[
      if (_nicknameIsValid) _controller.text.trim(),
      ..._dicePool.toList()..shuffle(_random),
    ];

    final resultado = await _sessionService.entrarComoInvitado(sugerencias);

    if (!mounted) return;
    _resolver(resultado, comoInvitado: true);
  }

  void _resolver(EntradaResult resultado, {bool comoInvitado = false}) {
    switch (resultado) {
      case EntradaCompletada():
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const CaminoScreen()),
        );
      case ContrasenaIncorrecta():
        setState(() {
          _saving = false;
          _errorMessage =
              'Esa no es la contraseña de ese apodo. Si el apodo no es tuyo, '
              'elige otro.';
        });
      case ApodoOcupado():
        setState(() {
          _saving = false;
          _errorMessage = comoInvitado
              ? 'No hemos encontrado un apodo libre. Escribe uno tú mismo.'
              : 'Ese apodo ya está ocupado. Prueba con otro.';
        });
      case ApodoDeJugadorSinContrasena():
        setState(() {
          _saving = false;
          _errorMessage =
              'Ese jugador no tiene contraseña, así que solo puede entrar '
              'desde el móvil donde se creó. Elige otro apodo.';
        });
      case ContrasenaDebil():
        setState(() {
          _saving = false;
          _errorMessage =
              'Esa contraseña es demasiado débil. Prueba con una más larga.';
        });
      case EntradaFallida():
        setState(() {
          _saving = false;
          _errorMessage =
              'No se pudo completar la entrada. Comprueba tu conexión e '
              'inténtalo de nuevo.';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final belowMinimum =
        _trimmedLength > 0 && _trimmedLength < UsernameScreen.minLength;
    final passwordBelowMinimum =
        _passwordController.text.isNotEmpty && !_passwordIsValid;

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
                        'Tu apodo y tu contraseña. Si ya juegas, entras en tu '
                        'perfil con tus puntos.',
                        style: GoogleFonts.outfit(
                          fontSize: 14.5,
                          color: Colors.white.withValues(alpha: 0.6),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_roster.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  RiseIn(
                    delay: const Duration(milliseconds: 260),
                    child: _RosterRow(
                      key: const Key('roster'),
                      apodos: _roster,
                      onTap: _onRosterTap,
                      onForget: _onRosterForget,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                RiseIn(
                  delay: const Duration(milliseconds: 300),
                  child: Column(
                    children: [
                      _NicknameField(
                        key: const Key('nickname-field'),
                        controller: _controller,
                        isValid: _nicknameIsValid,
                        isEmpty: _trimmedLength == 0,
                        onDice: _onDice,
                      ),
                      if (belowMinimum) ...[
                        const SizedBox(height: 8),
                        _FieldHint(
                          'Mínimo ${UsernameScreen.minLength} caracteres',
                        ),
                      ],
                      const SizedBox(height: 12),
                      _PasswordField(
                        key: const Key('password-field'),
                        controller: _passwordController,
                        focusNode: _passwordFocus,
                        isValid: _passwordIsValid,
                        visible: _passwordVisible,
                        onToggleVisibility: () => setState(
                          () => _passwordVisible = !_passwordVisible,
                        ),
                      ),
                      if (passwordBelowMinimum) ...[
                        const SizedBox(height: 8),
                        _FieldHint(
                          'Mínimo ${UsernameScreen.minPasswordLength} '
                          'caracteres',
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              'Con tu apodo y tu contraseña vuelves a entrar y '
                              'recuperas tu progreso, aquí o en otro móvil. '
                              'Guárdala bien: no podemos recuperarla.',
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
                            key: const Key('error-message'),
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

/// Aviso bajo un campo (mínimo de caracteres).
class _FieldHint extends StatelessWidget {
  const _FieldHint(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        texto,
        style: GoogleFonts.outfit(fontSize: 12.5, color: Colors.redAccent),
      ),
    );
  }
}

/// Apodos que ya han entrado en este dispositivo. Solo se dibuja si hay
/// alguno: en una instalación limpia la pantalla es exactamente la de siempre.
class _RosterRow extends StatelessWidget {
  const _RosterRow({
    super.key,
    required this.apodos,
    required this.onTap,
    required this.onForget,
  });

  final List<String> apodos;
  final void Function(String) onTap;
  final Future<void> Function(String) onForget;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '¿QUIÉN JUEGA?',
          style: GoogleFonts.outfit(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
            color: entryTeal.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final apodo in apodos)
              InputChip(
                key: Key('roster-$apodo'),
                label: Text(
                  apodo,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                avatar: CircleAvatar(
                  backgroundColor: entryTeal.withValues(alpha: 0.25),
                  child: Text(
                    initialOf(apodo),
                    style: GoogleFonts.baloo2(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                backgroundColor: entryCard,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                onPressed: () => onTap(apodo),
                onDeleted: () => onForget(apodo),
                deleteIcon: const Icon(Icons.close, size: 16),
                deleteButtonTooltipMessage:
                    'Olvidar $apodo en este dispositivo',
              ),
          ],
        ),
      ],
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

/// Mismo lenguaje visual que el campo de apodo, con el ojo de mostrar/ocultar
/// en el sitio del dado.
class _PasswordField extends StatelessWidget {
  const _PasswordField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isValid,
    required this.visible,
    required this.onToggleVisibility,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isValid;
  final bool visible;
  final VoidCallback onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    final borderColor = isValid
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
              focusNode: focusNode,
              obscureText: !visible,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Tu contraseña',
                hintStyle: GoogleFonts.outfit(
                  color: Colors.white.withValues(alpha: 0.35),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          IconButton(
            key: const Key('password-visibility'),
            tooltip: visible ? 'Ocultar contraseña' : 'Mostrar contraseña',
            onPressed: onToggleVisibility,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              fixedSize: const Size(44, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: Icon(
              visible ? Icons.visibility_off : Icons.visibility,
              color: entryTeal,
            ),
          ),
        ],
      ),
    );
  }
}
