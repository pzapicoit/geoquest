## Context

`usar_comodin` (definición vigente: `backend/supabase/migrations/20260820170100_corrige_lint_usar_comodin.sql`) resuelve la rama de radio así:

```sql
when 'km1000', 'km500' then
  select d.lat_real, d.lng_real into v_lat, v_lng from desafios d where d.id = p_desafio_id;
  return jsonb_build_object('tipo', p_tipo, 'lat', v_lat, 'lng', v_lng,
    'radio_km', case p_tipo when 'km1000' then 500 else 150 end);
```

El cliente dibuja el círculo con `puntosDelCirculo(centro, radioKm)` (`app/lib/mapa/circulo_radio.dart`) sobre una esfera de 6371 km —la misma que `calcular_distancia_km`— y además anima la cámara para encuadrarlo (`_zoomHaciaElRadio` en `nivel_juego_screen.dart`). Con el centro en el objetivo, el comodín tiene dos fugas: el círculo marca la respuesta y el propio encuadre de cámara la centra en pantalla.

Restricciones del proyecto que condicionan el diseño:

- No hay pgTAP: los tests de base de datos son scripts `do $$` autónomos que solo se consideran seguros contra el remoto si la función bajo prueba no tiene efectos secundarios (ver cabecera de `backend/supabase/tests/test_calcular_puntaje.sql`). `usar_comodin` escribe (descuenta inventario, marca el intento), así que no es testeable por esa vía.
- `supabase db lint` ya obligó a dos migraciones correctivas en esta función (`...170100`, `...200100`): toda función nueva nace con `set search_path = public` y sin caminos sin `return`.

## Goals / Non-Goals

**Goals:**

- El objetivo queda dentro del círculo y nunca cerca de su centro, con garantías comprobables.
- El contrato del RPC no cambia: `{tipo, lat, lng, radio_km}`. Cero líneas de app y cero cambios de esquema.
- La geometría queda aislada en una función sin efectos secundarios, para poder verificarla con un script como los existentes.

**Non-Goals:**

- Revisar los radios (500/150 km). Este cambio altera la potencia real del comodín; el reajuste va en otra tarea, con datos de partidas.
- La idea de UX de dibujar el borde difuso o un degradado (ver «Notas de producto»).
- Hacer `usar_comodin` idempotente ante reintentos de red (ver la decisión 3 y el riesgo asociado).

## Decisions

### D1. Centro desplazado: rumbo uniforme + distancia uniforme por área en la corona [0.35·R, 0.9·R]

```
u  := random()
f  := sqrt(0.35^2 + u * (0.9^2 - 0.35^2))     -- fracción del radio
d  := f * R                                    -- km
θ  := 2π * random()                            -- rumbo
```

`f = sqrt(a² + u·(b² − a²))` es el muestreo uniforme por área de una corona circular entre `a·R` y `b·R`: sin la raíz, la distancia se concentraría cerca del centro (el área crece con el cuadrado del radio), justo el sesgo que hay que evitar. La distancia media resultante es ≈0,665·R: ~330 km de error mínimo esperable con `km1000`, ~100 km con `km500`.

Los topes:

- **0,9·R como máximo**: el objetivo entra en el círculo con margen holgado, sin depender de que el redondeo del muestreo de 72 puntos del borde del cliente caiga a favor.
- **0,35·R como mínimo**: sin suelo, un sorteo puede dejar el objetivo casi en el centro y el comodín vuelve a ser un revelado por pura suerte. Con el suelo, el centro sigue siendo la apuesta que minimiza la distancia esperada (la corona es simétrica en rotación), pero esa apuesta cuesta ~0,66·R. Es exactamente el comportamiento buscado: acota, no resuelve.

*Alternativa descartada:* `d` uniforme en `[0, R)`. Más simple pero sesga el objetivo hacia el centro y permite el caso degenerado de distancia ~0.

### D2. Fórmula de destino esférico exacta en Postgres, no aproximación en grados

El desplazamiento se calcula con la misma fórmula que `_destino` en `circulo_radio.dart`, sobre la misma esfera de 6371 km:

```
δ    := d / 6371
lat2 := asin( clamp(sin φ1 · cos δ + cos φ1 · sin δ · cos θ) )
lng2 := λ1 + atan2( sin θ · sin δ · cos φ1 , cos δ − sin φ1 · sin lat2 )
```

Postgres trae todo lo necesario (`radians`, `degrees`, `pi`, `asin`, `atan2`, `sin`, `cos`, `sqrt`, `random`), así que la versión exacta cabe en seis líneas. Aproximar el desplazamiento en grados (`Δlat = d/111`, `Δlng = d/(111·cos lat)`) ahorra nada y rompe en latitudes altas —a 500 km de desplazamiento, cerca de un polo, `cos lat` se va a cero—, además de dejar la distancia real dependiendo de la latitud. Usar la misma fórmula que el cliente hace que la garantía «distancia entre 0,35·R y 0,9·R» sea exacta bajo la misma métrica con la que se puntúa la respuesta.

Normalización de longitud equivalente a `Mercator.normalizarLongitud`, pero sin `%` sobre `double precision` (que Postgres no define): `lng - 360 * floor((lng + 180) / 360)` deja el resultado en [-180, 180). El `clamp` del argumento de `asin` con `least/greatest` replica el `.clamp(-1.0, 1.0)` del cliente y evita un error de dominio por redondeo cuando el objetivo está a menos de `d` de un polo.

### D3. La geometría va en una función auxiliar pura; el centro no se persiste

`desplazar_centro_radio(p_lat, p_lng, p_radio_km) returns jsonb` devuelve `{"lat": …, "lng": …}`.

