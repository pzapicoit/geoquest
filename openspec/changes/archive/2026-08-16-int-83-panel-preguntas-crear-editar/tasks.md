## 1. Dependencias y assets

- [x] 1.1 Añadir `d3-geo` y `topojson-client` a `panel/package.json`
- [x] 1.2 Vendorizar `world-atlas` (`countries-110m.json`, ~110m) como
  `panel/src/assets/world-110m.json`

## 2. Mapa de vista previa

- [x] 2.1 Crear `panel/src/components/MapaVistaPrevia.tsx`: proyección
  Natural Earth con `d3-geo`, silueta de continentes desde el JSON
  vendorizado, pin en `lat`/`lng`, país bajo el pin resaltado, etiqueta de
  coordenadas — sin interacción (sin zoom/drag/click)
- [x] 2.2 Test: el pin se reposiciona cuando cambian `lat`/`lng`; estado
  "coordenadas incompletas" cuando no son válidas

## 3. Datos: obtener, guardar, subir media

- [x] 3.1 `panel/src/lib/preguntaForm.ts`: `fetchPregunta(id)` — trae una
  fila de `desafios` para precargar el formulario en modo edición
- [x] 3.2 `fetchNivelesParaAsignar()` — trae `niveles` + `tematicas` +
  conteo de `nivel_desafios` por nivel, para la sección de asignación
- [x] 3.3 `subirMediaDesafio(id, tipo, file)` — sube a
  `challenge-media/{tipo}/{id}.{ext}` (`upsert: true`) y devuelve la URL
  pública
- [x] 3.4 `guardarPregunta(input)` — genera `id` con `crypto.randomUUID()`
  en creación (D1), sube media si aplica, hace `insert`/`update` en
  `desafios`
- [x] 3.5 `asignarPreguntaANiveles(desafioId, nivelIds, asignacionesActuales)`
  — calcula `orden = max(orden) + 1` por nivel e inserta en
  `nivel_desafios` (D4)
- [x] 3.6 Tests de `preguntaForm.ts`: guardado de creación con y sin subida
  de media, guardado de edición conservando media existente, cálculo de
  `orden` para asignación a niveles, propagación de errores de Storage/DB

## 4. Página del formulario

- [x] 4.1 `panel/src/pages/PreguntaForm.tsx`: selector de tipo excluyente,
  render condicional de imagen/vídeo/texto
- [x] 4.2 Subida de imagen/vídeo con validación de MIME y tamaño (D7) y
  previsualización (`URL.createObjectURL`)
- [x] 4.3 Campos lat/lng con validación de rango y mensaje de error;
  integrar `MapaVistaPrevia`
- [x] 4.4 Campo nombre del lugar y toggle activo/inactivo
- [x] 4.5 Sección "Asignar a nivel(es) ahora", visible solo en modo
  creación (D3): buscador + lista con checkboxes + pills de seleccionados
- [x] 4.6 Validación de campos obligatorios según tipo antes de guardar,
  con errores inline por campo
- [x] 4.7 Guardar (crear o editar) y volver al listado; manejar error de
  guardado sin perder los datos introducidos
- [x] 4.8 Cancelar vuelve al listado sin guardar
- [x] 4.9 Tests de `PreguntaForm.tsx`: cambio de tipo, validaciones,
  guardado en creación y edición, asignación a niveles, cancelar

## 5. Enrutado y listado

- [x] 5.1 `panel/src/App.tsx`: rutas `/preguntas/nueva` y
  `/preguntas/:id/editar` (dentro de `RequireAuth`/`PanelLayout`)
- [x] 5.2 `panel/src/pages/Preguntas.tsx`: habilitar navegación de "Nueva
  pregunta" y "Editar" (quitar `aria-disabled`/`Próximamente`)
- [x] 5.3 Actualizar/ajustar tests de `Preguntas.test.tsx` afectados por el
  cambio

## 6. Verificación

- [x] 6.1 `npm run typecheck`, `npm run lint`, `npm run format:check` en
  `panel/`
- [x] 6.2 `npm run test:coverage` en `panel/`
- [ ] 6.3 Probar manualmente: crear pregunta de cada tipo, editar una
  existente, asignar a niveles al crear, validaciones de coordenadas y de
  campos obligatorios
