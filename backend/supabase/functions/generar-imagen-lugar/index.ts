// INT-113: ilustra un lugar por invocacion (D1).
//
// Una invocacion por imagen y no una por lote: el limite de duracion de una
// Edge Function no da para 20 imagenes, y asi el fallo o la lentitud de una no
// arrastra al resto de la tanda.

import { ErrorFuncion } from '../_shared/errores.ts'
import { modeloImagen, pedirAOpenai } from '../_shared/openai.ts'
import { servirFuncionIa } from '../_shared/servir.ts'

const ESPERA_MAX_MS = 150_000
const MAX_TEXTO = 400

// WebP pesa una fraccion de PNG a igual tamano visible, y eso cuenta tres
// veces: memoria del wizard, subida al bucket y descarga en la app del jugador.
// El bucket challenge-media acepta image/webp.
const FORMATO = 'webp'
const MIME = 'image/webp'
const TAMANO = '1024x1024'
const CALIDAD = 'medium'

interface Peticion {
  nombre: string
  descripcion: string | null
  // Estilo permanente de la tematica (columna tematicas.prompt_imagen): decide
  // que y como se dibuja en esta tematica. Para "Banderas" es lo que hace que se
  // dibuje la bandera y no el paisaje del pais.
  estiloTematica: string | null
  // Indicaciones de esta tanda concreta: matizan el estilo, no lo sustituyen.
  indicaciones: string | null
}

function validarPeticion(cuerpo: unknown): Peticion {
  const p = cuerpo as Record<string, unknown>
  const nombre = typeof p?.nombre === 'string' ? p.nombre.trim() : ''
  const descripcion = typeof p?.descripcion === 'string' ? p.descripcion.trim() : ''

  if (!nombre) throw new ErrorFuncion('peticion_invalida', 'nombre vacio')

  const indicaciones = typeof p?.indicaciones === 'string' ? p.indicaciones.trim() : ''
  const estilo = typeof p?.estiloTematica === 'string' ? p.estiloTematica.trim() : ''

  return {
    nombre: nombre.slice(0, MAX_TEXTO),
    descripcion: descripcion ? descripcion.slice(0, MAX_TEXTO) : null,
    estiloTematica: estilo ? estilo.slice(0, MAX_TEXTO) : null,
    indicaciones: indicaciones ? indicaciones.slice(0, MAX_TEXTO) : null,
  }
}

function prompt(peticion: Peticion): string {
  return [
    `Ilustracion 3D estilo Pixar de: ${peticion.nombre}.`,
    peticion.descripcion ? `Se reconoce por: ${peticion.descripcion}.` : '',
    // El estilo de la tematica gobierna el motivo y prevalece sobre las reglas
    // genericas de mas abajo: una bandera no es un paisaje, y una tematica de
    // banderas necesita que se dibuje el simbolo, no el pais.
    peticion.estiloTematica
      ? `Estilo de esta tematica, manda sobre cualquier regla generica de las siguientes: ${peticion.estiloTematica}.`
      : '',
    // Las indicaciones de la tanda matizan, no sustituyen.
    peticion.indicaciones
      ? `Indicaciones de esta tanda, que matizan lo anterior: ${peticion.indicaciones}.`
      : '',
    'Render 3D estilizado y colorido, iluminacion calida y cinematografica,',
    'colores saturados, aspecto de pelicula de animacion moderna.',
    'El motivo ocupa el centro del encuadre y se reconoce con claridad.',
    // Coherencia geografica, pero solo cuando lo que se dibuja es un lugar
    // fisico: en pruebas el modelo planto el Coliseo en un desierto con canones,
    // y eso vuelve injusta la pregunta porque el jugador apunta al mapa por el
    // paisaje que ve.
    'Si lo que se ilustra es un lugar fisico, su entorno debe corresponder a su',
    'geografia real: terreno, vegetacion, clima y luz propios de su latitud, sin',
    'trasladarlo a otro paisaje ni inventar desiertos, montanas o costas que no',
    'existen ahi.',
    'Aun asi, el fondo no debe delatar la respuesta: sin edificios ni monumentos',
    'reconocibles alrededor, sin carteles ni senalizacion.',
    'Sin texto, sin letras, sin numeros, sin logotipos ni marcas de agua.',
    'Sin personas en primer plano.',
  ]
    .filter(Boolean)
    .join(' ')
}

function extraerImagen(respuesta: unknown): string {
  const base64 = (respuesta as { data?: { b64_json?: string }[] })?.data?.[0]?.b64_json
  if (typeof base64 !== 'string' || !base64) {
    throw new ErrorFuncion('respuesta_invalida', 'la respuesta no trae imagen en base64')
  }
  return base64
}

servirFuncionIa(async (cuerpo) => {
  const peticion = validarPeticion(cuerpo)

  const respuesta = await pedirAOpenai(
    'images/generations',
    {
      model: modeloImagen(),
      prompt: prompt(peticion),
      n: 1,
      size: TAMANO,
      quality: CALIDAD,
      output_format: FORMATO,
    },
    ESPERA_MAX_MS,
  )

  return { imagenBase64: extraerImagen(respuesta), mime: MIME }
})
