## MODIFIED Requirements

### Requirement: Backend único compartido

La app de jugador y el panel de administración SHALL usar el mismo proyecto
Supabase, sin ningún servicio backend intermedio para leer o escribir datos del
juego: ambos siguen hablando con Postgres vía REST y RPC.

El único código server-side propio admitido SHALL ser Edge Functions del mismo
proyecto Supabase, y solo para lo que un cliente no puede hacer sin exponer un
secreto —custodiar credenciales de terceros y llamar a su API en nombre del
panel—. Estas funciones MUST NOT convertirse en capa de acceso a datos del juego
ni sustituir a RLS como frontera de seguridad.

#### Scenario: Se documenta la arquitectura

- **WHEN** se consulta `.devplugin/architecture.md`
- **THEN** consta que ambos clientes atacan el mismo proyecto vía REST y RPC
- **AND** consta que no existe backend custom aparte, más allá de las Edge
  Functions que custodian credenciales de terceros

#### Scenario: Un dato del juego se lee desde el panel

- **WHEN** el panel necesita leer o escribir datos del juego
- **THEN** lo hace directamente contra Postgres con la clave publicable, sujeto a
  RLS, sin pasar por una Edge Function

#### Scenario: Se necesita llamar a una API de terceros con credencial

- **WHEN** una pantalla necesita una API externa que exige una clave secreta
- **THEN** la llamada se hace desde una Edge Function que custodia esa clave, y
  la función comprueba por sí misma que el invocador está autorizado

## ADDED Requirements

### Requirement: Edge Functions versionadas y sus secretos fuera del repo

Las Edge Functions SHALL vivir bajo `backend/supabase/functions/` y desplegarse
con el CLI desde el repositorio. Sus secretos SHALL configurarse aparte, en el
proyecto remoto, y MUST NOT versionarse: el repositorio solo documenta qué
secretos hacen falta y cómo se configuran, nunca sus valores.

#### Scenario: Se documenta el flujo de despliegue

- **WHEN** un desarrollador consulta `backend/README.md`
- **THEN** encuentra cómo desplegar las funciones y cómo configurar sus secretos
  sin pasar por el dashboard

#### Scenario: Un secreto nuevo se documenta sin su valor

- **WHEN** una función necesita una credencial nueva
- **THEN** el repositorio documenta su nombre y para qué sirve
- **AND** el valor solo existe en el proyecto remoto

#### Scenario: Falta un secreto en el entorno

- **WHEN** una función se invoca en un proyecto donde su secreto no está
  configurado
- **THEN** falla con un error identificable, sin exponer detalles del entorno
