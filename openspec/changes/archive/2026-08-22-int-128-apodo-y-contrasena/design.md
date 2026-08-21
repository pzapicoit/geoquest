## Context

Un jugador de GeoQuest no tiene credenciales: su identidad es una sesión anónima
de Supabase Auth persistida por el SDK (INT-75). De ahí salen los dos síntomas del
issue —"Cambiar de jugador" renombra en vez de cambiar, y el progreso es
irrecuperable— y por eso la solución es darle credenciales, no idear un mecanismo
para vivir sin ellas.

Estado actual relevante, comprobado sobre el código y sobre el proyecto remoto:

- `AnonymousSessionService.ensureSession()` cortocircuita con
  `currentSession != null`: correcto para arrancar, inservible para cambiar de
  jugador.
- `login_screen._onSwitchPlayer()` solo hace `_usernameStorage.clear()`.
- `username_screen._onStart()` hace `updateNickname()`: un `update` de
  `profiles.nombre` sobre `auth.uid()` — de ahí el renombrado.
- `AuthGateway` expone solo `currentSession`, `signInAnonymously` y
  `linkIdentity`.
- **No hay índice único sobre `profiles.device_id`**: un dispositivo ya puede
  tener N perfiles sin migración.
- **No hay caché en memoria de camino ni comodines**: ningún servicio guarda
  estado `static`.
- **`clasificacion_global` parte de `respuestas_desafio`**: un perfil sin partidas
  no aparece en el ranking.
- **El panel nunca escribe en `profiles`**, solo lee (`useAdminProfile.ts`): no
  existe ningún camino que renombre un apodo.
- **Nada depende de `is_anonymous`**: cero apariciones en migraciones, policies,
  app y panel. `AccountLinkingService` solo lo usan sus propios tests y el enlace
  "Vincular una cuenta" no tiene acción.
- Proyecto remoto (`/auth/v1/settings`): proveedor de email habilitado,
  `disable_signup: false`, **`mailer_autoconfirm: false`** — la confirmación por
  email está activa, en contra de lo que declara `config.toml`
  (`enable_confirmations = false`). Ese desajuste es el único obstáculo real del
  diseño (D3).
- `config.toml`: `minimum_password_length = 6`, `password_requirements = ""`,
  `enable_anonymous_sign_ins = true`, y rate limit de plataforma
  `sign_in_sign_ups = 30` por 5 minutos por IP.

## Goals / Non-Goals

**Goals:**

- Que un jugador pueda entrar en su perfil desde cualquier dispositivo con algo
  que solo él sabe.
- Que varios jugadores alternen en el mismo móvil sin pisarse el progreso.
- Que ningún camino pueda renombrar el perfil del jugador anterior.
- No montar nada de email: ni SMTP, ni verificación, ni plantillas.
- Que el primer arranque no gane fricción.

**Non-Goals:**

- Recuperar una contraseña olvidada. No hay canal para hacerlo sin email, y
  fingir que existe sería peor que decirlo (D11).
- Vinculación real de Google/Apple.
- Login social, biometría o passkeys (`passkeys_enabled: false` en el remoto).
- El tope diario de comodines por anuncio, que con multi-perfil se multiplica.

## Decisions

### D1 — Contraseña real en vez del canje del apodo público (vía A del issue)

La vía A convertía el apodo en credencial. Como los apodos se ven enteros en
Clasificación, eso significa que **leer la pantalla de ranking era suficiente para
entrar en cualquier cuenta**, y todo el diseño se iba en amortiguarlo: clave
secreta en una edge function, gate de rol para que no cayera un admin, tabla de
canjes y tope por dispositivo hecho a mano — un tope que además era falsificable,
porque el `device_id` lo declara el cliente.

Una contraseña elimina el agujero en vez de acotarlo, y con él se va todo lo que
existía para amortiguarlo: **cero edge functions, cero clave secreta, cero tabla
de topes**. El rate limit lo pone la plataforma (30 altas/logins por 5 min por IP)
y está mejor colocado que el nuestro, porque va por IP y no por un dato que envía
el cliente. El backend de este cambio se queda en una migración pequeña.

Precio: un campo más en la pantalla, y una contraseña olvidada es un perfil
perdido (D11).

### D2 — La identidad interna es un email sintético derivado del apodo, calculado en el cliente

Supabase Auth necesita un identificador para una contraseña: email o teléfono. No
queremos ninguno de verdad. Se usa
`sha256(apodo.trim().toLowerCase())` en hexadecimal como parte local, con dominio
`geoquest.invalid`.

Que se **derive** del apodo, y no que se guarde en una tabla, es lo que evita el
único servicio de servidor que quedaría: el cliente calcula el identificador él
solo, así que `signUp` y `signInWithPassword` se llaman directamente y no hay
ninguna función intermedia que resolver apodo → identidad.

