## MODIFIED Requirements

### Requirement: Cálculo de puntaje a partir de la distancia
El sistema SHALL traducir una distancia en kilómetros a un puntaje entero
mediante una curva exponencial con suelo, de forma que puntúe a cualquier
distancia: puntaje máximo (`MAX`) en distancia 0, decreciente de forma
exponencial según una escala de kilómetros (`k`), sin llegar nunca a 0 y sin
bajar nunca del suelo mínimo configurado (`PISO`).

#### Scenario: Distancia cero
- **WHEN** la distancia calculada es 0
- **THEN** el puntaje es exactamente el puntaje máximo configurado (`MAX`)

#### Scenario: Distancia en las antípodas
- **WHEN** la distancia calculada es la máxima posible entre dos puntos del
  globo (~20.015 km)
- **THEN** el puntaje es exactamente el suelo mínimo configurado (`PISO`)

#### Scenario: Distancia intermedia
- **WHEN** la distancia calculada está entre 0 y la distancia máxima posible
  entre dos puntos del globo
- **THEN** el puntaje decrece de forma exponencial según la distancia y
  queda estrictamente entre `PISO` y `MAX`

#### Scenario: A mayor distancia, nunca más puntaje
- **WHEN** se comparan dos distancias donde la primera es menor que la
  segunda
- **THEN** el puntaje calculado para la primera es mayor o igual que el
  calculado para la segunda

#### Scenario: El puntaje nunca baja del suelo ni sube del máximo
- **WHEN** se calcula el puntaje para cualquier distancia no negativa
- **THEN** el resultado está siempre en el rango cerrado `[PISO, MAX]`
