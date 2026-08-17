## Context

INT-90 implementó el camino vertical pero se apartó del mock de
referencia (`[App] - Camino vertical.dc.html`) en dos puntos, sin
documentarlo como decisión explícita en su momento:

1. Omitió el botón fijo inferior "Jugar nivel {{ currentNum }} ·
   {{ currentTheme }}" que el mock sí tiene, como CTA principal para
   abrir la parada actual sin tener que tocar la tarjeta.
2. El mock asume un camino largo (13 niveles) y por eso su
   `ListView`/scroll invertido siempre tiene contenido de sobra para
   llenar la pantalla. Con el contenido real actual (1-2 niveles), el
   camino queda anclado al fondo (offset 0 de un `ListView` invertido
   sin nada que hacer scroll) con un vacío enorme por encima, algo que
   el mock nunca necesitó resolver porque nunca lo sufre.

## Goals / Non-Goals

**Goals:**
- Añadir el botón "Jugar nivel N · Tema" fijo sobre el camino,
  navegando a la parada `es_actual`.
- Usar tarjetas con la misma altura que el mock de referencia
  (`ROW_H = 208`), en vez de una altura reducida inventada.
- Cuando el camino no llena la pantalla, mantenerlo apoyado justo
  encima del botón (con un margen pequeño y fijo) — igual que el mock,
  que siempre ancla el camino desde abajo — dejando el hueco sobrante
  hacia la barra superior en vez de partirlo en dos huecos o dejarlo
  pegado al fondo. Sin cambiar el comportamiento ya verificado para
  caminos largos (que siguen ancladas/scrolleables igual que antes).

**Non-Goals:**
- No se replica la animación `gq-bob2` (rebote) del botón del mock.
- No cambia nada del cálculo de `camino_jugador`, fronteras o puntos.

## Decisions

**D1 — Botón fijo inferior "Jugar nivel N · Tema".**
Nuevo widget `_BotonJugar`, superpuesto con `Positioned` igual que la
barra superior, visible solo cuando existe una parada `esActual` (si el
camino está completo, no hay parada actual y el botón no se muestra —
mismo criterio que ya usa el "Mi nivel" flotante). Reutiliza el mismo
`_onTapParada` que ya usan las tarjetas, así que toca el mismo camino de
navegación ya probado.

**D2 — Reserva de espacio para el botón; el sobrante sube, no se
reparte.**
El `ListView` ya usaba un padding inferior fijo (`_paddingInferior`);
se sustituye por `_ctaAltura`, que reserva la altura del nuevo botón
más un margen pequeño y fijo — el camino siempre queda apoyado justo
encima del botón, nunca centrado en medio de un hueco. El padding
superior reserva al menos la altura de la barra (`_topBarAltura`) y
absorbe TODO el sobrante cuando el contenido no llena la pantalla. Se
calcula, en cada `build()`:

```
disponible = alturaPantalla - _topBarAltura - _ctaAltura
extra = max(0, disponible - alturaTotalDelContenido)
paddingTop = _topBarAltura + extra
paddingBottom = _ctaAltura   // fijo, no depende de `extra`
```

Cuando el contenido ya llena o excede `disponible` (caminos largos, el
caso que ya cubren los tests existentes), `extra = 0` y el padding
vuelve a ser exactamente el de antes — no cambia nada del
comportamiento ya verificado.
Alternativa descartada: repartir `extra` por igual entre `paddingTop` y
`paddingBottom` (centrar el grupo de paradas en la pantalla) — probado
en una primera vuelta de este mismo delta y descartado tras testing
local: deja un hueco vacío entre la última tarjeta y el botón que no
existe en el mock, que siempre ancla el camino desde abajo.
Alternativa descartada: forzar un mínimo de niveles "de mentira" para
que el camino nunca se vea corto — maquilla el síntoma en vez de
arreglar el layout, y sería confuso si el jugador desplaza un camino
con paradas que no existen.

**D3 — El auto-scroll usa el mismo padding dinámico.**
El cálculo de offset de `_autoScroll` (D4 de `design.md` de INT-90) ya
sumaba el padding inferior como base de su acumulado; ahora recibe el
mismo `paddingBottom` calculado en `build()` en vez de la constante fija,
para que el centrado de la parada actual siga siendo exacto también
cuando el camino es corto y además está centrado en pantalla.

## Risks / Trade-offs

- **[Riesgo] Doble camino para abrir el nivel actual** (tocar la
  tarjeta o el botón) → Mitigación: ambos llaman al mismo
  `_onTapParada`, cero lógica duplicada, y es exactamente lo que hace
  el mock de referencia.
- **[Riesgo] El centrado dinámico podría desalinear el auto-scroll si
  se usan constantes distintas en el botón y en `_autoScroll`** →
  Mitigación: D3 obliga a pasar el mismo valor calculado una sola vez
  en `build()`, no una constante duplicada.
