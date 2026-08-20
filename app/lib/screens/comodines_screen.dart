import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/comodines_gateway.dart';

const _bgTop = Color(0xFF102A38);
const _bgMid = Color(0xFF0B1B27);
const _bgBottom = Color(0xFF08131C);
const _teal = Color(0xFF2BC0A8);
const _blue = Color(0xFF1B6FA8);
const _gold = Color(0xFFFFC53D);
const _ink = Color(0xFF0E1620);

/// Si el SDK de anuncios en vídeo (INT-117) ya está integrado en la app.
///
/// Hoy NO lo está: `false` a propósito (requirement "Obtención de comodines
/// por vídeo publicitario" de `comodines/spec.md`, escenario "La vía de
/// anuncio no está disponible todavía" — el botón SHALL mostrarse
/// deshabilitado en vez de llamar al RPC y simular un visionado que nunca
/// ocurrió). Cuando INT-117 integre el SDK real, este flag pasa a `true` (o
/// se sustituye por la condición real de "hay un anuncio cargado y listo")
/// y `_HojaObtenerMas._verAnuncio` empieza a llamar de verdad a
/// `concederComodinPorAnuncio()` tras el callback de recompensa del SDK —el
/// resto del cableado (gateway, manejo de errores, refresco del inventario)
/// ya está escrito y probado, ver `comodines_gateway_test.dart`.
const bool anuncioDisponible = false;

String _nombre(ComodinTipo tipo) => switch (tipo) {
  ComodinTipo.tiempo => 'Tiempo extra',
  ComodinTipo.pais => 'País',
  ComodinTipo.km1000 => 'Radio 1000 km',
  ComodinTipo.km500 => 'Radio 500 km',
};

String _descripcion(ComodinTipo tipo) => switch (tipo) {
  ComodinTipo.tiempo =>
    'Añade 15 segundos al margen antes de que tu respuesta se envíe sola.',
  ComodinTipo.pais =>
    'Revela el país real del objetivo, sin desvelar el lugar exacto.',
  ComodinTipo.km1000 =>
    'Dibuja en el mapa un círculo de 1000 km alrededor del objetivo real.',
  ComodinTipo.km500 =>
    'Dibuja en el mapa un círculo de 500 km alrededor del objetivo real.',
};

String _assetArte(ComodinTipo tipo) => switch (tipo) {
  ComodinTipo.tiempo => 'assets/comodines/arte_tiempo.png',
  ComodinTipo.pais => 'assets/comodines/arte_pais.png',
  ComodinTipo.km1000 => 'assets/comodines/arte_km1000.png',
  ComodinTipo.km500 => 'assets/comodines/arte_km500.png',
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

/// Pantalla Comodines (INT-119): inventario real de los 4 tipos y la hoja
/// "Obtener más" — hoy solo el vídeo publicitario tiene intención de ser
/// funcional (ver [anuncioDisponible]); "canjear puntos" y "pack explorador"
/// se enseñan sin acción real, con un aviso de "próximamente" al tocarlas.
class ComodinesScreen extends StatefulWidget {
  const ComodinesScreen({super.key, required this.puntosTotales, this.gateway});

  /// Puntos totales del jugador, ya cargados por quien navega aquí (mismo
  /// motivo que `RankingScreen.puntosTotales` en `camino_screen.dart`, D2 de
  /// su design.md): evita repetir `CaminoGateway.fetchCamino()` solo para
  /// el badge de la cabecera.
  final int puntosTotales;

  /// Inyectable para poder probar la pantalla sin salir a la red.
  final ComodinesGateway? gateway;

  @override
  State<ComodinesScreen> createState() => _ComodinesScreenState();
}

class _ComodinesScreenState extends State<ComodinesScreen> {
  late final ComodinesGateway _gateway =
      widget.gateway ?? SupabaseComodinesGateway(Supabase.instance.client);

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

  void _mostrarDescripcion(ComodinTipo tipo) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(_descripcion(tipo))));
  }

  Future<void> _abrirObtenerMas() async {
    final concedido = await showModalBottomSheet<ComodinTipo>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _HojaObtenerMas(gateway: _gateway),
    );
    if (!mounted || concedido == null) return;

    _recargar();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('¡Has ganado 1 comodín de ${_nombre(concedido)}!'),
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
        child: SafeArea(
          child: FutureBuilder<InventarioComodines>(
            future: _futuro,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator(color: _teal),
                );
              }
              if (snapshot.hasError) {
                return _ErrorComodines(onRetry: _recargar);
              }

              final inventario = snapshot.data!;
              return Column(
                children: [
                  _Cabecera(
                    puntosTotales: widget.puntosTotales,
                    total: inventario.total,
                  ),
                  Expanded(
                    child: ListView(
                      key: const Key('comodines-lista'),
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                      children: [
                        for (final tipo in ComodinTipo.values) ...[
                          _TarjetaComodin(
                            tipo: tipo,
                            cantidad: inventario.cantidadDe(tipo),
                            onInfo: () => _mostrarDescripcion(tipo),
                          ),
                          const SizedBox(height: 14),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    child: _BotonObtenerMas(onTap: _abrirObtenerMas),
                  ),
                ],
              );
            },
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
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
      child: Row(
        children: [
          // Sin caja de fondo (feedback tras probar la primera versión): ya
          // está sobre el fondo oscuro de la pantalla, no hace falta otra
          // cápsula alrededor del icono.
          IconButton(
            key: const Key('comodines-boton-volver'),
            onPressed: () => Navigator.of(context).maybePop(),
            style: IconButton.styleFrom(fixedSize: const Size(42, 42)),
            icon: const Icon(Icons.chevron_left, color: Colors.white, size: 30),
          ),
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
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$total comodines en tu mochila',
                  key: const Key('comodines-subtitulo'),
                  style: GoogleFonts.outfit(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _PildoraPuntos(puntos: puntosTotales),
        ],
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
            key: const Key('comodines-puntos-totales'),
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
    return SizedBox(
      key: Key('comodines-tarjeta-${tipo.aTexto}'),
      height: 112,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(_assetArte(tipo), fit: BoxFit.cover),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      _ink.withValues(alpha: 0.8),
                      _ink.withValues(alpha: 0.2),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _gold,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'x$cantidad',
                              key: Key('comodines-cantidad-${tipo.aTexto}'),
                              style: GoogleFonts.baloo2(
                                color: _ink,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _nombre(tipo),
                            style: GoogleFonts.baloo2(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              shadows: const [
                                Shadow(color: Color(0xB0000000), blurRadius: 6),
                              ],
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
          ),
        ),
      ),
    );
  }
}

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
        // Sin caja de fondo (feedback tras probar la primera versión): la
        // tarjeta ya trae su propio degradado oscuro debajo, no hace falta
        // otra cápsula alrededor del "?".
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          child: Text(
            '?',
            style: GoogleFonts.baloo2(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              shadows: const [Shadow(color: Color(0xB0000000), blurRadius: 6)],
            ),
          ),
        ),
      ),
    );
  }
}

