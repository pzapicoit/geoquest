## 1. Preguntas — edición inline

- [x] 1.1 `panel/src/lib/preguntas.ts`: añadir `actualizarDificultadPregunta(id, dificultad)` y `actualizarActivoPregunta(id, activo)` (update de una sola columna sobre `desafios`).
- [x] 1.2 `panel/src/pages/Preguntas.tsx`: sustituir el badge estático de dificultad por un `<select>` inline y el indicador de estado por un toggle inline en `FilaPregunta`; estado de guardado/error por fila y por campo, revertir valor en fallo.
- [x] 1.3 Tests de `Preguntas.test.tsx`/`preguntas.test.ts` para los 3 escenarios de la spec (cambiar dificultad, cambiar estado, fallo de guardado).

## 2. Temáticas — edición inline

- [x] 2.1 `panel/src/lib/tematicas.ts`: añadir `actualizarActivoTematica(id, activo)`.
- [x] 2.2 `panel/src/pages/Tematicas.tsx`: sustituir el indicador estático de estado por un toggle inline en `FilaTematica`; estado de guardado/error por fila, revertir valor en fallo.
- [x] 2.3 Tests de `Tematicas.test.tsx`/`tematicas.test.ts` para los 2 escenarios de la spec.

## 3. Nueva pregunta — cabeceras de sección (visual, sin spec propia)

- [x] 3.1 `panel/src/pages/PreguntaForm.tsx`: añadir cabeceras "1 · Contenido", "2 · Ubicación", "3 · Clasificación", "4 · Datos y estado" sobre los grupos de campos existentes, siguiendo el estilo de `[Admin] - Preguntas - Nueva.dc.html` (uppercase, tracking ancho, línea horizontal a la derecha). Sin cambios de campos, validación ni comportamiento.

## 4. Verificación

- [x] 4.1 `npm run lint`, `npx tsc --noEmit`, `npm run build`, `npx vitest run` en `panel/`. Resultado: lint limpio, typecheck limpio, build limpio (224 módulos), 169/169 tests (antes 164, +5 nuevos de este delta). Verificación visual autenticada no realizada — sin credenciales de admin ni `chromium-cli` disponibles en este entorno (mismo límite que en INT-106).
