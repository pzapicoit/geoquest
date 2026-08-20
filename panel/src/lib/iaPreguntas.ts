// Acceso del panel a las Edge Functions de generación con IA (INT-113).
//
// Las funciones custodian la clave de OpenAI; aquí vive la orquestación: pedir
// candidatos, deduplicarlos contra el banco y repetir si la tanda queda corta.
// El error nunca se muestra crudo: cada código tiene su mensaje en castellano.

import { supabase } from './supabaseClient'
import type { Dificultad } from './dificultad'
import { filtrarCandidatosNuevos, type LugarComparable } from './duplicadosLugar'

export const MAX_RONDAS_EXTRA = 2
export const IMAGENES_EN_PARALELO = 3

// Coste aproximado por imagen del modelo de imagen por defecto, para avisar al
// admin antes de lanzar la tanda. Es una estimación, no una factura.
export const COSTE_APROX_POR_IMAGEN_USD = 0.04

export interface CandidatoIA extends LugarComparable {
  descripcion: string
  // Ciudad y país del objetivo (INT-122). `null` cuando el candidato no está
  // dentro de ninguna localidad, o cuando el objetivo no tiene país real: es
  // un valor legítimo, no un dato pendiente, así que no descarta al candidato.
  ciudad: string | null
  pais: string | null
}

const CODIGOS = [
  'no_autorizado',
  'secreto_no_configurado',
  'peticion_invalida',
  'respuesta_invalida',
  'openai_error',
  'fallo_desconocido',
] as const

export type CodigoErrorIa = (typeof CODIGOS)[number]

const MENSAJES: Record<CodigoErrorIa, string> = {
  no_autorizado:
    'Tu sesión no tiene permisos de administrador para generar preguntas. Vuelve a entrar e inténtalo otra vez.',
  secreto_no_configurado:
    'La clave de OpenAI no está configurada como secreto de las funciones del proyecto de Supabase. No se ha generado nada.',
  peticion_invalida:
    'La configuración de la tanda no es válida. Revisa la temática, la dificultad y la cantidad.',
  respuesta_invalida: 'La IA ha respondido en un formato que no se entiende. Vuelve a intentarlo.',
  openai_error: 'La IA no ha respondido. Vuelve a intentarlo en un momento.',
  fallo_desconocido:
    'No se ha podido contactar con el generador. Revisa la conexión y vuelve a intentarlo.',
}

export class ErrorIa extends Error {
  constructor(readonly codigo: CodigoErrorIa) {
    super(MENSAJES[codigo])
    this.name = 'ErrorIa'
  }
}

export function mensajeDeError(error: unknown): string {
  if (error instanceof ErrorIa) return error.message
  return MENSAJES.fallo_desconocido
}

function esCodigo(valor: unknown): valor is CodigoErrorIa {
  return typeof valor === 'string' && (CODIGOS as readonly string[]).includes(valor)
}

// supabase-js envuelve una respuesta no-2xx en un error cuyo `context` es la
// Response: el código propio de la función viene en su cuerpo. Si no se puede
// leer (fallo de red, o el 401 que devuelve la plataforma antes de llegar a
// nuestro código) queda como fallo desconocido.
async function codigoDelError(error: unknown): Promise<CodigoErrorIa> {
  const contexto = (error as { context?: { json?: () => Promise<unknown> } } | null)?.context

  if (typeof contexto?.json === 'function') {
    try {
      const cuerpo = (await contexto.json()) as { codigo?: unknown }
      if (esCodigo(cuerpo?.codigo)) return cuerpo.codigo
    } catch {
      // Cuerpo ilegible: se trata como fallo desconocido.
    }
  }

  return 'fallo_desconocido'
}

export interface PeticionCandidatos {
  tematica: string
  dificultad: Dificultad
  cantidad: number
  // Los desafíos que ya tiene la temática, con sus coordenadas. Van a la función
  // por dos razones: para que no los repita, y porque son lo que le dice qué
  // cuenta como respuesta aquí. El banco es heterogéneo —«Banderas» responde
  // países, «Olimpiadas» ciudades, «Peliculas» títulos de película—, así que
  // fijar el tipo de respuesta en el prompt acierta en una temática y estropea
  // las demás.
  existentes: LugarComparable[]
  indicaciones: string | null
}