Que sea un **hash** y no el apodo tal cual: los apodos admiten hoy cualquier
carácter hasta 16 (la propia lista de sugerencias trae `BrújulaLoca`, con acento),
y espacios, acentos o emoji no son válidos en la parte local de un email.
Escaparlos exigiría inventar una codificación y mantenerla para siempre; un hash
es determinista, siempre válido y sin colisiones prácticas. Coste asumido: en el
panel de Auth los usuarios se ven como cadenas hexadecimales, así que la migración
lo documenta.

Que el hash sea sobre el apodo en **minúsculas**: el login deja de depender de
cómo se escriban las mayúsculas —nadie recuerda eso— y de paso impide que exista
un "pablo" impostor al lado de "Pablo".

Eso obliga a algo que el índice único de INT-111 no cubría: ese índice es
**exacto**, así que hasta ahora "Pablo" y "pablo" podían ser dos jugadores
distintos. Con identidades derivadas del apodo en minúsculas los dos derivarían
la misma, el primero que se pusiera contraseña se la quedaría y el segundo
perdería su perfil para siempre —sin recuperación posible, que es justo el fallo
que este cambio viene a eliminar—. La migración deduplica lo que ya exista y
sustituye el índice por uno sobre `lower(btrim(nombre))`, de modo que la
unicidad de alias y la unicidad de identidad pasen a ser la misma cosa. El
generador de alias por defecto de `handle_new_user` se ajusta al mismo criterio,
o un candidato que solo difiriera en mayúsculas haría fallar el alta.

Alternativas descartadas: el apodo como parte local (problema de juego de
caracteres); una tabla de correspondencia apodo → identidad (obliga a una llamada
al servidor antes de cada login y expone la correspondencia); teléfono (exige
proveedor de SMS).

### D3 — Hay que desactivar la confirmación de email en el proyecto remoto

Con `mailer_autoconfirm: false`, un `signUp` deja al usuario **sin confirmar**
—incapaz de iniciar sesión— e intenta entregar un correo a un buzón que no
existe. El diseño entero depende de invertir ese ajuste.

Se aplica con `supabase config push`, no con un clic en el dashboard: la spec
`backend-environment` pide que un clon llegue a un entorno operativo "sin haber
tocado la consola web", y `config.toml` ya declara el valor correcto —lo que hay
es deriva del remoto respecto al repo. Como `config push` empuja toda la sección
`[auth]`, la tarea incluye revisar antes qué más cambiaría (el `site_url` del
fichero apunta a `127.0.0.1:3000`) y dejar `config.toml` alineado con lo que se
quiere en remoto **antes** de empujar.

Efecto colateral aceptado: desactivar la confirmación significa que, si algún día
se admiten emails reales, se podría registrar uno ajeno sin verificarlo. Hoy no
hay ningún email real en el producto, y cuando lo haya el ajuste se revisa
entonces.

Respaldo si el ajuste no se pudiera cambiar: crear los usuarios desde una edge
function con `email_confirm: true` vía Admin API. Vuelve a meter la clave secreta,
así que solo se usa si D3 resulta imposible.

### D4 — Un perfil con contraseña no puede cambiar de apodo, y lo impide la base

Si la identidad deriva del apodo, renombrar un perfil con credenciales lo deja sin
acceso: el email que el cliente calcularía ya no sería el suyo. Un trigger
`before update on profiles` rechaza cambiar `nombre` cuando el usuario tiene
credenciales.

Se pone en la base y no en la app porque el fallo es silencioso y definitivo: el
jugador no se enteraría hasta intentar entrar desde otro móvil, cuando ya no hay
nada que hacer. Hoy ningún camino renombra (el panel solo lee `profiles`), así que
el trigger no rompe nada existente; existe para el día que alguien añada un
"editar apodo" sin recordar esta consecuencia.

### D5 — RPC `estado_apodo(alias)`, porque el error de login no distingue casos

`signInWithPassword` devuelve `Invalid login credentials` tanto si el usuario no
existe como si la contraseña es incorrecta —a propósito, para no filtrar qué
cuentas existen. Aquí eso deja a la pantalla sin poder decir nada útil: "¿me
equivoqué de contraseña, o ese apodo no era el mío?".

Una RPC `security definer` devuelve el estado del apodo y solo el estado:
`libre`, `con_contrasena`, `sin_contrasena`. No devuelve el email, ni el id, ni
nada más. La enumeración que permite es la que ya permite Clasificación, donde los
apodos están a la vista; lo nuevo que revela es si un apodo tiene contraseña, que
no abre ningún camino por sí solo.

### D6 — Registrarse es "sesión anónima → apodo → contraseña", en ese orden

