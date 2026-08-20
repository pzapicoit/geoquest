## ADDED Requirements

### Requirement: Extensión del margen de tiempo por el comodín "tiempo"

La cuenta atrás del desafío SHALL exponer una operación para extender su margen restante en una duración dada sin reiniciar el desafío ni afectar al cálculo de puntaje del servidor.

#### Scenario: Se extiende la cuenta atrás en curso

- **WHEN** se pide extender la cuenta atrás 15 segundos mientras está corriendo
- **THEN** el tiempo restante y el total aumentan en esa duración
- **AND** el instante de auto-envío se retrasa la misma duración
- **AND** el desafío no se reinicia (no se pierde el progreso de la barra ni el estado de zona crítica se recalcula desde cero)

#### Scenario: La extensión no altera el cálculo de puntaje

- **WHEN** un jugador extiende su cuenta atrás y responde después
- **THEN** el bonus de puntuación por rapidez del servidor se calcula igual que si no se hubiera extendido: sobre el tiempo real transcurrido desde que el desafío se marcó como mostrado
