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
- [ ] 4.2 Verificar en un entorno de staging/con copia de datos que el
      rebalanceo no rompe los `check` de orden ascendente entre
      `puntaje_minimo_superar <= umbral_estrella_1 <= umbral_estrella_2 <=
      umbral_estrella_3`

## 5. Panel

- [ ] 5.1 Subir `MAX_PUNTOS_DESAFIO` de 5000 a 5500 en
      `panel/src/lib/nivelRecorrido.ts`
- [ ] 5.2 Añadir constantes separadas para la curva de solo-distancia
      (`MAX_PUNTOS_DISTANCIA=5000`, `PISO_PUNTOS_DESAFIO=50`,
      `K_DISTANCIA_KM=1500`) y hacer que `distanciaMediaKm` las use en vez
      de `MAX_PUNTOS_DESAFIO` (D12)
- [ ] 5.3 Añadir el campo `segundos_por_desafio` al formulario de
      "Configuración del nivel" en `panel/src/pages/NivelRecorrido.tsx`,
      con validación de entero > 0
- [ ] 5.4 Actualizar `panel/src/lib/niveles.ts` (lectura/escritura del
      nivel) para incluir `segundos_por_desafio`
- [ ] 5.5 Actualizar/añadir tests en `nivelRecorrido.test.ts` y
      `niveles.test.ts` para el nuevo campo y para `distanciaMediaKm` con
      las constantes separadas

## 6. App (Flutter) — gateway

- [ ] 6.1 Cambiar `NivelJuegoGateway.responderDesafio` para aceptar
      `latitud`/`longitud` nulos (`double?`)
- [ ] 6.2 Añadir `Future<void> marcarDesafioMostrado({required
      intentoId, required desafioId})` a `NivelJuegoGateway` y su
      implementación Supabase (`rpc('marcar_desafio_mostrado', ...)`)
- [ ] 6.3 Exponer `segundosPorDesafio` en `DesafioJuego`/`IntentoNivel` (o
      en el nivel) para que la pantalla sepa cuánto dura la cuenta atrás
- [ ] 6.4 Exponer `puntosDistancia`/`puntosBonus` en el modelo de
      respuesta que devuelve `responderDesafio`, junto al `puntos` total
      ya existente
- [ ] 6.5 Actualizar los fakes de test del gateway
      (`app/test/fakes`) con la nueva superficie

## 7. App (Flutter) — pantalla de juego

- [ ] 7.1 Añadir estado de cuenta atrás (`Timer.periodic` o similar) a
      `_NivelJuegoScreenState`, arrancando/reiniciando en `initState` y en
      `_avanzarDesdeElRevelado`, y llamando a `marcarDesafioMostrado` en
      esos mismos puntos
- [ ] 7.2 Cancelar el temporizador en `dispose()` y al entrar en el
      revelado (`_revelado != null`)
- [ ] 7.3 Añadir el widget de la barra de cuenta atrás al `_HudJuego` (o
      `_TarjetaDeProgreso`) con los tres estados de color (`_teal`,
      `_gold`, `_rojo`) según los cortes de D10
- [ ] 7.4 Al llegar a 0 con pin colocado: invocar `_confirmar`
      automáticamente
- [ ] 7.5 Al llegar a 0 sin pin colocado: llamar a `responderDesafio` sin
      coordenadas y entrar en el revelado con un `_Revelado` que indique
      "sin pin" (para que la UI del revelado lo distinga)
- [ ] 7.6 Adaptar `_HojaDeRevelado`/`_TarjetaDeDistancia` para el caso sin
      pin: sin pin del jugador, sin línea, sin contador de distancia,
      solo ubicación real y contador de puntos (a 0)
- [ ] 7.7 Añadir el desglose de puntaje a `_HojaDeRevelado`: puntos de
      precisión y, si `puntosBonus > 0`, una línea "+N por rapidez"; sin
      línea de bonus cuando es 0 (D14 de `design.md`)
- [ ] 7.8 Tests de widget para: aparición y colores de la cuenta atrás,
      auto-confirmación con pin al llegar a 0, revelado sin pin al llegar
      a 0 sin pin, reinicio de la cuenta atrás al avanzar de desafío,
      desglose de bonus visible cuando `puntosBonus > 0` y ausente cuando
      es 0

## 8. Verificación final

- [ ] 8.1 Ejecutar la suite de tests de backend, panel y app
- [ ] 8.2 Probar manualmente un intento completo con al menos un timeout
      con pin y un timeout sin pin
- [ ] 8.3 Revisar que los niveles ya sembrados en el entorno de desarrollo
      siguen teniendo `puntaje_minimo_superar <= umbral_estrella_2 <=
      umbral_estrella_3` tras el rebalanceo
