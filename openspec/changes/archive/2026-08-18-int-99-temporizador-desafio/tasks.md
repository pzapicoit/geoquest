## 1. Migración de esquema

- [x] 1.1 Añadir `niveles.segundos_por_desafio integer not null default 60
      check (segundos_por_desafio > 0)`
- [x] 1.2 Añadir `intento_desafios.mostrado_en timestamptz` (nullable)
- [x] 1.3 Añadir `respuestas_desafio.segundos_transcurridos integer not
      null check (segundos_transcurridos >= 0)`
- [x] 1.4 Relajar `respuestas_desafio.lat_adivinada`/`lng_adivinada` a
      nullable. Los `check` existentes no hizo falta reescribirlos: en SQL
      un `check` sobre una columna `NULL` se evalúa a `NULL` y se acepta
      igual que `TRUE`, así que quitar el `not null` bastó.
- [x] 1.5 Relajar `respuestas_desafio.distancia_km` a nullable (mismo
      motivo que 1.4: el `check (distancia_km >= 0)` ya admite `NULL`)
- [x] 1.6 Añadir un `check` que exija que `lat_adivinada` y
      `lng_adivinada` sean ambas `NULL` o ambas no nulas (nunca una sola)

## 2. Funciones y trigger de puntaje/tiempo

- [x] 2.1 Crear `calcular_puntaje_por_distancia(distancia_km)` con el
      cuerpo exacto de la actual `calcular_puntaje` (D5 de `design.md`)
- [x] 2.2 `drop function calcular_puntaje(double precision)`
- [x] 2.3 Crear `calcular_puntaje(distancia_km, segundos_transcurridos,
      segundos_por_desafio)` que combine `calcular_puntaje_por_distancia`
      con el bonus por rapidez (fórmula D4 de `design.md`:
      `bonus_max=500`, `fraccion_acierto`, `fraccion_tiempo`)
- [x] 2.4 Reemplazar `respuestas_desafio_calcular_antes_de_insertar()`
      para: si `lat_adivinada`/`lng_adivinada` son `NULL`, fijar
      `distancia_km = NULL` y `puntos = 0`; si no, calcular distancia y
      puntaje con la nueva `calcular_puntaje`; en ambos casos calcular
      `segundos_transcurridos` a partir de
      `intento_desafios.mostrado_en` acotado a `[0,
      segundos_por_desafio]`, tratando `mostrado_en is null` como tiempo
      agotado (D6/D8)
- [x] 2.5 `backend/supabase/tests/test_calcular_puntaje_bonus.sql`: máximo
      puntaje (distancia 0, tiempo 0), tiempo agotado con precisión
      perfecta, suelo de precisión con tiempo 0, caso intermedio,
      monotonía del bonus con el tiempo, tiempo excedido sin bonus
      negativo. Ejecutado contra el remoto tras la migración: OK. El caso
      `mostrado_en` nulo vive en el trigger, no en la función pura — se
      verifica en el paso manual 8.2, igual que el resto de comportamiento
      del trigger.

## 3. RPCs

- [x] 3.1 `p_lat_adivinada`/`p_lng_adivinada` opcionales (`default null`),
      rechazando la llamada si se recibe solo una de las dos.
      Implementado con `create or replace` en vez de `drop` + `create`:
      añadir un default a un parámetro no cambia la lista de tipos de la
      función (a diferencia del cambio de tipo de retorno de INT-93), así
      que no hacía falta romper la identidad de la función ni volver a
      conceder sus grants.
- [x] 3.2 Actualizar `puntos_maximos` en la respuesta de
      `responder_desafio` para usar `calcular_puntaje(0, 0,
      segundos_por_desafio)` (máximo real con bonus)
- [x] 3.2b Añadir `puntos_distancia` (=
      `calcular_puntaje_por_distancia(distancia_km)`, o `0` si no hay
      pin) y `puntos_bonus` (= `puntos - puntos_distancia`) al jsonb de
      respuesta de `responder_desafio` (D14 de `design.md`)
