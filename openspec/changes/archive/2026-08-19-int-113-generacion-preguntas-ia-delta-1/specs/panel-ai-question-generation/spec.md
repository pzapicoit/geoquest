## ADDED Requirements

### Requirement: El estilo de la temática se aplica a todas sus ilustraciones

Al ilustrar los candidatos aprobados, la pantalla SHALL enviar el
`prompt_imagen` de la temática elegida junto con cada petición de imagen, sin
que el admin tenga que reescribirlo. Cuando la temática no tenga prompt, SHALL
enviarse vacío y el comportamiento SHALL ser el de antes de este delta.

Las indicaciones extra de la tanda SHALL seguir enviándose y SHALL convivir con
el prompt de la temática: el de la temática es el estilo permanente, las
indicaciones son el matiz de esa tanda.

#### Scenario: Se ilustra una temática con estilo propio

- **WHEN** se generan las imágenes de una tanda de una temática cuyo
  `prompt_imagen` describe su estilo
- **THEN** cada petición de imagen incluye ese estilo

#### Scenario: Se ilustra una temática sin estilo propio

- **WHEN** la temática elegida no tiene `prompt_imagen`
- **THEN** las peticiones de imagen se hacen sin estilo de temática, y las
  indicaciones extra de la tanda siguen aplicándose

#### Scenario: Conviven estilo de temática e indicaciones de la tanda

- **WHEN** la temática tiene `prompt_imagen` y además el admin escribió
  indicaciones extra
- **THEN** cada petición de imagen lleva las dos cosas, distinguidas

### Requirement: El paso 1 muestra el estilo que se va a aplicar

Al elegir una temática con `prompt_imagen`, el paso 1 SHALL mostrar ese texto en
modo lectura, para que el admin sepa con qué se van a ilustrar las preguntas
antes de gastar en imágenes. SHALL indicar también dónde se edita.

#### Scenario: La temática elegida tiene estilo

- **WHEN** el admin selecciona una temática con `prompt_imagen`
- **THEN** el paso 1 muestra ese texto como el estilo que se aplicará

#### Scenario: La temática elegida no tiene estilo

- **WHEN** el admin selecciona una temática sin `prompt_imagen`
- **THEN** el paso 1 lo indica y señala que puede definirse en la temática
