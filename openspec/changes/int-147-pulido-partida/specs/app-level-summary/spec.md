## ADDED Requirements

### Requirement: El ánimo del resumen no superado depende de lo cerca que se quedó
En el resumen no superado, el título y la frase de ánimo SHALL elegirse según el porcentaje del `puntaje_minimo_superar` alcanzado, siempre en tono positivo:

- desde el 80 %: «¡Casi lo tienes!» y «¡Estás cerca!»;
- desde el 50 % y por debajo del 80 %: «¡Vas bien!» y «¡Vas por buen camino!»;
- por debajo del 50 %: «¡Sigue intentándolo!» y «Cada intento cuenta.».

#### Scenario: Lejos del mínimo
- **WHEN** se cierra un intento no superado con el 38 % del mínimo
- **THEN** el resumen titula «¡Sigue intentándolo!» y no dice «¡Estás cerca!»

#### Scenario: A punto de superarlo
- **WHEN** se cierra un intento no superado con el 90 % del mínimo
- **THEN** el resumen titula «¡Casi lo tienes!» y dice «¡Estás cerca!»
