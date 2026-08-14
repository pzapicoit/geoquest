# Tareas — INT-73

## 1. Contención de claves

- [ ] 1.1 Desactivar las claves legacy (`anon`, `service_role`) del proyecto
      `xhrntgsdlnwrvwehqfgl` desde el dashboard de Supabase — **acción de usuario**,
      el CLI no expone gestión de claves
- [ ] 1.2 Verificar con `supabase projects api-keys` que ya no figuran activas
      (a fecha de hoy siguen activas)
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

> **Bloqueado**: Flutter SDK no está instalado.

- [ ] 5.1 Instalar el SDK de Flutter y pasar `flutter doctor`
- [ ] 5.2 `flutter create` sobre `app/` con el identificador de paquete del proyecto
- [ ] 5.3 Añadir la dependencia `supabase_flutter`
- [ ] 5.4 Inicializar Supabase en el arranque leyendo `String.fromEnvironment`,
      fallando explícitamente si falta alguna variable
- [ ] 5.5 Crear `app/dart_define.example.json` y su equivalente local no versionado
- [ ] 5.6 Pantalla de verificación de conectividad contra `/auth/v1/health`
- [ ] 5.7 Ejecutar la app y comprobar ambos casos: proyecto accesible y clave inválida
- [ ] 5.8 Verificar que la clave secreta no aparece en el binario compilado

## 6. Cierre

- [x] 6.1 Conectividad verificada contra el proyecto remoto:
      `supabase migration list` conecta, `/auth/v1/health` → 200,
      `/rest/v1/<tabla>` con publicable → 404 (autentica, tabla inexistente)
- [x] 6.2 Región `eu-west-1` confirmada por el usuario (2026-08-14): público
      objetivo europeo
- [x] 6.3 `openspec validate` de la propuesta
