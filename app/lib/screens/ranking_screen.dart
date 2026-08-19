import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/camino_gateway.dart';
import '../services/ranking_gateway.dart';

const _bgTop = Color(0xFF102A38);
const _bgMid = Color(0xFF0B1B27);
const _bgBottom = Color(0xFF08131C);
const _teal = Color(0xFF2BC0A8);
const _blue = Color(0xFF1B6FA8);
const _gold = Color(0xFFFFC53D);
const _plata = Color(0xFFD8E3E8);
const _bronce = Color(0xFFE09B62);

/// Colores de acento que rotan por `tematicaId`, para el punto de color de
/// cada chip de "Temática"/"Camino" — misma técnica que `_colorAcento` en
/// `camino_screen.dart`, redefinida aquí porque cada pantalla lleva sus
/// propias constantes de color (no hay un `AppColors` compartido).
const _acentosTematica = [
  _teal,
  Color(0xFFE0A24F),
  Color(0xFFE0715B),
  Color(0xFF8E7CE8),
  Color(0xFF4FB0E0),
];

Color _colorTematica(String tematicaId) =>
    _acentosTematica[tematicaId.hashCode.abs() % _acentosTematica.length];

const _gradientesAvatar = [
  [_teal, _blue],
  [Color(0xFFFFC53D), Color(0xFFF08A24)],
  [Color(0xFF8FE7D6), _teal],
  [Color(0xFF7FB2FF), _blue],
  [Color(0xFFFF9E9E), Color(0xFFE0574B)],
  [Color(0xFFC6A8FF), Color(0xFF7A5AF8)],
];

List<Color> _gradientePara(String usuarioId) =>
    _gradientesAvatar[usuarioId.hashCode.abs() % _gradientesAvatar.length];

