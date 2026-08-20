import { supabase } from './supabaseClient'
import type { TipoDesafio } from './preguntas'
import type { Dificultad } from './dificultad'

export type TipoMedia = Extract<TipoDesafio, 'imagen' | 'video'>

export interface PreguntaDetalle {
  id: string
  nombre: string
  tipo: TipoDesafio
  nombreLugar: string
  pista: string | null
  ciudad: string | null
  pais: string | null
  textoPregunta: string | null
  imagenUrl: string | null
  videoUrl: string | null
  latReal: number
  lngReal: number
  activo: boolean
  tematicaId: string
  dificultad: Dificultad
}

interface DesafioDetalleRow {
  id: string
  nombre: string
  tipo: TipoDesafio
  nombre_lugar: string
  pista: string | null
  ciudad: string | null
  pais: string | null
  texto_pregunta: string | null
  imagen_url: string | null
  video_url: string | null
  lat_real: number
  lng_real: number
  activo: boolean
  tematica_id: string
  dificultad: Dificultad
}

export async function fetchPregunta(id: string): Promise<PreguntaDetalle> {
  const { data, error } = await supabase
    .from('desafios')
    .select(
      'id, nombre, tipo, nombre_lugar, pista, ciudad, pais, texto_pregunta, imagen_url, video_url, lat_real, lng_real, activo, tematica_id, dificultad',
    )
    .eq('id', id)
    .single()
  if (error) throw new Error(error.message)

  const row = data as DesafioDetalleRow
  return {
    id: row.id,
    nombre: row.nombre,
    tipo: row.tipo,
    nombreLugar: row.nombre_lugar,
    pista: row.pista,
    ciudad: row.ciudad,
    pais: row.pais,
    textoPregunta: row.texto_pregunta,
    imagenUrl: row.imagen_url,
    videoUrl: row.video_url,
    latReal: row.lat_real,
    lngReal: row.lng_real,
    activo: row.activo,
    tematicaId: row.tematica_id,
    dificultad: row.dificultad,
  }
}

export interface TematicaOpcion {
  id: string
  nombre: string
  // Estilo de ilustración de la temática (INT-113 delta-1). Viene en la misma
  // consulta que ya cargaba el formulario: el generador lo necesita en el mismo
  // instante en que se cambia el selector, para poder mostrarlo.
  promptImagen: string | null
}

interface TematicaOpcionRow {
  id: string
  nombre: string
  prompt_imagen: string | null
}

export async function fetchTematicasParaPregunta(): Promise<TematicaOpcion[]> {
  const { data, error } = await supabase
    .from('tematicas')
    .select('id, nombre, prompt_imagen')
    .order('orden', { ascending: true })
  if (error) throw new Error(error.message)

  return ((data ?? []) as TematicaOpcionRow[]).map((row) => ({
    id: row.id,
    nombre: row.nombre,
    promptImagen: row.prompt_imagen,
  }))
}

const MAX_MEDIA_BYTES = 50 * 1024 * 1024

const MIME_PERMITIDOS: Record<TipoMedia, string[]> = {
  imagen: ['image/jpeg', 'image/png', 'image/webp'],
  video: ['video/mp4'],
}

const EXTENSION_POR_MIME: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
  'video/mp4': 'mp4',
}

export function validarArchivoMedia(tipo: TipoMedia, file: File): string | null {
  if (!MIME_PERMITIDOS[tipo].includes(file.type)) {
    return tipo === 'imagen' ? 'La imagen debe ser JPG, PNG o WEBP.' : 'El vídeo debe ser MP4.'
  }
  if (file.size > MAX_MEDIA_BYTES) {
    return 'El archivo supera el tamaño máximo de 50 MiB.'
  }
  return null
}

// La convencion `{tipo}/{desafio_id}.{extension}` del spec challenge-media-storage
// vive aqui y en un solo sitio: el guardado de lotes generados con IA
// (lib/loteIA.ts) la necesita tambien para poder limpiar una subida huerfana.
export function rutaMediaDesafio(id: string, tipo: TipoMedia, file: File): string {
  const extension = EXTENSION_POR_MIME[file.type] ?? file.name.split('.').pop() ?? 'bin'
  return `${tipo}/${id}.${extension}`
}

export async function subirMediaDesafio(id: string, tipo: TipoMedia, file: File): Promise<string> {
  const ruta = rutaMediaDesafio(id, tipo, file)

  const { error } = await supabase.storage
    .from('challenge-media')
    .upload(ruta, file, { upsert: true, contentType: file.type })
  if (error) throw new Error(error.message)

  const { data } = supabase.storage.from('challenge-media').getPublicUrl(ruta)
  return data.publicUrl
}

export interface GuardarPreguntaInput {
  id: string | null
  nombre: string
  tipo: TipoDesafio
  nombreLugar: string
  pista: string | null
  ciudad: string | null
  pais: string | null
  textoPregunta: string | null
  latReal: number
  lngReal: number
  activo: boolean
  tematicaId: string
  dificultad: Dificultad
  archivo: File | null
  imagenUrlActual: string | null
  videoUrlActual: string | null
}

export async function guardarPregunta(input: GuardarPreguntaInput): Promise<{ id: string }> {
  const id = input.id ?? crypto.randomUUID()

  let imagenUrl = input.tipo === 'imagen' ? input.imagenUrlActual : null
  let videoUrl = input.tipo === 'video' ? input.videoUrlActual : null

  if (input.archivo && (input.tipo === 'imagen' || input.tipo === 'video')) {
    const url = await subirMediaDesafio(id, input.tipo, input.archivo)
    if (input.tipo === 'imagen') imagenUrl = url
    else videoUrl = url
  }

  const pista = input.pista?.trim() ? input.pista.trim() : null
  // '' se guarda como NULL, no como cadena vacía (INT-122, D10): la app
  // distingue "sin ciudad" de "ciudad en blanco" para decidir si rotula la
  // ciudad o cae a nombre_lugar.
  const ciudad = input.ciudad?.trim() ? input.ciudad.trim() : null
  const pais = input.pais?.trim() ? input.pais.trim() : null

  const { error } = await supabase.from('desafios').upsert({
    id,
    nombre: input.nombre,
    tipo: input.tipo,
    imagen_url: imagenUrl,
    video_url: videoUrl,
    texto_pregunta: input.tipo === 'pregunta_texto' ? input.textoPregunta : null,
    lat_real: input.latReal,
    lng_real: input.lngReal,
    nombre_lugar: input.nombreLugar,
    pista,
    ciudad,
    pais,
    activo: input.activo,
    tematica_id: input.tematicaId,
    dificultad: input.dificultad,
  })
  if (error) throw new Error(error.message)

  return { id }
}
