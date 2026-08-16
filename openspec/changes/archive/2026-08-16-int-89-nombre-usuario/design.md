## Context

El splash (INT-88) ya resuelve la sesión anónima y navega a
`UsernamePlaceholderScreen` cuando `UsernameStorage.read()` devuelve `null`.
Esta pieza sustituye ese placeholder por la pantalla real, siguiendo el
diseño de Claude Design (`[App] - Nombre de usuario.dc.html`, proyecto
`d83d4c61-3a9e-4fff-b1c4-d2a19fd03ef5`).

El diseño es una tarjeta sobre cabecera de marca: logo, `h1` "¿Cómo te
llamamos?", campo de texto con botón de dado (sugerir apodo aleatorio),
contador `n/16`, texto de tranquilidad, chips de sugerencias, CTA
"Empezar a jugar" (deshabilitado si el campo está vacío) y enlace
secundario "¿Ya tienes una cuenta? Iniciar sesión".

`profiles.nombre` (creada por el trigger de alta anónima, INT-75) ya acepta
`update` de la propia fila vía la policy `profiles_update_own` — no hace
falta tocar el esquema.

## Goals / Non-Goals

**Goals:**
- Pantalla de apodo funcional: input validado, CTA que persiste el apodo
  en local (`UsernameStorage`, sin cambios) y en `profiles.nombre`, y
  navega a `TopicsMapPlaceholderScreen` (INT-90 la sustituirá).
- Reproducir la estructura visual del diseño (cabecera de marca, tarjeta,
  contador, texto de tranquilidad) con los componentes de Material que ya
  usa el resto de la app (mismo enfoque que `SplashScreen`: widgets propios,
  sin librería de UI adicional).
- Botón de dado que sugiere un apodo aleatorio de una lista fija embebida
  (igual que el prototipo `POOL` del diseño), sin llamada a red.
- Enlace secundario visible pero inerte (sin `onTap`), preparado para
  INT-75/`AccountLinkingService` cuando se decida activarlo.

**Non-Goals:**
- Wiring del enlace "Iniciar sesión" a `AccountLinkingService.link()` — el
  propio issue lo pide como hueco visual, no como flujo funcional.
- Mapa de temáticas real — sigue siendo `TopicsMapPlaceholderScreen`
  (INT-90).
- Chips de sugerencias dinámicas o personalizadas por servidor — se usa la
  misma lista fija que el prototipo de diseño.
- Comprobar unicidad del apodo — no está en los criterios de aceptación ni
  en el modelo de datos (`profiles.nombre` no tiene `unique`).

## Decisions

**Validación de longitud: mínimo 3, máximo 16 caracteres, tras `trim()`.**
El diseño solo deshabilita el CTA cuando el campo está vacío
(`n.trim().length === 0`), pero el issue pide explícitamente mínimo y
máximo. 16 ya está en el diseño (`maxlength="16"` del input y el contador
`{{counter}}`); 3 es el mínimo razonable más bajo que sigue evitando apodos
de una letra, sin criterio de negocio adicional que lo acote más. El CTA
queda deshabilitado hasta que la longitud (tras `trim`) esté en `[3, 16]`;
por debajo de 3 se muestra un texto de ayuda con el mínimo, igual que el
contador ya muestra el máximo.

**Persistencia remota vía un `ProfileGateway` nuevo, análogo a
`AuthGateway`.** Se añade `lib/services/profile_gateway.dart` con la
superficie mínima (`updateNickname(String nombre)`) sobre
`Supabase.instance.client.from('profiles')`, y su fake en
`test/fakes/fake_profile_gateway.dart`. Mismo patrón que
`AuthGateway`/`FakeAuthGateway` (INT-75): permite probar la pantalla sin
red, siguiendo la convención ya establecida en el proyecto en vez de
introducir una capa de repositorio distinta.

**Guardado local primero, luego remoto.** Al pulsar "Empezar a jugar":
1. `UsernameStorage.save(nombre)` (local, no puede fallar por red).
2. `ProfileGateway.updateNickname(nombre)` (remoto).
3. Si (2) falla, se muestra un error inline y no se navega — el apodo ya
   quedó guardado localmente, así que un reintento no repite el paso (1).
   Esto evita dejar al jugador en una pantalla sin salida por un fallo de
   red transitorio, consistente con el patrón de reintento del splash.

**Botón de dado con lista fija embebida en el widget**, sin nuevo
servicio. Es una utilidad puramente decorativa (igual que en el
prototipo); no justifica una abstracción ni tests de unidad más allá de
"al pulsar, el campo cambia a un valor no vacío de la lista".

## Risks / Trade-offs

- [El mínimo de 3 caracteres es una decisión de producto no confirmada por
  el issue] → Documentado aquí como decisión explícita; fácil de ajustar en
  una sola constante si el usuario pide otro valor tras probarlo.
- [Guardar local antes que remoto puede dejar `UsernameStorage` con un
  apodo que nunca llegó a `profiles` si el jugador cierra la app tras un
  fallo remoto] → Aceptable: el splash solo mira `UsernameStorage` para
  decidir si vuelve a pedir el apodo, así que la próxima vez que haya red
  se puede reintentar el guardado remoto sin repetir la pantalla. No se
  añade cola de reintento porque no hay más de un punto de escritura.
