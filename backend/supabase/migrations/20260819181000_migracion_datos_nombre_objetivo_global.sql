-- INT-116: migracion de datos sobre las 83 filas existentes de desafios y
-- las 6 de tematicas. Ver design.md D2/D3 de
-- openspec/changes/int-116-objetivo-global-nombre-corto para el
-- razonamiento completo de cada valor.

-- 1) Copia general: nombre_lugar ya sirve tal cual como nombre corto para
-- Monumentos/Banderas/Olimpiadas (59 filas). Para las 24 de Personas de la
-- Historia/Peliculas es un valor de partida que el paso 2 sobreescribe.
update desafios set nombre = nombre_lugar;

-- 2a) Personas de la Historia (11 filas): nombre = personaje (ya estaba
-- codificado en el nombre_lugar original como "Lugar de nacimiento de X");
-- nombre_lugar pasa a ser la ciudad de nacimiento real. En 5 de las 11 la
-- lat_real/lng_real ya guardada no correspondia al lugar real (verificado
-- por busqueda externa durante el /take de esta tarea) y se corrige aqui.
update desafios set nombre = 'Abraham Lincoln', nombre_lugar = 'Hodgenville, Kentucky, EE. UU.'
  where id = '5d9daea7-d508-43a7-87be-b8f9d382ff32'; -- coords ya correctas (Sinking Spring Farm)

-- Einstein: coordenada guardada (48.3696, 10.8929) caia en Augsburgo, a ~67
-- km de Ulm (48.3984, 9.9916), su lugar de nacimiento real.
update desafios set nombre = 'Albert Einstein', nombre_lugar = 'Ulm, Alemania',
    lat_real = 48.3984, lng_real = 9.9916
  where id = '0b426361-f345-4de6-a2db-e190bf3cf84f';

-- Darwin: coordenada guardada (52.6958, 0.1635) caia en Cambridgeshire, a
-- ~200 km de Shrewsbury (52.7128, -2.7632), su lugar de nacimiento real (The
-- Mount).
update desafios set nombre = 'Charles Darwin', nombre_lugar = 'Shrewsbury, Inglaterra',
    lat_real = 52.7128, lng_real = -2.7632
  where id = 'cb82de06-0a3d-4d92-b40d-f231123ce738';

update desafios set nombre = 'Isabel I de Inglaterra', nombre_lugar = 'Londres, Reino Unido'
  where id = '988b17b4-c94b-4849-b701-5356ff23acac'; -- coords ya correctas (Londres)

update desafios set nombre = 'Leonardo da Vinci', nombre_lugar = 'Vinci, Italia'
  where id = '84fd65d8-107e-4ae5-b145-6c6e5fb5dc9e'; -- coords ya correctas

update desafios set nombre = 'Ludwig van Beethoven', nombre_lugar = 'Bonn, Alemania'
  where id = 'bfa79ed5-e24a-44bc-bd28-68b6ecd8c9bf'; -- coords ya correctas

update desafios set nombre = 'Marie Curie', nombre_lugar = 'Varsovia, Polonia'
  where id = '928ff2a8-b043-49ba-9a0a-46f1213d9483'; -- coords ya correctas

update desafios set nombre = 'Martin Luther King Jr.', nombre_lugar = 'Atlanta, Georgia, EE. UU.'
  where id = 'b1d54ffd-a367-4e4d-87e4-bd2e74703aeb'; -- coords ya correctas

-- Mandela: coordenada guardada (-31.5942, 28.7837) caia en Mthatha, a ~49 km
-- de Mvezo (-31.9610, 28.4910), su lugar de nacimiento real.
update desafios set nombre = 'Nelson Mandela', nombre_lugar = 'Mvezo, Sudáfrica',
    lat_real = -31.9610, lng_real = 28.4910
  where id = 'cbdd1e59-46ba-42c6-89aa-c1eaf94a0ef7';

-- Steve Jobs: coordenada guardada (37.3541, -122.0321) caia en
-- Cupertino/Sunnyvale, a ~54 km de San Francisco (37.7749, -122.4194), su
-- ciudad de nacimiento real.
update desafios set nombre = 'Steve Jobs', nombre_lugar = 'San Francisco, California, EE. UU.',
    lat_real = 37.7749, lng_real = -122.4194
  where id = 'c7a51dcc-6f39-44c0-9d06-8908476360fd';

-- Teresa de Calcuta: coordenada guardada (41.3275, 19.8187) caia en Tirana
-- (Albania), a ~150 km de Skopie (41.9938, 21.4308), su ciudad de
-- nacimiento real (entonces Uskub, Imperio Otomano).
update desafios set nombre = 'Teresa de Calcuta', nombre_lugar = 'Skopie, Macedonia del Norte',
    lat_real = 41.9938, lng_real = 21.4308
  where id = 'e01dad2a-079a-4b23-9252-53a8a1f45cbb';

-- 2b) Peliculas (13 filas): nombre_lugar original traia el titulo (o una
-- referencia ambigua, resuelta abajo) en vez de un lugar; nombre pasa a ser
-- el titulo identificado y nombre_lugar la localizacion real de rodaje.
update desafios set nombre = 'El Fugitivo', nombre_lugar = 'Chicago, Illinois, EE. UU.'
  where id = '6d4c6a86-3336-4353-9094-dc3595d26268'; -- coords ya correctas (Willis Tower)

