## Why

Hoy "Cambiar de jugador" no cambia de jugador: **renombra el mismo perfil**.
`login_screen.dart` solo borra la clave `username` de `SharedPreferences` y la
sesión de Supabase Auth sigue intacta, así que `username_screen` acaba haciendo
un `update` de `profiles.nombre` sobre el perfil de siempre. Dos jugadores del
mismo móvil comparten progreso y el apodo anterior desaparece del ranking.

Debajo hay un problema mayor: **el progreso no es recuperable**. La única llave de
un perfil es la sesión anónima persistida en el dispositivo; si se borra o se
reinstala la app, ese jugador y sus puntos son inalcanzables para siempre.

La causa raíz de las dos cosas es la misma: **un jugador no tiene credenciales**.
Este cambio le da unas.

## What Changes

- **Un jugador pasa a tener apodo y contraseña.** Con eso entra en su perfil desde
  este móvil o desde otro, y varios jugadores alternan en el mismo dispositivo sin
  pisarse el progreso.
- **Sin email en ningún punto.** La identidad interna que Supabase Auth necesita
  es un email sintético derivado del apodo, que el cliente calcula y que no puede
  recibir correo (dominio `.invalid`, RFC 2606). No hay verificación, no hay SMTP,
  no hay recuperación por email — y eso último se dice en pantalla, no se esconde.
- **La captura de apodo se convierte en un login de verdad**: apodo + contraseña,
  un solo botón, que crea el perfil si el apodo está libre y entra en él si el
  apodo ya es de alguien.
- **"Cambiar de jugador" cierra sesión de verdad** y lleva a ese login.
- **Entrar como invitado sigue existiendo y sigue sin contraseña**: el primer
  arranque no gana fricción. Un invitado puede ponerse contraseña después y
  conserva su progreso (mismo usuario, no una cuenta nueva).
- **Un perfil sin contraseña no se puede abandonar en silencio**: soltar la sesión
  de un invitado equivale a perderlo, así que cambiar de jugador desde un perfil
  sin contraseña exige ponerle una antes, o descartarlo explícitamente.
- **Atajo de "¿quién juega?"**: el dispositivo recuerda los apodos que han entrado
  aquí y los ofrece para rellenar el apodo de un toque; la contraseña se sigue
  escribiendo. Se guardan **apodos, no sesiones ni contraseñas**.
- **BREAKING (producto)**: el mensaje "Sin contraseñas por ahora. Más adelante
  podrás vincular una cuenta" de la captura de apodo desaparece: ahora hay
  contraseña, y es lo que protege el progreso.
- **BREAKING (modelo de auth)**: un perfil con contraseña deja de ser anónimo en
  Supabase Auth. Nada en el proyecto depende de `is_anonymous` — verificado en
  migraciones, policies, app y panel.
- **BREAKING (dato)**: el apodo de un perfil con contraseña deja de ser
  modificable, porque la identidad interna deriva de él. Se impide en la base, no
  solo en la app. Ningún camino actual renombra apodos: el panel solo lee
  `profiles`.
- **Ajuste del proyecto Supabase**: el remoto tiene la confirmación por email
  activada (`mailer_autoconfirm: false`), mientras `config.toml` del repo declara
  `enable_confirmations = false`. El remoto está desalineado del repo y hay que
  alinearlo, o ningún alta con email sintético podrá iniciar sesión.

### Lo que esto sustituye

El issue planteaba tres vías y recomendaba la A: una edge function que canjea el
apodo público por una sesión. Se descarta. La A necesitaba la clave secreta, un
tope de intentos hecho a mano y aceptar que **cualquiera que leyera un apodo en
la Clasificación entraba en esa cuenta**. Una contraseña real no necesita nada de
eso: el rate limit lo pone ya la plataforma (30 altas/logins por 5 min por IP) y
no hay agujero que documentar. El precio es la fricción de un campo más y no
poder recuperar una contraseña olvidada.

## Capabilities

### New Capabilities

- `player-password-auth`: registro y acceso de un jugador con apodo y contraseña
  sin email. Identidad interna derivada del apodo, estado de un apodo (libre / con
  contraseña / ocupado sin contraseña), conversión de un invitado en jugador con
  contraseña conservando su progreso, y ausencia declarada de recuperación.
- `device-player-roster`: lista local de apodos que ya han entrado en este
  dispositivo, para rellenar el apodo de un toque y poder olvidarlo.

### Modified Capabilities

- `app-username`: la pantalla pasa a pedir apodo y contraseña y a resolver con un
  solo botón "crear perfil" o "entrar en el mío"; desaparece el texto que promete
  que no hay contraseñas; aparecen los errores propios del acceso (contraseña
  incorrecta, apodo ocupado sin contraseña).
- `app-login`: "Cambiar de jugador" suelta la sesión activa, no solo el apodo
  guardado, y exige contraseña en el perfil que se abandona si no la tiene.
- `player-anonymous-auth`: el invitado sigue entrando sin credenciales, pero puede
  convertirse en jugador con contraseña conservando el mismo usuario y su
  progreso; un dispositivo puede originar N perfiles.
- `player-alias-uniqueness`: el apodo sigue siendo único entre jugadores y ahora
  además es parte de la credencial, así que un perfil con contraseña no puede
  cambiar de apodo.

## Impact

**Backend** — no hay edge function, ni clave secreta, ni tabla de topes.
- Una migración: RPC `estado_apodo(alias)` y trigger que impide renombrar un
  perfil con credenciales.
- Un ajuste de configuración del proyecto (confirmación de email desactivada),
  aplicable de forma versionada con `supabase config push`.

**App**
- `AuthGateway`: crece con `signOut`, `signInWithPassword`, `updateUser` y
  `currentUser`.
- Nuevos `EstadoApodoGateway`, `PlayerSessionService` y `PlayerRosterStorage`.
- `username_screen` (login real), `login_screen` (cambio de jugador).

**Fuera de alcance (issue aparte)**
- El tope diario de comodines por anuncio (4/día) pasa a ser por perfil, así que
  se multiplica creando perfiles en el mismo móvil.
- Recuperación de una contraseña olvidada (haría falta un segundo factor que no
  sea email: código de un solo uso mostrado al crear el perfil, o vinculación de
  Google/Apple, que ya está a medias en el proyecto).
