## Why

Al terminar el último desafío de un nivel, la pantalla de juego hoy se
limita a volver al camino (`Navigator.pop`) sin cerrar el intento — un
placeholder dejado a propósito en INT-92/93 hasta que existiera lógica de
superación que cerrar (INT-79) y un `cerrar_intento_nivel` capaz de cerrar
cualquier intento real (INT-100, ya resuelto). El jugador nunca se entera
de si superó el nivel, cuántas estrellas ganó o si hizo récord, y el
camino tampoco refleja el resultado hasta reabrir la app.

## What Changes

- Nueva pantalla de resumen del nivel, fiel al diseño `[App] - Resumen del
  nivel.dc.html` (Claude Design), con sus dos estados:
  - **Superado**: nombre del nivel, mensaje de celebración, estrellas
    rellenándose una a una (con confeti si son 3), aviso de "nuevo récord
    personal" cuando corresponda, y botón "Continuar" al camino.
  - **No superado**: mensaje de ánimo, puntaje y cuánto faltó para el
    mínimo (con barra de progreso), estrellas apagadas, botón "Reintentar"
    (arranca el nivel desde el primer desafío) y enlace "Volver al
    camino".
- Al llegar al último desafío y pulsar "Ver resultados", la pantalla de
  juego pasa a cerrar el intento (`cerrar_intento_nivel`) y navega al
  resumen en vez de volver directamente al camino.
- **BREAKING**: `cerrar_intento_nivel` deja de devolver la fila cruda de
  `intentos_nivel` y pasa a devolver un `jsonb` con el resultado del cierre
  más los datos que el resumen necesita y que hoy no viajan a ningún
  sitio: el `puntaje_minimo_superar` del nivel y el `mejor_puntaje` que
  tenía el jugador en ese nivel *antes* de este cierre (para detectar
  récord sin que el propio cierre, que ya actualiza
  `progreso_usuario_nivel`, se pise a sí mismo). Único consumidor actual:
  esta misma app, que todavía no llama a la función en producción.
- El camino recarga su progreso al volver de la pantalla de juego
  (`Continuar` o `Volver al camino`), para que estrellas y desbloqueos
  nuevos se vean sin reabrir la app.

## Capabilities

### New Capabilities
- `app-level-summary`: pantalla de resumen del intento al terminar un
  nivel, con sus dos estados (superado / no superado) y sus acciones de
  continuar, reintentar y volver.

### Modified Capabilities
- `app-game-screen`: terminar el último desafío ya no vuelve directo al
  camino — cierra el intento y entra en el resumen del nivel.
- `level-progression`: el contrato de respuesta de `cerrar_intento_nivel`
  se amplía (puntaje mínimo del nivel y mejor puntaje previo del jugador),
  para que el cliente pueda mostrar "cuánto faltó" y detectar un récord sin
  llamadas adicionales ni condiciones de carrera con la propia
  actualización de progreso.
- `app-player-path-home`: el camino recarga su progreso al volver de la
  pantalla de juego, en vez de solo al abrir la Home.

## Impact

- **Backend**: nueva migración que sustituye `cerrar_intento_nivel` (jsonb
  de salida en vez de `intentos_nivel`); captura del `mejor_puntaje`
  previo antes del upsert de `progreso_usuario_nivel`.
- **App**: `nivel_juego_gateway.dart` (nuevo método `cerrarIntento` +
  modelo del resultado), `nivel_juego_screen.dart` (el "Ver resultados"
  del último desafío cierra el intento y navega en vez de hacer `pop`, y
  necesita recibir del camino el número de parada y el nombre de la
  temática para el rótulo del resumen), nueva pantalla
  `resumen_nivel_screen.dart`, y `camino_screen.dart` (recarga al volver de
  jugar).
