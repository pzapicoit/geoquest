## Why

Llenar el banco de preguntas es hoy el cuello de botella del contenido: cada
desafío de tipo imagen se crea a mano en `panel-questions-form`, y cada uno
obliga a buscar un lugar real, sus coordenadas y una imagen. Montar una tanda
para una temática nueva es media tarde de trabajo manual.

INT-113 automatiza la parte mecánica —proponer lugares reales y ilustrarlos—
dejando en manos del admin lo único que la IA no puede decidir: qué entra al
banco.

## What Changes

- **Nueva pantalla `/preguntas/generar-ia`** en el panel, con el wizard de tres
  pasos de la maqueta `[Admin] - Preguntas - Generar con IA.dc.html`:
  1. **Configurar**: temática, dificultad, cantidad e indicaciones extra
     opcionales. No gasta nada todavía.
  2. **Revisar propuestas**: tabla de candidatos (descripción, lugar,
     coordenadas, dificultad) con selección por fila, "marcar/desmarcar todas"
     y "otra tanda".
  3. **Ilustrar y guardar**: una imagen estilo Pixar por candidato aprobado, con
     barra de progreso, estado y "rehacer" por tarjeta, y barra final de guardado
     con toggle "Publicar activas".
- **Dos Edge Functions de Supabase** (las primeras del proyecto):
  `proponer-lugares` (texto) y `generar-imagen-lugar` (imagen). Encapsulan la
  API key de OpenAI, que vive como secreto de función (`geo_open_api`) y nunca
  llega al navegador. Ambas exigen `profiles.role = 'admin'` en el invocador.
- **Deduplicación de lugares** en el cliente, testeable: nombre normalizado (sin
  acentos ni mayúsculas) y cercanía de coordenadas (~10 km) contra el banco de
  esa temática y contra el resto del lote. Si tras filtrar faltan candidatos, se
  pide otra ronda a la IA con la lista de exclusión ampliada (hasta 2 rondas
  extra).
- **Guardado del lote** creando una fila `desafios` de tipo `imagen` por
  candidato aprobado, con su imagen subida a `challenge-media` siguiendo la
  convención ya vigente `imagen/{desafio_id}.{extension}`.
- **Entrada desde el listado de preguntas**: botón "Generar con IA" junto a
  "Nueva pregunta".
- **Aviso de coste aproximado** antes de lanzar la generación de imágenes, en
  lugar del contador de "créditos IA" de la maqueta (no existe tal sistema de
  créditos en el producto).
- **Errores traducidos**: la pantalla distingue "el secreto no está configurado",
  "la IA no responde" y "la IA no devolvió candidatos nuevos" en castellano, sin
  filtrar el error crudo de OpenAI ni de la función.

### Divergencias resueltas entre la maqueta y el modelo de datos

- **La columna "Enunciado" no se persiste.** El CHECK de `desafios` obliga a
  `texto_pregunta IS NULL` cuando `tipo = 'imagen'`. La descripción que genera la
  IA se usa como base del prompt de la ilustración y se muestra en la revisión
  como contexto, pero no se guarda. Guardarla exigiría cambiar el modelo de
  datos, fuera del alcance de este issue.
- **Dificultad: 5 valores, no 4.** La maqueta ofrece Fácil/Media/Difícil/Mixta;
  el catálogo real es el enum `dificultad` de 5 valores (INT-106). Manda el
  catálogo real y se retira "Mixta": el issue pide una dificultad por tanda.
- **Cantidad: contador de 3 a 20** (maqueta) en vez de los saltos 5/10/15/20 que
  menciona el issue. El contador los incluye y no cuesta más.

## Capabilities

### New Capabilities

- `panel-ai-question-generation`: la pantalla del panel que orquesta el wizard de
  tres pasos, la deduplicación de candidatos, el progreso de ilustración y el
  guardado del lote en el banco.
- `ai-generation-edge-functions`: el contrato de las dos Edge Functions —
  autorización solo admin, lectura del secreto de OpenAI, modelos configurables
  por variable de entorno, formato de respuesta y códigos de error.

### Modified Capabilities

- `panel-questions-listing`: la acción de creación deja de ser única; el listado
  gana un acceso "Generar con IA" a `/preguntas/generar-ia`.
- `backend-environment`: el repositorio deja de tener *solo* esquema. Pasa a
  versionar Edge Functions bajo `backend/supabase/functions/`, con su flujo de
  despliegue y la regla de que sus secretos se configuran fuera del repo y nunca
  se versionan. Matiza "Backend único compartido": sigue habiendo un único
  proyecto Supabase y ningún servicio intermedio, pero ahora existe código
  server-side propio, limitado a custodiar credenciales de terceros.

## Impact

**Código nuevo**

- `backend/supabase/functions/proponer-lugares/index.ts`
- `backend/supabase/functions/generar-imagen-lugar/index.ts`
- `backend/supabase/functions/_shared/` (autorización admin, lectura del secreto,
  respuestas de error)
- `panel/src/pages/PreguntasGenerarIA.tsx` + test
- `panel/src/lib/iaPreguntas.ts` (invocación de las funciones) + test
- `panel/src/lib/duplicadosLugar.ts` (normalización, haversine, filtrado) + test
- `panel/src/lib/loteIA.ts` (subida de imagen + inserción del lote) + test

**Código modificado**

- `panel/src/App.tsx`: ruta `/preguntas/generar-ia`
- `panel/src/pages/Preguntas.tsx`: botón "Generar con IA"
- `panel/src/lib/preguntaForm.ts`: se reutiliza `subirMediaDesafio` para el lote
- `backend/supabase/config.toml`: declaración de las dos funciones
- `backend/README.md`: despliegue de funciones y configuración de secretos
- `.devplugin/architecture.md`: Edge Functions en el mapa del sistema y sus
  gates de calidad

**Dependencias y entorno**

- API de OpenAI (texto e imágenes) como dependencia externa nueva del panel, vía
  las funciones. Sin librería nueva: `fetch` desde Deno.
- Secreto `geo_open_api` en el proyecto `xhrntgsdlnwrvwehqfgl`. **Hoy ese proyecto
  no tiene ningún custom secret**: el `geo_open_api` que existe está en el
  proyecto vecino Nomad Travel (`vcamgyuhbxbqunclcxjj`), creado ahí por error.
  Sin el secreto en GeoQuest, la pantalla funciona hasta el paso 1 y luego
  muestra el aviso de configuración.
- Deno 2.9 (ya instalado) como toolchain de las funciones: `deno check` y
  `deno lint` entran como gate de calidad del backend.
- Coste real por uso: cada imagen es una llamada facturable a OpenAI. El wizard
  lo avisa antes de lanzarlas.

**Sin impacto**

- `app/` (Flutter) no cambia: consume `desafios` igual que antes.
- No hay migración de esquema. No cambian las políticas RLS ni el bucket.
