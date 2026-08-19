## 1. Esquema y datos (backend)

- [x] 1.1 Migración de esquema: `tematicas.objetivo_global text` (nullable), `desafios.nombre text` (nullable), `desafios.pista text` (nullable, permanente).
- [x] 1.2 Migración de datos, primera pasada: `UPDATE desafios SET nombre = nombre_lugar` sobre las 83 filas existentes.
- [x] 1.3 Migración de datos, segunda pasada: `UPDATE` fila a fila por `id` para las 11 filas de "Personas de la Historia", fijando `nombre` (personaje) y `nombre_lugar` (ciudad de nacimiento) según la tabla de design.md D2.
- [x] 1.4 Migración de datos, segunda pasada: `UPDATE` fila a fila por `id` para las 13 filas de "Películas", fijando `nombre` (título identificado) y `nombre_lugar` (localización real de rodaje) según la tabla de design.md D2.
- [x] 1.5 Migración de datos, tercera pasada: `UPDATE` fila a fila por `id` de `lat_real`/`lng_real` para las 7 filas con coordenada incorrecta (Titanic, Jurassic Park, El Resplandor, Einstein, Darwin, Mandela, Steve Jobs, Teresa de Calcuta), con comentario en la migración documentando el error observado y la fuente del valor corregido.
- [x] 1.6 Migración de datos: `UPDATE tematicas SET objetivo_global = ...` para las 6 temáticas actuales, con los textos de design.md D3.
- [x] 1.7 Verificar que no queda ninguna fila con `nombre`/`objetivo_global` nulo y aplicar `ALTER TABLE ... SET NOT NULL` sobre `tematicas.objetivo_global` y `desafios.nombre`.
- [x] 1.8 `create or replace view desafios_para_jugar` añadiendo `nombre` a las columnas expuestas.
- [x] 1.9 `create or replace function iniciar_intento_parada` añadiendo `objetivo_global` (join a `tematicas` vía `camino.tematica_id`) al `jsonb` de respuesta, junto a `segundos_por_desafio`.

## 2. Panel — formularios

- [x] 2.1 Formulario de temática (`Tematicas.tsx`/lib asociada): añadir campo obligatorio `objetivo_global`, precargado al editar, bloqueando el guardado si está vacío.
- [x] 2.2 Formulario de pregunta (`PreguntaForm.tsx`/`preguntaForm.ts`): añadir `nombre` como primer campo, obligatorio, con su propia validación de guardado.
- [x] 2.3 Formulario de pregunta: añadir campo opcional `pista`, sin validación de obligatoriedad.
- [x] 2.4 Formulario de pregunta: re-etiquetar el campo de lugar existente para dejar claro que es la respuesta real revelada al terminar el desafío, no el nombre de la pregunta.

## 3. Panel — listado de preguntas

- [x] 3.1 Listado de preguntas (`Preguntas.tsx`): mostrar `nombre` como identificador de fila en vez de `nombre_lugar`/`texto_pregunta`.
- [x] 3.2 Buscador del listado: combinar `nombre` y `nombre_lugar` en el filtro de texto (case-insensitive), manteniendo el resto de filtros combinables.

## 4. App — pantalla de juego

- [x] 4.1 `DesafioJuego` (`nivel_juego_gateway.dart`): añadir campo `nombre`, parseado desde la respuesta de `desafios_para_jugar`/`iniciar_intento_parada`.
- [x] 4.2 `IntentoNivel` (`nivel_juego_gateway.dart`): añadir campo `objetivoGlobal`, parseado desde la respuesta de `iniciar_intento_parada`.
- [x] 4.3 Toast de pista (`nivel_juego_screen.dart`): mostrar `objetivoGlobal` de la parada junto al `nombre` del desafío actual, para los tres tipos de contenido (imagen, vídeo, pregunta de texto).

## 5. Verificación

- [x] 5.1 Backend: confirmar contra el proyecto Supabase enlazado que las 24 filas corregidas (11 Personas de la Historia + 13 Películas) tienen `nombre`/`nombre_lugar` correctos y que las 7 filas de coordenada corregida tienen `lat_real`/`lng_real` correctos.
- [ ] 5.2 Panel: crear/editar una temática y una pregunta comprobando los campos nuevos (`objetivo_global`, `nombre`, `pista`) y la búsqueda combinada del listado. (Pendiente de testing local manual del usuario; cubierto por tests automáticos de `Tematicas.test.tsx`/`PreguntaForm.test.tsx`/`Preguntas.test.tsx`.)
- [ ] 5.3 App: jugar una parada de cada temática migrada (al menos Personas de la Historia y Películas) comprobando que el toast muestra `objetivo_global` + `nombre`, y que las tarjetas de resultado siguen mostrando `nombre_lugar` sin cambios. (Pendiente de testing local manual del usuario; cubierto por test automático de `nivel_juego_screen_test.dart`.)
