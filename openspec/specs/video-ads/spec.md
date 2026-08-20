# video-ads Specification

## Purpose
TBD - created by archiving change int-117-publicidad-video-admob. Update Purpose after archive.

## Requirements

### Requirement: Anuncio de desbloqueo en la primera vez de una parada nueva

Desde la parada de `orden > 1` en adelante (la parada de `orden = 1` SHALL quedar siempre libre de anuncios), el sistema SHALL considerar que toca un anuncio de desbloqueo cuando el jugador no tiene todavía ningún `intento_nivel` registrado para esa parada (`camino_id`). Esta condición SHALL derivarse comprobando la ausencia de intentos previos, sin ningún flag adicional persistido.

#### Scenario: Primera vez del jugador en una parada de orden > 1

- **WHEN** un jugador sin ningún intento previo en una parada de `orden > 1` consulta si toca anuncio antes de jugarla
- **THEN** el sistema indica que toca anuncio de desbloqueo

#### Scenario: El jugador ya jugó esa parada antes

- **WHEN** un jugador que ya tiene al menos un intento registrado en una parada consulta si toca anuncio antes de volver a jugarla
- **THEN** el sistema no indica anuncio de desbloqueo para esa parada, sin importar cuántos intentos previos tenga

#### Scenario: La parada de orden 1 nunca pide anuncio de desbloqueo

- **WHEN** un jugador sin ningún intento previo consulta si toca anuncio antes de jugar la parada de `orden = 1`
- **THEN** el sistema no indica anuncio de desbloqueo para esa parada

### Requirement: Anuncio de cadencia cada 3 intentos jugados, contador de por vida

El sistema SHALL mantener un contador persistente por jugador (de por vida, sin reseteo por sesión ni por día) de intentos jugados desde el último anuncio de cadencia mostrado, y SHALL considerar que toca anuncio de cadencia cuando ese contador alcanzaría 3 con el intento que el jugador está a punto de arrancar, en cualquier parada.

#### Scenario: Se alcanza el tercer intento desde el último anuncio de cadencia

- **WHEN** un jugador cuyo contador de intentos desde el último anuncio de cadencia está en 2 va a arrancar un nuevo intento en cualquier parada
- **THEN** el sistema indica que toca anuncio de cadencia

#### Scenario: Todavía no toca cadencia

- **WHEN** un jugador cuyo contador de intentos desde el último anuncio de cadencia está en 0 o 1 va a arrancar un nuevo intento
- **THEN** el sistema no indica anuncio de cadencia

#### Scenario: El contador nunca se resetea por sesión ni por día

- **WHEN** un jugador cierra la app o cambia de dispositivo con su contador de cadencia en un valor intermedio
- **THEN** al volver a jugar, el contador continúa desde ese mismo valor, sin reiniciarse por el paso del tiempo ni por reinstalar la app

### Requirement: Sin solape — un único vídeo, ciclo de cadencia no consumido

Cuando el intento que arranca el jugador cumple a la vez la condición de anuncio de desbloqueo y la de anuncio de cadencia, el sistema SHALL mostrar un único vídeo, con prioridad para el de desbloqueo, y el contador de cadencia SHALL quedar exactamente igual que antes de ese intento (ni se resetea ni se incrementa).

#### Scenario: Coincide desbloqueo y cadencia en el mismo intento

- **WHEN** un jugador arranca, en una parada de `orden > 1` que nunca jugó antes, el intento que además le corresponde por cadencia
- **THEN** el sistema indica un único anuncio, de tipo desbloqueo
- **AND** tras arrancar ese intento, el contador de cadencia del jugador queda con el mismo valor que tenía justo antes de arrancarlo

#### Scenario: El ciclo de cadencia pospuesto se recupera en el siguiente intento

- **WHEN** un jugador cuyo intento anterior coincidió en desbloqueo y cadencia (contador sin resetear) arranca cualquier otro intento a continuación
- **THEN** el sistema indica de nuevo que toca anuncio de cadencia para este nuevo intento

### Requirement: El contador de cadencia se actualiza atómicamente al arrancar el intento

El sistema SHALL actualizar el contador de cadencia del jugador dentro de la misma operación que crea el intento de parada, recalculando las condiciones de desbloqueo y cadencia en ese momento en vez de confiar en un aviso previo del cliente: SHALL resetear el contador a 0 si toca cadencia sin solape, SHALL dejarlo intacto si hay desbloqueo (con o sin solape de cadencia), y SHALL incrementarlo en 1 en cualquier otro caso.

#### Scenario: Intento sin desbloqueo ni cadencia

- **WHEN** un jugador arranca un intento que no es la primera vez en esa parada y no le toca cadencia
- **THEN** el contador de cadencia del jugador se incrementa en 1 al arrancar ese intento

