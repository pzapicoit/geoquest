## Why

Los comodines `km1000` y `km500` devuelven hoy la **coordenada real del objetivo** como centro del círculo (`usar_comodin`, vigente en `20260820170100_corrige_lint_usar_comodin.sql:66-73`). Clavar el pin en el centro del círculo da distancia ~0, así que el comodín no acota la zona: resuelve el desafío. Eso rompe el balance de puntuación y contamina el ranking, porque el bonus por rapidez se multiplica sobre una precisión perfecta.

El comodín debe **acotar**, no resolver: el objetivo tiene que estar dentro del círculo, pero no en su centro.

## What Changes

- `usar_comodin` deja de emitir `lat_real`/`lng_real` para `km1000`/`km500` y emite un **centro desplazado al azar**, a una distancia entre el 35 % y el 90 % del radio del círculo, con rumbo uniforme en [0, 2π). El objetivo queda siempre dentro del círculo y nunca cerca del centro.
- Se añade una función pura auxiliar `desplazar_centro_radio(lat, lng, radio_km) → jsonb {lat, lng}` con la fórmula de destino esférico (la misma esfera de 6371 km que usa `calcular_distancia_km`), longitud normalizada a [-180, 180). Aislarla la hace verificable con un script `do $$` contra el remoto, como `test_calcular_puntaje.sql`, sin los efectos secundarios de `usar_comodin`.
- El contrato del RPC **no cambia**: sigue siendo `{tipo, lat, lng, radio_km}`. Ni `comodines_gateway.dart`, ni `circulo_radio.dart`, ni `mapa_mundi_controller` se tocan. Tampoco cambia el esquema: sin columnas nuevas.
- No es **BREAKING** para el cliente: el mismo payload con otro valor de `lat`/`lng`.

## Capabilities

### New Capabilities
<!-- Ninguna: es un cambio de comportamiento sobre capabilities existentes. -->

### Modified Capabilities
- `comodines`: el requisito «Efecto de los comodines de radio» pasa de devolver «la posición real del objetivo» a devolver un centro desplazado al azar que contiene al objetivo sin situarlo en el centro, con las garantías del desplazamiento (dentro del círculo, lejos del centro, aleatorio por uso).
- `app-game-screen`: el requisito «Overlay de radio en el mapa» dice que el círculo se dibuja «centrado en la posición real del objetivo». Pasa a describir el centro que emite el servidor. Es alineación de redacción: la app ya dibuja donde le dicen y no cambia una línea de código.

## Impact

- **Backend**: nueva migración con `desplazar_centro_radio(...)` (`security invoker`, `set search_path = public`, `revoke ... from public` + `grant ... to authenticated`, siguiendo la convención de `mis_comodines`/`anuncio_debido`) y `create or replace function usar_comodin(...)` con la rama de radio reescrita. El resto del cuerpo de `usar_comodin` (validaciones, descuento de inventario, marca de `comodin_usado`, `raise` final anti-lint) se mantiene literal.
- **Tests**: nuevo `backend/supabase/tests/test_desplazar_centro_radio.sql`, script autónomo y sin escrituras que valida por muestreo la distancia al objetivo, la normalización de longitud, el comportamiento en polos y antimeridiano, y que dos llamadas seguidas dan centros distintos.
- **App**: sin cambios de código. Los tests existentes (`comodines_gateway_test.dart`, `circulo_radio_test.dart`, `nivel_juego_screen_test.dart`) siguen valiendo tal cual porque usan payloads sintéticos.
- **Balance**: con el centro desplazado, el error mínimo esperable pasa de ~0 km a ~0,66·R (≈330 km con `km1000`, ≈100 km con `km500`). Parte del recorte de radios de INT-119 delta-1 (1000→500, 500→150) compensaba justo este bug, así que los radios quedan pendientes de revisar **en otra tarea**, con datos de partidas reales.
