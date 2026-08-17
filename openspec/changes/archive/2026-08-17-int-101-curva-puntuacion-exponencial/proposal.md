## Why

La curva de puntaje actual (`calcular_puntaje`, lineal con corte duro a 0 a partir de
2.000 km) no da señal de progreso más allá del corte —fallar por 2.100 km o por
19.000 km puntúa igual— y apenas premia la precisión fina (acertar la ciudad frente
al país cambia poco el resultado). Además, el panel obliga a teclear los umbrales de
estrellas como enteros absolutos que el admin debe calcular a mano conociendo el
máximo del nivel, lo que hace el diseño de niveles propenso a error.

## What Changes

- `calcular_puntaje` pasa de decaimiento lineal con corte a 0 a una curva exponencial
  con suelo (`MAX=5000, PISO=50, k=1500`): puntúa a cualquier distancia (mínimo 50 en
  antípodas), premia acercarse de forma creciente, y mantiene rango cerrado
  `[50, 5000]`. Misma firma — `responder_desafio`, el trigger de inserción y el
  `puntos_maximos` del revelado (`calcular_puntaje(0)`) no cambian.
- Constantes `MAX`/`PISO`/`k` aisladas y documentadas en la propia función para poder
  ajustarlas con playtesting sin tocar el resto del sistema.
- Panel — umbrales de estrellas 2 y 3 pasan de enteros absolutos a **porcentaje del
  puntaje máximo del nivel** (`N × 5000`, con `N` = preguntas por partida efectivas:
  `preguntas_por_partida` si está definido, o el tamaño del pool del recorrido si es
  `NULL`), con el absoluto calculado y guardado igual que hoy, y mostrando junto a
  cada umbral la distancia media que implica.
- `umbral_estrella_1` se retira del formulario del panel: conceptualmente ⭐ ya es
  `puntaje_minimo_superar` (el campo se mantiene tal cual). La columna en base de
  datos no se elimina —ya es una columna muerta que `cerrar_intento_nivel` no lee— y
  el guardado la fija automáticamente igual a `puntaje_minimo_superar` para seguir
  cumpliendo el `CHECK (puntaje_minimo_superar <= umbral_estrella_1)` existente sin
  necesitar una migración que la toque.
- Tests: comportamiento de la curva (d=0 → MAX, monotonía decreciente, antípodas →
  PISO, nunca 0, nunca por encima de MAX) y de la conversión porcentaje↔absoluto y
  validación en el panel.

## Capabilities

### New Capabilities

(ninguna)

### Modified Capabilities

- `challenge-scoring`: el requisito "Cálculo de puntaje a partir de la distancia"
  cambia de decaimiento lineal con corte exacto a 0 en el umbral, a decaimiento
  exponencial con suelo — el puntaje nunca es 0 y el rango queda acotado en
  `[50, 5000]`.
- `panel-level-detail`: el requisito "Tarjeta de configuración del nivel editable"
  cambia la forma de introducir los umbrales de 2 y 3 estrellas (de enteros absolutos
  a porcentaje del máximo del nivel, con absoluto y distancia media derivados) y
  retira `umbral_estrella_1` del formulario.

## Impact

- `backend/supabase/migrations/`: nueva migración que reemplaza `calcular_puntaje`
  (`create or replace`, misma firma) por la curva exponencial con suelo. No toca
  `responder_desafio`, el trigger `respuestas_desafio_antes_de_insertar` ni la RPC de
  revelado — todos llaman a `calcular_puntaje` por nombre.
- `panel/src/lib/nivelRecorrido.ts`: lógica de conversión porcentaje↔absoluto,
  cálculo de `N` efectivo, distancia media implicada por umbral, validación
  actualizada, y fijado automático de `umbral_estrella_1 = puntaje_minimo_superar`
  al guardar.
- `panel/src/pages/NivelRecorrido.tsx`: UI de la tarjeta "Configuración del nivel" —
  reemplaza los inputs de umbral 2/3 por inputs de porcentaje con el absoluto y la
  distancia media mostrados, y elimina el input de `umbral_estrella_1`.
- Tests nuevos/actualizados: SQL para `calcular_puntaje` y unitarios de
  `nivelRecorrido.ts`/`NivelRecorrido.tsx`.
- Sin migración que borre columnas ni cambios en `level-progression`
  (`cerrar_intento_nivel` en sus dos versiones ya ignora `umbral_estrella_1`).
- Las filas ya guardadas en `respuestas_desafio` conservan su puntaje calculado con
  la curva vieja; no se hace backfill.