class _BotonObtenerMas extends StatelessWidget {
  const _BotonObtenerMas({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Obtener más comodines',
      child: InkWell(
        key: const Key('comodines-obtener-mas'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 54,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_teal, _blue]),
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(color: Color(0x40000000), offset: Offset(0, 6)),
            ],
          ),
          child: Center(
            child: Text(
              'Obtener más comodines',
              style: GoogleFonts.baloo2(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
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

/// Hoja inferior "Obtener más comodines": 3 opciones, solo el vídeo
/// publicitario con intención de ser funcional (ver [anuncioDisponible]).
/// Devuelve (con `Navigator.pop`) el tipo concedido si el anuncio se
/// completa con éxito, o `null` si se cierra sin conseguir nada.
class _HojaObtenerMas extends StatefulWidget {
  const _HojaObtenerMas({required this.gateway});

  final ComodinesGateway gateway;

  @override
  State<_HojaObtenerMas> createState() => _HojaObtenerMasState();
}

class _HojaObtenerMasState extends State<_HojaObtenerMas> {
  bool _cargando = false;
  String? _error;

  void _proximamente(String que) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('$que estará disponible próximamente')),
      );
  }

  Future<void> _verAnuncio() async {
    if (!anuncioDisponible) {
      // INT-117 (AdMob) no está integrada todavía: sin un SDK real que
      // confirme el visionado, llamar al RPC aquí estaría concediendo el
      // comodín por un anuncio que nunca se vio (requirement "Obtención de
      // comodines por vídeo publicitario", escenario "La vía de anuncio no
      // está disponible todavía" de `comodines/spec.md`) — se muestra el
      // aviso y no se toca el servidor.
      _proximamente('Ver anuncios');
      return;
    }

    if (_cargando) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
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
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        decoration: BoxDecoration(
          color: _bgBottom,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Obtener más comodines',
              style: GoogleFonts.baloo2(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            _OpcionObtenerMas(
              clave: const Key('comodines-opcion-anuncio'),
              icono: Icons.play_circle_fill_rounded,
              titulo: 'Ver un anuncio',
              subtitulo: anuncioDisponible
                  ? 'Consigue 1 comodín aleatorio al terminar de verlo'
                  : 'Próximamente',
              habilitada: anuncioDisponible,
              cargando: _cargando,
              onTap: _verAnuncio,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                key: const Key('comodines-anuncio-error'),
                style: GoogleFonts.outfit(
                  color: const Color(0xFFFF9B9E),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 10),
            _OpcionObtenerMas(
              clave: const Key('comodines-opcion-puntos'),
              icono: Icons.star_rounded,
              titulo: 'Canjear puntos',
              subtitulo: 'Próximamente',
              habilitada: false,
              onTap: () => _proximamente('Canjear puntos'),
            ),
            const SizedBox(height: 10),
            _OpcionObtenerMas(
              clave: const Key('comodines-opcion-pack'),
              icono: Icons.card_giftcard_rounded,
              titulo: 'Pack explorador',
              subtitulo: 'Próximamente',
              habilitada: false,
              onTap: () => _proximamente('El pack explorador'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpcionObtenerMas extends StatelessWidget {
  const _OpcionObtenerMas({
    required this.clave,
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
    this.habilitada = true,
    this.cargando = false,
  });

  final Key clave;
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;

  /// Solo controla el estilo (atenuado o no): las 3 opciones siguen
  /// respondiendo al toque, aunque sea con un aviso de "próximamente" en vez
  /// de una acción real (mismo comportamiento que pide el prompt de esta
  /// tarea para "canjear puntos"/"pack explorador").
  final bool habilitada;

  final bool cargando;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: habilitada ? 1 : 0.5,
      child: InkWell(
        key: clave,
        onTap: cargando ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(icono, color: _teal, size: 26),
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
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitulo,
                      style: GoogleFonts.outfit(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (cargando)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _teal,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
