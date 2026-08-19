import 'package:geoquest/services/ranking_gateway.dart';

/// Falso de [RankingGateway] para probar la pantalla de Ranking sin salir a
/// la red (INT-110), siguiendo el patrón de `FakeCaminoGateway`.
class FakeRankingGateway implements RankingGateway {
  FakeRankingGateway({
    List<EntradaRanking> global = const [],
    Map<String, List<EntradaRanking>> porCamino = const {},
    Map<String, List<EntradaRanking>> porTematica = const {},
  }) {
    _global = global;
    _porCamino = porCamino;
    _porTematica = porTematica;
  }

  late List<EntradaRanking> _global;
  late Map<String, List<EntradaRanking>> _porCamino;
  late Map<String, List<EntradaRanking>> _porTematica;

  /// Excepción a lanzar en la próxima llamada, si se define.
  Object? throwOnNextCall;

  int fetchGlobalCalls = 0;
  int fetchPorCaminoCalls = 0;
  int fetchPorTematicaCalls = 0;
  final List<String> caminoIdsConsultados = [];
  final List<String> tematicaIdsConsultadas = [];

  void actualizarGlobal(List<EntradaRanking> entradas) => _global = entradas;

  void actualizarPorCamino(String caminoId, List<EntradaRanking> entradas) =>
      _porCamino = {..._porCamino, caminoId: entradas};

  void actualizarPorTematica(
    String tematicaId,
    List<EntradaRanking> entradas,
  ) => _porTematica = {..._porTematica, tematicaId: entradas};

  void _lanzarSiToca() {
    final error = throwOnNextCall;
    if (error != null) {
      throwOnNextCall = null;
      throw error;
    }
  }

  @override
  Future<List<EntradaRanking>> fetchClasificacionGlobal({
    int limite = 50,
  }) async {
    fetchGlobalCalls++;
    _lanzarSiToca();
    return _global;
  }

  @override
  Future<List<EntradaRanking>> fetchClasificacionPorCamino(
    String caminoId, {
    int limite = 50,
  }) async {
    fetchPorCaminoCalls++;
    caminoIdsConsultados.add(caminoId);
    _lanzarSiToca();
    return _porCamino[caminoId] ?? const [];
  }

  @override
  Future<List<EntradaRanking>> fetchClasificacionPorTematica(
    String tematicaId, {
    int limite = 50,
  }) async {
    fetchPorTematicaCalls++;
    tematicaIdsConsultadas.add(tematicaId);
    _lanzarSiToca();
    return _porTematica[tematicaId] ?? const [];
  }
}