String _formatMiles(int n) {
  final texto = n.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < texto.length; i++) {
    if (i > 0 && (texto.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(texto[i]);
  }
  return buffer.toString();
}

EntradaRanking? _buscarPropia(List<EntradaRanking> entradas) {
  for (final entrada in entradas) {
    if (entrada.esUsuarioActual) return entrada;
  }
  return null;
}

/// Chip seleccionable de la pestaña "Camino": una parada del camino.
class ChipCamino {
  const ChipCamino({
    required this.caminoId,
    required this.orden,
    required this.tematicaId,
    required this.tematicaNombre,
  });

  final String caminoId;
  final int orden;
  final String tematicaId;
  final String tematicaNombre;
}

/// Deriva los chips de la pestaña "Camino" a partir del camino del jugador:
/// una entrada por parada, ordenadas por `orden` ascendente aunque
/// [paradas] no lo esté (INT-110).
List<ChipCamino> derivarChipsCamino(List<ParadaCamino> paradas) {
  final ordenadas = [...paradas]..sort((a, b) => a.orden.compareTo(b.orden));
  return [
    for (final parada in ordenadas)
      ChipCamino(
        caminoId: parada.caminoId,
        orden: parada.orden,
        tematicaId: parada.tematicaId,
        tematicaNombre: parada.tematicaNombre,
      ),
  ];
}

/// Chip seleccionable de la pestaña "Temática".
class ChipTematica {
  const ChipTematica({required this.tematicaId, required this.tematicaNombre});

  final String tematicaId;
  final String tematicaNombre;
}

/// Deriva los chips de la pestaña "Temática" a partir del camino del
/// jugador: temáticas distintas, dedupe conservando el primer nombre visto,
/// en el orden de aparición de [paradas] (INT-110).
List<ChipTematica> derivarChipsTematica(List<ParadaCamino> paradas) {
  final vistas = <String>{};
  final chips = <ChipTematica>[];
  for (final parada in paradas) {
    if (vistas.add(parada.tematicaId)) {
      chips.add(
        ChipTematica(
          tematicaId: parada.tematicaId,
          tematicaNombre: parada.tematicaNombre,
        ),
      );
    }
  }
  return chips;
}

enum _Pestana { global, camino, tematica }

/// Pantalla de Clasificación (INT-110): tres pestañas navegables —Global,
/// Camino y Temática— sobre las clasificaciones de INT-109. Reproduce
/// `[App] - Ranking.dc.html` (Claude Design) como especificación visual,
/// con las simplificaciones de alcance de `design.md` (sin indicador ▲/▼,
/// sin racha/intentos/%acierto, sin concepto de "temporada").
class RankingScreen extends StatefulWidget {
  const RankingScreen({
    super.key,
    this.rankingGateway,
    this.caminoGateway,
    this.paradas,
    this.puntosTotales = 0,
  });

  /// Inyectables para poder probar la pantalla sin salir a la red.
  final RankingGateway? rankingGateway;
  final CaminoGateway? caminoGateway;

  /// Paradas del camino ya cargadas por quien navega aquí (normalmente
  /// `CaminoScreen`), para derivar los chips de Camino/Temática sin repetir
  /// `CaminoGateway.fetchCamino()` (design.md, decisión 2). Si es `null`, la
  /// propia pantalla las carga.
  final List<ParadaCamino>? paradas;

  /// Puntos totales del propio jugador, ya calculados por quien navega
  /// aquí — se muestran fijos en la cabecera sin depender de la pestaña
  /// activa (design.md, decisión 1).
  final int puntosTotales;

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  late final RankingGateway _rankingGateway =
      widget.rankingGateway ?? SupabaseRankingGateway(Supabase.instance.client);
  late final CaminoGateway _caminoGateway =
      widget.caminoGateway ?? SupabaseCaminoGateway(Supabase.instance.client);

  late List<ParadaCamino> _paradas = widget.paradas ?? const [];
  _Pestana _pestana = _Pestana.global;
  String? _caminoIdSeleccionado;
  String? _tematicaIdSeleccionada;
  late Future<List<EntradaRanking>> _futuro;

  /// Adelanto de la posición propia por tarjeta de la rejilla ("Tú #N" /
  /// "Sin jugar"), una entrada por `caminoId`/`tematicaId`. Se calcula una
  /// sola vez por apertura de pestaña (design.md, decisión 3) — `null`
  /// mientras no se ha entrado todavía en esa pestaña.
  Future<Map<String, EntradaRanking>>? _futuroPreviasCamino;
  Future<Map<String, EntradaRanking>>? _futuroPreviasTematica;

  List<ChipCamino> get _chipsCamino => derivarChipsCamino(_paradas);
  List<ChipTematica> get _chipsTematica => derivarChipsTematica(_paradas);

  bool get _haySeleccion =>
      (_pestana == _Pestana.camino && _caminoIdSeleccionado != null) ||
      (_pestana == _Pestana.tematica && _tematicaIdSeleccionada != null);

  @override
  void initState() {
    super.initState();
    if (widget.paradas == null) _cargarParadas();
    _futuro = _cargarRanking();
  }

  Future<void> _cargarParadas() async {
    final camino = await _caminoGateway.fetchCamino();
    if (!mounted) return;
    setState(() {
      _paradas = camino.entradas;
      // Las paradas pudieron llegar tarde (fallback sin `widget.paradas`):
      // si ya se había disparado una previa con la rejilla vacía, se
      // descarta para recalcularla con las paradas reales.
      _futuroPreviasCamino = null;
      _futuroPreviasTematica = null;
      _asegurarPreviasPestanaActual();
    });
  }

  /// Dispara (si hace falta) la carga de previas de la rejilla de la
  /// pestaña activa, sin repetirla si ya está en marcha (design.md,
  /// decisión 3).
  void _asegurarPreviasPestanaActual() {
    if (_pestana == _Pestana.camino && _caminoIdSeleccionado == null) {
      _futuroPreviasCamino ??= _cargarPreviasCamino();
    } else if (_pestana == _Pestana.tematica &&
        _tematicaIdSeleccionada == null) {
      _futuroPreviasTematica ??= _cargarPreviasTematica();
    }
  }

  Future<Map<String, EntradaRanking>> _cargarPreviasCamino() async {
    final chips = _chipsCamino;
    final resultados = await Future.wait([
      for (final chip in chips)
        _rankingGateway.fetchClasificacionPorCamino(chip.caminoId, limite: 1),
    ]);
    return {
      for (var i = 0; i < chips.length; i++)
        if (_buscarPropia(resultados[i]) != null)
          chips[i].caminoId: _buscarPropia(resultados[i])!,
    };
  }

  Future<Map<String, EntradaRanking>> _cargarPreviasTematica() async {
    final chips = _chipsTematica;
    final resultados = await Future.wait([
      for (final chip in chips)
        _rankingGateway.fetchClasificacionPorTematica(
          chip.tematicaId,
          limite: 1,
        ),
    ]);
    return {
      for (var i = 0; i < chips.length; i++)
        if (_buscarPropia(resultados[i]) != null)
          chips[i].tematicaId: _buscarPropia(resultados[i])!,
    };
  }

  Future<List<EntradaRanking>> _cargarRanking() {
    switch (_pestana) {
      case _Pestana.global:
        return _rankingGateway.fetchClasificacionGlobal();
      case _Pestana.camino:
        final caminoId = _caminoIdSeleccionado;
        return caminoId == null
            ? Future.value(const <EntradaRanking>[])
            : _rankingGateway.fetchClasificacionPorCamino(caminoId);
      case _Pestana.tematica:
        final tematicaId = _tematicaIdSeleccionada;
        return tematicaId == null
            ? Future.value(const <EntradaRanking>[])
            : _rankingGateway.fetchClasificacionPorTematica(tematicaId);
    }
  }

  void _onCambiarPestana(_Pestana nueva) {
    if (nueva == _pestana) return;
    setState(() {
      _pestana = nueva;
      // Cambiar de pestaña siempre vuelve a la rejilla, igual que el
      // mockup (`sels[i] = null` en cada cambio de pestaña) — nunca se
      // conserva una tarjeta abierta de una visita anterior.
      _caminoIdSeleccionado = null;
      _tematicaIdSeleccionada = null;
      if (nueva == _Pestana.global) {
        _futuro = _cargarRanking();
      } else {
        _asegurarPreviasPestanaActual();
      }
    });
  }

  /// Botón ‹ de la cabecera: si hay una tarjeta abierta, vuelve a la
  /// rejilla; si no, sale de la pantalla (design.md, decisión 2).
  void _onVolver() {
    if (_haySeleccion) {
      _cerrarTarjeta();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _cerrarTarjeta() {
    setState(() {
      _caminoIdSeleccionado = null;
      _tematicaIdSeleccionada = null;
    });
  }

  void _onSeleccionarCamino(String caminoId) {
    if (caminoId == _caminoIdSeleccionado) return;
    setState(() {
      _caminoIdSeleccionado = caminoId;
      _futuro = _cargarRanking();
    });
  }

  void _onSeleccionarTematica(String tematicaId) {
    if (tematicaId == _tematicaIdSeleccionada) return;
    setState(() {
      _tematicaIdSeleccionada = tematicaId;
      _futuro = _cargarRanking();
    });
  }

  ChipCamino? _buscarChipCamino(String? caminoId) {
    if (caminoId == null) return null;
    for (final chip in _chipsCamino) {
      if (chip.caminoId == caminoId) return chip;
    }
    return null;
  }

  ChipTematica? _buscarChipTematica(String? tematicaId) {
    if (tematicaId == null) return null;
    for (final chip in _chipsTematica) {
      if (chip.tematicaId == tematicaId) return chip;
    }
    return null;
  }

  String get _subtitulo {
    switch (_pestana) {
      case _Pestana.global:
        return 'Global · acumulado histórico';
      case _Pestana.camino:
        final chip = _buscarChipCamino(_caminoIdSeleccionado);
        if (chip != null) return 'Nivel ${chip.orden} · ${chip.tematicaNombre}';
        return 'Elige una parada del camino · ${_chipsCamino.length} paradas';
      case _Pestana.tematica:
        final chip = _buscarChipTematica(_tematicaIdSeleccionada);
        if (chip != null) return '${chip.tematicaNombre} · ranking';
        return 'Elige una temática · ${_chipsTematica.length} colecciones';
    }
  }

  String? _imagenTematica(String tematicaId) {
    for (final parada in _paradas) {
      if (parada.tematicaId == tematicaId) return parada.imagenPortadaUrl;
    }
    return null;
  }

  String _metaTexto(EntradaRanking entrada) {
    switch (_pestana) {
      case _Pestana.global:
      case _Pestana.tematica:
        final n = entrada.nivelesSuperados ?? 0;
        return n == 1 ? '1 nivel superado' : '$n niveles superados';
      case _Pestana.camino:
        return (entrada.superado ?? false) ? 'Superado' : 'Aún no superado';
    }
  }

  @override
  Widget build(BuildContext context) {
    final mostrarRejilla =
        (_pestana == _Pestana.camino || _pestana == _Pestana.tematica) &&
        !_haySeleccion;

    return PopScope(
      canPop: !_haySeleccion,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _cerrarTarjeta();
      },
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_bgTop, _bgMid, _bgBottom],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _Cabecera(
                  subtitulo: _subtitulo,
                  puntosTotales: widget.puntosTotales,
                  onBack: _onVolver,
                ),
                _SelectorPestanas(
                  pestana: _pestana,
                  onCambiar: _onCambiarPestana,
                ),
                Expanded(
                  child: mostrarRejilla
                      ? _buildRejilla()
                      : _buildClasificacion(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRejilla() {
    final futuro = _pestana == _Pestana.camino
        ? _futuroPreviasCamino
        : _futuroPreviasTematica;

    return FutureBuilder<Map<String, EntradaRanking>>(
      future: futuro,
      builder: (context, snapshot) {
        if (futuro == null ||
            snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(color: _teal));
        }
        if (snapshot.hasError) {
          return _EstadoError(
            onRetry: () => setState(() {
              if (_pestana == _Pestana.camino) {
                _futuroPreviasCamino = _cargarPreviasCamino();
              } else {
                _futuroPreviasTematica = _cargarPreviasTematica();
              }
            }),
          );
        }

        final previas = snapshot.data!;
        if (_pestana == _Pestana.camino) {
          return _RejillaTarjetas(
            key: const Key('ranking-rejilla-camino'),
            tarjetas: [
              for (final chip in _chipsCamino)
                _Tarjeta(
                  keyValue: 'ranking-tarjeta-camino-${chip.caminoId}',
                  onTap: () => _onSeleccionarCamino(chip.caminoId),
                  titulo: 'Nivel ${chip.orden}',
                  subtitulo: chip.tematicaNombre,
                  color: _colorTematica(chip.tematicaId),
                  numeroInsignia: chip.orden,
                  propia: previas[chip.caminoId],
                ),
            ],
          );
        }
        return _RejillaTarjetas(
          key: const Key('ranking-rejilla-tematica'),
          tarjetas: [
            for (final chip in _chipsTematica)
              _Tarjeta(
                keyValue: 'ranking-tarjeta-tematica-${chip.tematicaId}',
                onTap: () => _onSeleccionarTematica(chip.tematicaId),
                titulo: chip.tematicaNombre,
                subtitulo:
                    '${_paradas.where((p) => p.tematicaId == chip.tematicaId).length} niveles',
                color: _colorTematica(chip.tematicaId),
                imagenUrl: _imagenTematica(chip.tematicaId),
                propia: previas[chip.tematicaId],
              ),
          ],
        );
      },
    );
  }

  Widget _buildClasificacion() {
    return FutureBuilder<List<EntradaRanking>>(
      future: _futuro,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(color: _teal));
        }
        if (snapshot.hasError) {
          return _EstadoError(
            onRetry: () => setState(() {
              _futuro = _cargarRanking();
            }),
          );
        }

        final entradas = snapshot.data!;
        final propia = _buscarPropia(entradas);
        final otros = entradas.where((e) => !e.esUsuarioActual).toList();
        final vacio = otros.isEmpty;

        return Column(
          children: [
            Expanded(
              child: vacio
                  ? const _EstadoVacio()
                  : ListView(
                      key: const Key('ranking-lista'),
                      padding: const EdgeInsets.only(bottom: 12),
                      children: [
                        _Podio(top: entradas.take(3).toList()),
                        const SizedBox(height: 6),
                        for (final entrada in entradas.skip(3))
                          _FilaRanking(
                            entrada: entrada,
                            metaTexto: _metaTexto(entrada),
                          ),
                      ],
                    ),
            ),
            if (propia != null)
              _FilaPropia(entrada: propia, metaTexto: _metaTexto(propia)),
          ],
        );
      },
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({
    required this.subtitulo,
    required this.puntosTotales,
    required this.onBack,
  });

  final String subtitulo;
  final int puntosTotales;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
      child: Row(
        children: [
          IconButton(
            key: const Key('ranking-boton-volver'),
            onPressed: onBack,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              fixedSize: const Size(42, 42),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.chevron_left, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Clasificación',
                  style: GoogleFonts.baloo2(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitulo,
                  key: const Key('ranking-subtitulo'),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.14),
              border: Border.all(
                color: _gold.withValues(alpha: 0.35),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(14),
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
                  _formatMiles(puntosTotales),
                  key: const Key('ranking-puntos-totales'),
                  style: GoogleFonts.outfit(
                    color: const Color(0xFFFFD98A),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectorPestanas extends StatelessWidget {
  const _SelectorPestanas({required this.pestana, required this.onCambiar});

  final _Pestana pestana;
  final ValueChanged<_Pestana> onCambiar;

  static const _etiquetas = {
    _Pestana.global: 'Global',
    _Pestana.camino: 'Camino',
    _Pestana.tematica: 'Temática',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.09),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            for (final valor in _Pestana.values)
              Expanded(
                child: GestureDetector(
                  key: Key('ranking-tab-${valor.name}'),
                  onTap: () => onCambiar(valor),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: valor == pestana
                          ? const LinearGradient(colors: [_teal, _blue])
                          : null,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      _etiquetas[valor]!,
                      style: GoogleFonts.outfit(
                        color: valor == pestana
                            ? const Color(0xFF04202A)
                            : Colors.white.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
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

class _RejillaTarjetas extends StatelessWidget {
  const _RejillaTarjetas({super.key, required this.tarjetas});

  final List<Widget> tarjetas;

  @override
  Widget build(BuildContext context) {
    if (tarjetas.isEmpty) return const SizedBox.shrink();
    return GridView.count(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      crossAxisCount: 2,
      mainAxisSpacing: 11,
      crossAxisSpacing: 11,
      childAspectRatio: 0.8,
      children: tarjetas,
    );
  }
}

/// Tarjeta de la rejilla de Camino (con [numeroInsignia], sin imagen) o de
/// Temática (con [imagenUrl], sin insignia) — INT-110 delta-2.
class _Tarjeta extends StatelessWidget {
  const _Tarjeta({
    required this.keyValue,
    required this.onTap,
    required this.titulo,
    required this.subtitulo,
    required this.color,
    required this.propia,
    this.numeroInsignia,
    this.imagenUrl,
  });

  final String keyValue;
  final VoidCallback onTap;
  final String titulo;
  final String subtitulo;
  final Color color;
  final EntradaRanking? propia;
  final int? numeroInsignia;
  final String? imagenUrl;

  @override
  Widget build(BuildContext context) {
    final propiaTexto = propia?.posicion == null
        ? 'Sin jugar'
        : 'Tú #${propia!.posicion}';

    return GestureDetector(
      key: Key(keyValue),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            numeroInsignia != null
                ? _MediaInsignia(numero: numeroInsignia!, color: color)
                : _MediaImagen(url: imagenUrl, color: color),
            const SizedBox(height: 9),
            Text(
              titulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.5),
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
            ),
            const Spacer(),
            Container(
              margin: const EdgeInsets.only(top: 9),
              padding: const EdgeInsets.only(top: 9),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    propiaTexto,
                    key: Key('$keyValue-propia'),
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF8FE7D6),
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
                  ),
                  Text(
                    '›',
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
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

class _MediaInsignia extends StatelessWidget {
  const _MediaInsignia({required this.numero, required this.color});

  final int numero;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, Colors.white.withValues(alpha: 0.18)],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$numero',
        style: GoogleFonts.baloo2(
          color: const Color(0xFF04202A),
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _MediaImagen extends StatelessWidget {
  const _MediaImagen({required this.url, required this.color});

  final String? url;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final urlActual = url;
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: SizedBox(
        height: 78,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (urlActual == null)
              ColoredBox(color: color.withValues(alpha: 0.3))
            else
              Image.network(
                urlActual,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    ColoredBox(color: color.withValues(alpha: 0.3)),
              ),
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.nombre,
    required this.usuarioId,
    this.tamano = 40,
    this.anillo,
  });

  final String nombre;
  final String usuarioId;
  final double tamano;
  final Color? anillo;

  @override
  Widget build(BuildContext context) {
    final recortado = nombre.trim();
    final inicial = recortado.isEmpty
        ? '?'
        : recortado.substring(0, 1).toUpperCase();

    return Container(
      width: tamano,
      height: tamano,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tamano * 0.32),
        gradient: LinearGradient(colors: _gradientePara(usuarioId)),
        border: anillo == null ? null : Border.all(color: anillo!, width: 2.5),
      ),
      child: Text(
        inicial,
        style: GoogleFonts.baloo2(
          color: const Color(0xFF04202A),
          fontWeight: FontWeight.w800,
          fontSize: tamano * 0.42,
        ),
      ),
    );
  }
}

class _Podio extends StatelessWidget {
  const _Podio({required this.top});

  final List<EntradaRanking> top;

  @override
  Widget build(BuildContext context) {
    if (top.isEmpty) return const SizedBox.shrink();
    final primero = top.first;
    final visual = top.length == 3 ? [top[1], top[0], top[2]] : top;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final entrada in visual)
            Expanded(
              child: _PodioPuesto(
                entrada: entrada,
                destacado: entrada.usuarioId == primero.usuarioId,
              ),
            ),
        ],
      ),
    );
  }
}

class _PodioPuesto extends StatelessWidget {
  const _PodioPuesto({required this.entrada, required this.destacado});

  final EntradaRanking entrada;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final anillo = switch (entrada.posicion) {
      1 => _gold,
      2 => _plata,
      3 => _bronce,
      _ => Colors.white24,
    };
    final tamano = destacado ? 68.0 : 54.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              const SizedBox(height: 12),
              Positioned(
                top: 12,
                child: _Avatar(
                  nombre: entrada.nombre,
                  usuarioId: entrada.usuarioId,
                  tamano: tamano,
                  anillo: anillo,
                ),
              ),
              Positioned(
                top: 0,
                child: Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: anillo,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${entrada.posicion ?? '-'}',
                    style: GoogleFonts.baloo2(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF06202B),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: tamano + 20),
          Text(
            entrada.nombre,
            key: Key('ranking-podio-nombre-${entrada.usuarioId}'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _formatMiles(entrada.puntuacion),
            style: GoogleFonts.baloo2(
              color: anillo,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaRanking extends StatelessWidget {
  const _FilaRanking({required this.entrada, required this.metaTexto});

  final EntradaRanking entrada;
  final String metaTexto;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('ranking-fila-${entrada.usuarioId}'),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '${entrada.posicion ?? '—'}',
              textAlign: TextAlign.center,
              style: GoogleFonts.baloo2(
                color: Colors.white.withValues(alpha: 0.45),
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 12),
          _Avatar(nombre: entrada.nombre, usuarioId: entrada.usuarioId),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entrada.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  metaTexto,
                  style: GoogleFonts.outfit(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatMiles(entrada.puntuacion),
            style: GoogleFonts.baloo2(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaPropia extends StatelessWidget {
  const _FilaPropia({required this.entrada, required this.metaTexto});

  final EntradaRanking entrada;
  final String metaTexto;

  @override
  Widget build(BuildContext context) {
    final sinPosicion = entrada.posicion == null;

    return Padding(
      key: const Key('ranking-fila-propia'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF16242F),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _teal.withValues(alpha: 0.45), width: 2.5),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                sinPosicion ? '—' : '${entrada.posicion}',
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  color: const Color(0xFF8FE7D6),
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 10),
            _Avatar(nombre: entrada.nombre, usuarioId: entrada.usuarioId),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${entrada.nombre} · tú',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    sinPosicion ? 'Sin posición todavía' : metaTexto,
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _formatMiles(entrada.puntuacion),
              style: GoogleFonts.baloo2(
                color: const Color(0xFFFFD98A),
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'Todavía no hay clasificación para esta selección',
          key: const Key('ranking-estado-vacio'),
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            color: Colors.white.withValues(alpha: 0.55),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _EstadoError extends StatelessWidget {
  const _EstadoError({required this.onRetry});

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
              'No se pudo cargar la clasificación',
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
