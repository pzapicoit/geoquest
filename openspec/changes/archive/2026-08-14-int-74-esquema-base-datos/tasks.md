## 1. Migración: tipos y tablas base

- [x] 1.1 `supabase migration new create_game_schema` desde `backend/`
- [x] 1.2 Crear `type rol_usuario as enum ('admin', 'jugador')`
- [x] 1.3 Crear `type tipo_desafio as enum ('imagen', 'pregunta_texto', 'video')`
- [x] 1.4 Crear tabla `profiles` (`id` PK → `auth.users(id)` on delete cascade,
      `nombre`, `avatar_url`, `role rol_usuario` not null default `'jugador'`)
- [x] 1.5 Crear tabla `tematicas` (`id`, `nombre`, `imagen_portada`, `orden`
      unique, `estrellas_requeridas`, `activo`)

## 2. Migración: niveles y banco de desafíos

- [x] 2.1 Crear tabla `niveles` (`id`, `tematica_id` FK → `tematicas` on
      delete cascade, `orden`, `puntaje_minimo_superar`, `umbral_estrella_1/2/3`,
      `activo`, unique `(tematica_id, orden)`, check umbrales crecientes y
      `puntaje_minimo_superar <= umbral_estrella_1`)
- [x] 2.2 Crear tabla `desafios` (`id`, `tipo tipo_desafio`, `imagen_url`,
      `video_url`, `texto_pregunta`, `lat_real`, `lng_real` con check de rango,
      `nombre_lugar`, `activo`, check de exclusividad según `tipo` — ver D3 en
      `design.md`)
- [x] 2.3 Crear tabla `nivel_desafios` (`nivel_id` FK → `niveles` on delete
      cascade, `desafio_id` FK → `desafios` on delete restrict, `orden`, PK
      compuesta `(nivel_id, desafio_id)`, unique `(nivel_id, orden)`)

## 3. Migración: intentos y progreso

- [x] 3.1 Crear tabla `intentos_nivel` (`id`, `usuario_id` FK → `profiles` on
      delete cascade, `nivel_id` FK → `niveles` on delete cascade,
      `puntaje_total`, `superado`, `estrellas_obtenidas` check 0-3, `fecha`)
- [x] 3.2 Crear tabla `respuestas_desafio` (`id`, `intento_id` FK →
      `intentos_nivel` on delete cascade, `desafio_id` FK → `desafios` on
      delete restrict, `lat_adivinada`/`lng_adivinada` con check de rango,
      `distancia_km`, `puntos`, `respondido_en`, unique
      `(intento_id, desafio_id)`)
- [x] 3.3 Crear tabla `progreso_usuario_nivel` (`usuario_id` FK → `profiles`
      on delete cascade, `nivel_id` FK → `niveles` on delete cascade,
      `superado`, `mejor_puntaje`, `mejores_estrellas` check 0-3,
      `desbloqueado`, `actualizado_en`, PK compuesta `(usuario_id, nivel_id)`)

## 4. Índices y aplicación

- [x] 4.1 Índices sobre columnas de FK sin cubrir por una PK/unique ya
      existente: `niveles(tematica_id)`, `nivel_desafios(desafio_id)`,
      `intentos_nivel(usuario_id)`, `intentos_nivel(nivel_id)`,
      `respuestas_desafio(intento_id)`, `respuestas_desafio(desafio_id)`
- [x] 4.2 `supabase db push` desde `backend/` contra el proyecto remoto
- [x] 4.3 Actualizar el comentario de `backend/supabase/seed.sql` (ya no
      aplica "el esquema llega en INT-74"); sin insertar contenido ficticio

## 5. Verificación

- [x] 5.1 `supabase migration list` confirma que local y remoto coinciden
- [x] 5.2 Insertar y borrar filas de prueba vía SQL para confirmar cada
      constraint del punto 1-3 (exclusividad de `desafios`, unicidad de
      `orden`, rangos de lat/lng, `ON DELETE RESTRICT` vs `CASCADE`),
      revirtiendo los datos de prueba al terminar
- [x] 5.3 `supabase db reset --linked` reconstruye el esquema completo desde
      las migraciones sin intervención manual
