## ADDED Requirements

### Requirement: `profiles` tiene RLS mínimo y `role` no es auto-editable

`profiles` SHALL tener Row Level Security habilitado, con una única policy
que permita a un usuario autenticado leer (`select`) su propia fila. Ningún
usuario autenticado ni anónimo SHALL poder insertar, actualizar o borrar
filas de `profiles` por su cuenta — en particular, ningún usuario SHALL
poder cambiar su propio `role`.

Este requisito es un prerrequisito de seguridad de la capability
`challenge-media-storage`: sus policies de escritura comprueban
`profiles.role = 'admin'`, y esa comprobación solo es significativa si
`role` no puede editarse libremente por REST.

#### Scenario: Un usuario lee su propia fila de `profiles`

- **WHEN** un usuario autenticado hace `select` sobre `profiles` filtrando
  por su propio `id`
- **THEN** la operación se permite

#### Scenario: Un usuario intenta cambiar su propio rol

- **WHEN** un usuario autenticado o una sesión anónima intenta `update`
  sobre su propia fila de `profiles`, incluyendo cambiar `role` a `admin`
- **THEN** la base de datos rechaza la operación

#### Scenario: El alta de perfil sigue funcionando

- **WHEN** se crea un nuevo usuario en `auth.users` (alta anónima, INT-75)
- **THEN** el trigger `handle_new_user` sigue creando su fila en `profiles`
  con normalidad, porque corre como `security definer` y no está sujeto a
  estas policies
