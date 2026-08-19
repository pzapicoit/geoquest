import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

import '../mapa/mapa_mundi.dart';
import '../mapa/mapa_mundi_controller.dart';
import '../services/nivel_juego_gateway.dart';
import 'cuenta_atras_de_desafio.dart';
import 'resumen_nivel_screen.dart';

const _ink = Color(0xFF0E1620);
const _cardBg = Color(0xFF16242F);
const _teal = Color(0xFF2BC0A8);
const _azul = Color(0xFF1B6FA8);
const _gold = Color(0xFFFFC53D);
const _rojo = Color(0xFFFF5A5F);

/// Pantalla de juego de un nivel: arranca un intento real
/// (`iniciar_intento_parada`), muestra la pista de cada desafío en un toast y,
/// al cerrarlo, deja al jugador adivinar sobre el mapa mundial (INT-92).
///
/// Confirmar manda el pin a `responder_desafio` y revela el resultado sobre el
/// mismo mapa (INT-93): la ubicación real, el encuadre de los dos pines, la
/// línea entre ellos y los contadores de distancia y puntos. De ahí se avanza
/// con "Siguiente", o con "Ver resultados" en el último desafío, que cierra
/// el intento (`cerrar_intento_parada`) y entra en el resumen del nivel
/// (INT-94).
class NivelJuegoScreen extends StatefulWidget {
  const NivelJuegoScreen({
    super.key,
    required this.caminoId,
    this.nivelNombre,
    this.nivelOrden,
    this.tematicaNombre,
    this.gateway,
    this.cargadorDeMundo,
    this.ahora,
  });

  final String caminoId;

  /// Nombre que se enseña en el HUD. Llega desde el camino, que ya lo tiene
  /// cargado (D9 de `design.md`), en vez de costar una consulta extra.
  final String? nivelNombre;

  /// Posición del nivel en el camino del jugador y nombre de su temática,
  /// para el rótulo "Nivel N · Zona" del resumen (D4 de `design.md` de
  /// INT-94). El camino ya los tiene cargados, mismo motivo que
  /// `nivelNombre`.
  final int? nivelOrden;
  final String? tematicaNombre;

  /// Inyectable para poder probar la pantalla sin salir a la red.
  final NivelJuegoGateway? gateway;

  /// Inyectable para poder probar la pantalla sin leer el asset del mundo.
  final CargadorDeMundo? cargadorDeMundo;

  /// Reloj de pared del que cuelga la cuenta atrás del desafío. Inyectable
  /// porque `flutter_test` no falsea el reloj global (D2 de `design.md`): sin
  /// esto no hay forma de provocar que se agote el tiempo en un test.
  final DateTime Function()? ahora;

  @override
  State<NivelJuegoScreen> createState() => _NivelJuegoScreenState();
}

/// Lo que la pantalla necesita recordar mientras enseña el resultado de una
/// jugada. Sin banderas sueltas (D8 de `design.md`): o hay revelado con todos
/// sus datos, o no hay revelado.
class _Revelado {
  const _Revelado({
    required this.respuesta,
    required this.pin,
    required this.desafio,
    required this.esElUltimo,
  });

  final RespuestaDesafio respuesta;

  /// Dónde había clavado el pin el jugador al confirmar. `null` cuando el
  /// tiempo se agotó sin que hubiera ningún pin colocado (INT-99): el
  /// revelado se simplifica a solo ubicación real y puntos (D13 de
  /// `design.md`).
  final Coordenada? pin;

  /// El desafío respondido, para la miniatura de su pista.
  final DesafioJuego desafio;

  final bool esElUltimo;

  Coordenada get ubicacionReal => Coordenada(
    latitud: respuesta.latitudReal,
    longitud: respuesta.longitudReal,
  );
}

