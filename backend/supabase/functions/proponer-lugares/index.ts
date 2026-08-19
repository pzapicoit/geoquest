// INT-113: propone lugares reales para una tanda de preguntas del banco.
//
// El prompt se construye aqui, no lo manda el cliente (D3): si lo mandara, esta
// funcion seria un proxy generico de OpenAI con la clave del proyecto detras.
// El cliente solo elige tematica, dificultad, cantidad, exclusiones y sus
// indicaciones extra.

import { ErrorFuncion } from '../_shared/errores.ts'
import { modeloTexto, pedirAOpenai } from '../_shared/openai.ts'
import { servirFuncionIa } from '../_shared/servir.ts'

const ESPERA_MAX_MS = 90_000
const MAX_CANTIDAD = 20
const MAX_EXISTENTES = 60
const MAX_INDICACIONES = 500

const DIFICULTADES: Record<string, string> = {
  facil: 'lugares iconicos que casi cualquiera reconoce de vista',
  normal: 'lugares conocidos, pero no de los mas iconicos del mundo',
  intermedio: 'lugares que exigen cierta cultura geografica',
  dificil: 'lugares para aficionados a la geografia, poco presentes en la cultura popular',
  muy_dificil: 'lugares para expertos, raramente fotografiados o muy remotos',
}

interface LugarExistente {
  nombre: string
  lat: number
  lng: number
}

interface Peticion {
  tematica: string
  dificultad: string
  cantidad: number
  // Los desafios que ya tiene esa tematica. Sirven a la vez de lista de
  // exclusion y de definicion de que cuenta como respuesta: el banco real es
  // muy variado (paises en "Banderas", ciudades en "Olimpiadas", titulos de
  // pelicula en "Peliculas", monumentos en "Monumentos"), asi que el tipo de
  // respuesta no se puede fijar en el prompt sin equivocarse en tres de cuatro.
  existentes: LugarExistente[]
  indicaciones: string | null
}

interface Lugar {
  nombre: string
  lat: number
  lng: number
  descripcion: string
}

const ESQUEMA_RESPUESTA = {
  name: 'lugares_propuestos',
  strict: true,
  schema: {
    type: 'object',
    properties: {
      lugares: {
        type: 'array',
        items: {
          type: 'object',
          properties: {
            nombre: { type: 'string' },
            lat: { type: 'number' },
            lng: { type: 'number' },
            descripcion: { type: 'string' },
          },
          required: ['nombre', 'lat', 'lng', 'descripcion'],
          additionalProperties: false,
        },
      },
    },
    required: ['lugares'],
    additionalProperties: false,
  },
}

function validarPeticion(cuerpo: unknown): Peticion {
  const p = cuerpo as Record<string, unknown>
  const tematica = typeof p?.tematica === 'string' ? p.tematica.trim() : ''
  const dificultad = typeof p?.dificultad === 'string' ? p.dificultad : ''
  const cantidad = typeof p?.cantidad === 'number' ? Math.trunc(p.cantidad) : 0
  const indicaciones = typeof p?.indicaciones === 'string' ? p.indicaciones.trim() : ''

  if (!tematica) throw new ErrorFuncion('peticion_invalida', 'tematica vacia')
  if (!DIFICULTADES[dificultad]) {
    throw new ErrorFuncion('peticion_invalida', `dificultad desconocida: ${dificultad}`)
  }
  if (cantidad < 1 || cantidad > MAX_CANTIDAD) {
    throw new ErrorFuncion('peticion_invalida', `cantidad fuera de rango: ${cantidad}`)
  }

  const existentes = Array.isArray(p?.existentes)
    ? (p.existentes as unknown[])
        .filter((lugar): lugar is LugarExistente => {
          const l = lugar as Record<string, unknown>
          return (
            typeof l?.nombre === 'string' &&
            l.nombre.trim().length > 0 &&
            typeof l?.lat === 'number' &&
            typeof l?.lng === 'number'
          )
        })
        .slice(0, MAX_EXISTENTES)
    : []

  return {
    tematica,
    dificultad,
    cantidad,
    existentes,
    indicaciones: indicaciones ? indicaciones.slice(0, MAX_INDICACIONES) : null,
  }
}

