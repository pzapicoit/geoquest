import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Dominio de las identidades sintéticas. `.invalid` está reservado por la
/// RFC 2606 justamente para esto: no se puede registrar ni resolver, así que
/// ningún correo enviado ahí llega a ninguna parte. Es la garantía técnica de
/// que este proyecto no tiene email por ningún lado.
const dominioIdentidadSintetica = 'geoquest.invalid';

/// Identidad interna con la que un jugador entra en Supabase Auth (INT-128, D2).
///
/// Supabase exige un identificador para poder usar contraseña, y aquí no
/// queremos ninguno real. Se deriva del apodo en vez de guardarse en una tabla:
/// así el cliente lo calcula solo y no hace falta ningún servicio intermedio
/// que traduzca apodo → identidad.
///
/// Se usa el hash y no el apodo tal cual porque un apodo admite cualquier
/// carácter hasta 16 —la propia lista de sugerencias trae `BrújulaLoca`— y los
/// espacios, acentos y emoji no son válidos en la parte local de un email.
/// Escaparlos obligaría a inventar una codificación y a mantenerla para
/// siempre.
///
/// Se normaliza a minúsculas para que entrar no dependa de cómo se escriban
/// las mayúsculas, y de paso para que no pueda existir un "pablo" impostor al
/// lado de "Pablo".
///
/// **Cambiar esta función deja fuera de su cuenta a todo el que ya tenga
/// contraseña**: su identidad dejaría de coincidir con la registrada, sin
/// ningún aviso y sin forma de recuperarla. Es código congelado salvo
/// migración deliberada de todas las identidades existentes.
String identidadDeApodo(String apodo) {
  final normalizado = apodo.trim().toLowerCase();
  final digest = sha256.convert(utf8.encode(normalizado));
  return '$digest@$dominioIdentidadSintetica';
}
