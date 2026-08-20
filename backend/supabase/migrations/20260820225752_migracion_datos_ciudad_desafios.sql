-- INT-122 (D6, D7): backfill de `desafios.ciudad` para el banco existente.
--
-- Migración de datos, no de esquema. Va versionada y no por REST -- a
-- diferencia del backfill de `pais` de INT-119 delta-2 -- porque el banco de
-- contenido vive solo en el proyecto remoto (`seed.sql` tiene 21 líneas) y el
-- README documenta `supabase db reset --linked` como camino normal de reset:
-- un backfill aplicado por REST se evapora en el siguiente reset y nadie se
-- entera. Aquí sobrevive, se revisa en el PR y queda como registro de por qué
-- cada fila tiene el valor que tiene. En una base recién reseteada estos
-- `update` no encuentran filas y son no-ops inocuos.
--
-- Los valores se determinaron cruzando `nombre` Y coordenadas, no solo el
-- nombre. Ese cruce es lo que evita el error del tipo "Museo de Antioquía",
-- que por nombre parece Medellín y por coordenada es Antakya (Turquía) -- el
-- mismo caso que ya apareció al rellenar `pais` en INT-119 delta-2. Los casos
-- en los que el nombre y la ubicación no coinciden van comentados en su fila.
--
-- Criterio, aplicado igual a las 135 filas: `ciudad` es el municipio o
-- localidad DENTRO del cual está el objetivo. Se queda en `NULL` cuando el
-- objetivo no está dentro de ninguna localidad (mar abierto, yacimiento o
-- accidente natural en descampado), no cuando la localidad es pequeña o poco
-- conocida. Inventar la ciudad más cercana sería afirmar algo falso, y `NULL`
-- degrada al comportamiento que ya había: la app rotula `nombre_lugar`, que
-- para estos casos es justamente el mejor texto posible ("Monte Fuji",
-- "Stonehenge, Inglaterra", "Naufragio del Titanic, Océano Atlántico Norte").
--
-- Se empareja por `id` y no por `nombre_lugar`: es la clave estable, y varias
-- temáticas repiten lugar (el Coliseo está en Monumentos y en Peliculas, Petra
-- en Monumentos y en Peliculas), así que emparejar por texto tocaría filas de
-- otra temática sin querer.

