import 'package:flutter/painting.dart' show Offset;

/// Un guión de la línea punteada: dos puntos de pantalla.
typedef Guion = (Offset desde, Offset hasta);

/// Trocea una polilínea en guiones de largo [guion] separados por huecos de
/// largo [hueco], recorriéndola de principio a fin.
///
/// D6 de `design.md` (INT-93): los guiones se cortan en espacio de pantalla,
/// no en el del mundo, para que midan lo mismo a cualquier zoom —el
/// `stroke-dasharray` con `non-scaling-stroke` del diseño—. El patrón se
/// mantiene de un segmento al siguiente, así que la línea no reinicia el
/// dibujo en cada vértice del arco.
List<Guion> trocearEnGuiones(
  List<Offset> polilinea, {
  double guion = 2.5,
  double hueco = 9,
}) {
  assert(guion > 0 && hueco > 0, 'Un patrón sin largo no dibuja nada');

  final guiones = <Guion>[];
  var pintando = true;
  var restante = guion;

  for (var i = 1; i < polilinea.length; i++) {
    final hasta = polilinea[i];
    var desde = polilinea[i - 1];
    var largo = (hasta - desde).distance;
    if (largo <= 0) continue;

    final direccion = (hasta - desde) / largo;
    while (largo > restante) {
      final corte = desde + direccion * restante;
      if (pintando && corte != desde) guiones.add((desde, corte));
      desde = corte;
      largo -= restante;
      pintando = !pintando;
      restante = pintando ? guion : hueco;
    }

    if (pintando && hasta != desde) guiones.add((desde, hasta));
    restante -= largo;
  }

  return guiones;
}
