## MODIFIED Requirements

### Requirement: Efecto de los comodines de radio

Consumir `km1000` o `km500` SHALL devolver un centro de círculo **desplazado al azar respecto del objetivo** junto con el radio correspondiente (500 km para `km1000`, 150 km para `km500`), para que el cliente dibuje un círculo que acota la zona del objetivo, sin revelar `nombre_lugar` ni la coordenada real.

El desplazamiento SHALL cumplir, medido sobre la misma esfera que usa el cálculo de distancias del servidor:

- el objetivo SHALL quedar **dentro** del círculo: la distancia entre el centro emitido y el objetivo SHALL ser como máximo el 90 % del radio;
- el objetivo SHALL quedar **lejos del centro**: esa distancia SHALL ser como mínimo el 35 % del radio;
- el rumbo del desplazamiento SHALL sortearse uniformemente en todas las direcciones, y la distancia SHALL repartirse de forma uniforme por área dentro de esa corona, de modo que ninguna dirección ni ninguna franja del círculo sea más probable que otra;
- cada consumo SHALL sortear un desplazamiento nuevo, sin depender del desafío ni del jugador;
- la longitud emitida SHALL estar normalizada al rango [-180, 180), también cuando el desplazamiento cruza el antimeridiano, y la latitud SHALL mantenerse dentro de [-90, 90] cuando el objetivo está cerca de un polo.

#### Scenario: Se consume un comodín de radio

- **WHEN** un jugador con al menos 1 unidad de `km1000` o `km500` lo consume en un desafío en curso
- **THEN** recibe un centro de círculo y el radio correspondiente al tipo consumido (500 km para `km1000`, 150 km para `km500`)
- **AND** ese centro no es la coordenada real del objetivo
- **AND** no recibe `nombre_lugar` en esa misma respuesta

#### Scenario: El objetivo cae dentro del círculo pero no en el centro

- **WHEN** se calcula el centro que se emite para un objetivo y un radio dados
- **THEN** la distancia entre ese centro y el objetivo está entre el 35 % y el 90 % del radio del círculo
- **AND** por tanto pinchar el centro del círculo nunca da una distancia cercana a cero

#### Scenario: Dos consumos del mismo tipo sobre el mismo objetivo

- **WHEN** se calculan dos centros para el mismo objetivo y el mismo radio
- **THEN** los centros son distintos entre sí, porque cada cálculo sortea rumbo y distancia de nuevo

#### Scenario: El objetivo está junto al antimeridiano o en latitudes extremas

- **WHEN** el objetivo está a pocos kilómetros del antimeridiano, o cerca de un polo
- **THEN** el centro emitido llega con la longitud normalizada al rango [-180, 180) y la latitud dentro de [-90, 90]
- **AND** la distancia al objetivo sigue cumpliendo el margen del 35 %-90 % del radio
