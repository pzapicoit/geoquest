import 'package:flutter/material.dart';

/// Ancho máximo del área de juego, en píxeles lógicos.
///
/// Por encima de este ancho la app se pinta centrada en una franja de este
/// tamaño en vez de estirarse. El valor es el de un móvil grande en vertical:
/// todas las pantallas están diseñadas para eso, y la app se bloquea en
/// vertical (INT-102).
const double anchoMaximoDeJuego = 430;

/// Encajona la app en una franja vertical cuando la ventana es más ancha que
/// [anchoMaximoDeJuego].
///
/// Existe por el navegador —en una ventana de escritorio el diseño vertical se
/// estiraba y las pantallas quedaban desproporcionadas—, pero **no se decide
/// por plataforma sino por ancho disponible**: en un móvil la ventana es más
/// estrecha que el tope y este widget no hace nada, mientras que en una tablet
/// sí conviene que actúe.
///
/// El recorte no es decorativo: `CustomPaint` **no recorta su lienzo** al
/// tamaño del widget, así que el mapa mundial —un `CustomPainter` que dibuja
/// el mundo entero— se derramaba por la ventana completa mientras el resto de
/// la interfaz sí quedaba encajonada. El `ClipRect` es lo que mantiene la
/// franja siendo una franja.
///
/// Lo otro importante no es el `SizedBox`, es el [MediaQuery]: se sobrescribe el
/// tamaño con el del área realmente pintada. Sin eso, el ancho que ven las
/// pantallas seguiría siendo el de la ventana entera, y la aritmética que
/// depende de él se descuadraría — la cámara del mapa garantiza que el mundo
/// cubra el área visible, y el encuadre del revelado reserva una fracción del
/// alto para su hoja. Ambas leen `MediaQuery`.
class MarcoDeMovil extends StatelessWidget {
  const MarcoDeMovil({super.key, required this.child, this.fondo = _fondo});

  /// Fondo de los márgenes que quedan a los lados de la franja.
  static const Color _fondo = Color(0xFF061019);

  final Widget child;
  final Color fondo;

  @override
  Widget build(BuildContext context) {
    final medidas = MediaQuery.of(context);
    if (medidas.size.width <= anchoMaximoDeJuego) return child;

    return ColoredBox(
      color: fondo,
      child: Center(
        child: SizedBox(
          width: anchoMaximoDeJuego,
          child: ClipRect(
            child: MediaQuery(
              data: medidas.copyWith(
                size: Size(anchoMaximoDeJuego, medidas.size.height),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
