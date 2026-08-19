## 1. Modelo y gateway de clasificación

- [x] 1.1 Crear `app/lib/services/ranking_gateway.dart` con el modelo `EntradaRanking` (`usuarioId, nombre, avatarUrl, puntuacion, nivelesSuperados, superado, posicion, esUsuarioActual`) y una función pura de mapeo `mapearEntradaRanking(Map)` testeable sin red.
- [x] 1.2 Definir `abstract class RankingGateway` con `fetchClasificacionGlobal({int limite})`, `fetchClasificacionPorCamino(String caminoId, {int limite})`, `fetchClasificacionPorTematica(String tematicaId, {int limite})`.
- [x] 1.3 Implementar `SupabaseRankingGateway implements RankingGateway` llamando a `_client.rpc('clasificacion_global'|'clasificacion_por_camino'|'clasificacion_por_tematica', params: {...})` y mapeando cada fila con `mapearEntradaRanking`.
- [x] 1.4 Crear `app/test/fakes/fake_ranking_gateway.dart` (contador de llamadas por método, `throwOnNextCall`, datos fijos inyectables) siguiendo el patrón de `fake_camino_gateway.dart`.
- [x] 1.5 Tests de `ranking_gateway_test.dart`: mapeo correcto de filas, incluida la fila con `es_usuario_actual = true` y el caso `posicion = null`.

## 2. Helpers de selección (chips de Nivel/Temática)

- [x] 2.1 Función pura para derivar la lista de chips de "Temática" a partir de `List<ParadaCamino>` (temáticas distintas por `tematicaId`, dedupe conservando el primer `tematicaNombre` visto, en orden de aparición).
- [x] 2.2 Función pura para derivar la lista de chips de "Nivel" a partir de `List<ParadaCamino>` (una entrada por parada, en `orden`, con su `tematicaNombre` para el color/etiqueta del chip).
- [x] 2.3 Tests unitarios de ambos helpers (paradas vacías, temáticas repetidas, orden estable).

## 3. Pantalla de Clasificación

- [x] 3.1 Crear `app/lib/screens/ranking_screen.dart` como `StatefulWidget` con inyección opcional de `RankingGateway` y `CaminoGateway` por constructor (fallback a las implementaciones Supabase), siguiendo la paleta oscura/gradiente y fuentes `GoogleFonts.baloo2`/`GoogleFonts.outfit` de `camino_screen.dart`.
- [x] 3.2 Cabecera: botón volver, título "Clasificación", subtítulo contextual por pestaña, píldora de puntos totales del propio jugador.
- [x] 3.3 Selector de 3 pestañas (Global/Nivel/Temática) que, al cambiar, reasigna el `Future` de clasificación activo y resetea el estado de carga.
- [x] 3.4 Selector de chips horizontal (`ListView` scroll horizontal), visible solo en Nivel y Temática, usando los helpers de la sección 2; seleccionar un chip reasigna el `Future` de clasificación.
- [x] 3.5 Widget de podio (top 3) con avatar por inicial sobre gradiente (reutilizando el patrón de `_BotonPerfil`), nombre y puntuación, distinguiendo 1º/2º/3º; oculta puestos que no existan si hay menos de 3 filas.
- [x] 3.6 Lista scrollable con el resto de posiciones (puesto, avatar, nombre, dato contextual según pestaña — sección "Decisions" de design.md, punto 5 —, puntuación), con `Key` explícitas por fila para testing.
- [x] 3.7 Fila fija al pie con la posición/puntuación propia, usando la fila `es_usuario_actual = true`; estado especial "sin posición todavía" cuando `posicion == null`.
- [x] 3.8 Estados de carga (spinner) y vacío (mensaje "todavía no hay clasificación para esta selección") por pestaña/chip, sin mostrar datos obsoletos de la selección anterior mientras carga.
- [x] 3.9 Manejo de error de red (RPC falla): estado de error con opción de reintentar, siguiendo el patrón `_ErrorCamino` de `camino_screen.dart`.

## 4. Integración en la navegación

- [x] 4.1 Añadir botón de acceso a Ranking en `_BarraSuperior` de `camino_screen.dart`, junto al botón de perfil existente.
- [x] 4.2 Navegar con `Navigator.push(MaterialPageRoute(builder: (_) => RankingScreen(...)))`, abriendo por defecto la pestaña Global.
- [x] 4.3 Pasar a `RankingScreen` los datos ya disponibles en `CaminoScreen` (paradas del camino, puntos totales del jugador) para evitar una recarga redundante de `CaminoGateway.fetchCamino()` si ya están en memoria.

## 5. Tests de pantalla y verificación final

- [x] 5.1 `ranking_screen_test.dart`: cambio de pestaña recarga los datos correctos (usando `FakeRankingGateway`); selector de chips visible solo en Nivel/Temática; podio muestra top 3; fila fija muestra la posición propia incluso fuera del top; estados de carga y vacío.
- [x] 5.2 Test del punto de entrada: pulsar el botón de Ranking en `CaminoScreen` navega a `RankingScreen`.
- [x] 5.3 Ejecutar el conjunto completo de tests de `app/` y comprobar que no hay regresiones en `camino_screen_test.dart` tras tocar `_BarraSuperior`.
- [x] 5.4 Revisar visualmente contra el mockup de Claude Design (`[App] - Ranking.dc.html`) las 3 pestañas, confirmando que las simplificaciones de alcance (sin ▲/▼, sin racha/intentos/%acierto, subtítulo Global sin "temporada") están aplicadas de forma consistente y no accidentalmente omitidas en otro sitio.
