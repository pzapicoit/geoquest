## 1. Edge Functions (backend)

- [x] 1.1 Crear `backend/supabase/functions/_shared/cors.ts` con las cabeceras y
      el manejo de `OPTIONS` que necesitan las invocaciones desde el panel
- [x] 1.2 Crear `backend/supabase/functions/_shared/errores.ts` con el conjunto
      cerrado de códigos (`no_autorizado`, `secreto_no_configurado`,
      `peticion_invalida`, `respuesta_invalida`, `openai_error`) y el helper de
      respuesta JSON de error
- [x] 1.3 Crear `backend/supabase/functions/_shared/admin.ts`: cliente Supabase
      con el `Authorization` del invocador y comprobación de
      `profiles.role = 'admin'` (D5)
- [x] 1.4 Crear `backend/supabase/functions/_shared/openai.ts`: lectura de
      `geo_open_api`, de `GEOQUEST_MODELO_TEXTO` / `GEOQUEST_MODELO_IMAGEN` con
      sus defaults, y `fetch` con `AbortController` (D8, D10)
- [x] 1.5 Implementar `backend/supabase/functions/proponer-lugares/index.ts`:
      valida la petición, construye el prompt en servidor con exclusiones e
      indicaciones extra, pide salida estructurada, descarta coordenadas fuera de
      rango y devuelve los candidatos (D3)
- [x] 1.6 Implementar `backend/supabase/functions/generar-imagen-lugar/index.ts`:
      una ilustración estilo Pixar por invocación, WebP 1024×1024 calidad media,
      devuelta en línea con su MIME (D7)
- [x] 1.7 Declarar ambas funciones en `backend/supabase/config.toml` con
      `verify_jwt` activado
- [x] 1.8 `deno check` y `deno lint` limpios sobre `backend/supabase/functions/`

## 2. Deduplicación de lugares (panel, lógica pura)

- [x] 2.1 Crear `panel/src/lib/duplicadosLugar.ts`: `normalizarNombreLugar`
      (minúsculas, sin acentos, sin puntuación, espacios colapsados)
- [x] 2.2 Añadir `distanciaKm` (haversine) y la constante de umbral de 10 km
- [x] 2.3 Añadir `filtrarCandidatosNuevos(candidatos, existentes)`: descarta
      duplicados contra el banco de la temática y entre candidatos del propio
      lote, preservando el orden de llegada
- [x] 2.4 Tests de `duplicadosLugar`: nombre con acentos y mayúsculas, nombre
      distinto a menos de 10 km, duplicado dentro del lote, lugar cercano de otra
      temática (no es duplicado), límite exacto del umbral

## 3. Acceso a las funciones desde el panel

- [x] 3.1 Crear `panel/src/lib/iaPreguntas.ts` con los tipos del contrato
      (`CandidatoIA`, `ImagenIA`) y `proponerLugares` / `generarImagenLugar`
      sobre `supabase.functions.invoke`
- [x] 3.2 Añadir el mapa de códigos de error a mensajes en castellano y la
      función que traduce cualquier fallo (incluido el de red) a uno de ellos
      (D12)
- [x] 3.3 Añadir `fetchLugaresExistentes(tematicaId)`: nombre y coordenadas de
      los desafíos de esa temática, para la deduplicación
- [x] 3.4 Añadir `pedirCandidatosDeduplicados`: orquesta las rondas extra (máximo
      2) ampliando la exclusión, y devuelve los candidatos junto a si la tanda
      quedó corta (D9)
- [x] 3.5 Tests de `iaPreguntas`: traducción de cada código de error, ronda extra
      que completa la tanda, rondas agotadas con tanda corta, error de red

## 4. Guardado del lote

- [x] 4.1 Crear `panel/src/lib/loteIA.ts` con `guardarLoteIA`: por candidato,
      genera el `id`, sube el `Blob` con `subirMediaDesafio` e inserta la fila
      (`tipo = 'imagen'`, `texto_pregunta` nulo, temática, dificultad, lugar,
      coordenadas, `activo` según el toggle) (D6, D11)
- [x] 4.2 Devolver el resultado por candidato para poder reintentar solo los que
      fallaron, sin perder las imágenes ya generadas
- [x] 4.3 Tests de `loteIA`: lote completo, candidato sin imagen que se omite,
      fallo de subida y fallo de inserción

## 5. Pantalla del wizard

- [x] 5.1 Crear `panel/src/pages/PreguntasGenerarIA.tsx` con el indicador de tres
      pasos y el estado del wizard (configuración, candidatos, imágenes, guardado)
- [x] 5.2 Paso 1: selector de temática, las cinco dificultades como tarjetas,
      contador de 3 a 20 (por defecto 8), indicaciones extra opcionales y aviso de
      que todavía no se gasta nada (D14)
- [x] 5.3 Paso 2: tabla de candidatos con selección por fila, marcar/desmarcar
      todas, otra tanda, descartar tanda, aviso de tanda corta y resumen con el
      coste aproximado de las imágenes
- [x] 5.4 Paso 3: barra de progreso, tarjeta por candidato con estado, reintento
      por tarjeta y bucle con 3 invocaciones en vuelo (D10)
- [x] 5.5 Barra de guardado con el toggle "Publicar activas", deshabilitada
      mientras queden imágenes en curso, y banner de confirmación con enlace al
      banco
- [x] 5.6 Liberar los `objectURL` de las imágenes al descartar la tanda y al
      desmontar la pantalla (D4)
- [x] 5.7 Traducir el lenguaje visual de la maqueta a las clases Tailwind y los
      tokens `brand-*` que ya usa el panel

## 6. Integración en el panel

- [x] 6.1 Añadir la ruta `/preguntas/generar-ia` en `panel/src/App.tsx`, dentro de
      `RequireAuth` + `PanelLayout`
- [x] 6.2 Añadir el botón "Generar con IA" en `panel/src/pages/Preguntas.tsx`
      junto a "Nueva pregunta"
- [x] 6.3 Test de `Preguntas` para el nuevo botón y su destino

## 7. Tests de la pantalla

- [x] 7.1 Test del paso 1: dificultades del catálogo, límites del contador,
      generar deshabilitado sin temática
- [x] 7.2 Test del paso 2: candidatos marcados por defecto, descarte de una fila,
      desmarcar todas deshabilita continuar, descartar tanda vuelve al paso 1
- [x] 7.3 Test del paso 3: progreso, imagen fallida que no bloquea el lote,
      rehacer una imagen
- [x] 7.4 Test de guardado: filas creadas con `activo` según el toggle, candidato
      sin imagen omitido, guardar deshabilitado mientras se generan imágenes
- [x] 7.5 Test de errores: secreto sin configurar y fallo de la IA muestran
      mensaje propio, no el error crudo

## 8. Documentación y gates

- [x] 8.1 Documentar en `backend/README.md` el despliegue de las funciones, el
      secreto `geo_open_api`, las variables de modelo con sus defaults y que los
      valores no se versionan
- [x] 8.2 Actualizar `.devplugin/architecture.md`: Edge Functions en el mapa del
      sistema, su papel limitado a custodiar credenciales, y `deno check` /
      `deno lint` como gate de calidad del backend
- [x] 8.3 `npm run lint`, `npm run typecheck`, `npm run format:check` y
      `npm run test:coverage` limpios en `panel/`
