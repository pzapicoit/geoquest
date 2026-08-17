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
//
// Dos rasgos del dataset obligan a tocar la geometría al decodificarla, los
// dos por el mismo motivo —el antimeridiano— y los dos documentados en el
// `design.md` de INT-103: el polígono de cierre polar de la Antártida llega
// partido en dos anillos que hay que fusionar (D2/D3/D4), y los anillos que
// cruzan de verdad el meridiano 180 hay que partirlos (D5).

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

const _fuentePorDefecto =
    'https://cdn.jsdelivr.net/npm/world-atlas@2.0.2/countries-50m.json';

// El asset commiteado se generó con este TopoJSON, cuyo sha256 es
// 04342cdc1e3016bcd7db1630de95684d67b79fe3c8c460321e87aef469502394.
// Sirve para saber si una regeneración futura parte del mismo dato o de otro.

/// Un anillo con menos área que esto está colapsado en una línea: no aporta
/// relleno y solo ensucia la pasada de contorno. El barrido de los 241 países
/// del dataset encuentra exactamente uno, la arista del polo antártico.
const double _areaMinima = 1e-9;

/// Suelo al que se acota la costa de un cierre polar. Va un pelo por dentro
/// de la latitud a la que Mercator cierra el mundo (85,05112877980659°) para
/// que la costa no caiga sobre la propia arista del polo: si cayeran en la
/// misma horizontal, el anillo se tocaría a sí mismo y el relleno par-impar
/// dejaría una muesca. El hueco que deja son 0,03 px a escala mínima.
const double _latitudSueloCostaPolar = -85.05;

Future<void> main(List<String> args) async {
  final fuente = _argumento(args, '--source') ?? _fuentePorDefecto;
  final destino = _argumento(args, '--out') ?? 'assets/world/world_50m.bin';

  stdout.writeln('Leyendo $fuente');
  final crudo = fuente.startsWith('http')
      ? await _descargar(fuente)
      : await File(fuente).readAsString();

  final topo = jsonDecode(crudo) as Map<String, dynamic>;
  final mundo = _decodificarPaises(topo, 'countries');
  final paises = mundo.paises;

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
  // Un salto en estos dos números al cambiar de dataset avisa de que las
  // reglas de geometría están encajando donde no tocaba.
  stdout.writeln(
    'Geometría: ${mundo.fusionados} polígono(s) de cierre polar fusionado(s), '
    '${mundo.partidos} anillo(s) partido(s) en el antimeridiano, '
    '${mundo.descartados} anillo(s) sin área descartado(s)',
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

/// Lo que sale de decodificar: la geometría y la cuenta de lo que las reglas
/// han tenido que tocar.
typedef Mundo = ({
  List<List<Float32List>> paises,
  int fusionados,
  int partidos,
  int descartados,
});

/// Deshace la topología de TopoJSON: reconstruye los arcos absolutos a
/// partir de las deltas cuantizadas y los cose en anillos por geometría.
///
/// Devuelve, por cada geometría del objeto pedido, la lista de sus anillos;
/// cada anillo es una lista plana `[lng, lat, lng, lat, ...]`.
Mundo _decodificarPaises(Map<String, dynamic> topo, String objeto) {
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
  var fusionados = 0;
  var partidos = 0;
  var descartados = 0;

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
      final cosidos = [
        for (final anillo in poligono as List)
          _coser((anillo as List).cast<int>(), arcos),
      ];

      // El cierre polar se fusiona antes de mirar el antimeridiano: el anillo
      // que sale de fusionarlo ya no tiene ningún salto que partir, mientras
      // que partir primero rompería la arista del polo antes de poder
      // emparejarla con la costa (D6).
      final tratados = <List<double>>[];
      final aristaPolar = _indiceDeLaAristaPolar(cosidos);
      if (aristaPolar >= 0) {
        tratados.add(_fusionarCierrePolar(cosidos, aristaPolar));
        fusionados++;
      } else {
        for (final cosido in cosidos) {
          final trozos = _partirEnElAntimeridiano(cosido);
          if (trozos.length > 1) partidos++;
          tratados.addAll(trozos);
        }
      }

      for (final anillo in tratados) {
        final limpio = _sinRepetidosSeguidos(anillo);
        // Menos de tres puntos no encierra nada, y un anillo colapsado en una
        // línea solo ensucia el contorno.
        if (limpio.length < 6 || _area(limpio).abs() < _areaMinima) {
          descartados++;
          continue;
        }
        anillos.add(Float32List.fromList(limpio));
      }
    }
    if (anillos.isNotEmpty) paises.add(anillos);
  }

  return (
    paises: paises,
    fusionados: fusionados,
    partidos: partidos,
    descartados: descartados,
  );
}

