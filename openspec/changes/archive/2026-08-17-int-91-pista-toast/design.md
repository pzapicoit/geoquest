## Context

`CaminoScreen` (INT-90) navega a `NivelJuegoPlaceholderScreen` al tocar una
parada desbloqueada, solo para poder probar manualmente qué nivel se iba a
abrir. El backend (INT-95) ya expone lo necesario para reemplazar ese
placeholder por una pantalla real:

- RPC `iniciar_intento_nivel(p_nivel_id uuid) returns jsonb`, que crea la
  fila en `intentos_nivel` para `auth.uid()` y devuelve
  `{"intento_id": uuid, "desafios": [{id, tipo, imagen_url, video_url,
  texto_pregunta, activo}, ...]}`. Los desafíos ya vienen filtrados
  (`activo = true`), ordenados y — si el nivel tiene
  `preguntas_por_partida` — recortados al azar en el propio SQL.
- `tipo` es un enum Postgres (`'imagen' | 'video' | 'pregunta_texto'`) con
  exclusividad mutua garantizada por constraint: un desafío `imagen` solo
  trae `imagen_url`, uno `video` solo `video_url`, uno `pregunta_texto`
  solo `texto_pregunta` (las otras dos columnas llegan `null`).

Esta pantalla es solo la fase 1 ("pista"): mostrar el contenido de cada
desafío en un toast. La fase 2 (mapa a pantalla completa donde el jugador
marca su respuesta, y el guardado de puntos en `respuestas_desafio`) es
INT-92 y queda fuera de esta propuesta.

## Goals / Non-Goals

**Goals:**
- Arrancar un intento real (`iniciar_intento_nivel`) al entrar a la
  pantalla de juego, en vez del placeholder estático.
- Mostrar la pista del desafío actual en un toast, con el contenido
  correcto según `tipo`.
- Dejar visible el progreso (`Desafío X de N`) y el puntaje acumulado del
  intento.
- Cerrar el toast debe revelar el estado de mapa a pantalla completa,
  aunque ese estado siga siendo un stub hasta INT-92 (mismo patrón que
  dejó INT-90 con esta propia pantalla).

**Non-Goals:**
- Implementar el mapa interactivo o la lógica de adivinar/puntuar
  (INT-92).
- Avanzar automáticamente de un desafío al siguiente: eso ocurre al
  resolver en el mapa, que no existe todavía. Esta pantalla, tal cual
  queda tras INT-91, solo muestra la pista del primer desafío del
  intento.
- Cachear o reanudar un intento ya iniciado (por ejemplo, si el usuario
  sale y vuelve a entrar a la parada): cada entrada llama de nuevo a
  `iniciar_intento_nivel` y crea un intento nuevo, igual que hace
  `CaminoGateway.fetchCamino()` con cada apertura de la Home.

## Decisions

**D1 — Un solo widget de pantalla, no dos.** En vez de mantener
`NivelJuegoPlaceholderScreen` como la vista "de fondo" tras cerrar el
toast, se elimina y su rol pasa a ser un widget interno privado de
`NivelJuegoScreen` (el "stub de mapa"). Mantener dos screens obligaría a
pasar el intento ya cargado de una a otra sin motivo: el mapa real
(INT-92) va a necesitar los mismos desafíos y el mismo `intento_id`, así
que es la misma pantalla la que evoluciona, no una navegación distinta.

**D2 — Gateway dedicado, mismo patrón que `CaminoGateway`.**
`NivelJuegoGateway` es una clase abstracta con
`Future<IntentoNivel> iniciarIntento(String nivelId)`, implementada por
`SupabaseNivelJuegoGateway` sobre
`_client.rpc('iniciar_intento_nivel', params: {'p_nivel_id': nivelId})`.
Igual que `CaminoGateway`, se puede inyectar un fake en tests sin tocar la
red. Modelos nuevos (`IntentoNivel`, `DesafioJuego`) en el mismo archivo,
igual que `CaminoJugador`/`ParadaCamino` en `camino_gateway.dart`.

**D3 — Puntaje del intento se muestra fijo en 0.** Un intento recién
creado no tiene filas en `respuestas_desafio` todavía (esa tabla solo se
llena al resolver, que es INT-92). Consultarla en este punto sería una
llamada de red que siempre devolvería 0 para este flujo. Se muestra `0`
directamente sin consulta adicional; cuando INT-92 añada la resolución,
esa historia es quien tendrá el puntaje real que mostrar tras cada
desafío.

**D4 — Progreso usa el índice local, no datos del servidor.** `Desafío X
de N` sale de `desafios.length` (N) y de un índice local en el estado del
widget que arranca en 0 (X = índice + 1). No hace falta que el backend
lleve la cuenta: mientras no exista la fase de mapa, el índice nunca
avanza dentro de esta pantalla.

**D5 — Reproducción de vídeo con `video_player`.** No hay ninguna
dependencia de vídeo en `pubspec.yaml` todavía. Se añade
[`video_player`](https://pub.dev/packages/video_player) (paquete oficial
de `flutter.dev`, ya soporta iOS/Android/Web como el resto del proyecto)
en vez de alternativas como `chewie` (trae controles de UI completos que
no pide el criterio de aceptación — solo dice "video reproduciéndose").
El vídeo de pista arranca en autoplay, en bucle y sin sonido
(`setVolume(0)`): son clips ambientales de un lugar, no llevan audio
relevante para adivinar, y pedir que el jugador le dé a play manualmente
antes de ver la pista sería fricción innecesaria. *(Asunción a validar —
ver Open Questions.)*

**D6 — Estado de carga/error sigue el patrón de `CaminoScreen`.**
`FutureBuilder`/estado explícito (`_cargando`, `_error`) igual que ya usa
`CaminoScreen` para `fetchCamino()`: spinner mientras se llama a
`iniciar_intento_nivel`, mensaje + botón "Reintentar" si falla (nivel
inactivo/inexistente, sin red, etc.), sin distinguir el motivo concreto
del error en la UI (igual que el resto de la app no lo hace hoy).

## Risks / Trade-offs

- **[Riesgo] Probar reproducción real de vídeo en widget tests es frágil**
  (el motor de `video_player` no corre en el entorno de test) →
  Mitigación: los tests cubren el mapeo de datos (`DesafioJuego` desde el
  jsonb de la RPC) y la lógica de la pantalla (qué contenido decide
  mostrar según `tipo`, cálculo de "X de N") con un `NivelJuegoGateway`
  falso; el widget de vídeo en sí se prueba solo por construcción (no
  lanza, usa la URL correcta), no por reproducción real.
- **[Riesgo] Autoplay con sonido silenciado puede no ser lo que el diseño
  original (`.dc.html`, no accesible en esta sesión) tenía pensado** →
  Mitigación: es una decisión reversible y aislada a un widget; se deja
  registrada como asunción en Open Questions para revisar en testing
  local frente al mockup real.
- **[Trade-off] Cada apertura de la pantalla crea un intento nuevo en
  `intentos_nivel`**, incluso si el jugador entra y sale sin jugar → Ya es
  el comportamiento que la RPC ofrece hoy (INT-95 no contempla reanudar
  intentos) y coincide con cómo ya se comporta `CaminoGateway` para la
  Home; no se introduce lógica de reanudación en esta historia para no
  ampliar su alcance.

## Open Questions

- ¿El vídeo de pista debe llevar sonido y controles visibles, o el
  autoplay silencioso en bucle (D5) es correcto? A confirmar contra el
  mockup de Claude Design cuando se pueda importar, o directamente en
  testing local.
