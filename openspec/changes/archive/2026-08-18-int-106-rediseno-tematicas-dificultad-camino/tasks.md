## 1. Backend — esquema nuevo

- [x] 1.1 Migración: `create type dificultad as enum ('facil','normal','intermedio','dificil','muy_dificil')`.
- [x] 1.2 Migración: crear tabla `dificultad_defaults` (PK `dificultad`, columnas `preguntas_por_partida`, `segundos_por_desafio`, `puntaje_minimo_superar`, `umbral_estrella_2`, `umbral_estrella_3`, todas `not null`) y sembrar sus 5 filas con los valores de `design.md` D3.
- [x] 1.3 Migración: `alter table desafios add column dificultad dificultad not null default 'normal'` (quitar el `default` en una migración posterior una vez completado el backfill, para que las altas nuevas exijan el valor explícito).
- [x] 1.4 Migración: `alter table desafios add column tematica_id uuid references tematicas(id) on delete restrict` — nullable en esta migración (se hace `not null` tras el backfill del punto 2.2).
- [x] 1.5 Migración: añadir a `camino` las columnas `tematica_id` (FK `tematicas`, nullable en esta migración), `dificultad` (enum, nullable en esta migración), `nombre` (text, nullable), `activo` (bool, not null default true), y overrides nullable `preguntas_por_partida`, `segundos_por_desafio`, `puntaje_minimo_superar`, `umbral_estrella_2`, `umbral_estrella_3`.

## 2. Backend — migración de datos

- [x] 2.1 Backfill `desafios.tematica_id`: por cada desafío, tomar la `tematica_id` del nivel de menor `orden` entre sus filas de `nivel_desafios` (join `nivel_desafios` → `niveles`). Ejecutar antes una query de auditoría que liste los `desafios.id` sin ninguna fila en `nivel_desafios` (no tienen de dónde inferir temática) y los que aparecen en niveles de más de una temática distinta (la migración se queda con la primera, documentar el resto); resolver ambos casos manualmente si aparecen antes de continuar.
- [x] 2.2 Tras el backfill, `alter table desafios alter column tematica_id set not null` y quitar el `default 'normal'` de `desafios.dificultad` (punto 1.3).
- [x] 2.3 Backfill de `camino`: por cada fila existente, tomar `tematica_id` del `nivel_id` referenciado, fijar `dificultad = 'normal'`, `nombre` = `niveles.nombre`, `activo` = `niveles.activo`, y copiar como overrides explícitos `preguntas_por_partida`, `segundos_por_desafio`, `puntaje_minimo_superar`, `umbral_estrella_2`, `umbral_estrella_3` del nivel referenciado.
- [x] 2.4 Tras el backfill, `alter table camino alter column tematica_id set not null`, `alter column dificultad set not null`.
- [x] 2.5 Renombrar `intentos_nivel.nivel_id` → `camino_id` y `progreso_usuario_nivel.nivel_id` → `camino_id`; repuntar sus FKs a `camino(id)` (antes apuntaban a `niveles(id)`).

## 3. Backend — RPCs y vistas

- [x] 3.1 Crear `iniciar_intento_parada(p_camino_id uuid)` (reemplaza `iniciar_intento_nivel`): resuelve temática+dificultad efectivos de la parada (override o `dificultad_defaults`), sortea `preguntas_por_partida` desafíos activos de `desafios_para_jugar` filtrados por esa `tematica_id`+`dificultad`, persiste en `intento_desafios` igual que hoy. Borrar `iniciar_intento_nivel`.
- [x] 3.2 Renombrar la RPC de cierre de intento (migración `20260818090000_cerrar_intento_nivel_resumen.sql` la define) a `cerrar_intento_parada`, operando sobre `camino_id`: resolver `puntaje_minimo_superar`/`umbral_estrella_2/3` efectivos de la parada (override o `dificultad_defaults`), `umbral_estrella_1` = mínimo efectivo.
- [x] 3.3 Actualizar el trigger `respuestas_desafio_calcular_antes_de_insertar` (usa hoy `join intentos_nivel it join niveles n on n.id = it.nivel_id` para leer `segundos_por_desafio`) para resolver el valor efectivo desde `camino_id` (override o `dificultad_defaults`).
- [x] 3.4 Actualizar `marcar_desafio_mostrado` y `responder_desafio` si referencian `niveles`/`nivel_id` internamente (revisar `20260818110000_temporizador_desafio_bonus_rapidez.sql`).
- [x] 3.5 Reescribir la vista `camino_jugador` para exponer temática+dificultad+nombre de la parada (en vez de "el nivel al que apunta") y usar `camino_id` en vez de `nivel_id`.
- [x] 3.6 Actualizar `metricas_home()`: sustituir `niveles_activos` (conteo de `niveles` activos) por `paradas_activas` (conteo de `camino` activo).
- [x] 3.7 Actualizar `alertas_contenido()`: la alerta `nivel_baja_tasa` pasa a calcularse por `camino_id` en vez de `nivel_id`.
- [x] 3.8 Actualizar `actividad_reciente()`: el evento `nivel_superado` pasa a incluir `camino_id` en su `detalle` en vez de `nivel_id`.
- [x] 3.9 Borrar las RPCs `reordenar_niveles` y `reordenar_preguntas_nivel`. `reordenar_tematicas` y `reordenar_camino` no cambian.
- [x] 3.10 Borrar la vista `desafios_uso`.