export async function proponerLugares(peticion: PeticionCandidatos): Promise<CandidatoIA[]> {
  const { data, error } = await supabase.functions.invoke<{ lugares?: CandidatoIA[] }>(
    'proponer-lugares',
    { body: peticion },
  )
  if (error) throw new ErrorIa(await codigoDelError(error))

  return (data?.lugares ?? []).map((lugar) => ({
    nombre: lugar.nombre,
    lat: lugar.lat,
    lng: lugar.lng,
    // Una función anterior a INT-122 no manda estas claves; se resuelven a
    // `null`, que es exactamente lo que se guardaba antes.
    ciudad: lugar.ciudad ?? null,
    pais: lugar.pais ?? null,
    descripcion: lugar.descripcion,
  }))
}

function blobDesdeBase64(base64: string, mime: string): Blob {
  const binario = atob(base64)
  const bytes = new Uint8Array(binario.length)
  for (let i = 0; i < binario.length; i += 1) bytes[i] = binario.charCodeAt(i)
  return new Blob([bytes], { type: mime })
}

export async function generarImagenLugar(lugar: {
  nombre: string
  descripcion: string | null
  // Estilo permanente de la temática: decide qué y cómo se dibuja aquí.
  estiloTematica: string | null
  // Indicaciones de esta tanda: matizan lo anterior. Van separadas a propósito
  // (D2): concatenarlas perdería cuál gobierna el motivo y cuál el contenido.
  indicaciones: string | null
}): Promise<Blob> {
  const { data, error } = await supabase.functions.invoke<{
    imagenBase64?: string
    mime?: string
  }>('generar-imagen-lugar', { body: lugar })
  if (error) throw new ErrorIa(await codigoDelError(error))
  if (!data?.imagenBase64) throw new ErrorIa('respuesta_invalida')

  return blobDesdeBase64(data.imagenBase64, data.mime ?? 'image/webp')
}

interface DesafioLugarRow {
  nombre_lugar: string
  lat_real: number
  lng_real: number
}

export async function fetchLugaresExistentes(tematicaId: string): Promise<LugarComparable[]> {
  const { data, error } = await supabase
    .from('desafios')
    .select('nombre_lugar, lat_real, lng_real')
    .eq('tematica_id', tematicaId)
  if (error) throw new Error(error.message)

  return ((data ?? []) as DesafioLugarRow[]).map((row) => ({
    nombre: row.nombre_lugar,
    lat: row.lat_real,
    lng: row.lng_real,
  }))
}

export interface TandaCandidatos {
  candidatos: CandidatoIA[]
  tandaCorta: boolean
}

// Pide candidatos y repite mientras la deduplicación deje la tanda corta, hasta
// MAX_RONDAS_EXTRA rondas adicionales. El tope evita el bucle infinito cuando la
// temática está agotada, que es el modo de fallo real: pedir 20 monumentos
// cuando solo quedan 6 sin usar.
export async function pedirCandidatosDeduplicados(entrada: {
  tematicaId: string
  tematicaNombre: string
  dificultad: Dificultad
  cantidad: number
  indicaciones: string | null
}): Promise<TandaCandidatos> {
  const existentes = await fetchLugaresExistentes(entrada.tematicaId)
  const aceptados: CandidatoIA[] = []
  const conocidos: LugarComparable[] = [...existentes]

  for (let ronda = 0; ronda <= MAX_RONDAS_EXTRA; ronda += 1) {
    const faltan = entrada.cantidad - aceptados.length
    if (faltan <= 0) break

    const propuestos = await proponerLugares({
      tematica: entrada.tematicaNombre,
      dificultad: entrada.dificultad,
      cantidad: faltan,
      existentes: conocidos,
      indicaciones: entrada.indicaciones,
    })
    if (propuestos.length === 0) break

    // Se suman también los rechazados: si no, la ronda siguiente vuelve a
    // proponer lo mismo y nunca converge.
    propuestos.forEach((lugar) =>
      conocidos.push({ nombre: lugar.nombre, lat: lugar.lat, lng: lugar.lng }),
    )

    const nuevos = filtrarCandidatosNuevos(propuestos, [...existentes, ...aceptados])
    aceptados.push(...nuevos.slice(0, faltan))
  }

  return { candidatos: aceptados, tandaCorta: aceptados.length < entrada.cantidad }
}

// Mantiene `limite` tareas en vuelo: secuencial, 20 imágenes son una espera
// larguísima; sin límite, el rate limit de OpenAI empieza a devolver errores que
// el admin lee como "la IA falla".
export async function ejecutarConLimite<T>(
  items: T[],
  limite: number,
  tarea: (item: T) => Promise<void>,
): Promise<void> {
  let siguiente = 0

  const trabajadores = Array.from({ length: Math.max(1, Math.min(limite, items.length)) }, () =>
    (async () => {
      while (siguiente < items.length) {
        const indice = siguiente
        siguiente += 1
        await tarea(items[indice])
      }
    })(),
  )

  await Promise.all(trabajadores)
}