class _NivelJuegoScreenState extends State<NivelJuegoScreen>
    with TickerProviderStateMixin {
  /// Coreografía del revelado, con los tiempos del diseño (D4 de
  /// `design.md`): una sola fuente de tiempo para los cinco tramos.
  static const Duration _duracionDelRevelado = Duration(milliseconds: 5440);
  static const int _pinRealDesde = 620;
  static const int _pinRealHasta = 1140;
  static const int _encuadreDesde = 1140;
  static const int _encuadreHasta = 2540;
  static const int _lineaDesde = 2540;
  static const int _lineaHasta = 3540;
  static const int _distanciaDesde = 3540;
  static const int _distanciaHasta = 4540;
  static const int _puntosDesde = 4540;
  static const int _puntosHasta = 5440;

  late final NivelJuegoGateway _gateway =
      widget.gateway ?? SupabaseNivelJuegoGateway(Supabase.instance.client);

  final MapaMundiController _mapa = MapaMundiController();

  late final AnimationController _coreografia = AnimationController(
    vsync: this,
    duration: _duracionDelRevelado,
  )..addListener(_alAvanzarLaCoreografia);

  late Future<IntentoNivel> _futuro;

  /// Posición dentro del intento: avanza al pulsar "Siguiente".
  int _indice = 0;
  bool _pistaVisible = true;
  bool _enviando = false;
  bool _cerrando = false;
  int _puntaje = 0;
  String? _mensaje;
  Timer? _temporizadorDelMensaje;
  _Revelado? _revelado;

  /// Cuenta atrás del desafío actual (INT-99, continua desde INT-114).
  /// Arranca al recibir el intento (primer desafío) y en
  /// [_avanzarDesdeElRevelado] (los siguientes), mismos instantes en que se
  /// llama a `marcarDesafioMostrado` (D11 de `design.md`). Se ignora —el HUD
  /// no enseña la barra— mientras hay un revelado en pantalla.
  late final CuentaAtrasDeDesafio _cuentaAtras = CuentaAtrasDeDesafio(
    vsync: this,
    ahora: widget.ahora,
    alAgotarse: _alAgotarseElTiempo,
  );

  /// El intento en curso, para saber a qué desafío responder cuando la cuenta
  /// atrás se agota sola.
  IntentoNivel? _intento;

  /// Encuadre desde el que arranca la animación de cámara: el que tenía el
  /// jugador al confirmar. Se guarda para poder repetir la animación.
  CamaraMapa? _camaraDelJugador;
  CamaraMapa? _camaraDelRevelado;

  /// Tamaño del mapa cuando se calculó [_camaraDelRevelado]. Si cambia a media
  /// animación (una rotación), ese encuadre hay que recalcularlo.
  Size? _tamanoDelRevelado;

  @override
  void initState() {
    super.initState();
    _iniciarIntento();
  }

  @override
  void dispose() {
    _temporizadorDelMensaje?.cancel();
    _cuentaAtras.dispose();
    _coreografia.dispose();
    _mapa.dispose();
    super.dispose();
  }

  /// Arranca —o relanza, si el intento anterior falló— la carga del
  /// intento. Encadena el arranque de la cuenta atrás del primer desafío en
  /// cuanto la RPC responde (D11 de `design.md`): no puede hacerse antes,
  /// porque hasta entonces no se conoce `segundosPorDesafio` ni el primer
  /// desafío del intento. El error se traga aquí a propósito: quien ya
  /// escucha `_futuro` (el `FutureBuilder` de [build]) es quien enseña el
  /// estado de error, así que no hace falta un segundo manejador.
  void _iniciarIntento() {
    final futuro = _gateway.iniciarIntento(widget.caminoId);
    _futuro = futuro;
    futuro.then(_alCargarElIntento, onError: (Object _) {});
  }

  void _alCargarElIntento(IntentoNivel intento) {
    if (!mounted || intento.desafios.isEmpty) return;
    _arrancarCuentaAtras(intento, intento.desafios[_indice].id);
  }

  void _cerrarPista() => setState(() => _pistaVisible = false);

  void _abrirPista() => setState(() => _pistaVisible = true);

  void _avisar(String mensaje) {
    setState(() => _mensaje = mensaje);
    _temporizadorDelMensaje?.cancel();
    _temporizadorDelMensaje = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _mensaje = null);
    });
  }

  /// Arranca —o reinicia— la cuenta atrás de `desafioId` y marca en el
  /// servidor que se ha vuelto el desafío actual (D1/D2/D11 de
  /// `design.md`). Idempotente en el propio timer: llamarla de nuevo
  /// cancela cualquier cuenta atrás anterior antes de empezar la nueva.
  void _arrancarCuentaAtras(IntentoNivel intento, String desafioId) {
    _intento = intento;
    _cuentaAtras.arrancar(Duration(seconds: intento.segundosPorDesafio));

    // Si esta llamada falla (red, o una app que no la conoce), el servidor
    // trata el desafío como agotado y no da bonus (D6 de `design.md`), pero
    // la partida sigue: no hay razón para bloquear al jugador por un fallo
    // en una llamada que solo afecta al puntaje, nunca a si puede jugar.
    _gateway
        .marcarDesafioMostrado(
          intentoId: intento.intentoId,
          desafioId: desafioId,
        )
        .catchError((Object _) {});
  }

  /// Al llegar la cuenta atrás a 0: con un pin colocado, la misma acción que
  /// "Confirmar"; sin él, una respuesta sin coordenadas (D8/D13 de
  /// `design.md`, requirement "Comportamiento al agotar el tiempo").
  void _alAgotarseElTiempo() {
    final intento = _intento;
    if (!mounted || intento == null || _revelado != null) return;

    if (_mapa.pin != null) {
      _confirmar(intento);
    } else {
      _confirmarSinPin(intento);
    }
  }

  Future<void> _confirmar(IntentoNivel intento) async {
    final pin = _mapa.pin;
    if (pin == null || _enviando) return;

    setState(() => _enviando = true);
    try {
      final respuesta = await _gateway.responderDesafio(
        intentoId: intento.intentoId,
        desafioId: intento.desafios[_indice].id,
        latitud: pin.latitud,
        longitud: pin.longitud,
      );
      if (!mounted) return;

      _cuentaAtras.parar();
      setState(() {
        _enviando = false;
        _revelado = _Revelado(
          respuesta: respuesta,
          pin: pin,
          desafio: intento.desafios[_indice],
          esElUltimo: _indice >= intento.desafios.length - 1,
        );
      });
      _lanzarElRevelado();
    } catch (_) {
      if (!mounted) return;
      // El pin se conserva: el jugador ya había decidido dónde, y volver a
      // colocarlo tras un fallo de red sería castigarle por la red.
      setState(() => _enviando = false);
      _avisar('No se pudo enviar tu respuesta. Inténtalo de nuevo.');
    }
  }

  /// Registra una respuesta sin coordenadas: el tiempo se agotó y el jugador
  /// no había colocado ningún pin (D7/D13 de `design.md`). El servidor
  /// persiste 0 puntos sin distancia; el revelado que sigue se simplifica en
  /// consecuencia (sin pin del jugador, sin línea, sin contador de
  /// distancia).
  Future<void> _confirmarSinPin(IntentoNivel intento) async {
    if (_enviando) return;

    setState(() => _enviando = true);
    try {
      final respuesta = await _gateway.responderDesafio(
        intentoId: intento.intentoId,
        desafioId: intento.desafios[_indice].id,
        latitud: null,
        longitud: null,
      );
      if (!mounted) return;

      _cuentaAtras.parar();
      setState(() {
        _enviando = false;
        _revelado = _Revelado(
          respuesta: respuesta,
          pin: null,
          desafio: intento.desafios[_indice],
          esElUltimo: _indice >= intento.desafios.length - 1,
        );
      });
      _lanzarElRevelado();
    } catch (_) {
      if (!mounted) return;
      setState(() => _enviando = false);
      _avisar('No se pudo enviar tu respuesta. Inténtalo de nuevo.');
    }
  }

  /// Márgenes que el encuadre del revelado tiene que respetar: arriba el HUD,
  /// abajo la hoja de resultado. Son las proporciones del diseño (20 % y 48 %
  /// de la altura), no píxeles fijos, para que en una pantalla pequeña la hoja
  /// tampoco tape un pin.
  EdgeInsets get _margenesDelRevelado {
    final alto = _mapa.tamano.height;
    return EdgeInsets.fromLTRB(62, alto * 0.2, 62, alto * 0.48);
  }

  /// Lanza —o relanza— la coreografía del revelado. Repetirla no vuelve a
  /// llamar al servidor: todo lo que hace falta está ya en [_revelado] (D11).
  void _lanzarElRevelado() {
    final revelado = _revelado;
    if (revelado == null) return;

    final origen = _camaraDelJugador ??= _mapa.camara;
    _mapa
      ..limpiarRevelado()
      ..aplicarCamara(origen);
    _calcularElEncuadreDelRevelado(revelado);

    _coreografia.forward(from: 0);
  }

  void _calcularElEncuadreDelRevelado(_Revelado revelado) {
    _tamanoDelRevelado = _mapa.tamano;
    _camaraDelRevelado = _mapa.camaraPara([
      // Sin pin, el encuadre solo tiene que enseñar la ubicación real: no
      // hay un segundo punto que encajar junto a ella (D13).
      if (revelado.pin != null) revelado.pin!,
      revelado.ubicacionReal,
    ], margenes: _margenesDelRevelado);
  }

  /// Cuánto ha avanzado el tramo que va de [desdeMs] a [hastaMs], de 0 a 1.
  double _tramo(int desdeMs, int hastaMs) {
    final transcurrido =
        _coreografia.value * _duracionDelRevelado.inMilliseconds;
    return ((transcurrido - desdeMs) / (hastaMs - desdeMs)).clamp(0.0, 1.0);
  }

  /// Lo que la coreografía empuja al mapa: el pin real, el encuadre y la
  /// línea. Los contadores no pasan por aquí — los leen sus propios widgets
  /// para no reconstruir la pantalla entera en cada fotograma (D8).
  void _alAvanzarLaCoreografia() {
    final revelado = _revelado;
    if (revelado == null) return;

    if (_tramo(_pinRealDesde, _pinRealHasta) > 0 && _mapa.pinReal == null) {
      _mapa.revelarUbicacion(
        revelado.ubicacionReal,
        nombre: revelado.respuesta.nombreLugar,
      );
    }

    // Si la pantalla ha cambiado de tamaño a media animación —el teclado, las
    // barras del sistema o un Split View; desde INT-102 ya no una rotación—,
    // el encuadre de destino que se calculó al arrancar ya no sirve: se
    // recalcula y se sale desde donde esté la cámara ahora. Llegar bien a un
    // encuadre nuevo importa más que la suavidad del tramo que quedaba.
    if (_tamanoDelRevelado != _mapa.tamano) {
      _camaraDelJugador = _mapa.camara;
      _calcularElEncuadreDelRevelado(revelado);
    }

    final origen = _camaraDelJugador;
    final destino = _camaraDelRevelado;
    final encuadre = _tramo(_encuadreDesde, _encuadreHasta);
    if (encuadre > 0 && origen != null && destino != null) {
      _mapa.aplicarCamara(
        CamaraMapa.interpolar(
          origen,
          destino,
          Curves.easeInOutCubic.transform(encuadre),
        ),
      );
    }

    _mapa.progresoDeLaLinea = _tramo(_lineaDesde, _lineaHasta);
  }

  /// Los contadores suben con una desaceleración, como el `1 - (1 - t)³` del
  /// diseño.
  double get _avanceDeLaDistancia =>
      Curves.easeOutCubic.transform(_tramo(_distanciaDesde, _distanciaHasta));

  double get _avanceDeLosPuntos =>
      Curves.easeOutCubic.transform(_tramo(_puntosDesde, _puntosHasta));

  int get _puntosDelContador {
    final revelado = _revelado;
    if (revelado == null) return 0;
    return (revelado.respuesta.puntos * _avanceDeLosPuntos).round();
  }

  /// Puntaje del intento contando la jugada que se está revelando, que ya está
  /// registrada en el servidor.
  int get _puntajeConElRevelado =>
      _puntaje + (_revelado?.respuesta.puntos ?? 0);

  void _avanzarDesdeElRevelado(IntentoNivel intento) {
    final revelado = _revelado;
    if (revelado == null) return;

    if (revelado.esElUltimo) {
      _cerrarYVerResultados(intento);
      return;
    }

    _coreografia.stop();
    _mapa
      ..limpiarPin()
      ..limpiarRevelado()
      ..reiniciarEncuadre();
    final siguiente = _indice + 1;
    setState(() {
      _puntaje += revelado.respuesta.puntos;
      _indice = siguiente;
      _pistaVisible = true;
      _revelado = null;
      _camaraDelJugador = null;
      _camaraDelRevelado = null;
      _tamanoDelRevelado = null;
    });
    _arrancarCuentaAtras(intento, intento.desafios[siguiente].id);
  }

  /// Cierra el intento al terminar el último desafío y, si sale bien, entra
  /// en el resumen del nivel en vez de volver directamente al camino (D11
  /// de `design.md` de INT-94: es el único punto en que la pantalla sabe
  /// con certeza que el jugador ya vio el último revelado).
  Future<void> _cerrarYVerResultados(IntentoNivel intento) async {
    if (_cerrando) return;

    setState(() => _cerrando = true);
    try {
      final resultado = await _gateway.cerrarIntento(intento.intentoId);
      if (!mounted) return;

      setState(() => _cerrando = false);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResumenNivelScreen(
            resultado: resultado,
            caminoId: widget.caminoId,
            nivelNombre: widget.nivelNombre,
            nivelOrden: widget.nivelOrden,
            tematicaNombre: widget.tematicaNombre,
            totalDesafios: intento.desafios.length,
            gateway: _gateway,
            cargadorDeMundo: widget.cargadorDeMundo,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      // El revelado se conserva en pantalla: el jugador ya lo vio entero,
      // perderlo por un fallo de red además de tener que reintentar sería
      // castigarle dos veces por lo mismo.
      setState(() => _cerrando = false);
      _avisar('No se pudo cerrar el nivel. Inténtalo de nuevo.');
    }
  }

  Future<void> _pedirSalir() async {
    final salir = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0xC7060E14),
      builder: (_) =>
          _ModalSalir(puntaje: _puntajeConElRevelado, posicion: _indice + 1),
    );
    if (salir == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ink,
      body: FutureBuilder<IntentoNivel>(
        future: _futuro,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: _teal));
          }

          // `setState(_iniciarIntento)` en vez de reasignar `_futuro` a mano:
          // así un reintento también encadena el arranque de la cuenta atrás
          // del primer desafío si esta vez la carga sale bien.
          void reintentar() => setState(_iniciarIntento);

          if (snapshot.hasError) {
            return SafeArea(child: _ErrorIntento(onRetry: reintentar));
          }

          final desafios = snapshot.data!.desafios;
          if (desafios.isEmpty) {
            return SafeArea(
              child: _ErrorIntento(
                mensaje: 'Este nivel todavía no tiene desafíos disponibles',
                onRetry: reintentar,
              ),
            );
          }

          final intento = snapshot.data!;
          final desafioActual = desafios[_indice];
          final revelado = _revelado;
          final revelando = revelado != null;

          return Stack(
            children: [
              Positioned.fill(
                child: MapaMundi(
                  controller: _mapa,
                  cargador: widget.cargadorDeMundo,
                  // La jugada ya está cerrada: el encuadre lo lleva la
                  // coreografía y el pin no se mueve de donde se confirmó.
                  interactivo: !revelando,
                ),
              ),
              const Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 150,
                child: IgnorePointer(child: _DegradadoSuperior()),
              ),
              // Aviso periférico de que se acaba el tiempo: por encima del
              // mapa, por debajo del HUD y sin recibir toques (D7).
              if (!revelando)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _cuentaAtras,
                      builder: (context, _) => _MarcoDeTiempoCritico(
                        opacidad: opacidadDelMarcoCritico(
                          restante: _cuentaAtras.restante,
                          umbral: _cuentaAtras.umbralCritico,
                          conLatido: !MediaQuery.of(context).disableAnimations,
                        ),
                      ),
                    ),
                  ),
                ),
              if (!revelando && !_pistaVisible)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AnimatedBuilder(
                    animation: _mapa,
                    builder: (context, _) => _ControlesAdivinar(
                      pin: _mapa.pin,
                      enviando: _enviando,
                      onVerPista: _abrirPista,
                      onConfirmar: () => _confirmar(intento),
                    ),
                  ),
                ),
              if (!revelando && _pistaVisible)
                Positioned.fill(
                  child: _ToastPista(
                    desafio: desafioActual,
                    posicion: _indice + 1,
                    onListo: _cerrarPista,
                  ),
                ),
              if (revelando)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AnimatedBuilder(
                    animation: _coreografia,
                    builder: (context, _) => _HojaDeRevelado(
                      revelado: revelado,
                      distanciaKm: revelado.respuesta.distanciaKm == null
                          ? null
                          : revelado.respuesta.distanciaKm! *
                                _avanceDeLaDistancia,
                      puntos: _puntosDelContador,
                      avanceDelDestello: _avanceDeLosPuntos,
                      cerrando: _cerrando,
                      onContinuar: () => _avanzarDesdeElRevelado(intento),
                      onRepetir: _lanzarElRevelado,
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: AnimatedBuilder(
                  animation: _coreografia,
                  builder: (context, _) => _HudJuego(
                    posicion: _indice + 1,
                    total: desafios.length,
                    // El total sube a la vez que el contador de puntos.
                    puntaje: _puntaje + _puntosDelContador,
                    resueltos: _indice + (revelando ? 1 : 0),
                    nombreDelNivel: widget.nivelNombre,
                    onSalir: _pedirSalir,
                    // La barra no corre durante el revelado (D11).
                    cuentaAtras: revelando ? null : _cuentaAtras,
                  ),
                ),
              ),
              if (_mensaje != null)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 110,
                  child: _Aviso(texto: _mensaje!),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Borde rojo fino en el canto de la pantalla mientras el desafío está en zona
/// crítica de tiempo (INT-114, D7 de `design.md`).
///
/// Es un aviso para la visión periférica: el jugador tiene la vista en el mapa
/// y la barra del HUD pasándose a rojo se le escapa. La opacidad llega ya
/// calculada por [opacidadDelMarcoCritico] —fundido de entrada y latido salen
/// del propio tiempo restante— y se hornea en los colores en vez de envolver
/// todo en un `Opacity`, que en una capa a pantalla completa costaría un
/// `saveLayer` por fotograma.
class _MarcoDeTiempoCritico extends StatelessWidget {
  const _MarcoDeTiempoCritico({required this.opacidad});

  /// Cuánto se mete el marco hacia dentro del área visible, y radio de sus
  /// esquinas (DD1 del delta 1).
  ///
  /// Flutter no dice en ninguna parte el radio de las esquinas del dispositivo,
  /// así que el marco no puede copiarlo: tiene que caber dentro de cualquiera.
  /// Con este margen y este radio, el contorno entra en una pantalla de
  /// esquinas de hasta 76 px de radio —un iPhone reciente ronda los 55—, y en
  /// una pantalla de cantos rectos se ve redondeado, que es igual de bueno. Un
  /// rectángulo recto pegado a los cuatro cantos, en cambio, pierde las cuatro
  /// esquinas en cualquier móvil actual.
  static const double margen = 6;
  static const double radio = 56;

  /// Fino, pero lo justo para verse con el mapa a pantalla completa (DD2).
  static const double grosor = 4;
  static const double grosorDelHalo = 8;

  final double opacidad;

  @override
  Widget build(BuildContext context) {
    if (opacidad <= 0) return const SizedBox.shrink();

    final visible = opacidad.clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.all(margen),
      child: DecoratedBox(
        key: const Key('nivel-juego-marco-critico'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radio),
          border: Border.all(
            color: _rojo.withValues(alpha: visible),
            width: grosor,
          ),
        ),
        // Segundo trazo, más ancho y muy tenue: deja el canto como un halo en
        // vez de una línea dura, sin pintar un degradado.
        //
        // Mismo radio que el de fuera, no uno menor: `DecoratedBox` no mete a
        // su hijo dentro del borde —eso solo lo hace `Container`—, así que los
        // dos trazos comparten rectángulo. Con un radio menor, el halo pasa a
        // ser el contorno más exterior en las esquinas, y entonces es él —y no
        // el borde— quien decide hasta qué redondeo de pantalla cabe el marco:
        // con radio 40 sobre margen 4 se cortaba ya en 53, por debajo de un
        // iPhone. Compartiendo radio los dos contornos coinciden y no hay dos
        // holguras distintas que vigilar.
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radio),
            border: Border.all(
              color: _rojo.withValues(alpha: visible * 0.22),
              width: grosorDelHalo,
            ),
          ),
        ),
      ),
    );
  }
}

