import 'package:geoquest/services/anuncios_gateway.dart';

/// Falso de [AnunciosGateway] para probar `CaminoScreen` sin salir a la red
/// ni tocar el SDK de AdMob (INT-117, mismo patrón que `FakeComodinesGateway`).
class FakeAnunciosGateway implements AnunciosGateway {
  FakeAnunciosGateway({
    this.tipoPendiente = TipoAnuncioPendiente.ninguno,
    this.retraso = Duration.zero,
    this.recompensaGanada = false,
  });

  /// Lo que devuelve `anuncioDebido` la próxima vez que se llame.
  TipoAnuncioPendiente tipoPendiente;

  /// Retraso artificial antes de resolver `mostrarSiToca`, para poder
  /// probar el guard de doble-tap de `_CaminoScreenState` (INT-117).
  Duration retraso;

  final List<String> caminoIdsConsultados = [];
  int mostrarSiTocaCalls = 0;

  /// Lo que devuelve `mostrarParaRecompensa` la próxima vez que se llame
  /// (INT-117 delta-1).
  bool recompensaGanada;

  int mostrarParaRecompensaCalls = 0;

  @override
  Future<TipoAnuncioPendiente> anuncioDebido(String caminoId) async {
    caminoIdsConsultados.add(caminoId);
    return tipoPendiente;
  }

  @override
  Future<void> mostrarSiToca(String caminoId) async {
    mostrarSiTocaCalls++;
    if (retraso > Duration.zero) {
      await Future<void>.delayed(retraso);
    }
    await anuncioDebido(caminoId);
  }

  @override
  Future<bool> mostrarParaRecompensa() async {
    mostrarParaRecompensaCalls++;
    if (retraso > Duration.zero) {
      await Future<void>.delayed(retraso);
    }
    return recompensaGanada;
  }
}