- [x] 3.3 Crear `marcar_desafio_mostrado(p_intento_id, p_desafio_id)`:
      `security definer`, valida pertenencia del intento a `auth.uid()`,
      `update ... where mostrado_en is null` (D2/D3)
- [x] 3.4 Revocar `execute` de `marcar_desafio_mostrado` de `public` y
      concederlo a `authenticated`
- [x] 3.6 (no estaba en la lista original) `iniciar_intento_nivel` expone
      `segundos_por_desafio` en su respuesta jsonb, para que la app lo
      lea sin una segunda consulta a `niveles` (necesario para 6.3)
- [ ] 3.5 Tests de las RPCs: marcar dos veces no cambia `mostrado_en`,
      marcar un intento ajeno se rechaza, responder sin pin persiste 0
      puntos y coordenadas nulas, responder con una sola coordenada se
      rechaza, la respuesta con pin incluye `puntos_distancia`/
      `puntos_bonus` coherentes con `puntos`, la respuesta sin pin los
      devuelve en `0`. **No automatizado**: estas RPCs dependen de
      `auth.uid()`, y este repo no tiene (todavía) un arnés de usuarios de
      prueba vía la Auth API para probar RPCs `security definer` desde un
      script SQL — el único precedente (`architecture.md`) es probar RLS a
      mano contra el remoto con JWTs reales. Cubierto por el paso manual
      8.2 en su lugar.

## 4. Rebalanceo de datos existentes

- [x] 4.1 En la misma migración, `update niveles set
      puntaje_minimo_superar = round(puntaje_minimo_superar * 1.1),
      umbral_estrella_1 = round(umbral_estrella_1 * 1.1),
      umbral_estrella_2 = round(umbral_estrella_2 * 1.1),
      umbral_estrella_3 = round(umbral_estrella_3 * 1.1)` sobre todos los
      niveles existentes (D9). Verificado contra el remoto: el único nivel
      con umbrales reales (1000/1000/1500/2000) quedó en
      1100/1100/1650/2200, exactamente ×1.1.
- [x] 4.2 No hace falta staging: `round()` es monótona, así que escalar los
      cuatro campos por el mismo factor 1.1 no puede invertir su orden
      (ver nota de 4.1). Verificado igualmente contra los datos reales del
      remoto tras el push.

## 5. Panel

- [x] 5.1 Subir `MAX_PUNTOS_DESAFIO` de 5000 a 5500 en
      `panel/src/lib/nivelRecorrido.ts`
- [x] 5.2 Añadir constantes separadas para la curva de solo-distancia
      (`MAX_PUNTOS_DISTANCIA=5000`, `PISO_PUNTOS_DESAFIO=50`,
      `K_DISTANCIA_KM=1500`) y hacer que `distanciaMediaKm` las use en vez
      de `MAX_PUNTOS_DESAFIO` (D12)
- [x] 5.3 Añadir el campo `segundos_por_desafio` al formulario de
      "Configuración del nivel" en `panel/src/pages/NivelRecorrido.tsx`,
      con validación de entero > 0
- [x] 5.4 Actualizar `panel/src/lib/niveles.ts` (`crearNivel` fija
      `segundos_por_desafio: 60` explícito al crear un nivel; la
      lectura/escritura de la configuración vive en `nivelRecorrido.ts`,
      cubierta por 5.1-5.3)
- [x] 5.5 Tests actualizados en `nivelRecorrido.test.ts`, `niveles.test.ts`
      y `NivelRecorrido.test.tsx` para el nuevo campo y para
      `distanciaMediaKm` con las constantes separadas. `npx tsc -b
      --noEmit`, `npx eslint .`, `npx prettier --check .` y `npx vitest run
      --coverage` (238 tests) en verde; cobertura sin regresión
      (89.58% statements / 78.65% branches / 94.69% funciones / 94.58%
      líneas).

