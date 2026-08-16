## Why

El banco de preguntas/desafíos ya tiene listado y borrado (INT-82), pero
crear o editar una pregunta solo se puede hacer a mano contra Supabase: el
panel no ofrece ningún formulario, y "Nueva pregunta"/"Editar" están
deshabilitados a propósito a la espera de esta pantalla.

## What Changes

- Nueva pantalla de formulario (`/preguntas/nueva` y `/preguntas/:id/editar`)
  para crear o editar un desafío del banco: selector de tipo excluyente
  (imagen/vídeo/pregunta de texto) que muestra solo el campo correspondiente,
  subida de imagen o vídeo con previsualización, textarea para pregunta de
  texto, lat/lng con validación de rango y vista previa no interactiva en un
  mapa, nombre del lugar, estado activo/inactivo y una sección opcional para
  asignar la pregunta a uno o varios niveles al crearla.
- Guardado: sube el archivo de media al bucket `challenge-media` (cuando
  aplica) y crea/actualiza la fila de `desafios`; si se marcaron niveles,
  inserta las filas correspondientes en `nivel_desafios` al final del orden
  existente de cada nivel.
- Habilita "Nueva pregunta" y "Editar" en el listado (INT-82), que hasta
  ahora estaban deshabilitados a propósito, para que naveguen a esta nueva
  pantalla.

## Capabilities

### New Capabilities
- `panel-questions-form`: pantalla de creación/edición de una pregunta del
  banco, incluyendo subida de media, validación y asignación opcional a
  niveles.

### Modified Capabilities
- `panel-questions-listing`: "Nueva pregunta" y "Editar" dejan de estar
  deshabilitados y navegan a la pantalla de creación/edición.

## Impact

- `panel/src/pages/`: nueva página de formulario; `Preguntas.tsx` pierde el
  estado deshabilitado de sus dos acciones.
- `panel/src/lib/`: nuevas funciones de datos (obtener una pregunta para
  editar, listar niveles disponibles para asignar, subir media, guardar).
- `panel/src/App.tsx`: nuevas rutas `/preguntas/nueva` y
  `/preguntas/:id/editar`.
- Nuevo componente de mapa de vista previa (no interactivo), sin tocar
  backend/esquema — todo lo necesario (`desafios`, `nivel_desafios`, bucket
  `challenge-media`, RLS admin-only) ya existe.
