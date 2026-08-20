## Why

GeoQuest no tiene ningún mecanismo de ayuda dentro de una partida ni ninguna vía de re-engagement basada en publicidad. Se quiere introducir comodines (poder-ups consumibles) que el jugador puede usar durante una partida y reponer viendo un anuncio en vídeo (INT-117), sentando además la base de un futuro modelo freemium sin tener que resolver ya cobros reales.

## What Changes

- Nuevo inventario de comodines por jugador, con 4 tipos: `tiempo` (extiende el margen antes del auto-envío 15s), `pais` (revela el país del objetivo), `km1000` y `km500` (acotan el objetivo a ese radio en el mapa).
- Semilla de inventario al crear el perfil: 1 unidad de `tiempo`/`pais`/`km1000`, 0 de `km500`.
- Regla de uso: como máximo 1 comodín (de cualquier tipo) por intento de parada. Usarlo en un desafío bloquea el uso de cualquier otro comodín en el resto de desafíos de ese mismo intento. Se consume al usarse; no se repone si el intento se pierde o se falla la pregunta.
- Obtención: solo viendo un anuncio en vídeo (Rewarded, no Rewarded Interstitial — aquí es 100% opt-in del jugador). Concede 1 comodín aleatorio, con un tope diario. Depende del SDK de AdMob de INT-117 — mientras esa historia no esté implementada, el botón de anuncio queda deshabilitado con un aviso ("disponible próximamente"), sin bloquear el resto de la funcionalidad de comodines.
- **BREAKING**: ninguno — es una capability enteramente nueva sobre datos nuevos, no toca contratos existentes salvo las adiciones aditivas descritas abajo.
- UI: pill de comodines (recuento total) en la cabecera de la Home/camino vertical, que abre la pantalla de Comodines; bandeja plegable de comodines sobre el mapa de la pantalla de juego; pantalla de Comodines con inventario real y hoja "Obtener más" (solo el botón de anuncio funcional; "canjear puntos" y "pack de pago" quedan visibles sin funcionalidad, fuera de alcance).

## Capabilities

### New Capabilities

- `comodines`: tipos de comodín, inventario por jugador, regla de un uso por intento, RPC de consumo con el efecto de cada tipo, y concesión de comodín por anuncio con tope diario.

### Modified Capabilities

- `game-data-model`: nuevas tablas/columnas para el inventario de comodines por jugador y para marcar qué comodín (si alguno) se ha usado ya en un intento en curso.
- `challenge-timer`: la cuenta atrás por desafío (cosmética pero disparadora del auto-envío) puede extenderse 15s por el comodín `tiempo`; no cambia el cálculo de puntaje del servidor, que sigue siendo sobre tiempo real transcurrido.
- `app-game-screen`: añade la bandeja plegable de comodines sobre el mapa, conectada al inventario real y a su efecto (incluye overlay de radio para `km1000`/`km500`).
- `app-player-path-home`: añade el pill de comodines en la cabecera, con navegación a la pantalla de Comodines.
- `panel-questions-form`: añade un campo opcional `pais` (país real del objetivo) al formulario de preguntas, necesario para que el comodín `pais` tenga qué revelar — no existe hoy ningún campo de país en `desafios`.

## Impact

- **Backend**: migración de esquema (tabla de inventario de comodines, marca de uso por intento), RPCs de consumo y de concesión por anuncio, y las RPCs de revelado (país, radio) que devuelven solo la información mínima necesaria sin exponer `nombre_lugar` completo.
- **App**: nueva pantalla `Comodines`, cambios en `Camino vertical` (Home) y en la pantalla de juego (mapa), overlay de círculo de radio en `app/lib/mapa/`.
- **Panel**: campo opcional `pais` en el formulario de preguntas. Los 83 desafíos existentes quedan con `pais` nulo — mientras no se rellene, el comodín `pais` no está disponible para esa pregunta concreta (ver Open Questions en design.md); no hay gestión de inventario de comodines desde el admin, eso queda fuera de alcance.
- **Dependencia externa**: la vía de obtención por anuncio depende de que INT-117 (AdMob) esté implementada; se diseña de forma que el resto de la capability funcione igual sin ella (botón deshabilitado).
