## 1. Proyecto Supabase — desactivar la confirmación de email

- [x] 1.1 Revisar qué cambiaría `supabase config push` en el remoto además de la confirmación: `site_url` (hoy `127.0.0.1:3000` en el fichero), `additional_redirect_urls`, `jwt_expiry` y los rate limits. Dejar `config.toml` con los valores que se quieren en remoto **antes** de empujar (D3).
- [x] 1.2 `supabase config push` y comprobar con `curl $SUPABASE_URL/auth/v1/settings` que `mailer_autoconfirm` pasa a `true`. Es la verificación válida, no el listado del CLI. Hecho: además de la confirmación cambiaron `max_frequency` (1m→1s) y `otp_length` (8→6), ambos de OTP por email, que este producto no usa.
- [x] 1.3 Documentar en `backend/README.md` que la confirmación de email debe quedar desactivada y por qué (la identidad interna es sintética y no puede recibir correo), para que un clon no lo descubra por un login que falla.

## 2. Backend — estado del apodo y bloqueo de renombrado

- [x] 2.1 Migración con `estado_apodo(p_alias text) returns text` (`security definer`, `stable`, `set search_path = public`): devuelve `libre` / `con_contrasena` / `sin_contrasena` comparando el apodo sin distinguir mayúsculas ni espacios sobrantes, y decide "tiene contraseña" por `coalesce(auth.users.encrypted_password, '') <> ''` — **no** por `is not null`, que GoTrue deja lleno también en las altas anónimas y haría pasar por jugador con contraseña a cualquier invitado. Devuelve **solo** el estado (D5).
- [x] 2.2 `revoke execute` a `public` y `grant execute` a `anon, authenticated`: la pantalla de acceso la consulta antes de tener sesión de ese jugador.
- [x] 2.3 Trigger `before update on profiles` que rechace cambiar `nombre` cuando el usuario tenga credenciales, con mensaje explícito de por qué (D4). Comentario en la migración: no hay hoy ningún camino que renombre, existe para el día que se añada uno.
- [x] 2.4 Comentario en la migración explicando el formato de identidad sintética (hash del apodo en minúsculas + `@geoquest.invalid`), para que quien vea el panel de Auth entienda las cadenas hexadecimales (D2).
- [x] 2.5 Deduplicar los alias de jugador que solo difieren en mayúsculas o espacios y sustituir el índice único exacto de INT-111 por uno sobre `lower(btrim(nombre))`: con identidades derivadas del apodo en minúsculas, dos alias así derivan la misma credencial y el segundo jugador perdería su perfil sin recuperación. Ajustar `handle_new_user` al mismo criterio para que su candidato por defecto no reviente el alta. El sufijo del dedupe se busca libre fila a fila, porque uno calculado a ciegas puede chocar con un `" (2)"` que dejara la deduplicación de INT-111 y tumbar la creación del índice.
- [x] 2.6 `supabase db lint --linked` sin hallazgos nuevos.

## 3. App — identidad y servicios

- [x] 3.1 `identidad_de_apodo.dart`: función pura `identidadDeApodo(String apodo)` → `sha256(apodo.trim().toLowerCase())` hex + `@geoquest.invalid`, declarando `crypto` como dependencia directa en `pubspec.yaml` (hoy solo entra como transitiva, así que usarla sin declararla es un aviso de `flutter analyze` esperando a pasar). Comentario dejando claro que cambiar esta función deja fuera de su cuenta a todo el mundo que ya tenga contraseña.
- [x] 3.2 Tests de `identidadDeApodo`: determinismo, insensibilidad a mayúsculas y a espacios, apodos con acentos y con emoji, y dos apodos distintos dando identidades distintas.
- [x] 3.3 `AuthGateway`: añadir `signOut()`, `signInWithPassword(...)`, `updateUser(...)` y `currentUser`, implementarlos en `SupabaseAuthGateway` y actualizar el falso de `app/test/fakes/`. Sin `signUp`: el alta va por sesión anónima (D6).
- [x] 3.4 `EstadoApodoGateway` + implementación Supabase sobre la RPC, traduciendo a un enum sellado y tratando un valor inesperado como fallo, no como "libre".
- [x] 3.5 Tests de `EstadoApodoGateway`: los tres estados, valor desconocido y error de red.
- [x] 3.6 `PlayerRosterStorage` sobre `SharedPreferences`: `read`, `registrar` (sin duplicados, más reciente primero, tope aplicado), `olvidar`.
- [x] 3.7 Tests de `PlayerRosterStorage`: lista vacía, orden por recencia, sin duplicados al reentrar, descarte del menos reciente al superar el tope, `olvidar`.
- [x] 3.8 `PlayerSessionService.entrar(apodo, contrasena)`: consulta el estado y resuelve — `libre` → sesión anónima (reutilizada si ya la hay) + `updateNickname` + `updateUser` con identidad y contraseña (D6); `con_contrasena` → `signInWithPassword`; `sin_contrasena` → resultado de apodo ocupado. Resultado sellado por caso, sin excepciones cruzando la frontera.
- [x] 3.9 `PlayerSessionService.entrarComoInvitado(aliasSugerido)`: nunca entra en un perfil existente; si el alias sugerido está ocupado, prueba otro hasta dar con uno libre (spec `app-username`).
- [x] 3.10 `PlayerSessionService.ponerContrasena(contrasena)`: `updateUser` con la identidad derivada del apodo actual y la contraseña, sobre la sesión activa; conserva el perfil (D8).
- [x] 3.11 `PlayerSessionService.cambiarDeJugador()`: exige que el jugador activo tenga credenciales; si no, devuelve el caso "necesita contraseña" sin soltar la sesión (D7). Un `descartarJugador()` aparte hace el `signOut` explícito.
- [x] 3.12 Tests de `PlayerSessionService` con falsos, cubriendo cada rama: apodo libre crea perfil, apodo con contraseña correcta entra, contraseña incorrecta no cambia de sesión, apodo sin contraseña se rechaza, invitado con alias ocupado acaba en perfil nuevo, conversión conserva el usuario, cambio de jugador sin contraseña no suelta la sesión, y el roster solo se toca cuando la entrada culmina.
- [x] 3.13 Comprobar explícitamente en un test que `updateNickname` **no** se llama en la rama de acceso con contraseña: es la garantía central de que no se renombra el perfil ajeno.

