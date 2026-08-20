## 1. Esquema y revelado en Postgres

- [x] 1.1 Migración de esquema: `alter table desafios add column ciudad text`, con comentario que explique el papel del campo frente a `nombre_lugar` y `pais`
- [x] 1.2 En la misma migración, `create or replace function responder_desafio(...)` partiendo de la definición vigente de `20260818122000_dificultad_camino_rpcs_vistas.sql`: `ciudad` al `select into` y al `jsonb_build_object`, sin tocar nada más del cuerpo (D2)
- [x] 1.3 `supabase db push` y `supabase db lint --linked` sin errores nuevos
- [x] 1.4 Verificar contra el remoto que `responder_desafio` devuelve `ciudad` (una respuesta real de prueba, o `explain`/inspección del `jsonb`) y que `desafios_para_jugar` **no** la trae

## 2. Backfill del banco

- [x] 2.1 Leer las 135 filas de `desafios` (`id`, `nombre`, `nombre_lugar`, `pais`, `lat_real`, `lng_real`) vía REST con la clave secreta de `backend/.env.local`
- [x] 2.2 Determinar la ciudad de cada fila cruzando nombre y coordenadas, no solo el nombre (D7); anotar las que se quedan en `NULL` y por qué
- [x] 2.3 Migración de datos con un `update` por fila, agrupada por temática y con comentarios de los casos no obvios, en la línea de `20260819181000_migracion_datos_nombre_objetivo_global.sql` (D6)
- [x] 2.4 `supabase db push` y comprobar el recuento: cuántas filas quedan con `ciudad` y cuántas en `NULL`, contra lo previsto en 2.2

## 3. App — el revelado nombra la ciudad

- [x] 3.1 `nivel_juego_gateway.dart`: `RespuestaDesafio` gana `ciudad` (`String?`), y se añade el lector `_textoOpcional` que hoy no existe (D5)
- [x] 3.2 `mapearRespuestaDesafio` lee `ciudad` como opcional, sin exigirla
- [x] 3.3 `nivel_juego_screen.dart`: resolver `ciudad ?? nombre_lugar` en un solo punto y usarlo tanto en el rótulo de la hoja como en el `nombre:` de `revelarUbicacion` (D4)
- [x] 3.4 Tests del gateway: revelado con `ciudad`, revelado con `ciudad` a `null`, y revelado sin la clave `ciudad` en el `jsonb` (app nueva contra RPC vieja)
- [x] 3.5 Tests de pantalla: la hoja muestra la ciudad; con `ciudad` a `null` muestra `nombre_lugar`; el rótulo del pin coincide con el de la hoja

## 4. Panel — campo de ciudad en el formulario

- [x] 4.1 `preguntaForm.ts`: `ciudad` en el tipo de fila, en el `select` de carga, en el input de guardado y en el trim a `null` (D10)
- [x] 4.2 `PreguntaForm.tsx`: campo opcional "Ciudad" junto a "País", con texto de ayuda que diga que es lo que la app muestra al revelar y qué se lee si se deja vacío
- [x] 4.3 Tests: guardar sin ciudad, guardar con ciudad, cargar una pregunta que ya la tiene, y vaciar la de una que la tenía

## 5. Generación con IA — ciudad y país por candidato

- [x] 5.1 `proponer-lugares/index.ts`: `ciudad` y `pais` en `ESQUEMA_RESPUESTA` y en la interfaz `Lugar`
- [x] 5.2 Reglas de formato del prompt: ciudad y país correspondientes a las coordenadas, vacíos permitidos cuando no haya ciudad o país reales, y refuerzo explícito de que la descripción no los nombra (D8)
- [x] 5.3 `extraerLugares`: los dos campos son opcionales — un candidato sin ciudad se acepta, no se descarta; cadena vacía se normaliza a `null`
- [x] 5.4 `supabase functions deploy proponer-lugares` y verificar contra una temática real que los candidatos traen ciudad y país coherentes con sus coordenadas, y que ninguna descripción los nombra
- [x] 5.5 `iaPreguntas.ts`: `CandidatoIA` gana `ciudad`/`pais` y `proponerLugares` los arrastra sin pasarlos por la deduplicación (D9)
- [x] 5.6 `loteIA.ts`: `CandidatoParaGuardar` gana `ciudad`/`pais` y el `insert` los escribe, con `null` para los vacíos
- [x] 5.7 `PreguntasGenerarIA.tsx`: la tabla del paso 2 muestra ciudad y país por fila —marcando las que llegan sin ciudad— y `guardar()` los pasa al lote (D11)
- [x] 5.8 Tests del panel: candidato con ciudad se guarda con ella, candidato sin ciudad se guarda con `null` y sigue seleccionable, y la tabla del paso 2 pinta ambos campos

## 6. Cierre

- [x] 6.1 `.devplugin/architecture.md`: entrada de INT-122 en las filas de `backend/`, `app/` y `panel/`
- [x] 6.2 `backend/README.md`: mención de `desafios.ciudad` donde se explica el contenido del banco, si aplica
- [x] 6.3 Suites completas: `flutter test`, tests del panel con cobertura, `supabase db lint --linked`
- [ ] 6.4 Prueba en dispositivo del revelado: una pregunta con ciudad y una sin ella