/// Cose un anillo a partir de sus índices de arco. Un índice negativo `i`
/// significa "el arco `-i-1` recorrido al revés"; el primer punto de cada
/// arco encadenado se descarta porque coincide con el último del anterior.
///
/// Devuelve `double` de 64 bits: las reglas de geometría que vienen después
/// comparan longitudes contra 180 exacto, y redondear a 32 bits antes de eso
/// desdibujaría justo el dato en el que se apoyan.
List<double> _coser(List<int> indices, List<Float64List> arcos) {
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
  return puntos;
}

/// Área con signo del anillo, por la fórmula del cordón de zapato sobre la
/// lista plana `[lng, lat, ...]`. Solo se usa su magnitud, para saber si el
/// anillo encierra algo o está colapsado en una línea.
double _area(List<double> anillo) {
  final total = anillo.length ~/ 2;
  var doble = 0.0;
  for (var i = 0; i < total; i++) {
    final j = (i + 1) % total;
    doble +=
        anillo[i * 2] * anillo[j * 2 + 1] - anillo[j * 2] * anillo[i * 2 + 1];
  }
  return doble / 2;
}

bool _enAntimeridiano(double longitud) => (longitud.abs() - 180).abs() < 1e-9;

/// Quita los puntos que repiten al inmediatamente anterior.
///
/// Los anillos de world-atlas vienen cerrados explícitamente, con el último
/// punto igual al primero. Cortar por un vértice que es a la vez el índice 0
/// y el último —o recorrer el anillo en círculo pasando por los dos— emite el
/// mismo punto dos veces seguidas y deja un segmento de longitud cero dentro
/// del recorrido. El cierre explícito sí se conserva: ese punto repite al
/// primero, no al anterior.
List<double> _sinRepetidosSeguidos(List<double> anillo) {
  final limpio = <double>[];
  for (var i = 0; i < anillo.length; i += 2) {
    final ultimo = limpio.length;
    if (ultimo >= 2 &&
        limpio[ultimo - 2] == anillo[i] &&
        limpio[ultimo - 1] == anillo[i + 1]) {
      continue;
    }
    limpio.add(anillo[i]);
    limpio.add(anillo[i + 1]);
  }
  return limpio;
}

/// Posición de la arista del polo dentro de un polígono de cierre polar, o
/// `-1` si el polígono no lo es (D2).
///
/// Un polígono con más de un anillo en el que uno encierra área cero no es un
/// contorno con agujeros —un agujero no puede ser mayor que su exterior—: son
/// los arcos de un mismo contorno que la topología dejó separados. Así viene
/// la Antártida en world-atlas: la arista del polo por un lado (257 puntos a
/// -89,999°) y la costa por otro (2539 puntos).
///
/// Se busca en cualquier posición en vez de dar por hecho que es la primera:
/// el orden de los anillos dentro del polígono no es algo que el formato
/// garantice. El barrido de los 241 países del dataset encuentra este caso
/// exactamente una vez.
int _indiceDeLaAristaPolar(List<List<double>> anillos) {
  if (anillos.length < 2) return -1;
  for (var i = 0; i < anillos.length; i++) {
    if (_area(anillos[i]).abs() < _areaMinima) return i;
  }
  return -1;
}