Lo natural sería `signUp(identidad, contraseña)` y aplicar el apodo después. No
funciona: al llegar el `updateNickname` el usuario **ya tiene credenciales**, así
que el trigger de D4 rechazaría el renombrado y ningún jugador podría registrarse.
La alternativa de pasar el apodo en los metadatos del `signUp`, para que
`handle_new_user` lo insertara de una vez, tampoco convence: si ese `insert`
chocara con el índice único, fallaría el alta entera con un error de servidor
opaco, y además obligaría a tocar `handle_new_user`, que ya lleva tres migraciones
encima.

Se registra en tres pasos: sesión anónima → `updateNickname` → `updateUser` con la
identidad derivada y la contraseña. En el momento del renombrado el usuario aún no
tiene credenciales, así que D4 no le afecta, y una colisión de apodo llega como
`AliasEnUsoException`, que la pantalla ya sabe traducir. El efecto secundario
bueno: **registrarse y convertir a un invitado (D8) son el mismo camino**, con el
primer paso ya hecho en el segundo caso, y `signUp` no hace falta en ninguna parte.

El alta suelta la sesión que hubiera y crea una **siempre**, aunque ya hubiera
una viva. Razonando sobre los caminos, reutilizarla sería seguro —a la pantalla
de acceso solo se llega con sesión en el primer arranque, cuyo perfil aún no ha
reclamado apodo—, pero esa seguridad depende de que nadie añada mañana un cuarto
camino hasta esa pantalla. Creando sesión nueva, el perfil que `updateNickname`
renombra acaba de nacer y no puede ser el de nadie: la garantía es estructural en
vez de razonada, y es la garantía central de todo el cambio.

Precio: en el primer arranque, el usuario anónimo que creó el splash queda sin
usar. No se limpia: borrarlo exigiría dar permiso de eliminación de usuarios a
algún componente, mucho más privilegio por cero ganancia visible, y un perfil sin
partidas **no aparece en el ranking**, porque `clasificacion_global` parte de
`respuestas_desafio`. Se acepta como deuda.

### D7 — El invitado sigue existiendo, pero abandonarlo exige ponerle contraseña

Obligar a contraseña en el primer arranque es fricción justo donde más cuesta, así
que "Entrar sin cuenta como invitado" se mantiene tal cual: sesión anónima, sin
credenciales.

Pero un perfil sin contraseña solo es alcanzable desde la sesión guardada en este
móvil: soltarla es perderlo. Así que "Cambiar de jugador" desde un perfil sin
contraseña **no** suelta la sesión sin más: pide ponerle una contraseña para poder
volver, y ofrece descartar ese jugador de forma explícita para quien de verdad no
lo quiera. La fricción queda exactamente donde hay algo que perder, y en ningún
otro sitio.

### D8 — El invitado se convierte con `updateUser`, sobre su propia sesión

`updateUser({ email, password })` sobre la sesión anónima activa es el camino
documentado para convertir un usuario anónimo en permanente: **mismo `auth.uid()`,
mismo perfil, mismo progreso**. No hace falta Admin API ni clave secreta, porque
el usuario se modifica a sí mismo con su propio JWT.

**Qué significa "tener credenciales", y por qué no es lo que parece.** Tanto el
trigger de D4 como la consulta de D5 necesitan distinguir a un jugador con
contraseña de un invitado. La condición evidente —`encrypted_password is not
null` en `auth.users`— **es falsa**: GoTrue no deja ese campo a null en las altas
anónimas, así que se cumple para todo el mundo. Aplicada así, el trigger
rechazaba renombrar a un usuario anónimo recién creado y, como el alta es
"sesión anónima → apodo → contraseña" (D6), **ningún jugador podía registrarse**;
y la consulta respondía "con contraseña" para cualquier invitado.

El criterio correcto es tener una contraseña **no vacía**
(`coalesce(encrypted_password, '') <> ''`). Se descubrió probando contra el
proyecto remoto: no lo detectaron ni la batería de tests —que usa falsos, no
GoTrue— ni dos revisiones del código, porque la condición es plausible leyéndola.
Es el argumento a favor de que la validación de este cambio incluya
obligatoriamente una pasada contra el remoto, no solo tests y revisión.

### D9 — Contraseña de 6 caracteres, sin requisitos de complejidad

Se deja el mínimo que ya declara el proyecto y `password_requirements` vacío. Es
un juego de geografía que se pasa de mano en mano; una regla de símbolos y
mayúsculas en un móvil compartido produce contraseñas apuntadas en un papel, no
cuentas más seguras. La defensa real contra fuerza bruta es el límite de la
plataforma por IP, que no depende de la longitud.

### D10 — Un apodo ocupado por un perfil sin contraseña se rechaza

