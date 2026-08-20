---
type: functional
parent: int-119-comodines-inventario-uso
reason: Feedback de Pablo tras probar la build en dispositivo — el comodín de tiempo debe parar el crono del todo (no solo dar 15s extra) y los radios de los comodines de distancia se recortan (1000→500 km, 500→150 km); además ajustes visuales (iconos más grandes en el juego, tarjetas de la pantalla Comodines sin caja/borde y más espaciadas).
---

## Why

Probando la build, dos de los 4 comodines no dan el efecto que se quiere: "tiempo" da +15s cuando el jugador quiere jugar sin presión de tiempo del todo, y los radios de acierto (1000km/500km) son demasiado generosos — se quieren más ajustados (500km/150km) para que sigan siendo un reto. De paso, feedback visual: los iconos de la bandeja de juego deben verse más grandes, y las tarjetas de la pantalla Comodines llevan una caja con borde que no hace falta (mismo criterio que el fix anterior de esta historia).

## What Changes

- **BREAKING** (comportamiento, no de datos): el comodín `tiempo` deja de sumar 15s al margen — ahora **detiene el cronómetro por completo** para el desafío en curso: se juega esa pregunta sin límite de tiempo ni auto-envío.
- **BREAKING** (comportamiento): el radio del comodín `km1000` pasa de 1000 km a **500 km**; el radio del comodín `km500` pasa de 500 km a **150 km**. Los identificadores internos (`km1000`/`km500`, nombres de columna/enum) no cambian, solo el radio que conceden.
- Iconos de la bandeja de comodines en la pantalla de juego, más grandes (feedback: "se verán mejor").
- Tarjetas de la pantalla Comodines: se quita la caja con borde alrededor de cada una y se usa el icono (ya sin fondo blanco, ver fix anterior) en vez del arte ancho como fondo de tarjeta; más separación vertical entre comodines.
- **Aviso de contenido, no de código**: los assets `icono_km1000.png`/`arte_km1000.png` y `icono_km500.png`/`arte_km500.png` llevan el texto "< 1000 km" / "< 500 km" **incrustado en el propio PNG** (no es un overlay de la app). Con el recorte de radios, ese texto queda desactualizado (mostrará "1000"/"500" mientras el radio real concedido es 500/150) hasta que haya arte nuevo — no es algo que se pueda corregir sin encargar nuevas imágenes o superponer un texto por código. Pendiente de decisión de Pablo (ver Open Questions en design.md).

## Capabilities

### New Capabilities

(ninguna)

### Modified Capabilities

- `comodines`: el requirement "Efecto del comodín tiempo" cambia de "extiende 15s" a "detiene el cronómetro por completo". El requirement "Efecto de los comodines de radio" cambia los radios concedidos (1000→500, 500→150).
- `challenge-timer`: el requirement "Extensión del margen de tiempo por el comodín tiempo" se sustituye por uno de detención completa (el método `extender()` deja de usarse para este comodín).

## Impact

- **Backend**: `usar_comodin` — el caso `tiempo` deja de devolver `extra_segundos` (ya no aplica); los casos `km1000`/`km500` devuelven el nuevo `radio_km` (500/150 en vez de 1000/500).
- **App**: `_NivelJuegoScreenState._aplicarEfectoComodin` usa `CuentaAtrasDeDesafio.parar()` en vez de `.extender()` para `tiempo` (el método `extender()` y sus tests quedan sin uso y se retiran); tamaño de icono en `BandejaComodines`; rediseño de `_TarjetaComodin` en `ComodinesScreen` (icono en vez de arte ancho, sin caja/borde, más espaciado).
- Sin cambios de esquema (no hace falta migración de columnas/tipos, solo de los literales `15`/`1000`/`500` en la función `usar_comodin`).
