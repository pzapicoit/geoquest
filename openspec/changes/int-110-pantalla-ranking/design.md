## Context

La app Flutter (`app/lib`) no usa gestión de estado con librería (Provider/Riverpod/Bloc): cada pantalla es un `StatefulWidget` con `setState`, inyección manual de gateways por constructor, y navegación con `Navigator.push`/`MaterialPageRoute` (sin GoRouter, sin bottom nav bar). El patrón de capas es `screens/<pantalla>.dart` (widgets privados incluidos en el mismo archivo) + `services/<dominio>_gateway.dart` (interfaz + implementación Supabase + modelos de datos del propio dominio).

El backend de clasificación (INT-109, ya archivado) expone tres RPC `security definer` en Supabase — `clasificacion_global(p_limite)`, `clasificacion_por_camino(p_camino_id, p_limite)`, `clasificacion_por_tematica(p_tematica_id, p_limite)` — cada una devolviendo filas con `usuario_id, nombre, avatar_url, puntuacion, niveles_superados|superado, posicion, es_usuario_actual`, acotadas a un límite `[1,100]` en servidor, incluyendo siempre la fila del llamante. Ese proposal marcó explícitamente la UI de app como fuera de su alcance — esta es la tarea que la consume.

`CaminoGateway.fetchCamino()` (`app/lib/services/camino_gateway.dart`) ya devuelve la lista de paradas del camino (`ParadaCamino`) con `tematicaId`/`tematicaNombre` por parada, en orden — de ahí se pueden derivar tanto los chips de "Nivel" (una parada = un chip) como los de "Temática" (temáticas distintas, deduplicadas).

El mockup de diseño (Claude Design, `[App] - Ranking.dc.html`) usa datos simulados con conceptos que el backend real no soporta: indicador de variación ▲/▼, "racha", "intentos", "% acierto" y "temporada". Estos se simplifican o se omiten según el proposal.

## Goals / Non-Goals

**Goals:**
- Pantalla de Clasificación funcional consumiendo las 3 RPC reales, con las 3 pestañas, podio, lista, fila fija propia y estados de carga/vacío.
- Seguir las convenciones existentes de la app (StatefulWidget+setState, gateway inyectable, GoogleFonts Baloo2/Outfit, paleta oscura, testing con fakes).
- Un punto de entrada real desde la navegación existente (barra superior de `CaminoScreen`).

**Non-Goals:**
- Backend nuevo o cambios de esquema (ya cubierto por INT-109 / `player-ranking`).
- Indicador de variación ▲/▼, racha, intentos, % de acierto o concepto de "temporada" — no hay datos que los soporten hoy.
- Avatar con imagen real (`avatar_url`) — la app no descarga ni cachea imágenes de avatar en ningún otro sitio hoy; se usa el patrón existente de iniciales sobre gradiente (`_BotonPerfil` en `camino_screen.dart`).
- Paginación / scroll infinito más allá del top acotado por servidor (máx. 100 filas) — fuera de alcance de esta iteración.

## Decisions

### 1. Nuevo gateway `RankingGateway` dedicado a las 3 RPC
`app/lib/services/ranking_gateway.dart`: `abstract class RankingGateway` con tres métodos (`fetchClasificacionGlobal`, `fetchClasificacionPorCamino(caminoId)`, `fetchClasificacionPorTematica(tematicaId)`) + `class SupabaseRankingGateway implements RankingGateway` llamando a `_client.rpc('clasificacion_global'|'clasificacion_por_camino'|'clasificacion_por_tematica', params: {...})`, siguiendo el patrón de `nivel_juego_gateway.dart` para invocar RPC y mapear filas.

Modelo único `EntradaRanking { usuarioId, nombre, avatarUrl, puntuacion, nivelesSuperados, superado, posicion, esUsuarioActual }` (campos opcionales según la función de origen) — se prefiere un modelo compartido a tres modelos casi idénticos, ya que las 3 RPC comparten la mayoría de columnas.

**Alternativa descartada**: extender `CaminoGateway` con métodos de ranking. Se descarta porque `CaminoGateway` es del dominio "camino del jugador", no de clasificación entre jugadores; mezclar responsabilidades dificultaría el testing con fakes independientes.

