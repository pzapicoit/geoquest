## Why

El camino del jugador (INT-90) navega hacia una pantalla de juego real al
tocar una parada desbloqueada, pero hoy solo existe un placeholder
(`NivelJuegoPlaceholderScreen`) que ni arranca un intento ni muestra
contenido de ningún desafío. El backend (INT-95) ya expone la vista
`desafios_para_jugar` y la RPC `iniciar_intento_nivel`, pensadas
justamente para alimentar esta pantalla sin filtrar la ubicación real.
Falta la primera fase de la pantalla de juego: mostrar la pista de cada
desafío en un toast antes de pasar al mapa (la fase de mapa/adivinar es
INT-92, aparte).

## What Changes

- Nueva pantalla `NivelJuegoScreen` que sustituye a
  `NivelJuegoPlaceholderScreen` como destino de `CaminoScreen` al tocar
  una parada desbloqueada (superada o actual).
- Al montarse, la pantalla llama a la RPC `iniciar_intento_nivel(nivel_id)`
  para crear el intento del jugador y obtener, en una sola respuesta, el
  `intento_id` y la lista de desafíos de esa partida (mismas columnas que
  `desafios_para_jugar`: `id`, `tipo`, `imagen_url`, `video_url`,
  `texto_pregunta`, `activo`).
- Toast/tarjeta superpuesta con el contenido de la pista del desafío
  actual, según su `tipo`: imagen a buen tamaño, video reproduciéndose, o
  texto de la pregunta en grande.
- Cabecera visible con el progreso dentro del intento ("Desafío 3 de 6")
  y el puntaje acumulado del intento actual (arranca en 0 — INT-92 sumará
  puntos al resolver cada desafío desde `respuestas_desafio`).
- Botón "Listo, voy a adivinar" que cierra el toast. Cerrar el toast pasa
  al estado de mapa a pantalla completa; ese estado es un stub visual
  hasta que INT-92 lo implemente (misma relación que dejó INT-90 con esta
  pantalla).
- Nuevo gateway de app (`NivelJuegoGateway`) que invoca
  `iniciar_intento_nivel` vía `supabase_flutter` y mapea la respuesta a
  modelos de la app (`IntentoNivel`, `DesafioJuego`).
- Estado de carga y de error al arrancar el intento (fallo de red o RPC),
  siguiendo el mismo patrón ya usado en `CaminoGateway`/`CaminoScreen`.
- Se elimina `NivelJuegoPlaceholderScreen`, ya sin uso.

## Capabilities

### New Capabilities
- `app-game-screen`: pantalla de juego del nivel — arranque de intento
  vía `iniciar_intento_nivel`, toast de pista por desafío según su tipo,
  progreso ("Desafío X de N") y puntaje acumulado visibles, y el gateway
  de app que la alimenta desde Supabase.

### Modified Capabilities
(ninguna — `app-player-path-home` ya especifica de forma genérica que
tocar una parada desbloqueada navega "a la pantalla de juego del
`nivel_id`"; esta propuesta solo reemplaza qué pantalla es esa, sin
cambiar ese requisito)

## Impact

- **Código nuevo**: `app/lib/screens/nivel_juego_screen.dart` (+ widget
  del toast de pista), `app/lib/services/nivel_juego_gateway.dart`.
- **Código modificado**: `app/lib/screens/camino_screen.dart`
  (`_onTapParada` navega a `NivelJuegoScreen` en vez del placeholder).
- **Código eliminado**: `app/lib/screens/nivel_juego_placeholder_screen.dart`.
- **Dependencias externas**: `video_player` (o equivalente ya evaluado en
  `pubspec.yaml`) si no hay ya una dependencia de reproducción de vídeo en
  el proyecto — a confirmar en design.md.
- **Backend**: sin cambios. Se apoya en `iniciar_intento_nivel` y
  `desafios_para_jugar`, ya archivadas en `challenge-play` (INT-95).
- **Diseño**: el mockup visual vive en Claude Design
  (`[App] - Pantalla de juego.dc.html`); esta sesión no tiene acceso al
  MCP de importación de diseño (`claude_design`/`/design-login`), así que
  la implementación sigue los criterios de aceptación de INT-91 y el
  lenguaje visual ya establecido en `camino_screen.dart` (paleta, tipos
  `GoogleFonts.baloo2`/`outfit`) en vez del mockup pixel a pixel.