## 4. App — pantallas

- [x] 4.1 `username_screen`: campo de contraseña (con mostrar/ocultar) reutilizando el estilo de `_NicknameField`, validación del mínimo, y un solo botón que resuelve crear o entrar (D13).
- [x] 4.2 `username_screen`: mensajes distinguibles para contraseña incorrecta, apodo ocupado sin contraseña y fallo de conexión, conservando lo escrito al fallar.
- [x] 4.3 `username_screen`: sustituir el texto "Sin contraseñas por ahora. Más adelante podrás vincular una cuenta" por la explicación de para qué sirve la contraseña, más la advertencia de que no se puede recuperar. Sin enlace de "he olvidado mi contraseña".
- [x] 4.4 `username_screen`: sección de apodos recientes que rellena el apodo y pasa el foco a la contraseña, oculta por completo con roster vacío, con acción de olvidar por apodo.
- [x] 4.5 `login_screen._onSwitchPlayer`: `signOut` real cuando el jugador tiene contraseña; petición de contraseña con salida explícita de "descartar este jugador" cuando no la tiene; y recarga del progreso del jugador que entra en vez de reutilizar el `Future` del anterior.
- [x] 4.6 `login_screen`: el enlace "Vincular una cuenta para no perder el progreso" pasa a ofrecer ponerse contraseña cuando el jugador no la tiene, y se queda decorativo cuando ya la tiene.
- [x] 4.7 Tests de widget de `username_screen`: apodo libre navega, contraseña incorrecta muestra su mensaje, apodo ocupado sin contraseña muestra el suyo, contraseña corta deshabilita el botón, roster vacío no dibuja la sección, y pulsar un apodo del roster rellena sin navegar.
- [x] 4.8 Tests de widget de `login_screen`: cambio de jugador con contraseña lleva al acceso, sin contraseña pide ponerla y no suelta la sesión, descartar sí la suelta, y el progreso mostrado tras el cambio es del jugador que entra.

## 5. Verificación

- [x] 5.1 `flutter test` en verde, incluidos los tests existentes de `username_screen`, `login_screen`, `profile_gateway` y `anonymous_session_service` que cambian de expectativa.
- [x] 5.2 `flutter test --coverage`: 92,94% frente al 93,10% de `main`. La diferencia son los envoltorios de Supabase (`auth_gateway`, `profile_gateway`), que en `main` no aparecían en el informe porque ningún test los cargaba y ahora sí. `PlayerSessionService` queda al 100%.
- [x] 5.3 `flutter analyze` y `dart format --set-exit-if-changed` limpios.
- [x] 5.4 Prueba local end-to-end contra el remoto: crear jugador A con contraseña y puntos; cambiar a jugador B nuevo; volver a A con su contraseña y comprobar puntuación, camino y comodines; comprobar que A sigue en la clasificación; comprobar que una contraseña mal escrita no entra; comprobar que el apodo de un invitado antiguo sale como ocupado.
- [x] 5.5 Prueba de la conversión (verificada contra el remoto a nivel de API — alta anónima, apodo, `updateUser` con identidad y contraseña, y acceso posterior con ella devolviendo el mismo perfil; el diálogo de la pantalla lo cubren los tests de widget): entrar como invitado, acumular algún punto, ponerse contraseña, y comprobar que el perfil es el mismo (mismo apodo, mismos puntos) y que se puede entrar con esa contraseña tras un cambio de jugador.
- [x] 5.6 Comprobar a mano que el trigger de D4 rechaza un `update` de `profiles.nombre` sobre un jugador con contraseña, y lo permite sobre uno sin ella.