function instrucciones(peticion: Peticion): string {
  const ejemplos = peticion.existentes
    .map((lugar) => `- ${lugar.nombre} (${lugar.lat.toFixed(4)}, ${lugar.lng.toFixed(4)})`)
    .join('\n')

  return [
    'Eres documentalista geografico de un juego en el que el jugador ve una',
    'ilustracion y tiene que senalar en un mapa mundial el lugar al que',
    'corresponde.',
    '',
    `Propon exactamente ${peticion.cantidad} respuestas nuevas para la tematica`,
    `"${peticion.tematica}", con esta dificultad: ${DIFICULTADES[peticion.dificultad]}.`,
    '',
    // El tipo de respuesta lo define el banco, no el prompt: en "Banderas" la
    // respuesta es un pais con las coordenadas de su capital, en "Peliculas" es
    // el titulo de la pelicula con las coordenadas del rodaje. Fijarlo aqui
    // seria acertar en una tematica y estropear las demas.
    ejemplos
      ? [
          'Que cuenta como respuesta en esta tematica lo definen las que ya',
          'existen en su banco:',
          ejemplos,
          '',
          'Sigue exactamente ese mismo criterio: si son paises, propon paises; si',
          'son ciudades, ciudades; si son titulos de obra, titulos de obra con las',
          'coordenadas del lugar que les corresponde. Y no repitas ninguna de',
          'ellas, ni una variante del mismo con otro nombre o en otro idioma.',
        ].join('\n')
      : [
          'Esta tematica no tiene todavia ninguna pregunta, asi que propon lugares',
          'reales concretos y reconocibles, cada uno con el nombre por el que se',
          'conoce.',
        ].join('\n'),
    '',
    'Reglas de formato, estas no se negocian:',
    '- "nombre": como se conoce la respuesta, en castellano, sin ambiguedad.',
    '- "lat" y "lng": coordenadas WGS84 reales, con al menos cuatro decimales,',
    '  del punto que representa esa respuesta en el mapa del juego.',
    '- "descripcion": una sola frase de lo que se ve, SIN nombrar la respuesta y',
    '  SIN nombrar su pais, su ciudad ni su gentilicio. Es la pista que leera el',
    '  jugador, asi que no debe delatar la respuesta.',
  ]
    .filter(Boolean)
    .join('\n')
}

function extraerLugares(respuesta: unknown, cantidad: number): Lugar[] {
  const contenido = (respuesta as { choices?: { message?: { content?: string } }[] })?.choices?.[0]
    ?.message?.content
  if (typeof contenido !== 'string') {
    throw new ErrorFuncion('respuesta_invalida', 'la respuesta no trae contenido de texto')
  }

  let interpretado: unknown
  try {
    interpretado = JSON.parse(contenido)
  } catch {
    throw new ErrorFuncion('respuesta_invalida', 'el contenido no es JSON')
  }

  const lugares = (interpretado as { lugares?: unknown })?.lugares
  if (!Array.isArray(lugares)) {
    throw new ErrorFuncion('respuesta_invalida', 'el JSON no trae la lista de lugares')
  }

  // Coordenadas fuera de rango o campos vacios se descartan aqui: una fila de
  // desafios con lat 120 no la deja pasar el CHECK de la base, y es mejor que
  // el candidato no llegue a la revision que fallar al guardar el lote.
  return lugares
    .filter((lugar): lugar is Lugar => {
      const l = lugar as Record<string, unknown>
      return (
        typeof l?.nombre === 'string' &&
        l.nombre.trim().length > 0 &&
        typeof l?.descripcion === 'string' &&
        typeof l?.lat === 'number' &&
        typeof l?.lng === 'number' &&
        Number.isFinite(l.lat) &&
        Number.isFinite(l.lng) &&
        l.lat >= -90 &&
        l.lat <= 90 &&
        l.lng >= -180 &&
        l.lng <= 180
      )
    })
    .slice(0, cantidad)
    .map((lugar) => ({
      nombre: lugar.nombre.trim(),
      lat: lugar.lat,
      lng: lugar.lng,
      descripcion: lugar.descripcion.trim(),
    }))
}

servirFuncionIa(async (cuerpo) => {
  const peticion = validarPeticion(cuerpo)

  const respuesta = await pedirAOpenai(
    'chat/completions',
    {
      model: modeloTexto(),
      messages: [
        { role: 'system', content: instrucciones(peticion) },
        {
          // Las indicaciones del admin manda sobre QUE proponer -- si pide
          // "capitales y sus banderas", eso gana al criterio deducido del
          // banco--, pero no sobre las reglas de formato ni sobre no repetir.
          role: 'user',
          content: peticion.indicaciones
            ? `Indicaciones del administrador. Tienen prioridad para decidir QUE proponer, por encima del criterio deducido del banco; no cambian las reglas de formato ni la de no repetir: ${peticion.indicaciones}`
            : 'Sin indicaciones adicionales del administrador.',
        },
      ],
      response_format: { type: 'json_schema', json_schema: ESQUEMA_RESPUESTA },
    },
    ESPERA_MAX_MS,
  )

  return { lugares: extraerLugares(respuesta, peticion.cantidad) }
})
