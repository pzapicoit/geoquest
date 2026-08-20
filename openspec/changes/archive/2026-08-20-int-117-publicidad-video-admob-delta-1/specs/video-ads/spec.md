## ADDED Requirements

### Requirement: Formato Rewarded (`RewardedAd`) para obtención bajo demanda

Para cualquier flujo de anuncio iniciado explícitamente por el jugador (p. ej. tocar "Ver un anuncio" para obtener un comodín, `comodines`), la app SHALL usar el formato `RewardedAd` de AdMob, distinto de `RewardedInterstitialAd` (reservado a los anuncios de gating automático de desbloqueo/cadencia de esta misma capability). El comodín u otra recompensa asociada SHALL concederse únicamente si el callback de recompensa del anuncio (`onUserEarnedReward`) llega a dispararse.

#### Scenario: Se carga un anuncio para un flujo bajo demanda

- **WHEN** la app necesita cargar un anuncio porque el jugador tocó una opción de "ver anuncio para obtener algo"
- **THEN** usa la API de `RewardedAd` del SDK de AdMob, no `RewardedInterstitialAd`

#### Scenario: El anuncio no llega a completarse

- **WHEN** un `RewardedAd` bajo demanda no carga, falla al cargar, o se cierra antes de que se dispare `onUserEarnedReward`
- **THEN** la app no concede ninguna recompensa y lo comunica como un fallo, sin fail-open (a diferencia del gating automático, aquí no hay nada que "dejar pasar")
