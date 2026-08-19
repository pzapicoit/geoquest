## Context

`RankingScreen` (INT-110) ya usa "camino"/`caminoId`/`ChipNivel.caminoId` internamente para esta pestaña — el gateway (`fetchClasificacionPorCamino`) y el modelo de datos (`ParadaCamino`, `camino_id`) ya estaban bien nombrados. Solo el texto visible (etiqueta de pestaña, subtítulo, etiqueta de chip) y algunos identificadores puramente cosméticos (`ChipNivel`, `derivarChipsNivel`) usaban la palabra "Nivel", heredada de un error de redacción en el ticket original.

Por separado, el selector de chips (`_SelectorChips`) reserva una `SizedBox(height: 48)` para el `ListView` horizontal de chips. Ese alto se reparte así: el propio `ListView` aplica `padding: EdgeInsets.fromLTRB(18, 14, 18, 2)` (14 arriba + 2 abajo = 16px), dejando 32px de alto disponible para cada chip; cada chip añade `padding: EdgeInsets.symmetric(vertical: 9)` (18px), dejando solo 14px para el contenido (el punto de color + el texto). Una línea de texto con `GoogleFonts.outfit` a `fontSize: 12` necesita más de 14px de alto de línea (ascOsent+descenso+leading), así que se recorta contra el borde del chip.

## Goals / Non-Goals

**Goals:**
- La pestaña que agrupa por parada del camino se llama "Camino" en todo lo visible (pestaña, subtítulo, chip).
- El texto de los chips de filtro (Camino y Temática) se ve completo, sin recorte, con margen para variar la fuente o el tamaño ligeramente en el futuro sin volver a romperse.

**Non-Goals:**
- No cambia el contrato de las RPC ni el modelo de datos (`clasificacion_por_camino`, `ParadaCamino`) — ya usaban "camino" correctamente.
- No rediseña el selector de chips más allá de corregir el alto; sigue siendo un `ListView` horizontal de chips.

## Decisions

1. **Renombrar solo lo visible + identificadores cosméticos de esta pantalla**, no tocar el gateway ni el modelo de camino existente (`CaminoGateway`, `ParadaCamino`), que ya usan el vocabulario correcto. Alcance: `ranking_screen.dart` y sus tests.
2. **Corregir el alto del selector de chips con margen, no al límite exacto**: subir la `SizedBox` de 48 a 54px y reducir el padding vertical del `ListView` a `EdgeInsets.fromLTRB(18, 10, 18, 4)`, dejando ~22px de alto de contenido tras el padding del chip — margen cómodo sobre los ~16-17px que necesita una línea de texto a `fontSize: 12`, en vez de ajustar al pixel justo que causó el bug original.

## Risks / Trade-offs

- **[Riesgo] Quedan referencias a "Nivel" en textos históricos** (comentarios de código, nombres de commit anteriores) → no se tocan intencionadamente: el histórico de git no se reescribe; solo importa que el código y los tests actuales no usen ya esa palabra de cara al jugador.
