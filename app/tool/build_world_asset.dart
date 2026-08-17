// Genera `assets/world/world_50m.bin` a partir del TopoJSON de países de
// Natural Earth 50m (INT-92, D2/D3 de `design.md`).
//
//   dart run tool/build_world_asset.dart
//   dart run tool/build_world_asset.dart --source /ruta/countries-50m.json
//
// El binario resultante se commitea: la app y sus tests nunca dependen de
// tener red, y regenerarlo solo hace falta si se quiere cambiar de dataset.
//
// Fuente: https://cdn.jsdelivr.net/npm/world-atlas@2.0.2/countries-50m.json
// (paquete `world-atlas`, derivado de Natural Earth 1:50m Admin 0 –
// Countries). Natural Earth es de dominio público: sus datos se pueden usar,
// redistribuir y modificar sin permiso ni atribución.
//
// Formato del binario (little endian), pensado para leerse de un tirón con
// `ByteData` sin construir objetos intermedios:
//
//   'GQW1'                      4 bytes de firma
//   uint32  numeroDePaises
//   por cada país:
//     uint32  numeroDeAnillos
//     por cada anillo:
//       uint32  numeroDePuntos
//       numeroDePuntos × (float32 longitud, float32 latitud)
//
// Un "país" es una unidad de relleno: sus anillos se dibujan en un único
// `Path` con `PathFillType.evenOdd`, de modo que los agujeros (Lesoto dentro
// de Sudáfrica, por ejemplo) salen solos.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

const _fuentePorDefecto =
    'https://cdn.jsdelivr.net/npm/world-atlas@2.0.2/countries-50m.json';

Future<void> main(List<String> args) async {
  final fuente = _argumento(args, '--source') ?? _fuentePorDefecto;
  final destino = _argumento(args, '--out') ?? 'assets/world/world_50m.bin';

  stdout.writeln('Leyendo $fuente');
  final crudo = fuente.startsWith('http')
      ? await _descargar(fuente)
      : await File(fuente).readAsString();

  final topo = jsonDecode(crudo) as Map<String, dynamic>;
  final paises = _decodificarPaises(topo, 'countries');

  final bytes = _serializar(paises);
  final salida = File(destino);
  await salida.parent.create(recursive: true);
  await salida.writeAsBytes(bytes);

  final anillos = paises.fold<int>(0, (n, p) => n + p.length);
  final puntos = paises.fold<int>(
    0,
    (n, p) => n + p.fold<int>(0, (m, a) => m + a.length ~/ 2),
  );
  stdout.writeln(
    'Escrito $destino: ${paises.length} países, $anillos anillos, '
    '$puntos puntos, ${(bytes.length / 1024).toStringAsFixed(0)} KB',
  );
}

String? _argumento(List<String> args, String nombre) {
  final i = args.indexOf(nombre);
  return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
}

Future<String> _descargar(String url) async {
  final cliente = HttpClient();
  try {
    final peticion = await cliente.getUrl(Uri.parse(url));
    final respuesta = await peticion.close();
    if (respuesta.statusCode != 200) {
      throw HttpException('HTTP ${respuesta.statusCode} al pedir $url');
    }
    // Se espera aquí dentro a propósito: el `finally` cierra el cliente, y
    // devolver el futuro sin consumir cortaría la descarga a medias.
    return await respuesta.transform(utf8.decoder).join();
  } finally {
    cliente.close();
  }
}

/// Deshace la topología de TopoJSON: reconstruye los arcos absolutos a
/// partir de las deltas cuantizadas y los cose en anillos por geometría.
///
/// Devuelve, por cada geometría del objeto pedido, la lista de sus anillos;
/// cada anillo es una lista plana `[lng, lat, lng, lat, ...]`.
List<List<Float32List>> _decodificarPaises(
  Map<String, dynamic> topo,
  String objeto,
) {
  final transform = topo['transform'] as Map<String, dynamic>;
  final escala = (transform['scale'] as List).cast<num>();
  final traslacion = (transform['translate'] as List).cast<num>();

  // Arcos absolutos en grados. En TopoJSON cuantizado cada arco llega como
  // una lista de deltas enteras que hay que ir acumulando.
  final arcos = <Float64List>[];
  for (final arcoCrudo in topo['arcs'] as List) {
    final deltas = arcoCrudo as List;
    final puntos = Float64List(deltas.length * 2);
    var x = 0.0;
    var y = 0.0;
    for (var i = 0; i < deltas.length; i++) {
      final par = (deltas[i] as List).cast<num>();
      x += par[0];
      y += par[1];
      puntos[i * 2] = x * escala[0] + traslacion[0];
      puntos[i * 2 + 1] = y * escala[1] + traslacion[1];
    }
    arcos.add(puntos);
  }

  final geometrias =
      (topo['objects'] as Map<String, dynamic>)[objeto]['geometries'] as List;

  final paises = <List<Float32List>>[];
  for (final geometria in geometrias.cast<Map<String, dynamic>>()) {
    final tipo = geometria['type'] as String?;
    final crudos = geometria['arcs'] as List?;
    if (crudos == null) continue;

    final poligonos = switch (tipo) {
      'Polygon' => [crudos],
      'MultiPolygon' => crudos,
      // El objeto `countries` de world-atlas solo trae polígonos; cualquier
      // otro tipo sería un dataset distinto al esperado.
      _ => throw StateError('Tipo de geometría no soportado: $tipo'),
    };

    final anillos = <Float32List>[];
    for (final poligono in poligonos) {
      for (final anillo in poligono as List) {
        anillos.add(_coser((anillo as List).cast<int>(), arcos));
      }
    }
    if (anillos.isNotEmpty) paises.add(anillos);
  }

  return paises;
}

/// Cose un anillo a partir de sus índices de arco. Un índice negativo `i`
/// significa "el arco `-i-1` recorrido al revés"; el primer punto de cada
/// arco encadenado se descarta porque coincide con el último del anterior.
Float32List _coser(List<int> indices, List<Float64List> arcos) {
  final puntos = <double>[];
  for (final indice in indices) {
    final invertido = indice < 0;
    final arco = arcos[invertido ? -indice - 1 : indice];
    final total = arco.length ~/ 2;

    for (var paso = 0; paso < total; paso++) {
      final i = invertido ? total - 1 - paso : paso;
      if (paso == 0 && puntos.isNotEmpty) continue;
      puntos.add(arco[i * 2]);
      puntos.add(arco[i * 2 + 1]);
    }
  }
  return Float32List.fromList(puntos);
}

Uint8List _serializar(List<List<Float32List>> paises) {
  var bytes = 8;
  for (final anillos in paises) {
    bytes += 4;
    for (final anillo in anillos) {
      bytes += 4 + anillo.length * 4;
    }
  }

  final buffer = ByteData(bytes);
  buffer.setUint8(0, 0x47); // G
  buffer.setUint8(1, 0x51); // Q
  buffer.setUint8(2, 0x57); // W
  buffer.setUint8(3, 0x31); // 1
  buffer.setUint32(4, paises.length, Endian.little);

  var offset = 8;
  for (final anillos in paises) {
    buffer.setUint32(offset, anillos.length, Endian.little);
    offset += 4;
    for (final anillo in anillos) {
      buffer.setUint32(offset, anillo.length ~/ 2, Endian.little);
      offset += 4;
      for (final valor in anillo) {
        buffer.setFloat32(offset, valor, Endian.little);
        offset += 4;
      }
    }
  }

  return buffer.buffer.asUint8List();
}
