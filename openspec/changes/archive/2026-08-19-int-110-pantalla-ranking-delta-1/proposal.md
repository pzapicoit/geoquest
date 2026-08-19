---
type: functional
parent: int-110-pantalla-ranking
reason: Feedback de testing local — la pestaña "Nivel" está mal nombrada (el ticket original la describió mal; agrupa por camino, no por "nivel") y el texto de los chips de filtro se ve cortado.
---

## Why

En testing local de INT-110 se detectaron dos problemas en la pantalla de Clasificación:

1. La pestaña "Nivel" agrupa por parada del **camino** (`clasificacion_por_camino`, `camino_id`), no por "nivel" — nombre que el ticket original usó por error. El resto de la app ya usa "camino"/"parada" como vocabulario de cara al jugador (no "nivel"), así que mantener "Nivel" es una inconsistencia de producto, no solo un detalle cosmético.
2. El texto de los chips de filtro (selector de Nivel/Temática) se ve cortado verticalmente: la `SizedBox` que envuelve el `ListView` de chips (48px) no dejaba suficiente alto tras restar el padding del propio `ListView` y el padding vertical del chip, así que el texto se recorta contra el borde del chip.

## What Changes

- Renombrar la pestaña "Nivel" a "Camino" en toda la pantalla de Clasificación: etiqueta de la pestaña, subtítulo contextual ("Camino N · <temática>") y etiqueta de cada chip ("Camino N" en vez de "Nivel N").
- **BREAKING** (solo interno, sin persistencia): se renombran identificadores internos asociados (`ChipNivel` → `ChipCamino`, `derivarChipsNivel` → `derivarChipsCamino`, claves de test `ranking-tab-nivel`/`ranking-chip-nivel-*` → `ranking-tab-camino`/`ranking-chip-camino-*`). No afecta a datos ni a contratos de red.
- Corregir el alto reservado para el selector de chips para que el texto no se recorte, en cualquiera de las dos pestañas con selector (Camino y Temática).

## Capabilities

### Modified Capabilities
- `app-ranking`: la pestaña que clasifica por parada del camino se llama "Camino" (no "Nivel") en la etiqueta de la pestaña, el subtítulo y los chips; el selector de chips no debe recortar su texto.

## Impact

- `app/lib/screens/ranking_screen.dart`: identificadores, textos visibles y layout del selector de chips.
- `app/test/ranking_chips_test.dart`, `app/test/ranking_screen_test.dart`: nombres/keys actualizados.
- `openspec/specs/app-ranking/spec.md`: texto de los requisitos que mencionan "Nivel" pasa a "Camino".
- Sin cambios de backend ni de RPC — `clasificacion_por_camino` ya usaba el vocabulario correcto.
