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

  List<ChipCamino> get _chipsCamino => derivarChipsCamino(_paradas);
  List<ChipTematica> get _chipsTematica => derivarChipsTematica(_paradas);

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
      if (_pestana == _Pestana.camino &&
          _caminoIdSeleccionado == null &&
          _chipsCamino.isNotEmpty) {
        _caminoIdSeleccionado = _chipsCamino.first.caminoId;
        _futuro = _cargarRanking();
      } else if (_pestana == _Pestana.tematica &&
          _tematicaIdSeleccionada == null &&
          _chipsTematica.isNotEmpty) {
        _tematicaIdSeleccionada = _chipsTematica.first.tematicaId;
        _futuro = _cargarRanking();
      }
    });
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
      if (nueva == _Pestana.camino) {
        _caminoIdSeleccionado ??= _chipsCamino.isEmpty
            ? null
            : _chipsCamino.first.caminoId;
      } else if (nueva == _Pestana.tematica) {
        _tematicaIdSeleccionada ??= _chipsTematica.isEmpty
            ? null
            : _chipsTematica.first.tematicaId;
      }
      _futuro = _cargarRanking();
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
        return chip == null
            ? 'Camino'
            : 'Camino ${chip.orden} · ${chip.tematicaNombre}';
      case _Pestana.tematica:
        final chip = _buscarChipTematica(_tematicaIdSeleccionada);
        return chip == null ? 'Temática' : '${chip.tematicaNombre} · ranking';
    }
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
          child: Column(
            children: [
              _Cabecera(
                subtitulo: _subtitulo,
                puntosTotales: widget.puntosTotales,
                onBack: () => Navigator.of(context).pop(),
              ),
              _SelectorPestanas(
                pestana: _pestana,
                onCambiar: _onCambiarPestana,
              ),
              if (_pestana == _Pestana.camino)
                _SelectorChips(
                  prefijoKey: 'ranking-chip-camino',
                  seleccionado: _caminoIdSeleccionado,
                  onSeleccionar: _onSeleccionarCamino,
                  chips: [
                    for (final chip in _chipsCamino)
                      _ChipDato(
                        id: chip.caminoId,
                        etiqueta: 'Camino ${chip.orden}',
                        color: _colorTematica(chip.tematicaId),
                      ),
                  ],
                ),
              if (_pestana == _Pestana.tematica)
                _SelectorChips(
                  prefijoKey: 'ranking-chip-tematica',
                  seleccionado: _tematicaIdSeleccionada,
                  onSeleccionar: _onSeleccionarTematica,
                  chips: [
                    for (final chip in _chipsTematica)
                      _ChipDato(
                        id: chip.tematicaId,
                        etiqueta: chip.tematicaNombre,
                        color: _colorTematica(chip.tematicaId),
                      ),
                  ],
                ),
              Expanded(
                child: FutureBuilder<List<EntradaRanking>>(
                  future: _futuro,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(
                        child: CircularProgressIndicator(color: _teal),
                      );
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
                    final otros = entradas
                        .where((e) => !e.esUsuarioActual)
                        .toList();
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
                          _FilaPropia(
                            entrada: propia,
                            metaTexto: _metaTexto(propia),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
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

class _ChipDato {
  const _ChipDato({
    required this.id,
    required this.etiqueta,
    required this.color,
  });

  final String id;
  final String etiqueta;
  final Color color;
}

class _SelectorChips extends StatelessWidget {
  const _SelectorChips({
    required this.chips,
    required this.seleccionado,
    required this.onSeleccionar,
    required this.prefijoKey,
  });

  final List<_ChipDato> chips;
  final String? seleccionado;
  final ValueChanged<String> onSeleccionar;
  final String prefijoKey;

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) return const SizedBox(height: 8);
    return SizedBox(
      height: 54,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final chip = chips[index];
          final activo = chip.id == seleccionado;
          return GestureDetector(
            key: Key('$prefijoKey-${chip.id}'),
            onTap: () => onSeleccionar(chip.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: activo
                    ? _teal.withValues(alpha: 0.16)
                    : Colors.white.withValues(alpha: 0.05),
                border: Border.all(
                  color: activo
                      ? _teal.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.1),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: chip.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    chip.etiqueta,
                    style: GoogleFonts.outfit(
                      color: activo
                          ? const Color(0xFF8FE7D6)
                          : Colors.white.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
