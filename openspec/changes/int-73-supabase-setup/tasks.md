# Tareas — INT-73

## 1. Contención de claves

- [x] 1.1 Claves legacy (`anon`, `service_role`) desactivadas desde el dashboard
      por el usuario (2026-08-14)
- [x] 1.2 Verificado **funcionalmente**: ambas legacy devuelven 401 contra un
      endpoint de datos; las nuevas devuelven 404 (autentican, tabla inexistente).
      Ojo: `supabase projects api-keys` sigue enumerando las legacy aunque estén
      desactivadas, así que ese listado no sirve como comprobación
- [x] 1.3 Confirmar que las nuevas (`sb_publishable_…`, `sb_secret_…`) siguen operativas

## 2. Entorno de backend

- [x] 2.1 `supabase init` dentro de `backend/`
- [x] 2.2 `supabase link --project-ref xhrntgsdlnwrvwehqfgl`
- [x] 2.3 `project_id` del stack local fijado a `geoquest` (venía `backend` por el
      nombre de la carpeta). El ref remoto no vive aquí sino en `supabase/.temp/`,
      gitignorado — por eso se documenta en README y `.env.example`
- [x] 2.4 `backend/.env.example` con nombres de variable y placeholders
- [x] 2.5 `backend/.env.local` con los valores reales (no versionado)
- [x] 2.6 `.env.local`, `.env.*.local` y `dart_define.json` en el `.gitignore` raíz
- [x] 2.7 Verificado con `git check-ignore` y `git add --dry-run`: ningún fichero
      con claves reales entra al repo

## 3. Documentación

- [x] 3.1 `backend/README.md`: prerrequisitos, arranque, parada, reset, migraciones
- [x] 3.2 Documentado el síntoma de "Docker parado" y su solución
- [x] 3.3 Documentado el reparto de claves y por qué la secreta no sale de `backend/`
- [x] 3.4 `.devplugin/architecture.md` con el backend único compartido y las
      herramientas de calidad por módulo

## 4. Flujo remote-first

> Decisión D6: sin stack local hasta INT-77. Docker deja de ser bloqueante.

- [x] 4.1 Verificado que `supabase db reset --linked` existe: la cadena de
      migraciones se puede reaplicar desde cero contra el remoto sin Docker
- [x] 4.2 README reescrito como remote-first, con el stack local marcado como
      opcional y diferido
- [x] 4.3 Documentada la advertencia de que `db reset --linked` actúa sobre el
      único entorno existente
- [x] 4.4 `backend/supabase/seed.sql` creado y documentado. `[db.seed]` ya venía
      activo en `config.toml` apuntando a `./seed.sql`
- [ ] 4.5 Reevaluar Docker al empezar INT-77

## 5. Cliente en la app

- [x] 5.1 Flutter 3.47.0 / Dart 3.13.0 instalado. `flutter doctor`: Flutter ✓,
      Xcode 26.6 ✓, Chrome ✓. **Android toolchain ✗** — falta el SDK de Android;
      no bloquea INT-73 pero hay que instalarlo antes de INT-88
- [x] 5.2 `flutter create --org es.intermarkit --project-name geoquest`
      sobre `app/`, plataformas ios/android/web
- [x] 5.3 `supabase_flutter ^2.17.2` y `http` como dependencias directas
- [x] 5.4 `AppConfig.fromEnvironment` valida antes de inicializar y lanza
      `MissingConfigError` nombrando la variable ausente
- [x] 5.5 `app/dart_define.example.json` versionado; `dart_define.json` real
      generado desde `.env.local` y gitignorado
- [x] 5.6 `ConnectivityCheck` contra `/auth/v1/health`, inyectable para test
- [x] 5.7 Cubierto por 10 tests (`flutter test`): éxito, clave inválida con el
      motivo visible, timeout, red caída, y que no se usa la raíz de PostgREST.
      **Falta la prueba visual del usuario** — ver nota abajo
- [x] 5.8 Verificado sobre `build/web`: la clave secreta aparece en 0 ficheros,
      la publicable en 1 (intencionado), ningún JWT legacy

> **Pendiente de prueba local del usuario**: los tests usan un cliente HTTP
> falso. El camino real (red real contra el proyecto real) está verificado a
> nivel HTTP con `curl`, pero nadie ha visto la app en pantalla todavía:
>
> ```
> cd app && flutter run -d chrome --dart-define-from-file=dart_define.json
> ```

## 6. Cierre

- [x] 6.1 Conectividad verificada contra el proyecto remoto:
      `supabase migration list` conecta, `/auth/v1/health` → 200,
      `/rest/v1/<tabla>` con publicable → 404 (autentica, tabla inexistente)
- [x] 6.2 Región `eu-west-1` confirmada por el usuario (2026-08-14): público
      objetivo europeo
- [x] 6.3 `openspec validate` de la propuesta