## 6. App (Flutter) — gateway

- [x] 6.1 Cambiar `NivelJuegoGateway.responderDesafio` para aceptar
      `latitud`/`longitud` nulos (`double?`)
- [x] 6.2 Añadir `Future<void> marcarDesafioMostrado({required
      intentoId, required desafioId})` a `NivelJuegoGateway` y su
      implementación Supabase (`rpc('marcar_desafio_mostrado', ...)`)
- [x] 6.3 Exponer `segundosPorDesafio` en `IntentoNivel` (default 60 para
      no romper constructores `const` en otros tests que no ejercitan el
      temporizador)
- [x] 6.4 Exponer `puntosDistancia`/`puntosBonus` en `RespuestaDesafio`;
      `distanciaKm` pasa a `double?` (única relajación necesaria: la
      ubicación real se revela con o sin pin)
- [x] 6.5 Fakes de test del gateway (`app/test/fakes`) actualizados con la
      nueva superficie

## 7. App (Flutter) — pantalla de juego

- [x] 7.1 Estado de cuenta atrás (`Timer.periodic`) en
      `_NivelJuegoScreenState`, arrancando/reiniciando en `_iniciarIntento`
      (encadenado tras `iniciarIntento`, ya que hasta entonces no se conoce
      `segundosPorDesafio`) y en `_avanzarDesdeElRevelado`, llamando a
      `marcarDesafioMostrado` en esos mismos puntos (fire-and-forget: un
      fallo de red no bloquea la partida, D6)
- [x] 7.2 Temporizador cancelado en `dispose()` y al entrar en el revelado
- [x] 7.3 Widget `_CuentaAtras` en `_HudJuego` con los tres estados de
      color (`_teal`/`_gold`/`_rojo`) según los cortes de D10 (50%/20%)
- [x] 7.4 Al llegar a 0 con pin colocado: invoca `_confirmar`
      automáticamente
- [x] 7.5 Al llegar a 0 sin pin colocado: `_confirmarSinPin` llama a
      `responderDesafio` sin coordenadas y entra en el revelado con
      `_Revelado.pin = null`
- [x] 7.6 `_HojaDeRevelado`/`_TarjetaDeDistancia` adaptadas para el caso
      sin pin: sin pin del jugador, sin línea, sin contador de distancia,
      solo ubicación real y contador de puntos (a 0)
- [x] 7.7 Desglose de puntaje (`_DesgloseDePuntaje`) en `_HojaDeRevelado`:
      puntos de precisión y, si `puntosBonus > 0`, una línea "+N por
      rapidez"; sin línea de bonus cuando es 0 (D14 de `design.md`)
- [x] 7.8 Tests de widget para: aparición y colores de la cuenta atrás,
      auto-confirmación con pin al llegar a 0, revelado sin pin al llegar
      a 0 sin pin, reinicio de la cuenta atrás al avanzar de desafío,
      desglose de bonus visible/ausente. `flutter analyze`, `dart format
      --set-exit-if-changed .` y `flutter test --coverage` (232 tests) en
      verde; cobertura 93.1% global, 96.8% en `nivel_juego_screen.dart`.

## 8. Verificación final

- [x] 8.1 Backend: `test_calcular_puntaje.sql` y
      `test_calcular_puntaje_bonus.sql` contra el remoto, OK. Panel:
      vitest (238 tests) + tsc + eslint + prettier, OK. App: flutter test
      (232 tests) + analyze + format, OK.
- [ ] 8.2 Probar manualmente un intento completo con al menos un timeout
      con pin y un timeout sin pin — pendiente de testing local del
      usuario
- [x] 8.3 Los checks de la tabla lo garantizan en el momento de la
      migración (habría abortado si no); confirmado además contra los
      datos reales: único nivel con umbrales — 1100 ≤ 1650 ≤ 2200 tras el
      rebalanceo.
