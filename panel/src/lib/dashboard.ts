import { supabase } from './supabaseClient'

export interface MetricasHome {
  jugadoresTotales: number
  jugadoresActivos7d: number
  partidasHoy: number
  nivelesActivos: number
}

export interface AlertaContenido {
  tipo: string
  referenciaId: string
  titulo: string
  detalle: Record<string, unknown>
  etiqueta: string
}

export interface EventoActividad {
  tipo: string
  ocurridoEn: string
  texto: string
  detalle: Record<string, unknown>
  etiqueta: string | null
}

interface MetricasHomeRow {
  jugadores_totales: number
  jugadores_activos_7d: number
  partidas_hoy: number
  niveles_activos: number
}

interface AlertaContenidoRow {
  tipo: string
  referencia_id: string
  titulo: string
  detalle: Record<string, unknown>
}

interface EventoActividadRow {
  tipo: string
  ocurrido_en: string
  texto: string
  detalle: Record<string, unknown>
}

export async function fetchMetricasHome(): Promise<MetricasHome> {
  const { data, error } = await supabase.rpc('metricas_home')
  if (error) throw error

  const row = (data as MetricasHomeRow[] | null)?.[0]
  if (!row) throw new Error('metricas_home no devolvió ninguna fila')

  return {
    jugadoresTotales: row.jugadores_totales,
    jugadoresActivos7d: row.jugadores_activos_7d,
    partidasHoy: row.partidas_hoy,
    nivelesActivos: row.niveles_activos,
  }
}

// Nombre legible de un nivel: "<temática> · Nivel <orden>". Una consulta a
// `niveles` y una a `tematicas` (batch por ids únicos), no una por fila.
async function resolveNivelEtiquetas(
  nivelIds: (string | undefined)[],
): Promise<Map<string, string>> {
  const etiquetas = new Map<string, string>()
  const ids = [...new Set(nivelIds.filter((id): id is string => Boolean(id)))]
  if (ids.length === 0) return etiquetas

  const { data: niveles, error: nivelesError } = await supabase
    .from('niveles')
    .select('id, orden, tematica_id')
    .in('id', ids)
  if (nivelesError) throw nivelesError

  const tematicaIds = [...new Set((niveles ?? []).map((nivel) => nivel.tematica_id as string))]
  const { data: tematicas, error: tematicasError } =
    tematicaIds.length > 0
      ? await supabase.from('tematicas').select('id, nombre').in('id', tematicaIds)
      : { data: [] as { id: string; nombre: string }[], error: null }
  if (tematicasError) throw tematicasError

  const nombrePorTematica = new Map(
    (tematicas ?? []).map((tematica) => [tematica.id, tematica.nombre]),
  )

  for (const nivel of niveles ?? []) {
    const nombreTematica = nombrePorTematica.get(nivel.tematica_id) ?? 'Temática desconocida'
    etiquetas.set(nivel.id, `${nombreTematica} · Nivel ${nivel.orden}`)
  }

  return etiquetas
}

// Nombre legible de un desafío: "<lugar> (<tipo>)". Una sola consulta batch.
async function resolveDesafioEtiquetas(
  desafioIds: (string | undefined)[],
): Promise<Map<string, string>> {
  const etiquetas = new Map<string, string>()
  const ids = [...new Set(desafioIds.filter((id): id is string => Boolean(id)))]
  if (ids.length === 0) return etiquetas

  const { data, error } = await supabase
    .from('desafios')
    .select('id, tipo, nombre_lugar')
    .in('id', ids)
  if (error) throw error

  for (const desafio of data ?? []) {
    etiquetas.set(desafio.id, `${desafio.nombre_lugar} (${desafio.tipo})`)
  }

  return etiquetas
}

export async function fetchAlertasContenido(): Promise<AlertaContenido[]> {
  const { data, error } = await supabase.rpc('alertas_contenido')
  if (error) throw error

  const filas = (data ?? []) as AlertaContenidoRow[]
  const nivelIds = filas
    .filter((fila) => fila.tipo === 'nivel_baja_tasa')
    .map((fila) => fila.referencia_id)
  const desafioIds = filas
    .filter((fila) => fila.tipo === 'desafio_incompleto')
    .map((fila) => fila.referencia_id)

  const [nivelEtiquetas, desafioEtiquetas] = await Promise.all([
    resolveNivelEtiquetas(nivelIds),
    resolveDesafioEtiquetas(desafioIds),
  ])

  return filas.map((fila) => ({
    tipo: fila.tipo,
    referenciaId: fila.referencia_id,
    titulo: fila.titulo,
    detalle: fila.detalle,
    etiqueta:
      nivelEtiquetas.get(fila.referencia_id) ??
      desafioEtiquetas.get(fila.referencia_id) ??
      fila.titulo,
  }))
}

export async function fetchActividadReciente(limite = 20): Promise<EventoActividad[]> {
  const { data, error } = await supabase.rpc('actividad_reciente', { p_limite: limite })
  if (error) throw error

  const filas = (data ?? []) as EventoActividadRow[]
  const nivelIds = filas
    .filter((fila) => fila.tipo === 'nivel_superado')
    .map((fila) => fila.detalle?.nivel_id as string | undefined)

  const nivelEtiquetas = await resolveNivelEtiquetas(nivelIds)

  return filas.map((fila) => ({
    tipo: fila.tipo,
    ocurridoEn: fila.ocurrido_en,
    texto: fila.texto,
    detalle: fila.detalle,
    etiqueta:
      fila.tipo === 'nivel_superado'
        ? (nivelEtiquetas.get(fila.detalle?.nivel_id as string) ?? null)
        : null,
  }))
}
