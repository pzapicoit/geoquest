---
type: functional
parent: int-119-comodines-inventario-uso
reason: Feedback de Pablo tras seguir probando en dispositivo — el comodín de proximidad debe acercar la cámara a la zona, no solo dibujar el círculo; además dos defectos visuales incidentales en la pantalla de revelado (fondo blanco tras la miniatura de pista, disposición del puntaje) y el backfill de país en el contenido existente.
---

## Why

Probando más a fondo: el comodín de radio dibuja el círculo pero no mueve la cámara, así que en un mapa muy alejado el círculo puede quedar minúsculo o fuera de vista — pide que además haga zoom sobre la zona. De paso, dos defectos visuales en la pantalla de revelado (ajenos a comodines pero encontrados en la misma sesión de pruebas) y el backfill de `desafios.pais`, que quedó pendiente como deuda de contenido en la historia original y ahora es lo que de verdad permite probar el comodín "país" con datos reales.

## What Changes

- El comodín `km1000`/`km500` SHALL, además de dibujar el círculo, encuadrar la cámara del mapa sobre la zona del círculo (animado, ~350ms).
- Backfill de contenido (no de código): `desafios.pais` se rellena para 134 de los 135 desafíos existentes (la excepción, "Titanic", no tiene país real — su lugar es el naufragio en aguas internacionales). Determinado con conocimiento geográfico directo a partir de `nombre`/`nombre_lugar`/`lat_real`/`lng_real` de cada fila, sin necesidad de una integración nueva con un proveedor de IA externo.
- Fix visual (ajeno a comodines, encontrado en la misma sesión): la miniatura de la pista en la hoja de revelado dejaba ver un fondo casi blanco en los bordes (degradado claro contra una hoja oscura) — pasa a un fondo oscuro consistente con el resto de la hoja.
- Fix visual (ajeno a comodines): el puntaje ganado del revelado ("+X") y el máximo ("/ 5.500") estaban en la misma línea, lo que hacía leer el separador de millares como un punto decimal ("+3.540" parecía "+3,54"); el máximo pasa a su propia línea debajo, más pequeño.

## Capabilities

### New Capabilities

(ninguna)

### Modified Capabilities

- `app-game-screen`: el requirement "Overlay de radio en el mapa" gana el encuadre de cámara, además del círculo.

## Impact

- **Backend**: sin cambios de esquema ni de RPC — el backfill de `pais` es una operación de datos sobre la tabla `desafios` ya existente, ejecutada directamente contra el proyecto remoto (mismo patrón que otras correcciones de datos de esta historia).
- **App**: `_NivelJuegoScreenState` gana una animación de cámara dedicada (`_zoomComodin`) que interpola hacia el encuadre del círculo, con el mismo patrón que `_acercamiento` de `_MapaMundiState` (INT-114); `_MiniaturaDeLaPista` y el bloque de puntaje del revelado ajustados visualmente.
- Sin cambios en `panel/` ni en el esquema.
