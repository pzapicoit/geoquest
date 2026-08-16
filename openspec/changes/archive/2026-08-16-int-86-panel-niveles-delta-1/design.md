## Context

`PanelLayout.tsx` (INT-81) define `NAV_ITEMS` como un array plano de 6
enlaces, cada uno con `enabled: true/false`. "Temáticas" (INT-85) y
"Preguntas/Desafíos" (INT-82/83) ya se habilitaron editando su entrada;
"Jugadores" y "Ranking" siguen deshabilitados a la espera de pantalla
propia. "Niveles" es distinto a esos dos: no es que le falte pantalla
propia, es que nunca la tendrá como enlace de nivel superior, porque el
dominio no tiene un listado de niveles fuera del contexto de una
temática (INT-86 lo confirma: la única pantalla de niveles es
`/tematicas/:id/niveles`).

## Goals / Non-Goals

**Goals:**
- Quitar la entrada "Niveles" de `NAV_ITEMS`.
- Poner al día la spec `panel-home-dashboard` (enlaces vigentes y su
  estado habilitado/deshabilitado real).

**Non-Goals:**
- No se resuelve el desajuste histórico de que INT-82/83/85 nunca
  actualizaron esta spec al habilitar sus enlaces (se corrige aquí de
  paso, al tener que tocar el mismo requirement, pero no se auditan el
  resto de specs del panel en busca de desajustes similares).
- No se toca "Jugadores" ni "Ranking": siguen deshabilitados a la espera
  de pantalla propia, caso distinto al de "Niveles".

## Decisions

**Eliminar la entrada en vez de dejarla deshabilitada.** Un enlace
deshabilitado comunica "todavía no" (como "Jugadores"/"Ranking"); pero
"Niveles" nunca será un enlace de nivel superior con pantalla propia. Un
enlace que nunca podrá activarse es ruido, no una promesa pendiente:
mejor no mostrarlo.

## Risks / Trade-offs

- [Alguien podría esperar ver "Niveles" en el menú por costumbre de otros
  paneles admin] → Aceptado: la navegación por temática (Temáticas →
  niveles de esa temática → Recorrido) es el único flujo real del
  dominio, y es descubrible desde "Temáticas".

## Migration Plan

Ninguna. Cambio de un array estático en un componente de React.
