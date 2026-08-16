## Why

El splash (INT-88) ya deriva al jugador sin nombre guardado a
`UsernamePlaceholderScreen`, un placeholder sin funcionalidad. Sin esta
pantalla real, ningún jugador nuevo puede completar el alta y llegar al
Mapa de temáticas: el flujo queda cortado justo después del splash.

## What Changes

- Pantalla "Nombre de usuario" real que sustituye a
  `UsernamePlaceholderScreen`: campo de texto para el apodo con validación
  de longitud mínima/máxima, botón "Empezar a jugar" que guarda el apodo y
  navega al Mapa de temáticas (hoy `TopicsMapPlaceholderScreen`, sin cambios
  — INT-90 lo sustituirá).
- El apodo se guarda en dos sitios al pulsar "Empezar a jugar": local
  (`UsernameStorage`, ya existe desde INT-88, para que el splash no vuelva a
  pedirlo) y remoto (`profiles.nombre` de la sesión anónima activa).
- Texto de tranquilidad fijo: sin contraseñas, se puede vincular una cuenta
  más adelante sin perder el progreso.
- Hueco visual para el enlace secundario "¿Ya tienes una cuenta? Iniciar
  sesión": visible pero sin `onTap` — se activará cuando se conecte al flujo
  de `linkIdentity` (INT-75, ya implementado en `AccountLinkingService` pero
  sin punto de entrada en la UI todavía).

## Capabilities

### New Capabilities
- `app-username`: pantalla que pide el apodo del jugador tras el splash,
  valida su longitud, lo persiste en local y en `profiles`, y navega al
  Mapa de temáticas.

### Modified Capabilities
(ninguna — la escritura en `profiles.nombre` ya está cubierta por la policy
`profiles_update_own` de player-anonymous-auth; no cambia ningún requisito
existente)

## Impact

- `app/lib/screens/`: nueva `username_screen.dart`, sustituye el uso de
  `UsernamePlaceholderScreen` en `splash_screen.dart`.
- `app/lib/services/`: no se toca `UsernameStorage`; se añade el guardado
  remoto en `profiles` (nuevo servicio o extensión de uno existente).
- Sin cambios de esquema ni migraciones en `backend/`.
