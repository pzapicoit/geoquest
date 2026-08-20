## REMOVED Requirements

### Requirement: Extensión del margen de tiempo por el comodín "tiempo"

**Reason**: El comodín `tiempo` deja de dar 15s extra; ahora detiene el cronómetro por completo (ver requirement "Detención completa del cronómetro por el comodín tiempo" en este mismo delta).
**Migration**: `CuentaAtrasDeDesafio.extender()` se retira (sin llamadores); el consumo de `tiempo` pasa a usar `CuentaAtrasDeDesafio.parar()`, ya existente.

La cuenta atrás del desafío SHALL exponer una operación para extender su margen restante en una duración dada sin reiniciar el desafío ni afectar al cálculo de puntaje del servidor.

#### Scenario: Se extiende la cuenta atrás en curso

- **WHEN** se pide extender la cuenta atrás 15 segundos mientras está corriendo
- **THEN** el tiempo restante y el total aumentan en esa duración
- **AND** el instante de auto-envío se retrasa la misma duración
- **AND** el desafío no se reinicia (no se pierde el progreso de la barra ni el estado de zona crítica se recalcula desde cero)

#### Scenario: La extensión no altera el cálculo de puntaje

- **WHEN** un jugador extiende su cuenta atrás y responde después
- **THEN** el bonus de puntuación por rapidez del servidor se calcula igual que si no se hubiera extendido: sobre el tiempo real transcurrido desde que el desafío se marcó como mostrado

## ADDED Requirements

### Requirement: Detención completa del cronómetro por el comodín "tiempo"

La cuenta atrás del desafío SHALL exponer una operación para detenerse por completo sin disparar el aviso de agotado, de forma que el desafío en curso quede sin límite de tiempo ni auto-envío, sin afectar al cálculo de puntaje del servidor.

#### Scenario: Se detiene la cuenta atrás en curso

- **WHEN** se pide detener la cuenta atrás mientras está corriendo
- **THEN** el tiempo restante deja de disminuir y no se dispara el auto-envío para ese desafío
- **AND** el desafío no se reinicia (no se pierde el progreso mostrado)

#### Scenario: La detención no altera el cálculo de puntaje

- **WHEN** un jugador detiene su cuenta atrás con este comodín y responde después
- **THEN** el bonus de puntuación por rapidez del servidor se calcula igual que siempre: sobre el tiempo real transcurrido desde que el desafío se marcó como mostrado
