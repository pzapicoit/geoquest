## 1. Renombrar "Nivel" a "Camino" en la pantalla de Clasificación

- [x] 1.1 Renombrar `ChipNivel` → `ChipCamino` y `derivarChipsNivel` → `derivarChipsCamino` en `app/lib/screens/ranking_screen.dart`.
- [x] 1.2 Renombrar el valor del enum `_Pestana.nivel` → `_Pestana.camino` (y todo lo que dependa de él: `_chipsNivel` → `_chipsCamino`, `_buscarChipNivel` → `_buscarChipCamino`, `_onSeleccionarNivel` → `_onSeleccionarCamino`).
- [x] 1.3 Cambiar la etiqueta de la pestaña de "Nivel" a "Camino" en `_SelectorPestanas._etiquetas`.
- [x] 1.4 Cambiar la etiqueta de cada chip de "Nivel N" a "Camino N".
- [x] 1.5 Cambiar el subtítulo contextual de "Nivel N · <temática>" a "Camino N · <temática>" (incluido el fallback genérico "Nivel" → "Camino").
- [x] 1.6 Renombrar la clave de los chips de `ranking-chip-nivel-*` a `ranking-chip-camino-*` y la de la pestaña de `ranking-tab-nivel` a `ranking-tab-camino`.

## 2. Corregir el recorte de texto en el selector de chips

- [x] 2.1 Subir el alto de la `SizedBox` que envuelve el `ListView` de chips (`_SelectorChips`) de 48 a 54px.
- [x] 2.2 Reducir el padding vertical del `ListView` de chips a `EdgeInsets.fromLTRB(18, 10, 18, 4)` para dejar más alto de contenido disponible.
- [x] 2.3 Confirmar visualmente (o con un test de `tester.getSize`/overflow) que el texto de un chip largo (p. ej. "Temática" más larga del catálogo) no se recorta ni genera overflow.

## 3. Actualizar tests y specs

- [x] 3.1 Actualizar `app/test/ranking_chips_test.dart`: `derivarChipsNivel` → `derivarChipsCamino`, `ChipNivel` → `ChipCamino`.
- [x] 3.2 Actualizar `app/test/ranking_screen_test.dart`: claves `ranking-tab-nivel`/`ranking-chip-nivel-*` → `ranking-tab-camino`/`ranking-chip-camino-*`, y cualquier texto de aserción que mencione "Nivel" en el contexto de esta pestaña.
- [x] 3.3 Ejecutar `flutter test`, `flutter analyze` y `dart format --set-exit-if-changed` en `app/` y confirmar que todo pasa sin regresiones.
- [ ] 3.4 Sincronizar `openspec/specs/app-ranking/spec.md` con los requisitos `MODIFIED` de este delta al archivar.