class _DegradadoSuperior extends StatelessWidget {
  const _DegradadoSuperior();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xE0060E14), Color(0x8C060E14), Color(0x00060E14)],
          stops: [0, 0.58, 1],
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

/// Capa fija sobre el mapa con salida, progreso y puntaje. Vive fuera del
/// toast (D8 de `design.md`) para seguir visible mientras se adivina, que es
/// justo cuando el jugador quiere saber por dónde va.
class _HudJuego extends StatelessWidget {
  const _HudJuego({
    required this.posicion,
    required this.total,
    required this.puntaje,
    required this.resueltos,
    required this.nombreDelNivel,
    required this.onSalir,
    required this.cuentaAtras,
  });

  final int posicion;
  final int total;
  final int puntaje;

  /// Cuántos desafíos del intento están ya respondidos. Con el revelado en
  /// pantalla incluye el que se está enseñando.
  final int resueltos;

  final String? nombreDelNivel;
  final VoidCallback onSalir;

  /// `null` mientras se enseña el revelado: la cuenta atrás (INT-99) no
  /// corre en esa fase, así que la barra no se pinta (D11 de `design.md`).
  final CuentaAtrasDeDesafio? cuentaAtras;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _BotonDeCristal(
                  clave: const Key('nivel-juego-salir'),
                  etiqueta: 'Salir del nivel',
                  onPressed: onSalir,
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TarjetaDeProgreso(
                    posicion: posicion,
                    total: total,
                    resueltos: resueltos,
                    nombreDelNivel: nombreDelNivel,
                  ),
                ),
                const SizedBox(width: 10),
                _PildoraDePuntaje(puntaje: puntaje),
              ],
            ),
            if (cuentaAtras != null) ...[
              const SizedBox(height: 8),
              _CuentaAtras(cuentaAtras: cuentaAtras!),
            ],
          ],
        ),
      ),
    );
  }
}

