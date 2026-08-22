import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoquest/screens/marco_de_movil.dart';

/// Monta el marco con un hijo que anota el ancho que ve por `MediaQuery`.
Future<Size> _anchoVisto(WidgetTester tester, Size ventana) async {
  tester.view.physicalSize = ventana;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  late Size visto;
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MarcoDeMovil(child: child!),
      home: Builder(
        builder: (context) {
          visto = MediaQuery.sizeOf(context);
          return const SizedBox.expand(child: ColoredBox(color: Colors.red));
        },
      ),
    ),
  );
  return visto;
}

void main() {
  testWidgets('en un móvil no encajona nada', (tester) async {
    final visto = await _anchoVisto(tester, const Size(390, 844));

    expect(visto.width, 390);
    // Sin marco no hay franja que pintar: el hijo ocupa la ventana entera.
    expect(tester.getSize(find.byType(ColoredBox).last).width, 390);
  });

  testWidgets('en una ventana ancha encajona a la franja de juego', (
    tester,
  ) async {
    final visto = await _anchoVisto(tester, const Size(1440, 900));

    expect(
      tester.getSize(find.byType(SizedBox).first).width,
      anchoMaximoDeJuego,
    );
    // Lo que importa: el ancho que ven las pantallas es el pintado, no el de
    // la ventana. La cámara del mapa y el encuadre del revelado calculan
    // sobre MediaQuery, así que un 1440 aquí les descuadraría la aritmética.
    expect(visto.width, anchoMaximoDeJuego);
    // El alto no se recorta: la franja es vertical, no una ventana de móvil.
    expect(visto.height, 900);
  });

  testWidgets('recorta lo que se pinte fuera de la franja', (tester) async {
    // Sin esto el mapa mundial se derrama por la ventana entera: CustomPaint
    // no recorta su lienzo al tamaño del widget, solo el layout queda
    // limitado. Se comprobo en navegador antes de existir este test.
    await _anchoVisto(tester, const Size(1440, 900));

    expect(find.byType(ClipRect), findsWidgets);
  });

  testWidgets('justo en el tope no encajona', (tester) async {
    final visto = await _anchoVisto(tester, Size(anchoMaximoDeJuego, 900));

    expect(visto.width, anchoMaximoDeJuego);
    expect(find.byType(Center), findsNothing);
  });
}