Los perfiles que ya existen (invitados de antes de este cambio) tienen apodo y no
tienen contraseña. Si otra persona escribe ese apodo, no puede entrar (no hay
credenciales que comprobar) ni registrarlo (el apodo es único). Se le dice que
está ocupado y que elija otro: es el viejo mensaje "ese apodo ya está en uso",
que sobrevive **solo** para este caso. El dueño legítimo, que sigue con su sesión
en su móvil, lo resuelve poniéndole contraseña (D8).

### D11 — No hay recuperación de contraseña, y se dice en pantalla

Sin email no hay canal para recuperarla. Lo que amortigua el golpe: la sesión
sigue persistida en el dispositivo, así que olvidarla no echa a nadie de su propio
móvil, solo impide entrar desde otro. La pantalla lo dice en una línea, en vez de
dejar al jugador descubrirlo el día que cambia de teléfono.

Descartado meter aquí un código de recuperación: es un mecanismo con su propia UX
(mostrarlo una vez, que el jugador lo guarde, validarlo) y merece su propio
cambio.

### D12 — Dónde vive la lógica en el cliente

- `AuthGateway` crece con `signOut()`, `signInWithPassword(...)`, `updateUser(...)`
  y `currentUser`. `signUp` no aparece: el alta va por sesión anónima (D6).
- `AnonymousSessionService.ensureSession()` **no se toca**.
- Nuevo `EstadoApodoGateway`: la RPC de D5, traducida a un enum sellado.
- Nuevo `PlayerSessionService`: la única pieza que decide crear / entrar /
  convertir / descartar, y la que se prueba a fondo con falsos.
- Nuevo `PlayerRosterStorage`: apodos del dispositivo.
- `username_screen` habla con `PlayerSessionService` en vez de con
  `ProfileGateway`.
- La identidad sintética de D2 vive en una única función pura
  (`identidad_de_apodo.dart`) con sus propios tests: es el punto donde un cambio
  descuidado deja a todo el mundo fuera de su cuenta.

### D13 — Un solo botón resuelve crear o entrar

La pantalla pide apodo y contraseña juntos y decide al pulsar: consulta el estado
del apodo (D5) y, según sea, registra o inicia sesión. Se descarta el patrón de
dos pasos (apodo → siguiente → contraseña) de Google o Slack: son más pantallas y
más estado para un formulario de dos campos, y el actual cabe en la tarjeta que ya
existe en `entry_widgets.dart`. El mock de Login (INT-108) no está versionado en
el repo, así que la referencia visual son esos componentes.

## Risks / Trade-offs

- **[Contraseña olvidada = perfil perdido desde otro móvil]** → Es el precio de no
  montar email. Amortiguado por la sesión persistida y declarado en pantalla
  (D11). Se cierra el día que exista código de recuperación o vinculación real.
- **[Desactivar la confirmación de email en el proyecto]** → Sin efecto hoy (no
  hay emails reales); a revisar si algún día se admiten (D3).
- **[`supabase config push` empuja toda la sección `[auth]`]** → Se revisa el
  diff antes y se alinea `config.toml` con lo que se quiere en remoto; el
  `site_url` a `127.0.0.1` es lo primero a comprobar.
- **[El apodo pasa a ser inmutable para quien tenga contraseña]** → Impuesto en la
  base (D4). Si más adelante se quiere permitir el cambio, hará falta actualizar
  la identidad de Auth en la misma operación, y eso sí necesita Admin API.
- **[Identidades opacas en el panel de Auth]** → Documentado en la migración y en
  la función pura de D2.
- **[Dos dispositivos en el mismo perfil sobrescribiéndose el progreso]** → Ahora
  es posible de verdad (antes hacía falta compartir la sesión). No se aborda: es
  inherente a "una cuenta, varios sitios" y el juego no tiene escritura
  concurrente conflictiva más allá de la última partida.
- **[Un jugador escribe su apodo con otras mayúsculas]** → Entra igual: el hash es
  sobre minúsculas (D2).

## Migration Plan

1. Alinear `config.toml` con lo que se quiere en el remoto y `supabase config
   push` (D3). Comprobar con `/auth/v1/settings` que `mailer_autoconfirm` pasa a
   `true` — es la verificación real, no el listado del CLI.
2. Migración con la RPC `estado_apodo` y el trigger de D4.
3. Cambios de app.

No hay migración de datos: los perfiles existentes siguen funcionando como
invitados sin contraseña y se convierten cuando su dueño quiera (D8, D10).

Marcha atrás: revertir la app deja el sistema como está hoy. La RPC y el trigger
quedan inertes (nadie los invoca; el trigger solo actúa sobre un renombrado, que
no ocurre en ningún camino). Los perfiles que ya se hubieran puesto contraseña
siguen funcionando: su sesión persistida los mantiene dentro, exactamente como un
invitado. Lo único que **no** vuelve atrás solo es el ajuste de confirmación de
email, que se revierte con otro `config push`.

## Open Questions

- Ninguna que bloquee la implementación.
