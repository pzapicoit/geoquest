---
type: functional
parent: int-86-panel-niveles
reason: El ítem "Niveles" del menú lateral nunca tiene un destino propio -
  no existe ni está prevista una pantalla de listado de niveles que cruce
  temáticas, solo se llega a los niveles entrando en una temática
  (/tematicas/:id/niveles, INT-86). Un enlace permanentemente
  deshabilitado en la navegación no aporta nada y puede confundir.
---

## Why

INT-86 construyó el listado de niveles de una temática
(`/tematicas/:id/niveles`), no un listado global de niveles. El ítem
"Niveles" de la navegación lateral (`panel-home-dashboard`, INT-81) sigue
deshabilitado como el resto de ítems que aún no tenían pantalla propia,
pero a diferencia de "Temáticas" y "Preguntas/Desafíos" (ya habilitados),
"Niveles" nunca podrá habilitarse como enlace directo: los niveles solo
existen en el contexto de una temática. Mantenerlo deshabilitado para
siempre es ruido en la navegación.

## What Changes

- Se elimina el ítem "Niveles" de `NAV_ITEMS` en `PanelLayout.tsx`: la
  navegación lateral pasa de 6 a 5 enlaces.
- Se actualiza la spec `panel-home-dashboard` para reflejar la lista de
  enlaces vigente (sin "Niveles") y su estado real actual (Temáticas y
  Preguntas/Desafíos ya habilitados desde INT-85/INT-83, no deshabilitados
  como decía la spec sin sincronizar desde entonces).

## Capabilities

### New Capabilities
(ninguna)

### Modified Capabilities
- `panel-home-dashboard`: la navegación lateral deja de incluir "Niveles"
  y la spec se pone al día con qué enlaces están habilitados hoy.

## Impact

- Frontend (`panel/`): `PanelLayout.tsx` (quita una entrada del array
  `NAV_ITEMS`) y su test `PanelLayout.test.tsx` si asume 6 ítems o
  referencia "Niveles".
- Sin cambios de backend ni de esquema.