## 4. Backend — RLS y limpieza final

- [x] 4.1 RLS de `dificultad_defaults`: `select` público autenticado, `insert`/`update`/`delete` solo `is_admin()` (sin `delete` real posible por ser catálogo fijo — bloquear explícitamente).
- [x] 4.2 Actualizar las policies de `tematicas`/`desafios`/`camino` para quitar `niveles`/`nivel_desafios` de las listas de tablas cubiertas por las policies de lectura pública y escritura solo-admin.
- [x] 4.3 `drop table nivel_desafios;` y `drop table niveles;` (una vez confirmado que 2.x y 3.x no dejan ninguna referencia activa).
- [x] 4.4 Ejecutar `supabase db lint`/tests de integración de backend si existen, para detectar cualquier referencia residual a `niveles`/`nivel_desafios`/`nivel_id` no contemplada arriba. Ejecutado tras el despliegue real: `supabase db lint --linked` → "No schema errors found".

## 5. Panel — dificultad y valores por defecto

- [x] 5.1 `panel/src/pages/PreguntaForm.tsx` y `panel/src/lib/preguntaForm.ts`: añadir selector de temática (nuevo, `desafios` no tenía `tematica_id`) y selector de dificultad; quitar la sección "Asignar a nivel(es) ahora" y sus llamadas a `nivel_desafios`/`niveles` (líneas ~67-80, ~184-203 de `preguntaForm.ts`).
- [x] 5.2 Actualizar `panel/src/lib/preguntaForm.test.ts` para los nuevos campos/flujo y quitar los mocks de `niveles`/`nivel_desafios`.
- [x] 5.3 Crear `panel/src/lib/dificultadDefaults.ts` (leer/editar `dificultad_defaults`) y `panel/src/pages/DificultadDefaults.tsx` (tabla de 5 filas editables, validación de orden ascendente y enteros positivos).
- [x] 5.4 Wire de la nueva pantalla en `panel/src/App.tsx` (ruta) y `panel/src/components/PanelLayout.tsx` (enlace de navegación).

## 6. Panel — camino y retirada de niveles

- [x] 6.1 Reescribir `panel/src/lib/camino.ts`: `listarCamino`/`añadirNivelACamino` pasan a trabajar con `tematica_id`+`dificultad`+overrides en vez de `nivel_id`/join a `niveles`; quitar la exclusión de combinaciones ya presentes.
- [x] 6.2 Reescribir `panel/src/pages/Camino.tsx`: selector de temática+dificultad al añadir, columna de dificultad en el listado, panel de edición de overrides opcionales por posición.
- [x] 6.3 Actualizar `panel/src/lib/camino.test.ts` y `panel/src/pages/Camino.test.tsx` (si existe) a los nuevos campos.
- [x] 6.4 Borrar `panel/src/pages/NivelesTematica.tsx`, `panel/src/pages/NivelRecorrido.tsx`, `panel/src/lib/niveles.ts`, `panel/src/lib/nivelRecorrido.ts` y sus ficheros de test (`NivelesTematica.test.tsx`, `NivelRecorrido.test.tsx`, `niveles.test.ts`, `nivelRecorrido.test.ts`).
- [x] 6.5 Quitar de `panel/src/App.tsx`/`PanelLayout.tsx` las rutas/enlaces a `/tematicas/:id/niveles` y `/niveles/:id`.
- [x] 6.6 `panel/src/lib/tematicas.ts` (línea 31, `supabase.from('niveles').select('tematica_id')`) y `panel/src/pages/Tematicas.tsx` (líneas 178, 553, recuento "N niveles"): sustituir por recuento de paradas de `camino` que referencian la temática; el borrado de temática pasa a bloquear si tiene `desafios` propios en vez de cascadear niveles.
- [x] 6.7 Actualizar `panel/src/lib/tematicas.test.ts` a los mocks nuevos.

## 7. Panel — listados y home

