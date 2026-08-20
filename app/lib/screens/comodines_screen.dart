import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/anuncios_gateway.dart';
import '../services/comodines_gateway.dart';
import 'entry_motion.dart';

// Paleta y medidas del mock `[App] - Comodines.dc.html` (turno 12a). Los
// valores están copiados literalmente de ahí: si hay que cambiar algo, se
// cambia primero en el mock.
const _bgTop = Color(0xFF102A38);
const _bgMid = Color(0xFF0B1B27);
const _bgBottom = Color(0xFF08131C);

/// `rgba(10,22,34,…)`: el degradado del pie que tapa la lista al hacer scroll.
const _velo = Color(0xFF0A1622);

const _teal = Color(0xFF2BC0A8);
const _tealClaro = Color(0xFF7FE3D2);
const _blue = Color(0xFF1B6FA8);
const _blueClaro = Color(0xFFBFD8EA);
const _gold = Color(0xFFFFC53D);
const _goldClaro = Color(0xFFFFE9A8);

/// Tinta del contador `×N` sobre el chip turquesa.
const _tintaChip = Color(0xFF052A24);

/// Placa de la cifra sobre el arte: los mismos azul y dorado que la que venía
/// pintada en los iconos cuadrados viejos (`Recursos/comodines/7.png` y
/// `8.png`), para que se vea como parte de la ilustración.
const _placaFondo = Color(0xFF1B5FC0);
const _placaBorde = Color(0xFFFFC42E);

const _fondoHoja = Color(0xFF12202B);
const _fondoToast = Color(0xFF16242F);
const _rojoError = Color(0xFFFF9B9E);

/// Alto del arte de cada comodín. El mock usa 132 px sobre un ancho de
/// contenido de 354 px (390 − 2×18): exactamente la proporción 8:3 de los PNG
/// de `assets/comodines/arte_*.png` (2048×768), así que `BoxFit.cover` no
/// llega a recortar nada.
const _altoArte = 132.0;

/// Hueco que el pie fijo le roba a la lista (`padding-bottom:132px` del mock).
const _huecoPie = 132.0;

/// `radial-gradient(150% 52% at 50% -6%, rgba(43,192,168,.22), transparent 62%)`
/// del mock. Flutter no tiene degradados radiales elípticos, así que se usa el
/// círculo equivalente en anchura; con un 22 % de opacidad la diferencia de
/// alto no se distingue.
const _resplandorSuperior = RadialGradient(
  center: Alignment(0, -1.12),
  radius: 1.5,
  colors: [Color(0x382BC0A8), Color(0x002BC0A8)],
  stops: [0, 0.62],
);

/// `radial-gradient(90% 40% at 12% 84%, rgba(27,111,168,.18), transparent 70%)`.
const _resplandorInferior = RadialGradient(
  center: Alignment(-0.76, 0.68),
  radius: 0.9,
  colors: [Color(0x2E1B6FA8), Color(0x001B6FA8)],
  stops: [0, 0.70],
);

/// `filter: grayscale(.9) brightness(.62)` del mock para un comodín agotado:
/// la matriz de `grayscale()` de CSS con `s = 1 − .9 = .1`, con cada fila
/// multiplicada por el `.62` de `brightness()`.
const List<double> _matrizAgotado = <double>[
  0.1806, 0.3991, 0.0403, 0, 0, //
  0.1186, 0.4611, 0.0403, 0, 0, //
  0.1186, 0.3991, 0.1023, 0, 0, //
  0, 0, 0, 1, 0, //
];

/// Nombre de cada tipo. El mock trae otros títulos ("A menos de 1 000 km",
/// "Congela el cronómetro 15 s"), pero se quedaron obsoletos cuando delta-1 de
/// INT-119 recortó los radios a 500/150 km y dejó `tiempo` sin límite en vez
/// de +15 s, así que aquí manda el comportamiento real del juego.
String _nombre(ComodinTipo tipo) => switch (tipo) {
  ComodinTipo.tiempo => 'Sin límite de tiempo',
  ComodinTipo.pais => 'País',
  ComodinTipo.km1000 => 'Radio 500 km',
  ComodinTipo.km500 => 'Radio 150 km',
};

