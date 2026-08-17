## 1. Backend: curva de puntuación exponencial

- [x] 1.1 Nueva migración (`create or replace`) que reescribe `calcular_puntaje`
      en `language plpgsql` con constantes locales nombradas y documentadas
      `MAX = 5000`, `PISO = 50`, `k = 1500`, implementando
      `round(PISO + (MAX - PISO) * exp(-d / k))`
- [x] 1.2 Confirmar que `responder_desafio`, el trigger
      `respuestas_desafio_antes_de_insertar` y `puntos_maximos` del revelado
      (`calcular_puntaje(0)`) siguen funcionando sin cambios (misma firma)
- [x] 1.3 Tests SQL de la curva: d=0 → MAX exacto; antípodas (~20.015 km) →
      PISO exacto; monotonía decreciente entre pares de distancias; resultado
      siempre en `[PISO, MAX]`; verificar los pares (d, puntos) de la tabla de
      la propuesta (50→4838, 200→4382, 500→3597, 1000→2591, 2000→1355,
      5000→227) con tolerancia de redondeo

## 2. Panel: lógica de umbrales por porcentaje

- [x] 2.1 `nivelRecorrido.ts`: calcular `N` efectivo del nivel
      (`preguntas_por_partida` si está definido, si no `preguntas.length`) y el
      máximo del nivel (`N × 5000`)
- [x] 2.2 `nivelRecorrido.ts`: añadir constantes `MAX_PUNTOS_DESAFIO = 5000`,
      `PISO_PUNTOS_DESAFIO = 50`, `K_DISTANCIA_KM = 1500` con comentario que
      referencia la migración SQL como fuente de verdad, y funciones de
      conversión porcentaje↔absoluto para los umbrales de 2 y 3 estrellas
- [x] 2.3 `nivelRecorrido.ts`: función que, dado un puntaje absoluto, devuelve
      la distancia media en km que implica (`d = -k · ln((puntos - PISO) /
      (MAX - PISO))`), usada para puntaje mínimo y umbrales 2/3
- [x] 2.4 `nivelRecorrido.ts`: actualizar `validarConfiguracionNivel` para
      validar `puntaje_minimo_superar <= umbral_estrella_2 <=
      umbral_estrella_3` sobre los absolutos ya derivados de los porcentajes,
      y quitar cualquier validación sobre `umbral_estrella_1`
- [x] 2.5 `nivelRecorrido.ts`: `guardarConfiguracionNivel` fija
      `umbral_estrella_1 = puntaje_minimo_superar` automáticamente al guardar,
      sin leerlo de un campo del formulario

## 3. Panel: UI de la tarjeta de configuración

- [x] 3.1 `NivelRecorrido.tsx`: sustituir los inputs de "Umbral 2 estrellas" y
      "Umbral 3 estrellas" (enteros absolutos) por inputs de porcentaje,
      mostrando junto a cada uno el absoluto calculado y la distancia media
      que implica
- [x] 3.2 `NivelRecorrido.tsx`: eliminar el input "Umbral 1 estrella"
- [x] 3.3 `NivelRecorrido.tsx`: mostrar la distancia media derivada junto al
      campo "Puntaje mínimo" existente (sin cambiar su tipo de input)

## 4. Tests

- [x] 4.1 `nivelRecorrido.test.ts`: conversión porcentaje↔absoluto y cálculo
      de distancia media en los puntos de referencia de la propuesta
- [x] 4.2 `nivelRecorrido.test.ts`: `validarConfiguracionNivel` bloquea el
      guardado cuando los porcentajes producen absolutos no ascendentes
- [x] 4.3 `NivelRecorrido.test.tsx`: actualizar los tests existentes de los
      inputs de umbral (ya no hay input de umbral 1; los de 2 y 3 estrellas
      son de porcentaje) y añadir cobertura de la distancia media mostrada

## 5. Verificación

- [x] 5.1 Ejecutar tests de backend (migraciones/SQL) y de panel (vitest)
- [ ] 5.2 `/opsx-verify` + revisión adversarial antes de archivar