#### Scenario: Intento de cadencia sin solape

- **WHEN** un jugador arranca un intento en una parada ya jugada antes, y le toca anuncio de cadencia
- **THEN** el contador de cadencia del jugador se resetea a 0 al arrancar ese intento

#### Scenario: La mutación no depende de si la app pudo mostrar el vídeo

- **WHEN** un jugador arranca un intento para el que tocaba anuncio (de cualquier tipo), independientemente de si el anuncio cargó o no en la app
- **THEN** el contador de cadencia se actualiza igual, porque el sistema no distingue "se mostró" de "falló la carga"

### Requirement: Integración fail-open del SDK de anuncios en la app

La app SHALL intentar cargar y mostrar un `RewardedInterstitialAd` antes de arrancar un intento cuando el sistema indique que toca anuncio (de cualquier tipo), con un timeout corto. Si el anuncio no carga a tiempo, o falla la carga, o no hay conexión, la app SHALL dejar continuar al jugador y arrancar el intento con normalidad, sin bloquear ni reintentar.

#### Scenario: El anuncio carga y se muestra

- **WHEN** toca anuncio antes de un intento y el `RewardedInterstitialAd` carga dentro del timeout
- **THEN** la app lo muestra, con su salida/skip nativo, y arranca el intento al cerrarse

#### Scenario: El anuncio no carga a tiempo

- **WHEN** toca anuncio antes de un intento y el `RewardedInterstitialAd` no ha cargado al agotarse el timeout, o falla su carga, o no hay conexión
- **THEN** la app arranca el intento con normalidad, sin mostrar ningún anuncio ni bloquear al jugador

#### Scenario: No toca ningún anuncio

- **WHEN** el sistema indica que no toca ningún anuncio para el intento que el jugador va a arrancar
- **THEN** la app arranca el intento directamente, sin intentar cargar ningún anuncio

### Requirement: Formato Rewarded Interstitial, no Interstitial estándar

La app SHALL usar exclusivamente el formato `RewardedInterstitialAd` de AdMob para los anuncios de desbloqueo y de cadencia, nunca un `InterstitialAd` estándar, en cumplimiento de la política de AdMob que reserva el condicionamiento de acceso a contenido al formato Rewarded.

#### Scenario: Se carga un anuncio para gating de intento

- **WHEN** la app necesita cargar un anuncio antes de arrancar un intento
- **THEN** usa la API de `RewardedInterstitialAd` del SDK de AdMob, no `InterstitialAd`

### Requirement: Formato Rewarded (`RewardedAd`) para obtención bajo demanda

Para cualquier flujo de anuncio iniciado explícitamente por el jugador (p. ej. tocar "Ver un anuncio" para obtener un comodín, `comodines`), la app SHALL usar el formato `RewardedAd` de AdMob, distinto de `RewardedInterstitialAd` (reservado a los anuncios de gating automático de desbloqueo/cadencia de esta misma capability). El comodín u otra recompensa asociada SHALL concederse únicamente si el callback de recompensa del anuncio (`onUserEarnedReward`) llega a dispararse.

#### Scenario: Se carga un anuncio para un flujo bajo demanda

- **WHEN** la app necesita cargar un anuncio porque el jugador tocó una opción de "ver anuncio para obtener algo"
- **THEN** usa la API de `RewardedAd` del SDK de AdMob, no `RewardedInterstitialAd`

#### Scenario: El anuncio no llega a completarse

- **WHEN** un `RewardedAd` bajo demanda no carga, falla al cargar, o se cierra antes de que se dispare `onUserEarnedReward`
- **THEN** la app no concede ninguna recompensa y lo comunica como un fallo, sin fail-open (a diferencia del gating automático, aquí no hay nada que "dejar pasar")

### Requirement: Configuración de IDs de AdMob sin depender de cuenta real

El sistema SHALL permitir compilar, ejecutar y probar la integración de anuncios sin que exista todavía una cuenta de AdMob real, usando los IDs de test oficiales de Google como valor por defecto de la plantilla de configuración, con los mismos IDs de test sustituibles por IDs reales sin cambiar código cuando la cuenta exista.

#### Scenario: Build de desarrollo sin cuenta AdMob

- **WHEN** se compila o se corren los tests de la app sin haber configurado credenciales propias de AdMob
- **THEN** el build usa los IDs de test oficiales de Google para `RewardedInterstitialAd`, sin error de configuración

#### Scenario: Se sustituyen los IDs de test por IDs reales

- **WHEN** existe una cuenta de AdMob real con su propio App ID y unidad de anuncio Rewarded Interstitial
- **THEN** sustituir esos valores en la configuración local basta para pasar a producción, sin tocar el código de la app
