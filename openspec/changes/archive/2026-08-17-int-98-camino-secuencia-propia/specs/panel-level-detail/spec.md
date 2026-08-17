## MODIFIED Requirements

### Requirement: Tarjeta de configuración del nivel editable
La pantalla SHALL ofrecer una tarjeta "Configuración del nivel" con campos
editables para el nombre del nivel, el puntaje mínimo para superarlo, los
umbrales de puntaje para 1, 2 y 3 estrellas, y el número de preguntas por
partida (`preguntas_por_partida`, opcional), y SHALL bloquear el guardado
si no se cumple `puntaje_minimo_superar <= umbral_estrella_1 <=
umbral_estrella_2 <= umbral_estrella_3`, o si `preguntas_por_partida` es
mayor que el número de preguntas ya asignadas al nivel en `nivel_desafios`.

#### Scenario: Guardar una configuración válida
- **WHEN** un admin edita el nombre y los umbrales de un nivel manteniendo
  el orden ascendente exigido y pulsa "Guardar"
- **THEN** la fila de `niveles` se actualiza con los nuevos valores

#### Scenario: Umbrales fuera de orden
- **WHEN** un admin introduce un `umbral_estrella_2` menor que
  `umbral_estrella_1`
- **THEN** el formulario bloquea el guardado y muestra un error indicando
  que los umbrales deben ser ascendentes

#### Scenario: Se define un número válido de preguntas por partida
- **WHEN** un admin fija `preguntas_por_partida = 5` en un nivel que tiene
  8 preguntas asignadas en su recorrido
- **THEN** el formulario guarda el valor sin error

#### Scenario: Se intenta pedir más preguntas de las disponibles
- **WHEN** un admin fija `preguntas_por_partida = 8` en un nivel que solo
  tiene 5 preguntas asignadas en su recorrido
- **THEN** el formulario bloquea el guardado y muestra un error indicando
  que el valor no puede superar el número de preguntas del recorrido

#### Scenario: Se deja preguntas_por_partida sin definir
- **WHEN** un admin guarda la configuración del nivel sin rellenar
  `preguntas_por_partida`
- **THEN** el formulario guarda `NULL`, sin bloquear el guardado