### 2. Los chips de Nivel/Temática se derivan de `CaminoGateway.fetchCamino()`, sin nuevo gateway
La pantalla de Ranking recibe (o resuelve internamente) la lista de `ParadaCamino` ya existente para construir: chips de "Nivel" (una entrada por parada, en `orden`) y chips de "Temática" (temáticas distintas por `tematicaId`, dedupe conservando el primer `tematicaNombre` visto). No se crea un gateway de temáticas nuevo.

**Alternativa descartada**: pedir al backend una función nueva que liste temáticas/paradas para el selector. Se descarta porque esa información ya está disponible en el cliente vía `CaminoGateway`, evitando una llamada de red adicional.

### 3. Estado: `StatefulWidget` + `setState`, una carga por (pestaña, selección de chip)
`RankingScreen` mantiene `_tab` (0/1/2), `_paradaSeleccionada`/`_tematicaSeleccionada` y un `Future<List<EntradaRanking>>` que se reasigna al cambiar de pestaña o de chip — mismo patrón que `CaminoScreen` con `FutureBuilder`. Cada cambio de selección dispara una nueva llamada RPC (sin caché entre pestañas): las clasificaciones pueden cambiar entre navegaciones y el volumen de datos es pequeño (top ≤100 filas).

### 4. Punto de entrada: icono en `_BarraSuperior` de `CaminoScreen`
Se añade un botón de acceso a Ranking en `_BarraSuperior` (junto al botón de perfil existente), navegando con `Navigator.push(MaterialPageRoute(builder: (_) => RankingScreen(...)))`. Se elige este punto porque es la única barra de navegación global persistente que existe hoy en la app.

**Alternativa descartada**: bottom nav bar nueva. Se descarta por ser un cambio de navegación mucho más amplio que esta tarea, no solicitado por el ticket.

### 5. Datos contextuales de la fila: simplificados a lo que el backend expone
- Pestaña Global: `"<nivelesSuperados> niveles superados"`.
- Pestaña Nivel: `"Superado"` / `"Aún no superado"` según `superado`.
- Pestaña Temática: `"<nivelesSuperados> niveles superados"`.

Sin indicador ▲/▼, sin racha, sin intentos, sin % de acierto — el proposal ya documenta esto como decisión de alcance frente al mockup.

### 6. Fila fija propia: usa la fila `es_usuario_actual = true` que ya devuelve cada RPC
No hace falta calcular la posición propia por separado ni hacer una segunda llamada: cada RPC ya incluye la fila del llamante. Si `posicion == null` (sin puntuación agregable), la fila fija muestra un estado "sin posición todavía" en vez de un número.

## Risks / Trade-offs

- **[Riesgo] Sin caché entre pestañas** → cada cambio de pestaña/chip dispara una llamada de red nueva, lo que puede sentirse lento con conexión mala. *Mitigación*: estado de carga inmediato (spinner) por selección, igual que ya hace `CaminoScreen`; no se optimiza más por ser fuera de alcance de esta iteración.
- **[Riesgo] El selector de "Nivel" puede tener 13+ chips** → en pantallas pequeñas el scroll horizontal de chips puede no dejar claro que hay más opciones. *Mitigación*: el propio mockup ya usa `overflow-x:auto` con chips de ancho fijo; se replica igual con un `ListView` horizontal.
- **[Trade-off] Simplificar el dato contextual respecto al mockup** → la pantalla real se ve "menos rica" que la maqueta. *Mitigación*: aceptado explícitamente en el proposal; se prioriza no inventar datos (racha/intentos/%acierto) que no existen en el backend.

## Migration Plan

No aplica migración de datos. Es una pantalla nueva sin flag de despliegue: se activa al mergear, con un botón de entrada nuevo en `CaminoScreen`. Reversible eliminando el botón de entrada y el archivo de la pantalla/gateway si hiciera falta revertir.

## Open Questions

Ninguna bloqueante — el punto de entrada elegido (barra superior de `CaminoScreen`) es una decisión razonable dado el estado actual de navegación; si el usuario prefiere otro punto de entrada (p. ej. desde el resumen de nivel) se puede ajustar en tasks.md antes de implementar.
