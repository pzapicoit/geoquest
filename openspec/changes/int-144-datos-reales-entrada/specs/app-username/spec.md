## ADDED Requirements

### Requirement: Las insignias de la cabecera muestran solo datos reales
La cabecera de la pantalla de apodo SHALL mostrar, como insignias, únicamente cifras obtenidas del camino real a través de `CaminoGateway`: el número de paradas del camino («N NIVELES») y el número de temáticas distintas entre ellas («N TEMÁTICAS»). No SHALL mostrar cifras escritas en el código ni un récord global de puntos.

Mientras el camino no se ha leído, o si la lectura falla, las insignias SHALL NOT mostrarse, y su espacio SHALL reservarse para que el resto de la pantalla no se desplace al aparecer.

#### Scenario: El camino se lee correctamente
- **WHEN** la pantalla de apodo se muestra y el camino tiene 8 paradas de 6 temáticas distintas
- **THEN** la cabecera muestra «8 NIVELES» y «6 TEMÁTICAS»
- **AND** no muestra ningún récord de puntos

#### Scenario: Una sola parada o una sola temática
- **WHEN** el camino tiene 1 parada
- **THEN** la cabecera muestra «1 NIVEL» y «1 TEMÁTICA», en singular

#### Scenario: Falla la lectura del camino
- **WHEN** la lectura del camino falla
- **THEN** la pantalla de apodo se muestra sin insignias y sigue permitiendo entrar