String _descripcion(ComodinTipo tipo) => switch (tipo) {
  ComodinTipo.tiempo =>
    'Detiene el cronómetro: respondes esta pregunta sin límite de tiempo.',
  ComodinTipo.pais =>
    'Revela el país real del objetivo, sin desvelar el lugar exacto.',
  ComodinTipo.km1000 =>
    'Dibuja en el mapa un círculo de 500 km alrededor del objetivo real.',
  ComodinTipo.km500 =>
    'Dibuja en el mapa un círculo de 150 km alrededor del objetivo real.',
};

/// Arte ancho de cada tipo, el que pide el mock (`assets/cmd-*.png` allí).
/// Antes esta pantalla usaba los iconos cuadrados `icono_*.png`, que son los
/// de la bandeja de la pantalla de juego, no los de este inventario.
String _assetArte(ComodinTipo tipo) => switch (tipo) {
  ComodinTipo.tiempo => 'assets/comodines/arte_tiempo.png',
  ComodinTipo.pais => 'assets/comodines/arte_pais.png',
  ComodinTipo.km1000 => 'assets/comodines/arte_km1000.png',
  ComodinTipo.km500 => 'assets/comodines/arte_km500.png',
};

/// Cifra que se dibuja sobre el arte, para los dos comodines de radio. El arte
/// (`Recursos/comodines/1..4.png`) viene limpio a propósito: los cuadrados que
/// llevaban la placa pintada (`7.png`, `8.png`) se quedaron con "< 1000 km" y
/// "< 500 km" cuando delta-1 recortó los radios, y una cifra en el PNG no se
/// puede corregir desde el código. Aquí la ponemos nosotros y sigue al backend.
String? _cifraSobreArte(ComodinTipo tipo) => switch (tipo) {
  ComodinTipo.km1000 => '< 500 km',
  ComodinTipo.km500 => '< 150 km',
  ComodinTipo.tiempo || ComodinTipo.pais => null,
};

/// `agotado` / `1 unidad` / `N unidades` del mock (se pinta en mayúsculas,
/// como el `text-transform:uppercase` de ahí).
String _etiquetaCantidad(int cantidad) => switch (cantidad) {
  0 => 'agotado',
  1 => '1 unidad',
  _ => '$cantidad unidades',
};

/// Separador de millares a la española, sin depender de `intl` (duplicado a
/// propósito: `camino_screen.dart`/`ranking_screen.dart` llevan cada uno el
/// suyo, no hay un módulo de utilidades compartido en la app).
String _formatMiles(int n) {
  final texto = n.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < texto.length; i++) {
    if (i > 0 && (texto.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(texto[i]);
  }
  return buffer.toString();
}

/// Aviso flotante con la pinta del `gq-toast3` del mock (`#16242F`, borde
/// blanco al 14 %, radio 16, 2 s) en vez del `SnackBar` por defecto de
/// Material. Lo usan todos los avisos de la pantalla y de su hoja.
void _mostrarAviso(BuildContext context, String mensaje, {Key? clave}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          mensaje,
          key: clave,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 13,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _fondoToast,
        elevation: 8,
        // `bottom:112px` del mock, medido para quedar justo encima del botón
        // "Obtener más comodines".
        margin: const EdgeInsets.only(left: 18, right: 18, bottom: 96),
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        ),
      ),
    );
}

/// Pantalla Comodines (INT-119): inventario real de los 4 tipos y la hoja
/// "Obtener más" — el vídeo publicitario es funcional (`RewardedAd` bajo
/// demanda, INT-117 delta-1); "canjear puntos" y "pack explorador" se
/// enseñan sin acción real, con un aviso de "próximamente" al tocarlas.
class ComodinesScreen extends StatefulWidget {
  const ComodinesScreen({
    super.key,
    required this.puntosTotales,
    this.gateway,
    this.anunciosGateway,
  });

  /// Puntos totales del jugador, ya cargados por quien navega aquí (mismo
  /// motivo que `RankingScreen.puntosTotales` en `camino_screen.dart`, D2 de
  /// su design.md): evita repetir `CaminoGateway.fetchCamino()` solo para
  /// el badge de la cabecera.
  final int puntosTotales;