- **Por qué separada**: es la única forma de tener test de base de datos en este proyecto. Sin efectos secundarios, el script `do $$` puede muestrear miles de sorteos contra el remoto y comprobar las garantías del spec.
- **Volatilidad**: se queda `volatile` (el default). Marcarla `stable` o `immutable` sería mentir —usa `random()`— y permitiría al planificador reutilizar un solo resultado.
- **Privilegios**: `security invoker` (no toca tablas) con `set search_path = public` por el lint. La intención es que no sea RPC de cliente —es un detalle interno de `usar_comodin`, que al ser `security definer` la ejecuta con los privilegios del propietario—, y **`revoke execute … from public` no basta para conseguirlo**: Supabase trae `alter default privileges in schema public grant execute on functions to anon, authenticated, service_role`, así que toda función nueva nace con esos grants explícitos y revocar del pseudo-rol `PUBLIC` no los toca. Comprobado contra el remoto: recién aplicada la migración, la ACL era `postgres=X | anon=X | authenticated=X | service_role=X`, es decir la función quedaba publicada como `POST /rest/v1/rpc/desplazar_centro_radio`. Hace falta `revoke execute … from anon, authenticated` explícito (migración `…211000`), que deja la ACL en `postgres=X | service_role=X`. Verificado en las dos direcciones: `authenticated` llamándola directa recibe `42501 permission denied`, y una función `security definer` propiedad de `postgres` —lo que es `usar_comodin`— la sigue llamando sin problema.
- **Sin persistir el centro**: la issue plantea guardarlo para que un reintento de red no mueva el círculo. Revisando el código, ese escenario no existe hoy: el segundo intento choca con `update intentos_nivel ... where comodin_usado is null` → `raise 'comodin_ya_usado_en_este_intento'`, así que nunca se emite un segundo centro. Persistirlo solo serviría para *recuperar* el centro tras una respuesta perdida, lo que exige dos columnas nuevas y rediseñar el RPC como idempotente — un problema distinto y preexistente (ver Riesgos).

### D4. `usar_comodin` se reescribe con `create or replace`, tocando solo la rama de radio

El resto del cuerpo (validación de intento/desafío, `pais_no_disponible`, descuento de inventario, marca de `comodin_usado`, y el `raise 'tipo_comodin_desconocido'` final que calla al linter) se copia literal de `...170100`. El radio se calcula una vez en una variable para no repetir el `case` en dos sitios:

```sql
v_radio := case p_tipo when 'km1000' then 500 else 150 end;
v_centro := desplazar_centro_radio(v_lat, v_lng, v_radio);
return jsonb_build_object('tipo', p_tipo,
  'lat', v_centro->'lat', 'lng', v_centro->'lng', 'radio_km', v_radio);
```

Pasar los valores como `jsonb` conserva el tipo numérico del JSON, así que el payload llega al cliente igual que antes y `_decimal` en `comodines_gateway.dart` no ve ningún cambio.

## Risks / Trade-offs

- **El desplazamiento cambia el balance del juego sin tocar los radios** → `km500` (150 km) sigue siendo muy fuerte y `km1000` (500 km) pasa a ser una pista razonable. Se acepta a propósito: primero se arregla la fuga, luego se recalibra con datos.
- **Un jugador que conozca el algoritmo sabe que el objetivo no está en el 35 % interior del círculo** → sigue sin ganar nada: por simetría rotacional el centro continúa siendo el punto que minimiza la distancia esperada, y ese mínimo es ~0,66·R. El suelo del 35 % quita casos de suerte, no añade información aprovechable.
- **Si se pierde la respuesta del RPC, el jugador gasta el comodín y no ve círculo** → riesgo preexistente, no introducido aquí (el reintento ya fallaba con `comodin_ya_usado_en_este_intento`). Queda fuera de alcance; merece issue propia para hacer `usar_comodin` idempotente persistiendo su payload.
- **El test de la geometría es estadístico** → se muestrea con un número alto de iteraciones (≥2000) y se comprueban invariantes duras (rango de distancia, longitud normalizada, latitud válida) más una comprobación de dispersión de rumbos, no una distribución exacta. Un fallo real de la fórmula rompe los invariantes en la primera iteración.
- **`random()` no es criptográfico** → no hace falta: el objetivo es que el centro no sea la respuesta, no resistir un ataque. Adivinar la semilla del backend no está al alcance del cliente y no cambia el hecho de que el objetivo puede estar en cualquier punto de la corona.

## Migration Plan

1. Nueva migración `20260821HHMMSS_comodin_radio_centro_desplazado.sql` con `desplazar_centro_radio` + `create or replace function usar_comodin(...)`.
2. Aplicar contra el remoto vinculado y pasar `supabase db lint` (la función nueva ya nace con `search_path`).
3. Ejecutar `backend/supabase/tests/test_desplazar_centro_radio.sql`.
4. **Rollback**: `create or replace` de la versión de `...170100` (la migración anterior queda intacta en el repo). El helper puede quedarse huérfano sin daño.

Sin datos que migrar: la función solo calcula. Los intentos ya jugados no guardan el centro emitido.

## Notas de producto

- **El círculo nítido invita a pinchar el centro.** Ahora que el centro es solo una zona, el borde difuso o un degradado hacia fuera comunicaría «está en algún punto de aquí dentro» mucho mejor que una circunferencia limpia. Vale una issue de UX aparte; el `CustomPainter` del overlay ya tiene todo lo necesario para probarlo.
- **Efecto colateral bueno:** el encuadre automático de cámara (`_zoomHaciaElRadio`) ya no centra la pantalla en el objetivo, que era una segunda pista involuntaria además del círculo.
- **Medir antes de recalibrar:** con este cambio conviene registrar la distancia final de las respuestas jugadas con comodín de radio para decidir los radios con datos, en vez de volver a ajustar a ojo como en INT-119 delta-1.