/// Concatena los arcos del cierre polar en un solo anillo. La arista del polo
/// va primera y se deja donde está; los demás anillos son costa y se acotan
/// al suelo para que no caigan sobre ella (D4).
List<double> _fusionarCierrePolar(List<List<double>> anillos, int aristaPolar) {
  final orden = [
    anillos[aristaPolar],
    for (var i = 0; i < anillos.length; i++)
      if (i != aristaPolar) anillos[i],
  ];

  final fusionado = <double>[];
  for (var i = 0; i < orden.length; i++) {
    final resuelto = _resolverExtremosDelAntimeridiano(orden[i]);
    for (var p = 0; p < resuelto.length; p += 2) {
      final latitud = resuelto[p + 1];
      fusionado.add(resuelto[p]);
      fusionado.add(
        i > 0 && latitud < _latitudSueloCostaPolar
            ? _latitudSueloCostaPolar
            : latitud,
      );
    }
  }
  return fusionado;
}

/// Decide de qué lado del antimeridiano está un extremo guardado a |lng| = 180
/// mirando el signo de su vecino (D3).
///
/// Los cuatro extremos de los dos arcos del cierre polar vienen guardados como
/// -180 aunque dos de ellos son geográficamente +180. Sin resolverlos, los dos
/// conectores del anillo fusionado caen en la misma vertical, se superponen y
/// se cancelan en par-impar: el relleno no cambiaría nada.
List<double> _resolverExtremosDelAntimeridiano(List<double> anillo) {
  final puntos = List<double>.of(anillo);
  final total = puntos.length ~/ 2;
  if (total < 2) return puntos;

  if (_enAntimeridiano(puntos[0])) {
    puntos[0] = puntos[2] < 0 ? -180.0 : 180.0;
  }
  final ultimo = (total - 1) * 2;
  if (_enAntimeridiano(puntos[ultimo])) {
    puntos[ultimo] = puntos[(total - 2) * 2] < 0 ? -180.0 : 180.0;
  }
  return puntos;
}

/// Parte un anillo que cruza de verdad el meridiano 180 (D5).
///
/// Un vértice a |lng| = 180 cuyos vecinos caen en hemisferios opuestos es un
/// cruce: en la proyección el anillo saltaría de un borde del cuadrado al
/// otro y ese salto se trazaría como una raya cruzando el mapa entero. Se
/// corta ahí y cada trozo se cierra por su lado, heredando la latitud del
/// vértice de corte. No hay que interpolar nada porque el vértice ya existe.
List<List<double>> _partirEnElAntimeridiano(List<double> anillo) {
  final total = anillo.length ~/ 2;
  final cortes = <int>[];
  for (var k = 0; k < total; k++) {
    if (!_enAntimeridiano(anillo[k * 2])) continue;
    final antes = anillo[((k - 1 + total) % total) * 2];
    final despues = anillo[((k + 1) % total) * 2];
    if (antes * despues < 0) cortes.add(k);
  }
  if (cortes.isEmpty) return [anillo];

  final trozos = <List<double>>[];
  for (var i = 0; i < cortes.length; i++) {
    final inicio = cortes[i];
    final fin = cortes[(i + 1) % cortes.length];

    final cuerpo = <double>[];
    for (var k = (inicio + 1) % total; k != fin; k = (k + 1) % total) {
      cuerpo.add(anillo[k * 2]);
      cuerpo.add(anillo[k * 2 + 1]);
    }
    // Dos cortes seguidos: entre ellos no queda territorio que cerrar.
    if (cuerpo.isEmpty) continue;

    final lado = cuerpo[0] < 0 ? -180.0 : 180.0;
    trozos.add(<double>[
      lado,
      anillo[inicio * 2 + 1],
      ...cuerpo,
      lado,
      anillo[fin * 2 + 1],
    ]);
  }
  return trozos;
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
