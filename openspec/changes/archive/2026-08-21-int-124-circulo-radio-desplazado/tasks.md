## 1. Migración: geometría del desplazamiento

- [x] 1.1 Crear `backend/supabase/migrations/20260821210000_comodin_radio_centro_desplazado.sql` con cabecera de comentario que explique el bug (centro = objetivo) y la corona [0.35·R, 0.9·R]
- [x] 1.2 Definir `desplazar_centro_radio(p_lat double precision, p_lng double precision, p_radio_km double precision) returns jsonb`, `language plpgsql`, `volatile`, `set search_path = public`: sortea `f = sqrt(0.1225 + random() * 0.6875)` y rumbo `2*pi()*random()`, aplica la fórmula de destino esférico con R = 6371 km y devuelve `{"lat": …, "lng": …}`
- [x] 1.3 Clampear el argumento de `asin` con `least/greatest` a [-1, 1] y normalizar la longitud con `lng - 360 * floor((lng + 180) / 360)`
- [x] 1.4 `revoke execute on function desplazar_centro_radio(double precision, double precision, double precision) from public` y no conceder a `authenticated` (la llama `usar_comodin` como `security definer`)

## 2. Migración: `usar_comodin`

- [x] 2.1 En la misma migración, `create or replace function usar_comodin(uuid, uuid, tipo_comodin)` copiando literal el cuerpo de `20260820170100_corrige_lint_usar_comodin.sql` (validaciones, `pais_no_disponible`, descuento de inventario, marca de `comodin_usado`, `raise 'tipo_comodin_desconocido'` final)
- [x] 2.2 Declarar `v_radio double precision` y `v_centro jsonb`; en la rama `'km1000', 'km500'` calcular el radio una sola vez y emitir `lat`/`lng` desde `v_centro->'lat'` / `v_centro->'lng'`
- [x] 2.3 Verificar que la rama de radio ya no lee `lat_real`/`lng_real` directamente hacia el payload y que ningún otro camino de la función cambia respecto de la versión anterior (diff de cuerpos)

## 3. Test de base de datos

- [x] 3.1 Crear `backend/supabase/tests/test_desplazar_centro_radio.sql` como script `do $$` autónomo, con la cabecera de convención (sin pgTAP, seguro contra el remoto porque la función no escribe)
- [x] 3.2 Muestrear ≥2000 sorteos sobre varios objetivos (ecuador, latitud media, junto al antimeridiano ±179.9, cerca de polo ±89.5) y ambos radios (500 y 150) comprobando con `calcular_distancia_km` que la distancia centro↔objetivo cae en [0.35·R − ε, 0.9·R + ε]
- [x] 3.3 Comprobar en cada muestra que la longitud emitida está en [-180, 180) y la latitud en [-90, 90]
- [x] 3.4 Comprobar que dos llamadas seguidas con los mismos argumentos devuelven centros distintos, y que los rumbos se reparten (muestras en los cuatro cuadrantes respecto del objetivo)
- [x] 3.5 Comprobar que la media de la fracción `d/R` sobre la muestra grande queda cerca de 0.665 (tolerancia amplia, ±0.03) — detecta el sesgo de haber olvidado la raíz

## 4. Aplicar y verificar

- [x] 4.1 Aplicar la migración al remoto vinculado (`supabase db push --linked` o equivalente del proyecto) y ejecutar `supabase db lint --linked`: sin avisos nuevos sobre `usar_comodin` ni `desplazar_centro_radio`
- [x] 4.2 Ejecutar `backend/supabase/tests/test_desplazar_centro_radio.sql` contra el remoto y que pase sin excepciones
- [x] 4.3 Ejecutar la suite de la app (`flutter test`) y confirmar que sigue verde sin cambios de código: los tests de comodines usan payloads sintéticos
- [x] 4.4 Comprobar manualmente en el dispositivo: consumir `km1000` en un desafío, ver que el círculo no está centrado en el objetivo y que al revelar la respuesta el objetivo cae dentro del círculo

## 5. Remate de privilegios (hallazgo al verificar contra el remoto)

- [x] 5.1 Comprobar la ACL real de `desplazar_centro_radio` en el remoto tras aplicar la migración, en vez de darla por buena leyendo el fichero
- [x] 5.2 Crear `20260821211000_desplazar_centro_radio_no_es_rpc_publica.sql` con `revoke execute ... from anon, authenticated`, documentando que los grants venían de los `default privileges` de Supabase y que `revoke from public` no los quita
- [x] 5.3 Verificar en el remoto que `authenticated` recibe `42501 permission denied` al llamarla directa y que una función `security definer` propiedad de `postgres` la sigue llamando (probado con un envoltorio temporal en una transacción con `rollback`, sin dejar rastro)
- [x] 5.4 Corregir la decisión D3 de `design.md`, que afirmaba que la función no quedaba expuesta al cliente
