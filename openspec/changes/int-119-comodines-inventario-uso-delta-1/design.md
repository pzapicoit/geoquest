## Context

`int-119-comodines-inventario-uso` (archivado) implementó el comodín `tiempo` como una extensión de 15s del margen antes del auto-envío (`CuentaAtrasDeDesafio.extender`), y los comodines de radio con 1000km/500km. Tras probar en dispositivo, Pablo pide un efecto distinto para `tiempo` (parar el crono del todo) y radios más ajustados para `km1000`/`km500`.

## Goals / Non-Goals

**Goals:**
- El comodín `tiempo` detiene el cronómetro por completo para el desafío en curso (sin auto-envío, sin límite de tiempo).
- `km1000` concede un radio de 500km; `km500` concede un radio de 150km.
- Iconos de la bandeja de juego más grandes; tarjetas de la pantalla Comodines sin caja/borde, con el icono en vez del arte ancho, más espaciadas.

**Non-Goals:**
- No se renombran los identificadores internos (`km1000`/`km500` siguen siendo esos nombres de enum/columna) — solo cambia el radio numérico que conceden.
- No se encarga arte nuevo en este delta: el desajuste entre el texto incrustado en los PNG ("< 1000 km"/"< 500 km") y el radio real queda como deuda pendiente (ver Open Questions), no se resuelve aquí salvo que Pablo pida lo contrario.

## Decisions

**D1 — `tiempo` usa `CuentaAtrasDeDesafio.parar()`, no `.extender()`.** `parar()` ya existe (detiene el ticker, congela `restante`/`fraccion`, no dispara `alAgotarse`) — es exactamente "crono parado, sin tiempo". `extender()` y sus 4 tests dedicados quedan sin ningún llamador tras este cambio y se retiran (código muerto, no se deja "por si acaso").

**D2 — `usar_comodin` para `tiempo` deja de devolver `extra_segundos`.** Ya no hay ninguna duración que comunicar — el payload pasa a `{"tipo":"tiempo"}`. `ResultadoTiempo` en `comodines_gateway.dart` pierde el campo `extraSegundos`.

**D3 — Los radios se cambian como literales dentro de `usar_comodin`, sin tocar esquema.** `case p_tipo when 'km1000' then 500 else 150 end` en vez de `1000`/`500`. No hace falta migración de columnas ni del enum `tipo_comodin`: es un cambio de comportamiento de la función, no de datos.

**D4 — Desajuste de arte conocido, no bloqueante.** El texto "< 1000 km"/"< 500 km" vive dentro del PNG (no es un overlay de Flutter), así que tras este cambio el icono mostrará un número que ya no es el radio real. Se documenta como deuda de contenido; no se resuelve con arte nuevo en este delta salvo decisión explícita de Pablo.

**D5 — Tarjetas de la pantalla Comodines: icono en vez de arte ancho, sin caja.** Mismo criterio que el fix visual anterior de esta historia ("no hace falta otra cápsula"): se quita el `Border.all`/fondo de imagen-como-card y se usa el icono cuadrado (ya transparente) junto al nombre/cantidad, con más espacio vertical entre tarjetas.

## Risks / Trade-offs

- **[Riesgo] El texto incrustado en el arte queda desactualizado (D4).** → Mitigación: documentado como deuda conocida; no afecta a la lógica de juego, solo a la claridad del icono hasta que haya arte nuevo o una decisión de superponer texto por código.
- **[Trade-off] `tiempo` sin límite podría parecer muy fuerte.** Mitigado por la regla ya existente de 1 comodín por intento (INT-119): usarlo en una pregunta agota el cupo del intento entero, así que no compromete el resto de la partida.
- **[Trade-off] Radios más pequeños (500/150 vs 1000/500) hacen estos comodines menos generosos.** Es exactamente lo que pide Pablo (más reto), no un efecto secundario no buscado.

## Migration Plan

1. Migración SQL nueva (`create or replace function usar_comodin`) con los literales de radio actualizados y sin `extra_segundos` para `tiempo`.
2. App: `_aplicarEfectoComodin` llama a `parar()` para `tiempo`; se retira `extender()` y sus tests; `ResultadoTiempo` pierde `extraSegundos`.
3. Ajustes visuales: tamaño de icono en `BandejaComodines`; rediseño de `_TarjetaComodin` en `ComodinesScreen`.
4. Todo aditivo/sustitutivo sobre lo ya desplegado, sin tocar filas existentes de `comodines_inventario`/`comodines_concesiones_anuncio`.

## Open Questions

- ~~¿Se deja el desajuste de texto en el arte de km1000/km500 tal cual hasta encargar arte nuevo, o se superpone un texto por código con el radio real mientras tanto?~~ **Resuelto**: se deja tal cual — Pablo generará versiones nuevas de esos iconos más adelante. No se toca nada por código mientras tanto.
