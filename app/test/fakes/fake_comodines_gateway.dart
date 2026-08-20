import 'package:geoquest/services/comodines_gateway.dart';

/// Inventario de ejemplo (semilla 1/1/1/0, D1 de `design.md`), para no
/// repetirlo en cada test que no ejercita cantidades concretas.
InventarioComodines inventarioDePrueba({
  int tiempo = 1,
  int pais = 1,
  int km1000 = 1,
  int km500 = 0,
}) {
  return InventarioComodines(
    cantidades: {
      ComodinTipo.tiempo: tiempo,
      ComodinTipo.pais: pais,
      ComodinTipo.km1000: km1000,
      ComodinTipo.km500: km500,
    },
  );
}

/// Lo que se mandó en una llamada a `usarComodin`, para poder comprobarlo
/// desde los tests.
class UsoDeComodinEnviado {
  const UsoDeComodinEnviado({
    required this.intentoId,
    required this.desafioId,
    required this.tipo,
  });

  final String intentoId;
  final String desafioId;
  final ComodinTipo tipo;
}

/// Falso de [ComodinesGateway] para probar la bandeja de la pantalla de
/// juego y la pantalla Comodines sin salir a la red (INT-119, mismo patrón
/// que `FakeNivelJuegoGateway`).
class FakeComodinesGateway implements ComodinesGateway {
  FakeComodinesGateway({InventarioComodines? inventario})
    : inventario = inventario ?? inventarioDePrueba();

  InventarioComodines inventario;

  /// Excepción a lanzar en la próxima llamada a `misComodines`.
  Object? throwOnNextMisComodines;

  int misComodinesCalls = 0;

  /// Lo que devuelve `usarComodin`; los tests que ejercitan un tipo concreto
  /// la cambian antes de usar el comodín.
  ResultadoUsoComodin resultadoUso = const ResultadoTiempo();

  /// Excepción a lanzar en la próxima llamada a `usarComodin`.
  Object? throwOnNextUsar;

  final List<UsoDeComodinEnviado> usosEnviados = [];

  /// Lo que devuelve `concederComodinPorAnuncio`.
  ComodinTipo tipoConcedido = ComodinTipo.tiempo;

  /// Excepción a lanzar en la próxima llamada a `concederComodinPorAnuncio`.
  Object? throwOnNextConceder;

  int concederComodinPorAnuncioCalls = 0;

  @override
  Future<InventarioComodines> misComodines() async {
    misComodinesCalls++;

    final error = throwOnNextMisComodines;
    if (error != null) {
      throwOnNextMisComodines = null;
      throw error;
    }

    return inventario;
  }

  @override
  Future<ResultadoUsoComodin> usarComodin({
    required String intentoId,
    required String desafioId,
    required ComodinTipo tipo,
  }) async {
    usosEnviados.add(
      UsoDeComodinEnviado(
        intentoId: intentoId,
        desafioId: desafioId,
        tipo: tipo,
      ),
    );

    final error = throwOnNextUsar;
    if (error != null) {
      throwOnNextUsar = null;
      throw error;
    }

    return resultadoUso;
  }

  @override
  Future<ComodinTipo> concederComodinPorAnuncio() async {
    concederComodinPorAnuncioCalls++;

    final error = throwOnNextConceder;
    if (error != null) {
      throwOnNextConceder = null;
      throw error;
    }

    return tipoConcedido;
  }
}
