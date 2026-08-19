## 1. Esquema

- [x] 1.1 Crear la migración `tematica_prompt_imagen`: `alter table tematicas add
      column prompt_imagen text` (D1), con comentario explicando que gobierna solo
      la ilustración
- [x] 1.2 Aplicar con `supabase db push` y comprobar con `supabase migration list`

## 2. Formulario de temáticas

- [x] 2.1 `panel/src/lib/tematicas.ts`: leer `prompt_imagen` en `fetchTematicas` y
      guardarlo en `guardarTematica` (vacío → null)
- [x] 2.2 `panel/src/pages/Tematicas.tsx`: campo multilínea opcional en el panel
      lateral, con texto de ayuda que aclare que solo gobierna la ilustración
- [x] 2.3 Tests de `tematicas.ts`: se guarda el prompt, se guarda como null
      cuando está vacío, se precarga al editar
- [x] 2.4 Test de `Tematicas.tsx`: el campo aparece, se precarga y llega al
      guardado

## 3. Generación con IA

- [x] 3.1 `panel/src/lib/preguntaForm.ts`: `fetchTematicasParaPregunta` devuelve
      también `promptImagen` (D5)
- [x] 3.2 `panel/src/lib/iaPreguntas.ts`: `generarImagenLugar` acepta
      `estiloTematica` además de `indicaciones` (D2)
- [x] 3.3 `panel/src/pages/PreguntasGenerarIA.tsx`: fijar el estilo de la temática
      al lanzar la tanda, igual que se hace con las indicaciones, y enviarlo en
      cada ilustración
- [x] 3.4 `panel/src/pages/PreguntasGenerarIA.tsx`: mostrar en el paso 1 el estilo
      que se aplicará, o su ausencia, señalando dónde se define (D4)
- [x] 3.5 Tests: la ilustración se pide con el estilo de la temática, sin él
      cuando la temática no lo tiene, y con los dos cuando además hay
      indicaciones

## 4. Edge Function de imagen

- [x] 4.1 `generar-imagen-lugar`: aceptar y validar `estiloTematica`, y componer
      el prompt distinguiendo su papel del de las indicaciones de tanda (D2)
- [x] 4.2 `deno check` y `deno lint` limpios
- [x] 4.3 Desplegar y verificar contra el remoto con el caso de «Banderas»:
      bandera sobre fondo neutro, sin escena

## 5. Cierre

- [x] 5.1 `npm run lint`, `npm run typecheck`, `npm run format:check` y
      `npm run test:coverage` limpios en `panel/`
- [x] 5.2 Documentar el campo en `backend/README.md` (qué gobierna y qué no) y en
      `.devplugin/architecture.md`
