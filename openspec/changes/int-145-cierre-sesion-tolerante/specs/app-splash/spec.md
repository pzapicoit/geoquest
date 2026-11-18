## MODIFIED Requirements

### Requirement: Reintento cuando falla la resolución de la sesión
Si crear o recuperar la sesión falla (por ejemplo, sin conectividad), el splash SHALL mostrar un estado de error con un motivo legible para el jugador y una acción para reintentar, en vez de navegar a otra pantalla.

El motivo SHALL elegirse según la causa del fallo y SHALL NOT incluir el texto de la excepción, URLs ni códigos internos:

- si la petición no llegó a obtener respuesta del servidor (sin red, tiempo agotado o servidor caído sin responder), el motivo SHALL indicar que no se pudo conectar con el servidor y que se compruebe la conexión o se reintente en unos minutos;
- si el servidor respondió con un error 5xx, el motivo SHALL indicar que el servidor no está respondiendo ahora mismo y que se reintente en unos minutos;
- en cualquier otro caso, el motivo SHALL ser un mensaje genérico de que no se pudo preparar la partida.

El detalle técnico del error SHALL conservarse para depuración, sin mostrarse en pantalla.

#### Scenario: Falla la creación de la sesión anónima
- **WHEN** la llamada a Supabase Auth para crear o recuperar la sesión falla
- **THEN** el splash muestra un motivo legible y un botón "Reintentar" que vuelve a intentar la resolución de la sesión

#### Scenario: Sin respuesta del servidor
- **WHEN** la creación de la sesión falla porque la petición no obtuvo respuesta (por ejemplo, `Failed to fetch` en web o un socket cerrado en móvil)
- **THEN** el splash dice que no se pudo conectar con el servidor
- **AND** no muestra el texto de la excepción ni la URL

#### Scenario: El servidor responde con un error 5xx
- **WHEN** la creación de la sesión falla con un error de Auth cuyo código HTTP es 500 o mayor
- **THEN** el splash dice que el servidor no está respondiendo ahora mismo