class _TarjetaDeProgreso extends StatelessWidget {
  const _TarjetaDeProgreso({
    required this.posicion,
    required this.total,
    required this.resueltos,
    required this.nombreDelNivel,
  });

  final int posicion;
  final int total;
  final int resueltos;
  final String? nombreDelNivel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 9),
      decoration: BoxDecoration(
        color: _ink.withValues(alpha: 0.6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  'Desafío $posicion de $total',
                  key: const Key('nivel-juego-progreso'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.baloo2(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (nombreDelNivel != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    nombreDelNivel!.toUpperCase(),
                    key: const Key('nivel-juego-nombre-nivel'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 7),
          Row(
            key: const Key('nivel-juego-segmentos'),
            children: [
              for (var i = 0; i < total; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: switch (i) {
                        _ when i < resueltos => _teal,
                        _ when i == posicion - 1 => _gold,
                        _ => Colors.white.withValues(alpha: 0.16),
                      },
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PildoraDePuntaje extends StatelessWidget {
  const _PildoraDePuntaje({required this.puntaje});

  final int puntaje;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.16),
        border: Border.all(color: _gold.withValues(alpha: 0.42), width: 1.5),
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
          const SizedBox(width: 6),
          Text(
            formatearPuntaje(puntaje),
            key: const Key('nivel-juego-puntaje'),
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

/// Separador de millares a la española, sin depender de `intl`.
String formatearPuntaje(int puntaje) {
  final digitos = puntaje.abs().toString();
  final partes = <String>[];
  for (var fin = digitos.length; fin > 0; fin -= 3) {
    partes.insert(0, digitos.substring(fin - 3 < 0 ? 0 : fin - 3, fin));
  }
  return '${puntaje < 0 ? '-' : ''}${partes.join('.')}';
}

/// "1:00", "0:09": minutos y segundos con dos dígitos, como un cronómetro.
String formatearCuentaAtras(int segundos) {
  final acotado = segundos < 0 ? 0 : segundos;
  final minutos = acotado ~/ 60;
  final resto = acotado % 60;
  return '$minutos:${resto.toString().padLeft(2, '0')}';
}

/// Color de la barra de cuenta atrás según el tiempo que queda (D10 de
/// `design.md` de INT-99, afinado en D6 de INT-114): teal por encima de la
/// mitad, ámbar entre la mitad y la zona crítica, rojo dentro de ella. El
/// umbral rojo no se recalcula aquí — lo decide la propia cuenta atrás, para
/// que barra y marco no puedan desincronizarse.
Color _colorDeLaCuentaAtras(CuentaAtrasDeDesafio cuenta) {
  if (cuenta.total <= Duration.zero) return _teal;
  if (cuenta.enZonaCritica) return _rojo;
  return cuenta.fraccion > 0.5 ? _teal : _gold;
}

/// Barra de cuenta atrás del desafío actual (INT-99): vive en el HUD, por
/// encima del toast de pista, para que el jugador sepa siempre cuánto tiempo
/// le queda sin tener que cerrar nada.
///
/// El `AnimatedBuilder` va por dentro a propósito (D4 de INT-114): el relleno
/// se repinta en cada fotograma, así que lo que se reconstruye tiene que ser
/// solo esta fila y no el `Stack` de la pantalla, que lleva el mapa.
class _CuentaAtras extends StatelessWidget {
  const _CuentaAtras({required this.cuentaAtras});

  final CuentaAtrasDeDesafio cuentaAtras;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('nivel-juego-cuenta-atras'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _ink.withValues(alpha: 0.6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: AnimatedBuilder(
        animation: cuentaAtras,
        builder: (context, _) {
          final color = _colorDeLaCuentaAtras(cuentaAtras);

          return Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: cuentaAtras.fraccion,
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.16),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                // La etiqueta se queda en segundos enteros: continua sería un
                // número ilegible cambiando 60 veces por segundo (D5).
                formatearCuentaAtras(cuentaAtras.segundosParaLaEtiqueta),
                key: const Key('nivel-juego-cuenta-atras-etiqueta'),
                style: GoogleFonts.baloo2(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Controles de la fase de adivinar: reabrir la pista, la indicación de qué
/// hacer y el botón de confirmar.
class _ControlesAdivinar extends StatelessWidget {
  const _ControlesAdivinar({
    required this.pin,
    required this.enviando,
    required this.onVerPista,
    required this.onConfirmar,
  });

  final Coordenada? pin;
  final bool enviando;
  final VoidCallback onVerPista;
  final VoidCallback onConfirmar;

  @override
  Widget build(BuildContext context) {
    final habilitado = pin != null && !enviando;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xE6060E14), Color(0x80060E14), Color(0x00060E14)],
          stops: [0, 0.52, 1],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BotonVerPista(onPressed: onVerPista),
              const SizedBox(height: 14),
              Align(child: _PildoraDeIndicacion(pin: pin)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: habilitado
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [_teal, _azul],
                          )
                        : null,
                    color: habilitado
                        ? null
                        : Colors.white.withValues(alpha: 0.08),
                    boxShadow: habilitado
                        ? const [
                            BoxShadow(
                              color: Color(0x990B4266),
                              offset: Offset(0, 6),
                            ),
                          ]
                        : null,
                  ),
                  child: TextButton(
                    key: const Key('nivel-juego-confirmar'),
                    onPressed: habilitado ? onConfirmar : null,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 19),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      'Confirmar',
                      style: GoogleFonts.baloo2(
                        color: habilitado
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.34),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BotonVerPista extends StatelessWidget {
  const _BotonVerPista({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutBack,
      builder: (context, valor, hijo) =>
          Transform.scale(scale: valor.clamp(0.0, 1.2), child: hijo),
      child: InkWell(
        key: const Key('nivel-juego-ver-pista'),
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 9, 15, 9),
          decoration: BoxDecoration(
            color: _ink.withValues(alpha: 0.78),
            border: Border.all(color: _teal.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [
              BoxShadow(
                color: Color(0x59000000),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_teal, _azul],
                  ),
                ),
                child: const Icon(
                  Icons.lightbulb_outline_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 9),
              Text(
                'Ver la pista',
                style: GoogleFonts.outfit(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PildoraDeIndicacion extends StatelessWidget {
  const _PildoraDeIndicacion({required this.pin});

  final Coordenada? pin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _ink.withValues(alpha: 0.72),
        border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: pin == null
            ? [
                const _PuntoQueLate(),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(
                    'Toca el mapa para colocar tu pin',
                    key: const Key('nivel-juego-indicacion-sin-pin'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ]
            : [
                const Icon(Icons.place_outlined, color: _rojo, size: 14),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(
                    'Toca para ajustar',
                    key: const Key('nivel-juego-indicacion-con-pin'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(
                    formatearCoordenadas(pin!),
                    key: const Key('nivel-juego-coordenadas'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.42),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
      ),
    );
  }
}

/// "40,4° N · 3,7° O", con coma decimal y hemisferio, como el mockup.
String formatearCoordenadas(Coordenada coordenada) {
  String grados(double valor, String positivo, String negativo) {
    final texto = valor.abs().toStringAsFixed(1).replaceAll('.', ',');
    return '$texto° ${valor >= 0 ? positivo : negativo}';
  }

  return '${grados(coordenada.latitud, 'N', 'S')} · '
      '${grados(coordenada.longitud, 'E', 'O')}';
}

class _PuntoQueLate extends StatefulWidget {
  const _PuntoQueLate();

  @override
  State<_PuntoQueLate> createState() => _PuntoQueLateState();
}

class _PuntoQueLateState extends State<_PuntoQueLate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controlador,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_controlador.value);
        return Transform.scale(
          scale: 1 + t * 0.14,
          child: Opacity(
            opacity: 0.9 - t * 0.45,
            child: Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _gold,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// "247" o "0,4". El diseño enseña kilómetros enteros y así se dejan, pero por
/// debajo de 10 km se muestra un decimal (D12 de `design.md`): un pin a 400 m
/// del sitio leído como "0 km" parece un fallo justo en el mejor acierto.
String formatearDistancia(double kilometros) {
  if (kilometros < 10) {
    return kilometros.toStringAsFixed(1).replaceAll('.', ',');
  }
  return formatearPuntaje(kilometros.round());
}

/// Hoja de resultado del revelado: de dónde era el lugar, cuánto te has
/// desviado, cuántos puntos te llevas y cómo seguir.
class _HojaDeRevelado extends StatelessWidget {
  const _HojaDeRevelado({
    required this.revelado,
    required this.distanciaKm,
    required this.puntos,
    required this.avanceDelDestello,
    required this.cerrando,
    required this.onContinuar,
    required this.onRepetir,
  });

  final _Revelado revelado;

  /// Valor que enseña el contador de distancia en este fotograma. `null` en
  /// una respuesta sin pin (INT-99): no hay distancia que contar, así que la
  /// hoja se simplifica sin esa tarjeta (D13 de `design.md`).
  final double? distanciaKm;

  /// Valor que enseña el contador de puntos en este fotograma.
  final int puntos;

  final double avanceDelDestello;

  /// `true` mientras `cerrar_intento_parada` está en curso, disparado desde
  /// "Ver resultados" del último desafío (INT-94).
  final bool cerrando;

  final VoidCallback onContinuar;
  final VoidCallback onRepetir;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: const Cubic(0.2, 0.9, 0.3, 1),
      builder: (context, entrada, hijo) => Transform.translate(
        offset: Offset(0, 46 * (1 - entrada.clamp(0.0, 1.0))),
        child: Opacity(opacity: entrada.clamp(0.0, 1.0), child: hijo),
      ),
      child: Container(
        key: const Key('nivel-juego-revelado'),
        decoration: BoxDecoration(
          color: _cardBg,
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x73000000),
              blurRadius: 44,
              offset: Offset(0, -18),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _MiniaturaDeLaPista(desafio: revelado.desafio),
                    const SizedBox(width: 13),
                    Expanded(child: _LugarRevelado(revelado: revelado)),
                  ],
                ),
                const SizedBox(height: 16),
                // Sin pin no hay distancia que contar (D13 de `design.md`):
                // solo la tarjeta de puntos, a toda anchura.
                if (distanciaKm case final distancia?)
                  // Las dos tarjetas miden lo mismo aunque una de ellas parta
                  // el texto de su cabecera en dos líneas.
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _TarjetaDeDistancia(kilometros: distancia),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _TarjetaDePuntos(
                            puntos: puntos,
                            maximo: revelado.respuesta.puntosMaximos,
                            avanceDelDestello: avanceDelDestello,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  _TarjetaDePuntos(
                    puntos: puntos,
                    maximo: revelado.respuesta.puntosMaximos,
                    avanceDelDestello: avanceDelDestello,
                  ),
                // El desglose de precisión/bonus solo tiene sentido con un
                // pin colocado: sin pin, precisión y bonus son ambos 0 (D14).
                if (distanciaKm != null)
                  _DesgloseDePuntaje(
                    puntosDistancia: revelado.respuesta.puntosDistancia,
                    puntosBonus: revelado.respuesta.puntosBonus,
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_teal, _azul],
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x990B4266),
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: TextButton(
                      key: const Key('nivel-juego-siguiente'),
                      onPressed: cerrando ? null : onContinuar,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 19),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: cerrando
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              revelado.esElUltimo
                                  ? 'Ver resultados'
                                  : 'Siguiente',
                              style: GoogleFonts.baloo2(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                ),
                Align(
                  child: TextButton(
                    key: const Key('nivel-juego-repetir'),
                    onPressed: onRepetir,
                    child: Text(
                      'Repetir animación',
                      style: GoogleFonts.outfit(
                        color: Colors.white.withValues(alpha: 0.42),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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

/// Miniatura de la pista original. Solo el desafío de imagen tiene algo que
/// enseñar; para vídeo y pregunta se usa el distintivo de su tipo (D9 de
/// `design.md`).
class _MiniaturaDeLaPista extends StatelessWidget {
  const _MiniaturaDeLaPista({required this.desafio});

  final DesafioJuego desafio;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFDF8), Color(0xFFE9F2F1)],
        ),
      ),
      child: switch (desafio.tipo) {
        TipoDesafio.imagen => Image.network(
          desafio.imagenUrl!,
          key: const Key('nivel-juego-miniatura-imagen'),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _distintivoDelTipo(desafio.tipo),
        ),
        _ => _distintivoDelTipo(desafio.tipo),
      },
    );
  }
}

Widget _distintivoDelTipo(TipoDesafio tipo) {
  return Center(
    child: Icon(
      switch (tipo) {
        TipoDesafio.imagen => Icons.image_outlined,
        TipoDesafio.video => Icons.videocam_rounded,
        TipoDesafio.preguntaTexto => Icons.help_outline_rounded,
      },
      key: const Key('nivel-juego-miniatura-tipo'),
      color: _azul,
      size: 26,
    ),
  );
}

class _LugarRevelado extends StatelessWidget {
  const _LugarRevelado({required this.revelado});

  final _Revelado revelado;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'UBICACIÓN REAL',
          style: GoogleFonts.outfit(
            color: _teal.withValues(alpha: 0.95),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          revelado.respuesta.nombreLugar,
          key: const Key('nivel-juego-lugar'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.baloo2(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          formatearCoordenadas(revelado.ubicacionReal),
          key: const Key('nivel-juego-coordenadas-reales'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _TarjetaDeDistancia extends StatelessWidget {
  const _TarjetaDeDistancia({required this.kilometros});

  final double kilometros;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.change_history_rounded,
                size: 14,
                color: Colors.white.withValues(alpha: 0.45),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'TE HAS DESVIADO',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  formatearDistancia(kilometros),
                  key: const Key('nivel-juego-distancia'),
                  maxLines: 1,
                  style: GoogleFonts.baloo2(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                'km',
                style: GoogleFonts.outfit(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TarjetaDePuntos extends StatelessWidget {
  const _TarjetaDePuntos({
    required this.puntos,
    required this.maximo,
    required this.avanceDelDestello,
  });

  final int puntos;
  final int maximo;
  final double avanceDelDestello;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.12),
        border: Border.all(color: _gold.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
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
                    Expanded(
                      child: Text(
                        'HAS GANADO',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: _gold.withValues(alpha: 0.8),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        '+${formatearPuntaje(puntos)}',
                        key: const Key('nivel-juego-puntos-ganados'),
                        maxLines: 1,
                        style: GoogleFonts.baloo2(
                          color: const Color(0xFFFFE9A8),
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '/ ${formatearPuntaje(maximo)}',
                      key: const Key('nivel-juego-puntos-maximos'),
                      style: GoogleFonts.outfit(
                        color: _gold.withValues(alpha: 0.6),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (avanceDelDestello > 0 && avanceDelDestello < 1)
            Positioned.fill(
              child: IgnorePointer(child: _Destello(avance: avanceDelDestello)),
            ),
        ],
      ),
    );
  }
}

/// Desglose del puntaje en precisión y bonus por rapidez (D14 de
/// `design.md`), para que el jugador entienda de dónde sale el total en vez
/// de ver solo una cifra. Solo se enseña con un pin colocado: sin pin ambos
/// componentes son 0 y no hay nada que desglosar.
class _DesgloseDePuntaje extends StatelessWidget {
  const _DesgloseDePuntaje({
    required this.puntosDistancia,
    required this.puntosBonus,
  });

  final int puntosDistancia;
  final int puntosBonus;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${formatearPuntaje(puntosDistancia)} puntos de precisión',
            key: const Key('nivel-juego-puntos-precision'),
            style: GoogleFonts.outfit(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          // Sin línea de bonus cuando es 0: tiempo agotado, o precisión ya
          // en el suelo de la curva (requirement "El revelado muestra el
          // desglose del bonus por rapidez").
          if (puntosBonus > 0)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                '+${formatearPuntaje(puntosBonus)} por rapidez',
                key: const Key('nivel-juego-puntos-bonus'),
                style: GoogleFonts.outfit(
                  color: _teal,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Brillo que cruza la tarjeta de puntos mientras sube el contador, como el
/// `gq-shine` del diseño.
class _Destello extends StatelessWidget {
  const _Destello({required this.avance});

  final double avance;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, restricciones) {
        const ancho = 42.0;
        final recorrido = restricciones.maxWidth + ancho * 2;

        return Stack(
          children: [
            Positioned(
              left: -ancho + recorrido * avance,
              top: 0,
              bottom: 0,
              width: ancho,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0),
                      Colors.white.withValues(alpha: 0.22),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('nivel-juego-aviso'),
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
      decoration: BoxDecoration(
        color: _ink,
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x80000000),
            blurRadius: 34,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Text(
        texto,
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BotonDeCristal extends StatelessWidget {
  const _BotonDeCristal({
    required this.clave,
    required this.etiqueta,
    required this.onPressed,
    required this.child,
  });

  final Key clave;
  final String etiqueta;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: etiqueta,
      child: InkWell(
        key: clave,
        onTap: onPressed,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _ink.withValues(alpha: 0.6),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _ModalSalir extends StatelessWidget {
  const _ModalSalir({required this.puntaje, required this.posicion});

  final int puntaje;
  final int posicion;

  @override
  Widget build(BuildContext context) {
    final resueltos = posicion > 2 ? '1–${posicion - 1}' : 'anteriores';

    return Dialog(
      backgroundColor: _cardBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 26),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _rojo.withValues(alpha: 0.16),
                border: Border.all(color: _rojo.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: _rojo,
                size: 22,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '¿Salir del nivel?',
              style: GoogleFonts.baloo2(
                color: Colors.white,
                fontSize: 23,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              'Perderás este intento completo: los '
              '${formatearPuntaje(puntaje)} puntos de los desafíos '
              '$resueltos y tendrás que empezar el nivel de nuevo.',
              key: const Key('nivel-juego-salir-detalle'),
              style: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 14.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_teal, _azul],
                  ),
                ),
                child: TextButton(
                  key: const Key('nivel-juego-seguir-jugando'),
                  onPressed: () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 17),
                  ),
                  child: Text(
                    'Seguir jugando',
                    style: GoogleFonts.baloo2(
                      color: Colors.white,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 9),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                key: const Key('nivel-juego-salir-confirmar'),
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: _rojo.withValues(alpha: 0.42)),
                  ),
                ),
                child: Text(
                  'Salir y perder el intento',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFFFF7B7F),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToastPista extends StatelessWidget {
  const _ToastPista({
    required this.desafio,
    required this.posicion,
    required this.onListo,
  });

  final DesafioJuego desafio;
  final int posicion;
  final VoidCallback onListo;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 220),
              builder: (context, valor, _) => ColoredBox(
                color: const Color(0xFF060E14).withValues(alpha: 0.82 * valor),
              ),
            ),
          ),
        ),
        // El cierre al tocar fuera envuelve toda la capa de contenido, no
        // solo el fondo pintado: si no, el área vacía del scroll se comería
        // el toque y la pista no se cerraría.
        Positioned.fill(
          child: GestureDetector(
            key: const Key('nivel-juego-fondo-pista'),
            onTap: onListo,
            behavior: HitTestBehavior.opaque,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 108, 18, 24),
                child: SingleChildScrollView(
                  child: GestureDetector(
                    // La tarjeta no cierra: solo lo hacen sus botones.
                    onTap: () {},
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 320),
                      curve: const Cubic(0.2, 0.9, 0.3, 1),
                      builder: (context, valor, hijo) => Opacity(
                        opacity: valor.clamp(0.0, 1.0),
                        child: Transform.translate(
                          offset: Offset(0, 26 * (1 - valor)),
                          child: Transform.scale(
                            scale: 0.97 + 0.03 * valor,
                            child: hijo,
                          ),
                        ),
                      ),
                      child: _TarjetaDePista(
                        desafio: desafio,
                        posicion: posicion,
                        onListo: onListo,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TarjetaDePista extends StatelessWidget {
  const _TarjetaDePista({
    required this.desafio,
    required this.posicion,
    required this.onListo,
  });

  final DesafioJuego desafio;
  final int posicion;
  final VoidCallback onListo;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x8C000000),
            blurRadius: 60,
            offset: Offset(0, 26),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CabeceraDePista(
            desafio: desafio,
            posicion: posicion,
            onCerrar: onListo,
          ),
          const SizedBox(height: 13),
          _ContenidoPista(desafio: desafio),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              pieDePista(desafio.tipo),
              key: const Key('nivel-juego-pie-pista'),
              style: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_teal, _azul],
                ),
                boxShadow: const [
                  BoxShadow(color: Color(0x990B4266), offset: Offset(0, 6)),
                ],
              ),
              child: TextButton(
                key: const Key('nivel-juego-boton-listo'),
                onPressed: onListo,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Listo, voy a adivinar',
                  style: GoogleFonts.baloo2(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
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

/// Pie explicativo fijo por tipo de pista (D10 de `design.md`): `desafios` no
/// tiene ninguna columna equivalente y el texto no varía por desafío.
String pieDePista(TipoDesafio tipo) => switch (tipo) {
  TipoDesafio.imagen =>
    '¿Dónde se tomó esta imagen? Coloca tu pin lo más cerca que puedas.',
  TipoDesafio.video =>
    '¿Dónde se grabó este vídeo? Coloca tu pin lo más cerca que puedas.',
  TipoDesafio.preguntaTexto =>
    'Coloca tu pin en el lugar que responde a la pregunta.',
};

String kickerDePista(TipoDesafio tipo, int posicion) => switch (tipo) {
  TipoDesafio.imagen => 'FOTO · PISTA $posicion',
  TipoDesafio.video => 'VÍDEO · PISTA $posicion',
  TipoDesafio.preguntaTexto => 'PREGUNTA · PISTA $posicion',
};

class _CabeceraDePista extends StatelessWidget {
  const _CabeceraDePista({
    required this.desafio,
    required this.posicion,
    required this.onCerrar,
  });

  final DesafioJuego desafio;
  final int posicion;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 0, 0),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_teal, _azul],
              ),
            ),
            child: Icon(
              switch (desafio.tipo) {
                TipoDesafio.imagen => Icons.image_outlined,
                TipoDesafio.video => Icons.videocam_outlined,
                TipoDesafio.preguntaTexto => Icons.help_outline_rounded,
              },
              color: Colors.white,
              size: 15,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              kickerDePista(desafio.tipo, posicion),
              key: const Key('nivel-juego-kicker'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                color: _teal.withValues(alpha: 0.95),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.7,
              ),
            ),
          ),
          InkWell(
            key: const Key('nivel-juego-cerrar-pista'),
            onTap: onCerrar,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.close_rounded,
                size: 15,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
      ),
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
      borderRadius: BorderRadius.circular(20),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 34),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _teal.withValues(alpha: 0.28)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _teal.withValues(alpha: 0.16),
            _azul.withValues(alpha: 0.14),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            texto,
            key: const Key('nivel-juego-texto-pregunta'),
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 25,
              height: 1.28,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Sin nombres en el mapa: fíate de la forma de la costa.',
            style: GoogleFonts.outfit(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

/// Vídeo de pista en autoplay, en bucle y sin sonido (D5 de INT-91): son
/// clips ambientales de un lugar, no llevan audio relevante para adivinar.
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
      borderRadius: BorderRadius.circular(20),
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