  /// Inyectable para poder probar la pantalla sin salir a la red.
  final ComodinesGateway? gateway;

  /// Inyectable para el flujo de "Ver un anuncio" (INT-117 delta-1); se
  /// reenvía desde `CaminoScreen`, igual que `gateway`.
  final AnunciosGateway? anunciosGateway;

  @override
  State<ComodinesScreen> createState() => _ComodinesScreenState();
}

class _ComodinesScreenState extends State<ComodinesScreen> {
  late final ComodinesGateway _gateway =
      widget.gateway ?? SupabaseComodinesGateway(Supabase.instance.client);
  late final AnunciosGateway _anunciosGateway =
      widget.anunciosGateway ?? AdMobAnunciosGateway(Supabase.instance.client);

  late Future<InventarioComodines> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = _gateway.misComodines();
  }

  void _recargar() {
    setState(() {
      _futuro = _gateway.misComodines();
    });
  }

  void _mostrarDescripcion(ComodinTipo tipo) =>
      _mostrarAviso(context, _descripcion(tipo));

  Future<void> _abrirObtenerMas() async {
    final concedido = await showModalBottomSheet<ComodinTipo>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      // `rgba(4,10,16,.68)` del mock, en vez del velo negro de Material.
      barrierColor: const Color(0xAD040A10),
      builder: (_) =>
          _HojaObtenerMas(gateway: _gateway, anunciosGateway: _anunciosGateway),
    );
    if (!mounted || concedido == null) return;

    _recargar();
    _mostrarAviso(context, '¡Has ganado 1 comodín de ${_nombre(concedido)}!');
  }

  @override
  Widget build(BuildContext context) {
    // El pie va fijo sobre la lista (`position:absolute` del mock), así que
    // la lista tiene que reservar su alto más lo que ocupe el indicador de
    // inicio del sistema, que en el mock no existe.
    final insetAbajo = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgMid, _bgBottom],
            stops: [0, 0.46, 1],
          ),
        ),
        // Los dos resplandores del mock, uno encima del otro: sin ellos el
        // fondo queda plano y se pierde el aire turquesa de la cabecera.
        child: DecoratedBox(
          decoration: const BoxDecoration(gradient: _resplandorSuperior),
          child: DecoratedBox(
            decoration: const BoxDecoration(gradient: _resplandorInferior),
            child: FutureBuilder<InventarioComodines>(
              future: _futuro,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: CircularProgressIndicator(color: _teal),
                  );
                }
                if (snapshot.hasError) {
                  return SafeArea(child: _ErrorComodines(onRetry: _recargar));
                }

                final inventario = snapshot.data!;
                return Stack(
                  children: [
                    SafeArea(
                      bottom: false,
                      child: Column(
                        children: [
                          _Cabecera(
                            puntosTotales: widget.puntosTotales,
                            total: inventario.total,
                          ),
                          Expanded(
                            child: ListView(
                              key: const Key('comodines-lista'),
                              padding: EdgeInsets.fromLTRB(
                                18,
                                18,
                                18,
                                _huecoPie + insetAbajo,
                              ),
                              children: [
                                for (final tipo in ComodinTipo.values) ...[
                                  _TarjetaComodin(
                                    tipo: tipo,
                                    cantidad: inventario.cantidadDe(tipo),
                                    onInfo: () => _mostrarDescripcion(tipo),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                const _NotaComodines(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _PieObtenerMas(onTap: _abrirObtenerMas),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.puntosTotales, required this.total});

  final int puntosTotales;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 2, 18, 0),
      child: Row(
        children: [
          const _BotonVolver(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Comodines',
                  style: GoogleFonts.baloo2(
                    color: Colors.white,
                    fontSize: 20,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$total comodines en tu mochila'.toUpperCase(),
                  key: const Key('comodines-subtitulo'),
                  style: GoogleFonts.outfit(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 10,
                    height: 1.2,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _PildoraPuntos(puntos: puntosTotales),
        ],
      ),
    );
  }
}

/// Botón de volver del mock: cuadrado de 40 px, radio 14, borde blanco al
/// 16 % sobre un fondo blanco al 6 %.
class _BotonVolver extends StatelessWidget {
  const _BotonVolver();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Volver',
      child: InkWell(
        key: const Key('comodines-boton-volver'),
        onTap: () => Navigator.of(context).maybePop(),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.16),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.chevron_left_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}

/// Badge de puntos igual que en Home (`_PildoraPuntos` de `camino_screen.dart`
/// — duplicado a propósito, mismo motivo que [_formatMiles]).
class _PildoraPuntos extends StatelessWidget {
  const _PildoraPuntos({required this.puntos});

  final int puntos;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              height: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _formatMiles(puntos),
            key: const Key('comodines-puntos-totales'),
            style: GoogleFonts.baloo2(
              color: _goldClaro,
              fontSize: 15,
              height: 1,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de un tipo de comodín tal cual la pinta el mock: el arte ancho a
/// todo el ancho de la lista con el contador `×N` encima, y debajo el título
/// con la etiqueta de unidades y el botón de ayuda.
///
/// Tocar el arte enseña la descripción, igual que el "?": el `onUse` del mock
/// ("se usará en la próxima pregunta") describe una preselección que el juego
/// no tiene — los comodines se gastan desde la bandeja de la pantalla de
/// juego (`bandeja_comodines.dart`), no desde aquí.
class _TarjetaComodin extends StatelessWidget {
  const _TarjetaComodin({
    required this.tipo,
    required this.cantidad,
    required this.onInfo,
  });

  final ComodinTipo tipo;
  final int cantidad;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    final agotado = cantidad == 0;

    return Column(
      key: Key('comodines-tarjeta-${tipo.aTexto}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: onInfo,
          child: SizedBox(
            height: _altoArte,
            child: Stack(
              children: [
                Positioned.fill(
                  child: _Arte(tipo: tipo, agotado: agotado),
                ),
                if (_cifraSobreArte(tipo) case final cifra?)
                  Positioned(
                    left: 26,
                    bottom: 22,
                    child: _PlacaCifra(cifra: cifra, agotado: agotado),
                  ),
                Positioned(
                  right: 2,
                  top: 6,
                  child: _ChipCantidad(tipo: tipo, cantidad: cantidad),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        _nombre(tipo),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.baloo2(
                          color: Colors.white.withValues(
                            alpha: agotado ? 0.6 : 1,
                          ),
                          fontSize: 17,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Text(
                      _etiquetaCantidad(cantidad).toUpperCase(),
                      style: GoogleFonts.outfit(
                        color: agotado
                            ? _gold.withValues(alpha: 0.9)
                            : Colors.white.withValues(alpha: 0.4),
                        fontSize: 9,
                        height: 1,
                        letterSpacing: 1.26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _BotonInfo(tipo: tipo, onTap: onInfo),
            ],
          ),
        ),
      ],
    );
  }
}

class _Arte extends StatelessWidget {
  const _Arte({required this.tipo, required this.agotado});

  final ComodinTipo tipo;
  final bool agotado;

  @override
  Widget build(BuildContext context) {
    // `cacheWidth` porque los PNG son de 2048 px de ancho y aquí se pintan a
    // ~354: sin él, cuatro artes descodificados a tamaño completo se comen
    // varios cientos de MB de memoria de texturas.
    final relacion = MediaQuery.devicePixelRatioOf(context);
    final arte = Image.asset(
      _assetArte(tipo),
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      cacheWidth: (MediaQuery.sizeOf(context).width * relacion).round(),
    );

    if (!agotado) return arte;
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(_matrizAgotado),
      child: arte,
    );
  }
}

/// Placa con la cifra del radio, dibujada sobre el arte. Es lo que antes venía
/// pintado en el PNG: al ponerla por código sigue al backend y no vuelve a
/// quedarse desfasada. Se apaga con el comodín agotado, igual que el arte.
class _PlacaCifra extends StatelessWidget {
  const _PlacaCifra({required this.cifra, required this.agotado});

  final String cifra;
  final bool agotado;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: agotado ? 0.5 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: _placaFondo,
          border: Border.all(color: _placaBorde, width: 2.5),
          borderRadius: BorderRadius.circular(11),
          boxShadow: const [
            BoxShadow(
              color: Color(0x59000000),
              offset: Offset(0, 2),
              blurRadius: 6,
            ),
          ],
        ),
        child: Text(
          cifra,
          style: GoogleFonts.baloo2(
            color: Colors.white,
            fontSize: 15,
            height: 1,
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// Contador `×N` del mock: chip turquesa con borde blanco y sombra dura.
/// Agotado pasa a gris, como el arte.
class _ChipCantidad extends StatelessWidget {
  const _ChipCantidad({required this.tipo, required this.cantidad});

  final ComodinTipo tipo;
  final int cantidad;

  @override
  Widget build(BuildContext context) {
    final agotado = cantidad == 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: agotado
            ? Colors.white.withValues(alpha: 0.06)
            : _teal.withValues(alpha: 0.9),
        border: Border.all(
          color: Colors.white.withValues(alpha: agotado ? 0.14 : 0.25),
          width: 2.5,
        ),
        borderRadius: BorderRadius.circular(13),
        boxShadow: const [
          BoxShadow(color: Color(0x73060E14), offset: Offset(0, 3)),
        ],
      ),
      child: Text(
        '×$cantidad',
        key: Key('comodines-cantidad-${tipo.aTexto}'),
        style: GoogleFonts.baloo2(
          color: agotado ? Colors.white.withValues(alpha: 0.4) : _tintaChip,
          fontSize: 17,
          height: 1,
          fontWeight: FontWeight.w800,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// "?" del mock: círculo de 26 px con borde blanco al 26 %. El área de toque
/// se estira a 40 px sin cambiar el dibujo, que 26 px se queda corto para un
/// dedo.
class _BotonInfo extends StatelessWidget {
  const _BotonInfo({required this.tipo, required this.onTap});

  final ComodinTipo tipo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Qué hace ${_nombre(tipo)}',
      child: InkWell(
        key: Key('comodines-info-${tipo.aTexto}'),
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.26),
                  width: 1.5,
                ),
                shape: BoxShape.circle,
              ),
              child: Text(
                '?',
                style: GoogleFonts.baloo2(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Recordatorio de las reglas de uso, al final de la lista (lo pide el mock y
/// faltaba: es donde el jugador se entera de que solo cabe un comodín por
/// pregunta, la regla D2 de `design.md`).
class _NotaComodines extends StatelessWidget {
  const _NotaComodines();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
      child: Text(
        'Puedes usar un comodín por pregunta. Se consumen al usarlos y no se '
        'recuperan al fallar.',
        style: GoogleFonts.outfit(
          color: Colors.white.withValues(alpha: 0.42),
          fontSize: 11.5,
          height: 1.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Pie fijo: el degradado que difumina la lista al pasar por debajo más el
/// botón principal.
class _PieObtenerMas extends StatelessWidget {
  const _PieObtenerMas({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final insetAbajo = MediaQuery.viewPaddingOf(context).bottom;

    return DecoratedBox(
      decoration: BoxDecoration(
        // `linear-gradient(0deg, rgba(10,22,34,.97) 60%, transparent)`.
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            _velo.withValues(alpha: 0.97),
            _velo.withValues(alpha: 0.97),
            _velo.withValues(alpha: 0),
          ],
          stops: const [0, 0.6, 1],
        ),
      ),
      child: Padding(
        // El mock deja 26 px por abajo en un marco sin indicador de inicio;
        // en un móvil de verdad manda el inset cuando es mayor.
        padding: EdgeInsets.fromLTRB(18, 26, 18, math.max(26, insetAbajo)),
        child: _BotonObtenerMas(onTap: onTap),
      ),
    );
  }
}

/// Botón principal con el balanceo `gq-bob3` del mock (±5 px, 3,4 s). Respeta
/// "reducir movimiento" del sistema, igual que el resto de animaciones en
/// bucle de la app (ver [reduceMotion] en `entry_motion.dart`).
class _BotonObtenerMas extends StatefulWidget {
  const _BotonObtenerMas({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_BotonObtenerMas> createState() => _BotonObtenerMasState();
}

class _BotonObtenerMasState extends State<_BotonObtenerMas>
    with SingleTickerProviderStateMixin {
  final bool _reduceMotion = reduceMotion;

  late final AnimationController _controlador = AnimationController(
    duration: const Duration(milliseconds: 1700),
    vsync: this,
  );

  late final Animation<double> _balanceo = CurvedAnimation(
    parent: _controlador,
    curve: Curves.easeInOut,
  );

  @override
  void initState() {
    super.initState();
    if (!_reduceMotion) _controlador.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final boton = Semantics(
      button: true,
      label: 'Obtener más comodines',
      child: DecoratedBox(
        decoration: BoxDecoration(
          // `linear-gradient(140deg, #2BC0A8, #1B6FA8)`.
          gradient: const LinearGradient(
            begin: Alignment(-0.64, -0.77),
            end: Alignment(0.64, 0.77),
            colors: [_teal, _blue],
          ),
          borderRadius: BorderRadius.circular(20),
          // `0 6px 0 rgba(11,66,102,.65)`: sombra dura, sin difuminar.
          boxShadow: const [
            BoxShadow(color: Color(0xA60B4266), offset: Offset(0, 6)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            key: const Key('comodines-obtener-mas'),
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(19),
              child: Center(
                child: Text(
                  'Obtener más comodines',
                  style: GoogleFonts.baloo2(
                    color: Colors.white,
                    fontSize: 18,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (_reduceMotion) return boton;
    return AnimatedBuilder(
      animation: _balanceo,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -5 * _balanceo.value),
        child: child,
      ),
      child: boton,
    );
  }
}

class _ErrorComodines extends StatelessWidget {
  const _ErrorComodines({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No se pudo cargar tu mochila de comodines',
              key: const Key('comodines-error'),
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              key: const Key('comodines-reintentar'),
              onPressed: onRetry,
              child: Text(
                'Reintentar',
                style: GoogleFonts.baloo2(
                  color: _teal,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hoja inferior "Conseguir comodines": 3 opciones, solo el vídeo publicitario
/// con intención de ser funcional. Devuelve (con `Navigator.pop`) el tipo
/// concedido si el anuncio se completa con éxito, o `null` si se cierra sin
/// conseguir nada.
class _HojaObtenerMas extends StatefulWidget {
  const _HojaObtenerMas({required this.gateway, required this.anunciosGateway});

  final ComodinesGateway gateway;
  final AnunciosGateway anunciosGateway;

  @override
  State<_HojaObtenerMas> createState() => _HojaObtenerMasState();
}

class _HojaObtenerMasState extends State<_HojaObtenerMas> {
  bool _cargando = false;
  String? _error;

  /// Como el `say()` del mock: cierra la hoja y deja el aviso a la vista, en
  /// vez de enseñarlo detrás de ella.
  void _proximamente(String que) {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '$que estará disponible próximamente',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _fondoToast,
          elevation: 8,
          margin: const EdgeInsets.only(left: 18, right: 18, bottom: 96),
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
          ),
        ),
      );
  }

  Future<void> _verAnuncio() async {
    if (_cargando) return;
    setState(() {
      _cargando = true;
      _error = null;
    });

    // Solo se concede si el jugador de verdad ganó la recompensa del
    // anuncio (INT-117 delta-1, D2/D3 de design.md) — a diferencia del
    // gating automático de INT-117 original, aquí no hay fail-open: si el
    // anuncio no carga o no se completa, no hay nada que conceder.
    final recompensaGanada = await widget.anunciosGateway
        .mostrarParaRecompensa();
    if (!mounted) return;
    if (!recompensaGanada) {
      setState(() {
        _cargando = false;
        _error = 'No se pudo mostrar el anuncio. Inténtalo de nuevo.';
      });
      return;
    }

    try {
      final tipo = await widget.gateway.concederComodinPorAnuncio();
      if (!mounted) return;
      Navigator.of(context).pop(tipo);
    } on ComodinRechazadoException catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e.motivo == MotivoRechazoComodin.topeDiarioAlcanzado
            ? 'Ya has alcanzado el máximo de comodines de hoy por anuncios'
            : 'No se pudo conceder el comodín';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = 'No se pudo conceder el comodín. Inténtalo de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Radio solo arriba (el mock también lo redondea abajo porque su marco de
    // móvil tiene esquinas redondas; en la app la hoja llega al borde) y la
    // línea turquesa como hijo aparte: `BoxDecoration` no admite un borde de
    // un solo lado junto con `borderRadius`.
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: ColoredBox(
        color: _fondoHoja,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(height: 2, color: _teal.withValues(alpha: 0.4)),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Conseguir comodines',
                      style: GoogleFonts.baloo2(
                        color: Colors.white,
                        fontSize: 19,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Elige cómo quieres sumar comodines a tu mochila.',
                      style: GoogleFonts.outfit(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _OpcionObtenerMas(
                      clave: const Key('comodines-opcion-anuncio'),
                      icono: Icons.play_arrow_rounded,
                      colorIcono: _tealClaro,
                      fondoIcono: _teal.withValues(alpha: 0.2),
                      borde: _teal.withValues(alpha: 0.35),
                      titulo: 'Ver un anuncio',
                      // El tope real son 4 al día
                      // (`20260820210000_tope_diario_comodines_anuncio_a_4`),
                      // no los 5 que dice el mock.
                      subtitulo: '1 comodín aleatorio · máx. 4 al día',
                      coste: 'Gratis',
                      colorCoste: _tealClaro,
                      cargando: _cargando,
                      onTap: _verAnuncio,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        key: const Key('comodines-anuncio-error'),
                        style: GoogleFonts.outfit(
                          color: _rojoError,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    _OpcionObtenerMas(
                      clave: const Key('comodines-opcion-puntos'),
                      icono: Icons.star_rounded,
                      colorIcono: _gold,
                      fondoIcono: _gold.withValues(alpha: 0.2),
                      borde: _gold.withValues(alpha: 0.35),
                      titulo: 'Canjear puntos',
                      subtitulo: 'Elige el comodín que quieras',
                      coste: '250 pts',
                      colorCoste: _gold,
                      onTap: () => _proximamente('Canjear puntos'),
                    ),
                    const SizedBox(height: 10),
                    _OpcionObtenerMas(
                      clave: const Key('comodines-opcion-pack'),
                      icono: Icons.auto_awesome_rounded,
                      colorIcono: _blueClaro,
                      fondoIcono: _blue.withValues(alpha: 0.28),
                      borde: _blue.withValues(alpha: 0.45),
                      titulo: 'Pack explorador',
                      subtitulo: '3 de cada comodín, de una vez',
                      coste: '2,99 €',
                      colorCoste: _blueClaro,
                      onTap: () => _proximamente('El pack explorador'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila de la hoja: pastilla de icono con su tinte, título, subtítulo y coste
/// a la derecha. "Canjear puntos" y "Pack explorador" se pintan igual que la
/// opción viva (lo pide el mock, y el requirement de `comodines/spec.md` es
/// que se muestren "sin funcionalidad"): el aviso de "próximamente" llega al
/// tocarlas.
class _OpcionObtenerMas extends StatelessWidget {
  const _OpcionObtenerMas({
    required this.clave,
    required this.icono,
    required this.colorIcono,
    required this.fondoIcono,
    required this.borde,
    required this.titulo,
    required this.subtitulo,
    required this.coste,
    required this.colorCoste,
    required this.onTap,
    this.cargando = false,
  });

  final Key clave;
  final IconData icono;
  final Color colorIcono;
  final Color fondoIcono;
  final Color borde;
  final String titulo;
  final String subtitulo;
  final String coste;
  final Color colorCoste;
  final VoidCallback onTap;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: clave,
      onTap: cargando ? null : onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: borde, width: 1.5),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: fondoIcono,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icono, color: colorIcono, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    titulo,
                    style: GoogleFonts.baloo2(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitulo,
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (cargando)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: _teal),
              )
            else
              Text(
                coste,
                style: GoogleFonts.baloo2(
                  color: colorCoste,
                  fontSize: 12,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