update desafios set nombre = 'Forrest Gump', nombre_lugar = 'Reflecting Pool, Lincoln Memorial, Washington D.C.'
  where id = '82e5fc11-3e54-451d-bf25-67ee88e3b2e9'; -- coords ya correctas

update desafios set nombre = 'Ghostbusters', nombre_lugar = 'Parque de bomberos Hook & Ladder 8, Tribeca, Nueva York'
  where id = '74664ee1-ba79-4009-9d01-de6c50e24f93'; -- coords ya correctas

update desafios set nombre = 'Gladiator', nombre_lugar = 'Coliseo de Roma, Italia'
  where id = 'f832de37-c5b4-44b9-8d75-4891aba9b983'; -- coords ya correctas

update desafios set nombre = 'Harry Potter y la Piedra Filosofal', nombre_lugar = 'Christ Church College, Oxford, Reino Unido'
  where id = '2446ceba-6d37-4182-938f-d31efeb0fb4e'; -- coords ya correctas

-- "Hepburn" identificado como Vacaciones en Roma (Roman Holiday, 1953):
-- coords ya correctas (Piazza di Spagna).
update desafios set nombre = 'Vacaciones en Roma', nombre_lugar = 'Plaza de España (Piazza di Spagna), Roma, Italia'
  where id = '6167c804-d600-4df5-8190-fd6407010c96';

update desafios set nombre = 'Solo en Casa 2', nombre_lugar = 'The Plaza Hotel, Nueva York, EE. UU.'
  where id = '6be92d6c-3080-4098-b1c8-80c62795b86c'; -- coords ya correctas

-- "Indiana" identificado como Indiana Jones y la Ultima Cruzada: coords ya
-- correctas (El Tesoro, Petra).
update desafios set nombre = 'Indiana Jones y la Última Cruzada', nombre_lugar = 'El Tesoro (Al-Khazneh), Petra, Jordania'
  where id = '5a8fac3b-b79f-424c-b14a-8398a60784f9';

-- Jurassic Park: coordenada guardada (-21.1335, -159.9061) caia en el
-- Pacifico Sur cerca de las Islas Cook, muy lejos de Kauai/Hawai donde se
-- rodo realmente. Se sustituye por la Cascada Manawaiopuna ("Jurassic
-- Falls"), localizacion real de rodaje.
update desafios set nombre = 'Jurassic Park', nombre_lugar = 'Cascada Manawaiopuna, Kauai, Hawái, EE. UU.',
    lat_real = 21.988205, lng_real = -159.525858
  where id = '0ed3d4dd-6822-4b66-bc75-825453d60f78';

update desafios set nombre = 'Misión Imposible', nombre_lugar = 'Trocadéro, París, Francia'
  where id = '26ec4c3a-2440-406b-8d27-a15fb03db600'; -- coords ya correctas

update desafios set nombre = 'Rocky', nombre_lugar = 'Escalinata del Museo de Arte de Filadelfia, EE. UU.'
  where id = 'b061e812-6abe-4fb8-b3c3-00a6b9390575'; -- coords ya correctas (Rocky Steps)

-- El Resplandor (The Shining): coordenada guardada (39.7449, -105.5129)
-- caia en Idaho Springs (Colorado), sin relacion conocida con la pelicula.
-- Se sustituye por Timberline Lodge (Monte Hood, Oregon), localizacion real
-- de rodaje de los exteriores del Overlook Hotel.
update desafios set nombre = 'El Resplandor', nombre_lugar = 'Timberline Lodge, Monte Hood, Oregón, EE. UU.',
    lat_real = 45.3311, lng_real = -121.7113
  where id = '496c9790-7fb1-4d13-9094-91c10eebe5d6';

-- Titanic: lng_real guardada (49.9469, positiva/Este) tenia el signo
-- invertido -- caia en Kazajistan en vez del Atlantico Norte. Las
-- coordenadas reales del naufragio son 41.7325N, 49.9469O.
update desafios set nombre = 'Titanic', nombre_lugar = 'Naufragio del Titanic, Océano Atlántico Norte',
    lng_real = -49.9469
  where id = 'c005d929-11ff-4dec-bd9a-2ab2efc77ff1';

-- 3) objetivo_global de las 6 tematicas actuales (redaccion acordada con el
-- usuario durante el /take de esta tarea).
update tematicas set objetivo_global = 'Adivina dónde está este monumento'
  where id = '8821607f-3386-433c-a87f-96de4b4de257'; -- Monumentos

update tematicas set objetivo_global = 'La capital de este país es...'
  where id = '6ade75ce-8417-4442-9069-0bb6a4aece57'; -- Banderas

update tematicas set objetivo_global = 'Esta escena, ¿a qué sitio corresponde?'
  where id = 'f6d78a61-6678-4fcf-89a0-e525aa5988df'; -- Peliculas

update tematicas set objetivo_global = '¿Dónde nació esta personalidad?'
  where id = '84fb0528-d440-498b-a366-7f45176f8149'; -- Personas de la Historia

update tematicas set objetivo_global = '¿Dónde fueron estas Olimpiadas?'
  where id = '938219d9-b690-4ccd-b969-4a912addeb8b'; -- Olimpiadas

update tematicas set objetivo_global = '¿Dónde está este museo?'
  where id = '6f897070-1b57-4c55-a674-5c6fe614fd60'; -- Museos

-- 4) Ya no queda ninguna fila nula tras los pasos 1-3: se cierra el
-- esquema a NOT NULL para altas futuras.
alter table tematicas alter column objetivo_global set not null;
alter table desafios alter column nombre set not null;