- [x] 7.1 `panel/src/pages/Preguntas.tsx` (línea 185, "Usado en N niveles") y `panel/src/lib/preguntas.ts`: sustituir el indicador de uso por el badge de dificultad; quitar el filtro "sin asignar"; añadir filtro por dificultad.
- [x] 7.2 Actualizar `panel/src/lib/preguntas.test.ts` a los mocks/expectativas nuevas.
- [x] 7.3 `panel/src/lib/dashboard.ts` (líneas 72, 153, 164): sustituir las lecturas de `niveles` para resolver nombres de actividad/alertas por lecturas de `camino`; `detalle?.nivel_id` → `detalle?.camino_id`.
- [x] 7.4 Actualizar `panel/src/lib/dashboard.test.ts` (línea 143, mock con `nivel_id`) al nuevo campo `camino_id`.
- [x] 7.5 `panel/src/pages/NivelesTematica.tsx` queda cubierto por 6.4 (se borra); confirmar que ninguna otra pantalla referencia `cantidadNiveles`/`preguntasTotal` de ese origen tras el cambio.

## 8. App (Flutter)

- [x] 8.1 `app/lib/services/nivel_juego_gateway.dart`: renombrar la llamada `iniciar_intento_nivel`/`p_nivel_id` (línea ~179-180) a `iniciar_intento_parada`/`p_camino_id`, y `cerrar_intento_nivel` (línea ~220) a `cerrar_intento_parada`. Actualizar los comentarios de doc que las nombran (líneas 43, 71, 118, 229, 276).
- [x] 8.2 `app/lib/services/camino_gateway.dart` (línea 107, `row['nivel_id']`): leer `row['camino_id']` de `camino_jugador` y renombrar el campo `nivelId` del modelo si procede para reflejar que identifica una parada.
- [x] 8.3 `app/lib/screens/nivel_juego_screen.dart`: actualizar los comentarios de doc que nombran `iniciar_intento_nivel`/`cerrar_intento_nivel` (líneas 21, 28, 1291). Sin cambio de comportamiento visible — el vocabulario de UI ("nivel", "camino de niveles") no cambia.
- [x] 8.4 Revisar los tests de `app/test` que mockean estas RPCs/campos y actualizarlos a los nuevos nombres.

## 9. Verificación

- [x] 9.1 Repasar cada capability nueva/modificada de `specs/` contra su implementación — todos los scenarios deben quedar cubiertos. Hecho vía `opsx-verify` + revisión adversarial (APROBADO, sin hallazgos críticos ni menores); incluyó corregir un bug de orden de migraciones encontrado en el proceso (ver `design.md`/migración `20260818122000`).
- [x] 9.2 Probar la migración de datos (2.1–2.5) sobre una copia de los datos reales de Supabase antes de aplicar en producción; revisar especialmente los avisos de auditoría de 2.1 (desafíos sin temática inferible o con temáticas distintas entre sus niveles). No había copia disponible (proyecto remoto único, sin staging) — aplicada directamente por decisión explícita del usuario. Ningún `RAISE WARNING` de auditoría se disparó durante `supabase db push` (ni orfandad de `desafios.tematica_id`, ni multi-tematica, ni historial huérfano de `camino_id`), señal de datos limpios. Durante el despliegue real aparecieron y se corrigieron 2 bugs que ninguna revisión de código sin base real pudo detectar: (1) `create or replace view camino_jugador` con columnas renombradas (ya corregido antes del push, ver 3.5 en la migración) y (2) el mismo problema en `metricas_home()` con `niveles_activos`→`paradas_activas` (encontrado en el primer intento de `db push`, corregido con `drop function` + `create function`, migración reaplicada con éxito).
- [ ] 9.3 Prueba manual end-to-end: crear una pregunta con temática+dificultad nuevas, añadirla al pool, montar una parada de camino para esa pareja, jugar un intento completo en la app y confirmar puntaje/estrellas/desbloqueo. Verificación parcial hecha: panel — `npm run build` (tsc + vite) compila limpio con las 224 rutas/módulos y el server de dev sirve la pantalla de login correctamente; no se pudo entrar autenticado (sin credenciales de admin a mano ni `chromium-cli` disponible en este entorno para automatizarlo). App — `flutter run` en simulador falló por un problema de esquema de Xcode preexistente y ajeno a este cambio ("No Xcode build settings have been found"), no relacionado con el código de INT-106. **Pendiente de que el usuario haga el recorrido real** (o me dé credenciales de admin del panel / arregle el esquema de Xcode si quiere que lo intente yo).
- [x] 9.4 Ejecutar la suite de tests de `panel/` (`npm test` o equivalente) y de `app/` (`flutter test`) tras todos los cambios anteriores. Panel: 164/164 (lint/prettier/tsc limpios). App: 236/236 (`flutter analyze` limpio, `dart format` sin cambios).