update desafios d
set ciudad = v.ciudad
from (values
  -- Monumentos
  ('6295f6ed-8aa7-43cc-b75b-cddadf70015e'::uuid, 'Bruselas'),  -- Atomium, Bruselas
  ('59f30b33-bdc6-49d3-9343-1475dc499d5a'::uuid, 'Chambord'),  -- Castillo de Chambord, Francia
  ('c1da3131-73db-4084-b473-cac568f40f2d'::uuid, 'Edimburgo'),  -- Castillo de Edimburgo, Escocia
  ('4a0f6c22-d52b-474f-9b42-d3c73a948110'::uuid, 'Himeji'),  -- Castillo de Himeji, Japón
  ('17253cf7-181e-4276-9e89-132797f6eb8b'::uuid, 'Schwangau'),  -- Castillo de Neuschwanstein, Baviera · el castillo está en el municipio de Schwangau
  ('b697a8b5-289f-44af-bd3d-278a3fa102c9'::uuid, 'Praga'),  -- Catedral de San Vito, Praga
  ('44552a34-b10d-4e6a-9e4f-2efbb696ea7b'::uuid, 'Roma'),  -- Coliseo Romano
  ('d3ee9c0f-9b59-440b-ac32-c917911a91e6'::uuid, 'Río de Janeiro'),  -- Cristo Redentor, Río de Janeiro
  ('8fa5fd74-fbb1-4515-aaf0-7ae4ad9c90ee'::uuid, 'Abu Dhabi'),  -- Gran Mezquita Sheikh Zayed, Abu Dhabi
  ('b360c061-6c64-4739-ad59-aee32c444e02'::uuid, 'Pekín'),  -- Gran Muralla China, Badaling · Badaling es distrito de Yanqing, municipio de Pekín
  ('f2ac69b0-79fd-4e12-abc4-0cd5a8b6d61f'::uuid, 'Granada'),  -- La Alhambra, Granada
  ('c141a511-1300-472d-b3cb-90bf78c64ef7'::uuid, 'Barcelona'),  -- La Sagrada Familia
  ('de4550f4-ffbc-4fdb-8af8-5d2af81cd630'::uuid, 'Washington D.C.'),  -- Monumento a Washington, EE.UU.
  ('4a257b97-308c-46e4-8237-4bdcbf4a2823'::uuid, 'Lisboa'),  -- Monumento a los Descubrimientos, Lisboa
  ('add99aeb-92a0-46fd-bbee-50a8ef80659d'::uuid, 'Versalles'),  -- Palacio de Versalles, Francia
  ('cdb0cd8a-27d7-4e5b-b9fe-2b399b633e29'::uuid, 'Budapest'),  -- Parlamento de Budapest, Hungría
  ('fc13efb2-a76b-408b-9072-9e7bbd6f7ef8'::uuid, 'Guiza'),  -- Pirámides de Guiza, Egipto · Guiza es ciudad propia dentro del Gran Cairo
  ('c78a72d5-14e8-4c55-9793-0d88c968a5d5'::uuid, 'San Francisco'),  -- Puente Golden Gate, San Francisco
  ('9a93927a-b881-4a42-93c7-18c4c794a377'::uuid, 'Madrid'),  -- Puerta de Alcalá, Madrid
  ('36e5bdf9-4e5f-477e-8718-287831fdb412'::uuid, 'Nueva Delhi'),  -- Puerta de la India, Nueva Delhi
  ('bc3f7bdb-0ff1-4d52-8e3a-494fc201d47e'::uuid, 'Mostar'),  -- Stari Most, Mostar
  ('2ad1d8a1-9183-4fe5-89a9-02974e113493'::uuid, 'Nueva York'),  -- Statua della Libertà · Liberty Island es territorio de la ciudad de Nueva York
  ('582f5c5c-075b-4050-b354-44a4f1a5d9f1'::uuid, 'Agra'),  -- Taj Mahal, Agra
  ('3da3e15f-3bb4-4727-a3d7-c928c61694df'::uuid, 'Mérida'),  -- Teatro Romano de Mérida, España
  ('beddb59b-1f3f-4aec-89b2-634d7aab60f4'::uuid, 'Kioto'),  -- Templo Kiyomizudera, Kioto
  ('bbf4f6a5-ce02-47bd-85df-b09f158ba90d'::uuid, 'Luxor'),  -- Templo de Luxor, Egipto · el templo está dentro de la ciudad de Luxor
  ('e17f3abe-05fd-45d2-a304-6f4e4524795e'::uuid, 'París'),  -- Torre Eiffel
  ('eb9a84ec-bb02-458b-8c1d-cee8a903e9c8'::uuid, 'Londres'),  -- Torre de Londres, Inglaterra
  ('1f453e81-2091-447c-bade-6fd87923bd4b'::uuid, 'Pisa'),  -- Torre de Pisa, Italia
  ('2b842d4d-3756-463f-8c3c-5a9b5e1b01d6'::uuid, 'Sídney'),  -- Ópera de Sídney
  -- Banderas
  ('9fff0d81-a72c-461f-b0a5-2071a06d9db8'::uuid, 'Berlín'),  -- Alemania
  ('9d5fee07-99f5-4537-ac38-41018350242e'::uuid, 'Buenos Aires'),  -- Argentina
  ('6502fd1d-7b4e-4552-a151-9bef4910cba8'::uuid, 'Canberra'),  -- Australia
  ('192db9b3-d76f-4419-864d-314ea63b7bd8'::uuid, 'Viena'),  -- Austria
  ('7ebdf83f-dbb4-4755-bc31-fe51207a27f5'::uuid, 'Bruselas'),  -- Belgica
  ('46d53710-2fbc-48ca-a20c-91693bdb2cc3'::uuid, 'Brasilia'),  -- Brasilarar
  ('5e2ce6a2-aca8-466e-87f4-3395edb0e404'::uuid, 'Ottawa'),  -- Canada
  ('1516daf1-b60e-4bde-9c8d-eca9065d4c7f'::uuid, 'Pekín'),  -- China
  ('f2496efc-b604-4caf-834a-ec7bbfc143b6'::uuid, 'Washington D.C.'),  -- EEUU
  ('af102eec-c798-4bbf-933d-306cd6dbc206'::uuid, 'Madrid'),  -- España
  ('ff114510-dd19-4ea3-974f-918bfb73ea2a'::uuid, 'París'),  -- Francia
  ('58c46dcd-0e6e-4a14-9eb0-1f13df65095c'::uuid, 'Nueva Delhi'),  -- India
  ('a67288c0-f8a4-4487-a9f5-bd3b7b583bf7'::uuid, 'Roma'),  -- Italia
  ('04b63881-80a4-4806-b92f-869f53ca1487'::uuid, 'Tokio'),  -- Japon
  ('3a776167-c0a5-41fb-b539-50f662a02a37'::uuid, 'Ciudad de México'),  -- Mexico
  ('8c6cd8e5-ea80-446f-931c-5f8bf4ecf25d'::uuid, 'Ámsterdam'),  -- Paises Bajos
  ('96758177-37a3-4768-999f-0cbb7a5f468e'::uuid, 'Lisboa'),  -- Portugal
  ('c6037ec1-8820-4225-9ab0-7192fb9f15c7'::uuid, 'Londres'),  -- Reino Unido
  ('28783c27-9259-4fda-9493-2300184c0634'::uuid, 'Moscú'),  -- Rusia
  ('f63dd877-f416-42bc-b8da-41d09efa7d2c'::uuid, 'Berna'),  -- Suiza
  -- Peliculas
  ('6d4c6a86-3336-4353-9094-dc3595d26268'::uuid, 'Chicago'),  -- El Fugitivo
  ('82e5fc11-3e54-451d-bf25-67ee88e3b2e9'::uuid, 'Washington D.C.'),  -- Forrest Gump
  ('74664ee1-ba79-4009-9d01-de6c50e24f93'::uuid, 'Nueva York'),  -- Ghostbusters
  ('f832de37-c5b4-44b9-8d75-4891aba9b983'::uuid, 'Roma'),  -- Gladiator
  ('2446ceba-6d37-4182-938f-d31efeb0fb4e'::uuid, 'Oxford'),  -- Harry Potter y la Piedra Filosofal
  ('26ec4c3a-2440-406b-8d27-a15fb03db600'::uuid, 'París'),  -- Misión Imposible
  ('b061e812-6abe-4fb8-b3c3-00a6b9390575'::uuid, 'Filadelfia'),  -- Rocky
  ('6be92d6c-3080-4098-b1c8-80c62795b86c'::uuid, 'Nueva York'),  -- Solo en Casa 2
  ('6167c804-d600-4df5-8190-fd6407010c96'::uuid, 'Roma'),  -- Vacaciones en Roma
  -- Personas de la Historia
  ('5d9daea7-d508-43a7-87be-b8f9d382ff32'::uuid, 'Hodgenville'),  -- Abraham Lincoln
  ('0b426361-f345-4de6-a2db-e190bf3cf84f'::uuid, 'Ulm'),  -- Albert Einstein
  ('cb82de06-0a3d-4d92-b40d-f231123ce738'::uuid, 'Shrewsbury'),  -- Charles Darwin
  ('988b17b4-c94b-4849-b701-5356ff23acac'::uuid, 'Londres'),  -- Isabel I de Inglaterra · nació en el palacio de Greenwich, hoy dentro de Londres
  ('84fd65d8-107e-4ae5-b145-6c6e5fb5dc9e'::uuid, 'Vinci'),  -- Leonardo da Vinci
  ('bfa79ed5-e24a-44bc-bd28-68b6ecd8c9bf'::uuid, 'Bonn'),  -- Ludwig van Beethoven
  ('928ff2a8-b043-49ba-9a0a-46f1213d9483'::uuid, 'Varsovia'),  -- Marie Curie
  ('b1d54ffd-a367-4e4d-87e4-bd2e74703aeb'::uuid, 'Atlanta'),  -- Martin Luther King Jr.
  ('cbdd1e59-46ba-42c6-89aa-c1eaf94a0ef7'::uuid, 'Mvezo'),  -- Nelson Mandela
  ('c7a51dcc-6f39-44c0-9d06-8908476360fd'::uuid, 'San Francisco'),  -- Steve Jobs
  ('e01dad2a-079a-4b23-9252-53a8a1f45cbb'::uuid, 'Skopie'),  -- Teresa de Calcuta
  -- Olimpiadas
  ('60ac36b3-2bbd-443e-9ce8-453544fa8235'::uuid, 'Atenas'),  -- Atenas
  ('6d8f347a-c5dc-4908-9d4a-ed4fad1aa39d'::uuid, 'París'),  -- Paris · la coordenada es el Stade de France (Saint-Denis), sede de París 2024
  ('15539cf9-3b56-469e-b7d6-52e9d4dca53c'::uuid, 'San Luis'),  -- San Luis
  -- Museos
  ('bc418d8f-8f34-44bd-8f2b-5cd10901c6e9'::uuid, 'Valencia'),  -- Museo Antropológico Príncipe Felipe
  ('9a6b3e80-c885-4955-8f1d-61e2882622d2'::uuid, 'Londres'),  -- Museo Británico
  ('2f78c9f4-72b5-44b4-a2cf-d3e8a7c8ece1'::uuid, 'Figueras'),  -- Museo Dalí de Figueras
  ('e6ceab67-b803-453b-9279-342ce11aa972'::uuid, 'El Cairo'),  -- Museo Egipcio de El Cairo
  ('40fb1c1a-2470-4ca6-b6ae-11d574081650'::uuid, 'Liubliana'),  -- Museo Etnográfico Nacional de Eslovenia
  ('9952dba5-9a0c-4533-be1e-19220d29ef08'::uuid, 'Bilbao'),  -- Museo Guggenheim Bilbao
  ('4cc98330-f4ac-4d37-8ef6-d7cf0082bbbd'::uuid, 'San Petersburgo'),  -- Museo Hermitage
  ('3e94cddd-0750-4022-b6a1-dfac33fd893d'::uuid, 'Boston'),  -- Museo Isabella Stewart Gardner
  ('fe4e43c1-bc62-4849-ae23-801b6f406cd9'::uuid, 'Nueva York'),  -- Museo Metropolitano de Arte
  ('b0defd1d-606c-456d-898d-20d8e6ed6cf8'::uuid, 'Túnez'),  -- Museo Nacional Bardo · Bardo es un suburbio de la ciudad de Túnez
  ('e92e038d-c486-444e-aeba-3940f81e833d'::uuid, 'Alejandría'),  -- Museo Nacional de Alejandría
  ('a187bfe1-f49b-4153-b0fe-36f819fd2e6d'::uuid, 'Ciudad de México'),  -- Museo Nacional de Antropología
  ('b36bbd8c-eb1b-49bd-a070-2ad1c049bb16'::uuid, 'Tokio'),  -- Museo Nacional de Arte Moderno de Tokio
  ('82ac209b-c5c0-49ae-a2bb-9b14bf66fe6e'::uuid, 'Mérida'),  -- Museo Nacional de Arte Romano
  ('204b9569-a4a5-429a-afb9-986267c61bae'::uuid, 'Bakú'),  -- Museo Nacional de Arte de Azerbaiyán
  ('125a0293-a155-4c91-a2fd-af43f7677b7c'::uuid, 'Barcelona'),  -- Museo Nacional de Arte de Cataluña
  ('ea61c1a5-a1bb-4a3f-963b-a7b4c8a5a266'::uuid, 'Canberra'),  -- Museo Nacional de Australia
  ('d87f8f9c-01f9-4b0c-bef4-e100607102c1'::uuid, 'Buenos Aires'),  -- Museo Nacional de Bellas Artes de Buenos Aires
  ('e4fb250b-80fe-495f-8dec-286531a74fa4'::uuid, 'Santiago de Chile'),  -- Museo Nacional de Bellas Artes de Santiago
  ('0ec5817a-b73d-42b9-8332-aa823eb834cd'::uuid, 'Sarajevo'),  -- Museo Nacional de Bosnia y Herzegovina
  ('5867e149-11c5-4a5b-8d8e-25612f2c9403'::uuid, 'Uagadugú'),  -- Museo Nacional de Burkina Faso
  ('f56194bd-583e-4bb4-a3eb-d6ec8ae968bc'::uuid, 'Pekín'),  -- Museo Nacional de China
  ('012cc5a8-00c7-45f0-bec8-94f3e4653cd5'::uuid, 'Seúl'),  -- Museo Nacional de Corea
  ('38b66ff6-25cb-454f-ba3d-438c0004dd52'::uuid, 'Tartu'),  -- Museo Nacional de Estonia · está en Tartu, no en Tallin
  ('1dc18f20-17ed-4db7-99a7-29aeda2d9d92'::uuid, 'Tiflis'),  -- Museo Nacional de Georgia
  ('f0e30ec9-23f6-46c1-af54-39546bbc81eb'::uuid, 'Washington D.C.'),  -- Museo Nacional de Historia Natural Smithsonian
  ('3ed2b35c-3336-41e9-bc93-d79e469b4b20'::uuid, 'Luxemburgo'),  -- Museo Nacional de Historia y Arte de Luxemburgo
  ('a3faa0ce-446f-4bc5-9cce-760eedd376a4'::uuid, 'Bamako'),  -- Museo Nacional de Mali
  ('e9de36f2-d89b-40e1-bafd-20962ec58d01'::uuid, 'Varsovia'),  -- Museo Nacional de Varsovia
  ('97765bb9-bc49-4e25-b71e-a0fe6afdf3f4'::uuid, 'Moscú'),  -- Museo Pushkin de Bellas Artes
  ('dcc8a1de-d959-4f55-8161-779f35292195'::uuid, 'Antakya'),  -- Museo de Antioquía · el nombre dice Antioquía pero la coordenada es Antakya (Turquía), no Medellín
  ('08a1d3b9-ca4b-4bd4-bbd3-82850d23786e'::uuid, 'Niterói'),  -- Museo de Arte Contemporáneo de Niterói
  ('20a64cb3-0d51-40be-bd3a-4ca68a5cd2e8'::uuid, 'Doha'),  -- Museo de Arte Islámico de Doha
  ('549996ba-f6c6-43cd-b6ff-8cfb5c12c906'::uuid, 'Medellín'),  -- Museo de Arte Moderno de Medellín
  ('c29fc056-9273-41b2-bbf7-e2b115e7df5c'::uuid, 'São Paulo'),  -- Museo de Arte Moderno de São Paulo
  ('2c548cca-52e9-4da8-be66-686da985f8ae'::uuid, 'Bogotá'),  -- Museo de Arte del Banco de la República
  ('fb35e314-585e-4f92-b3ec-5622d82cffc7'::uuid, 'Los Ángeles'),  -- Museo de Arte del Condado de Los Ángeles (LACMA)
  ('d53f77bb-7641-4538-aff6-2f62035d889f'::uuid, 'Montreal'),  -- Museo de Bellas Artes de Montreal
  ('268fd43b-3280-4921-b37a-1bb37cde834a'::uuid, 'Chicago'),  -- Museo de Ciencias y de la Industria
  ('e159346e-f42e-46b0-9961-f6cf49af7e0c'::uuid, 'Viena'),  -- Museo de Historia Natural de Viena
  ('a870e578-31ac-4839-b75c-852b1e8174ab'::uuid, 'Atenas'),  -- Museo de la Acrópolis
  ('f95bd78a-ea87-426c-8eaf-38a8abfcf846'::uuid, 'París'),  -- Museo del Louvre
  ('72a13b5f-9010-4ff5-a80a-ee517915b267'::uuid, 'Madrid'),  -- Museo del Prado
  ('91a4f6f7-7604-4576-9279-e9ef65af6a2f'::uuid, 'Ciudad del Vaticano'),  -- Museos Vaticanos
  -- Circuitos F1
  ('0260d6e1-21a7-4519-a6ae-53c47fcaccb9'::uuid, 'Melbourne'),  -- Circuito de Albert Park
  ('bef000af-9e18-4a27-8b68-3ef87636ab54'::uuid, 'São Paulo'),  -- Circuito de Interlagos
  ('53808ae5-8ea0-44b8-9d44-a689759b4137'::uuid, 'Monza'),  -- Circuito de Monza
  ('b7d4d57a-3885-445c-b40e-3ebb580bd000'::uuid, 'Montecarlo'),  -- Circuito de Mónaco · el trazado recorre Montecarlo y La Condamine
  ('a088dbeb-c7dd-41c7-8503-bc5806ebe496'::uuid, 'Stavelot'),  -- Circuito de Spa-Francorchamps · el trazado está en el municipio de Stavelot, no en la villa de Spa
  ('ec7c9b28-1464-4349-9282-11a2c6821bbd'::uuid, 'Suzuka'),  -- Circuito de Suzuka
  ('810d1901-8269-41df-b091-9270175faa59'::uuid, 'Abu Dhabi'),  -- Circuito de Yas Marina · Yas Island pertenece a Abu Dhabi
  ('c3671190-ea34-48c8-91dd-260904250baf'::uuid, 'Silverstone')  -- Silverstone
) as v(id, ciudad)
where d.id = v.id;

-- Las 10 filas que se quedan en `ciudad = NULL`, con el motivo. No son deuda
-- pendiente: son la respuesta correcta.
--
--   Machu Picchu                 el yacimiento no está dentro de Aguas Calientes
--   Monte Fuji                   accidente natural, reparte ladera entre varios municipios
--   Monte Rushmore               en el condado de Pennington, fuera de Keystone
--   Petra (Monumentos)           el yacimiento es contiguo a Wadi Musa, no está dentro
--   Stonehenge                   en campo abierto cerca de Amesbury
--   Templo de Kukulkán           Chichén Itzá está fuera de Pisté
--   El Resplandor                Timberline Lodge, en el monte Hood, sin localidad
--   Indiana Jones y la Última Cruzada   mismo yacimiento de Petra
--   Jurassic Park                cascada Manawaiopuna, valle privado de Kauai
--   Titanic                      naufragio en aguas internacionales (también sin `pais`)
