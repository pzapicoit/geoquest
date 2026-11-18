## Context

`_arrancarCuentaAtras(intento, desafioId)` arranca la cuenta atrás local y llama
a `marcarDesafioMostrado`. Hoy se invoca al recibir el intento (primer desafío)
y en `_avanzarDesdeElRevelado` (los siguientes), los mismos instantes en que se
abre la pista (`_pistaVisible = true`). La pista se cierra con `_cerrarPista`
(«Listo», X o fondo) y se reabre con `_abrirPista` («Ver la pista»).

En el servidor, `marcar_desafio_mostrado` solo fija `mostrado_en` si es `NULL`,
así que llamarlo más tarde mueve el inicio del bonus sin tocar SQL.

## Goals / Non-Goals

**Goals:** que el tiempo de respuesta y el bonus empiecen al pasar al mapa, con
un tope de lectura que impida estudiar la pista sin límite.

**Non-Goals:** cambiar el cálculo del bonus o el SQL; antitrampas de una app
modificada (INT-139).

## Decisions

**D1. Arrancar en el primer cierre de la pista.** Un campo
`_relojArrancadoPara` (id del desafío) evita arrancar dos veces. `_cerrarPista`
llama a `_arrancarCuentaAtras` si el desafío actual aún no lo tiene. Los puntos
donde hoy se arranca pasan a solo preparar la barra llena: un método
`_prepararCuentaAtras` que muestra los segundos completos sin correr.

**D2. Tope de lectura de 20 s, visible, con una sola fuente de verdad.** Un
`AnimationController` de 20 s, con el `vsync` de la pantalla, se lanza al
preparar cada desafío. Mueve la barra fina bajo «Listo» y, al completarse,
cierra la pista. Se para al cerrar la pista a mano. Al ir con el `vsync`, se
pausa con la pantalla (`TickerMode`), en vez de que un `Timer` aparte cierre la
pista con la barra a medias (revisión de `ecc:flutter-reviewer`).
- Accesibilidad: la barra queda fuera del árbol de semántica, porque su valor
  cambia en cada fotograma. El botón «Listo» anuncia el tope una vez («Tienes 20
  segundos para leer la pista»). Con el lector de pantalla activo
  (`accessibleNavigation`) no hay tope, por WCAG 2.2.1 (tiempo ajustable).
- *Alternativa:* sin tope. Se descarta: permitiría estudiar la imagen sin límite
  y contestar al instante con el bonus completo.
- *Alternativa:* un número en el botón. Se descarta: es más ruido visual que una
  barra.

**D3. «Ver la pista» no rearma nada.** Con el reloj ya en marcha, reabrir la
pista no arma el tope ni vuelve a llamar al servidor.

## Risks / Trade-offs

- [El comodín «tiempo» (`.parar()`) antes de arrancar] → Los comodines se usan
  desde la bandeja del mapa, que no se ve con la pista abierta. Si se usara
  antes, `parar()` sobre una cuenta atrás preparada deja el desafío sin límite,
  como hoy.
- [Auto-confirmación al agotarse] → Solo puede ocurrir después de arrancar, que
  ya implica haber cerrado la pista.
