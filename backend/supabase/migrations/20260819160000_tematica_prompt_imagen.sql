-- INT-113 delta-1 (D1): estilo de ilustración propio de cada temática.
--
-- La generación de preguntas con IA aplica este texto a TODAS las imágenes de la
-- temática, para que el estilo se decida una vez y no se reescriba de memoria en
-- cada tanda. El caso que lo motiva: en "Banderas" la ilustración debe ser la
-- bandera sobre fondo neutro; sin decirlo, el modelo la dibuja dentro de una
-- escena de ciudad que además da pistas de la respuesta.
--
-- Gobierna solo la ILUSTRACIÓN. Qué lugares se proponen se sigue deduciendo del
-- banco de la temática, y no de esta columna: dos fuentes para la misma decisión
-- no tendrían forma de resolverse cuando se contradijeran.
--
-- Nullable a propósito, sin default '': así "sin configurar" no se confunde con
-- "configurado como vacío". No hacen falta policies nuevas — las de `tematicas`
-- (lectura para autenticados, escritura solo admin vía is_admin()) cubren la
-- tabla entera, columna incluida.

alter table tematicas add column prompt_imagen text;

comment on column tematicas.prompt_imagen is
  'Indicaciones de estilo que la generación con IA aplica a las imágenes de esta temática. Solo afecta a la ilustración, no a qué lugares se proponen. Null = sin indicaciones propias.';
