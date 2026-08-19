import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { Link } from 'react-router-dom'
import { DIFICULTADES, type Dificultad } from '../lib/dificultad'
import { fetchTematicasParaPregunta, type TematicaOpcion } from '../lib/preguntaForm'
import {
  COSTE_APROX_POR_IMAGEN_USD,
  IMAGENES_EN_PARALELO,
  ejecutarConLimite,
  generarImagenLugar,
  mensajeDeError,
  pedirCandidatosDeduplicados,
  type CandidatoIA,
} from '../lib/iaPreguntas'
import { guardarLoteIA, type ResultadoGuardado } from '../lib/loteIA'

const CANTIDAD_MINIMA = 3
const CANTIDAD_MAXIMA = 20
const CANTIDAD_POR_DEFECTO = 8

type Fase = 'configurar' | 'proponiendo' | 'revisar' | 'ilustrando' | 'guardado'
type EstadoImagen = 'sin_generar' | 'en_cola' | 'generando' | 'lista' | 'fallida'

interface Candidato extends CandidatoIA {
  id: string
  seleccionado: boolean
  estado: EstadoImagen
  imagen: Blob | null
  urlPrevia: string | null
}

interface Resumen {
  creadas: number
  noGuardados: ResultadoGuardado[]
  activas: boolean
}

const PISTA_DIFICULTAD: Record<Dificultad, string> = {
  facil: 'lugares que casi cualquiera reconoce',
  normal: 'conocidos, pero no icónicos',
  intermedio: 'piden algo de cultura geográfica',
  dificil: 'para aficionados a la geografía',
  muy_dificil: 'para expertos',
}

const PUNTO_DIFICULTAD: Record<Dificultad, string> = {
  facil: 'bg-brand-teal',
  normal: 'bg-brand-blue',
  intermedio: 'bg-brand-gold',
  dificil: 'bg-brand-special',
  muy_dificil: 'bg-brand-error',
}

const BADGE_DIFICULTAD: Record<Dificultad, string> = {
  facil: 'bg-brand-teal/10 text-brand-teal',
  normal: 'bg-brand-blue/10 text-brand-blue',
  intermedio: 'bg-brand-gold/25 text-[#996100]',
  dificil: 'bg-brand-special/10 text-brand-special',
  muy_dificil: 'bg-brand-error/10 text-[#B3282D]',
}

const ETIQUETA_ESTADO: Record<EstadoImagen, string> = {
  sin_generar: 'Sin generar',
  en_cola: 'En cola',
  generando: 'Generando (3D Pixar)',
  lista: 'Ilustración lista',
  fallida: 'No se pudo generar',
}

const PUNTO_ESTADO: Record<EstadoImagen, string> = {
  sin_generar: 'bg-brand-night/20',
  en_cola: 'bg-brand-night/20',
  generando: 'bg-brand-special',
  lista: 'bg-brand-teal',
  fallida: 'bg-brand-error',
}

const FONDO_IA = { background: 'linear-gradient(140deg, #7C5CFF, #5B3FD1)' }
const FONDO_GUARDAR = { background: 'linear-gradient(140deg, #2BC0A8, #1B6FA8)' }

const dinero = new Intl.NumberFormat('es-ES', {
  style: 'currency',
  currency: 'USD',
  maximumFractionDigits: 2,
})

function formatearCoordenadas(lat: number, lng: number): string {
  return `${lat.toFixed(4)}, ${lng.toFixed(4)}`
}

function Girador({ clase }: { clase: string }) {
  return (
    <span
      role="presentation"
      className={`inline-block animate-spin rounded-full border-2 border-brand-special/25 border-t-brand-special ${clase}`}
    />
  )
}

export function PreguntasGenerarIA() {
  const [tematicas, setTematicas] = useState<TematicaOpcion[]>([])
  const [tematicaId, setTematicaId] = useState('')
  const [dificultad, setDificultad] = useState<Dificultad>('normal')
  const [cantidad, setCantidad] = useState(CANTIDAD_POR_DEFECTO)
  const [indicaciones, setIndicaciones] = useState('')
  // Las indicaciones con las que se pidió la tanda en curso. La ilustración usa
  // estas, no lo que haya en el textarea ahora: si el admin lo edita mientras se
  // generan las imágenes, las de esta tanda no deben cambiar a media tanda.
  const [indicacionesTanda, setIndicacionesTanda] = useState<string | null>(null)
  // Y el estilo de la temática con el que se lanzó, por lo mismo: si se cambia de
  // temática a media tanda, las imágenes en vuelo siguen siendo de la anterior.
  const [estiloTanda, setEstiloTanda] = useState<string | null>(null)

  const [fase, setFase] = useState<Fase>('configurar')
  const [candidatos, setCandidatos] = useState<Candidato[]>([])
  const [tandaCorta, setTandaCorta] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [publicarActivas, setPublicarActivas] = useState(true)
  const [guardando, setGuardando] = useState(false)
  const [resumen, setResumen] = useState<Resumen | null>(null)

  // Las previsualizaciones son objectURL: si no se revocan, cada tanda
  // descartada deja su memoria retenida hasta recargar la pestaña.
  const urlsCreadas = useRef<Set<string>>(new Set())

  // Identifica la tanda en curso. Las ilustraciones siguen en vuelo después de
  // descartar la tanda o de cerrar la pantalla —no hay forma de cancelar la
  // invocación—, así que al volver comprueban si su tanda sigue siendo la
  // vigente: si no, su imagen ya no tiene dueño y se descarta en el sitio en vez
  // de crear un objectURL que nadie revocará y de escribir estado de una tanda
  // que ya no existe.
  const tandaVigente = useRef(0)
  const montado = useRef(true)

  const liberarPrevias = useCallback(() => {
    urlsCreadas.current.forEach((url) => URL.revokeObjectURL(url))
    urlsCreadas.current.clear()
  }, [])

  const invalidarTanda = useCallback(() => {
    tandaVigente.current += 1
    liberarPrevias()
  }, [liberarPrevias])

  // `montado` se reafirma en el cuerpo del efecto, no solo se apaga en el
  // cleanup: en desarrollo StrictMode monta, desmonta y remonta el componente, y
  // los refs sobreviven a ese ciclo. Sin esta línea la guarda se queda en false
  // para siempre y ninguna ilustración llega a pintarse.
  useEffect(() => {
    montado.current = true
    return () => {
      montado.current = false
      liberarPrevias()
    }
  }, [liberarPrevias])

  useEffect(() => {
    let vigente = true
    fetchTematicasParaPregunta()
      .then((lista) => {
        if (!vigente) return
        setTematicas(lista)
        setTematicaId((actual) => actual || (lista[0]?.id ?? ''))
      })
      .catch(() => {
        if (!vigente) return
        setError('No se han podido cargar las temáticas.')
      })
    return () => {
      vigente = false
    }
  }, [])

  const tematica = tematicas.find((opcion) => opcion.id === tematicaId) ?? null
  const seleccionados = candidatos.filter((candidato) => candidato.seleccionado)
  const listas = seleccionados.filter((candidato) => candidato.estado === 'lista')
  const enCurso = seleccionados.some(
    (candidato) => candidato.estado === 'en_cola' || candidato.estado === 'generando',
  )
  const todasMarcadas = candidatos.length > 0 && seleccionados.length === candidatos.length

  const costeEstimado = useMemo(
    () => dinero.format(seleccionados.length * COSTE_APROX_POR_IMAGEN_USD),
    [seleccionados.length],
  )

  const reiniciarTanda = () => {
    invalidarTanda()
    setCandidatos([])
    setTandaCorta(false)
    setResumen(null)
    setFase('configurar')
  }

  const generarPropuestas = async () => {
    if (!tematica) return

    invalidarTanda()
    setError(null)
    setResumen(null)
    setCandidatos([])
    setTandaCorta(false)
    setFase('proponiendo')

    const indicacionesDeLaTanda = indicaciones.trim() || null
    setIndicacionesTanda(indicacionesDeLaTanda)
    setEstiloTanda(tematica.promptImagen)

    try {
      const tanda = await pedirCandidatosDeduplicados({
        tematicaId: tematica.id,
        tematicaNombre: tematica.nombre,
        dificultad,
        cantidad,
        indicaciones: indicacionesDeLaTanda,
      })

      setCandidatos(
        tanda.candidatos.map((candidato, indice) => ({
          ...candidato,
          id: `${indice}-${candidato.nombre}`,
          seleccionado: true,
          estado: 'sin_generar',
          imagen: null,
          urlPrevia: null,
        })),
      )
      setTandaCorta(tanda.tandaCorta)
      setFase('revisar')
    } catch (fallo) {
      setError(mensajeDeError(fallo))
      setFase('configurar')
    }
  }

  const cambiarEstado = useCallback((id: string, cambios: Partial<Candidato>) => {
    setCandidatos((actuales) =>
      actuales.map((candidato) => (candidato.id === id ? { ...candidato, ...cambios } : candidato)),
    )
  }, [])

  const ilustrar = useCallback(
    async (candidato: Candidato) => {
      const tanda = tandaVigente.current
      const sigueVigente = () => montado.current && tandaVigente.current === tanda

      cambiarEstado(candidato.id, { estado: 'generando' })
      try {
        const imagen = await generarImagenLugar({
          nombre: candidato.nombre,
          descripcion: candidato.descripcion,
          estiloTematica: estiloTanda,
          indicaciones: indicacionesTanda,
        })
        if (!sigueVigente()) return

        const url = URL.createObjectURL(imagen)
        urlsCreadas.current.add(url)
        cambiarEstado(candidato.id, { estado: 'lista', imagen, urlPrevia: url })
      } catch (fallo) {
        if (!sigueVigente()) return

        setError(mensajeDeError(fallo))
        cambiarEstado(candidato.id, { estado: 'fallida', imagen: null, urlPrevia: null })
      }
    },
    [cambiarEstado, estiloTanda, indicacionesTanda],
  )

  const generarImagenes = async () => {
    const pendientes = candidatos.filter(
      (candidato) => candidato.seleccionado && candidato.estado !== 'lista',
    )
    if (pendientes.length === 0) return

    setError(null)
    setFase('ilustrando')
    setCandidatos((actuales) =>
      actuales.map((candidato) =>
        candidato.seleccionado && candidato.estado !== 'lista'
          ? { ...candidato, estado: 'en_cola' }
          : candidato,
      ),
    )

    await ejecutarConLimite(pendientes, IMAGENES_EN_PARALELO, ilustrar)
  }

  const rehacer = async (candidato: Candidato) => {
    setError(null)
    await ilustrar(candidato)
  }

  const guardar = async () => {
    setGuardando(true)
    setError(null)
    try {
      const resultados = await guardarLoteIA({
        tematicaId,
        dificultad,
        activo: publicarActivas,
        candidatos: seleccionados.map((candidato) => ({
          nombre: candidato.nombre,
          lat: candidato.lat,
          lng: candidato.lng,
          imagen: candidato.estado === 'lista' ? candidato.imagen : null,
        })),
      })

      const noGuardados = resultados.filter((resultado) => !resultado.guardado)
      const creadas = resultados.length - noGuardados.length

      setResumen({ creadas, noGuardados, activas: publicarActivas })
      // Con algo sin guardar, la tanda se queda en pantalla para reintentar sin
      // volver a generar las imágenes que sí salieron.
      if (noGuardados.length === 0) setFase('guardado')
    } catch (fallo) {
      setError(mensajeDeError(fallo))
    } finally {
      setGuardando(false)
    }
  }

  const pasos: { numero: number; titulo: string; activo: boolean; hecho: boolean }[] = [
    {
      numero: 1,
      titulo: 'Configurar',
      activo: true,
      hecho: fase !== 'configurar',
    },
    {
      numero: 2,
      titulo: 'Revisar propuestas',
      activo: fase !== 'configurar',
      hecho: fase === 'ilustrando' || fase === 'guardado',
    },
    {
      numero: 3,
      titulo: 'Ilustrar y guardar',
      activo: fase === 'ilustrando' || fase === 'guardado',
      hecho: fase === 'guardado',
    },
  ]

  return (
    <div className="flex max-w-[1040px] flex-col gap-5">
      <div className="flex items-center gap-2 text-[13px] font-medium text-brand-night/45">
        <Link to="/preguntas" className="hover:text-brand-blue">
          Preguntas
        </Link>
        <span className="text-brand-night/30">/</span>
        <span className="font-semibold text-brand-night">Generar con IA</span>
      </div>

      <div className="flex flex-wrap items-end gap-5">
        <div className="min-w-0">
          <div className="flex items-center gap-2.5">
            <span
              className="rounded-full px-2.5 py-1 text-[11px] font-semibold tracking-[0.08em] text-white uppercase"
              style={FONDO_IA}
            >
              ✦ Beta
            </span>
            <span className="text-xs font-medium text-brand-night/45">
              Modelo de imagen: ilustración 3D (estilo Pixar)
            </span>
          </div>
          <h1 className="mt-2.5 font-display text-3xl font-extrabold tracking-tight text-brand-night">
            Generar preguntas con IA
          </h1>
          <p className="mt-1.5 max-w-[620px] text-sm text-brand-night/55">
            Elige temática, dificultad y cantidad. Revisas la lista propuesta, descartas lo que no
            quieras y GeoQuest ilustra cada lugar antes de guardarlo en el banco.
          </p>
        </div>
        <Link
          to="/preguntas/nueva"
          className="ml-auto self-end rounded-xl border-[1.5px] border-brand-border bg-white px-4 py-3 text-[13px] font-semibold text-brand-night/70 hover:border-brand-teal hover:text-brand-blue"
        >
          Crear a mano
        </Link>
      </div>

      <ol className="flex flex-wrap items-center gap-3">
        {pasos.map((paso) => (
          <li key={paso.numero} className="flex items-center gap-2.5">
            <span
              aria-hidden="true"
              className={`flex h-6 w-6 items-center justify-center rounded-full text-xs font-bold ${
                paso.hecho
                  ? 'bg-brand-teal text-white'
                  : paso.activo
                    ? 'bg-brand-night text-white'
                    : 'bg-white text-brand-night/40 ring-[1.5px] ring-brand-border ring-inset'
              }`}
            >
              {paso.hecho ? '✓' : paso.numero}
            </span>
            <span
              className={`text-[13px] font-semibold ${
                paso.activo ? 'text-brand-night' : 'text-brand-night/40'
              }`}
            >
              {`${paso.numero}. ${paso.titulo}`}
              {paso.hecho ? ' (completado)' : paso.activo ? ' (en curso)' : ' (pendiente)'}
            </span>
            {paso.numero < 3 && (
              <span
                aria-hidden="true"
                className={`h-px w-9 ${paso.hecho ? 'bg-brand-teal' : 'bg-brand-border'}`}
              />
            )}
          </li>
        ))}
      </ol>

      {error && (
        <div
          role="alert"
          className="rounded-xl border-[1.5px] border-brand-error bg-brand-error/5 px-4 py-3 text-[13px] font-medium text-[#B3282D]"
        >
          {error}
        </div>
      )}

      {/* PASO 1 */}
      <section className="flex flex-col gap-5 rounded-2xl border border-brand-border bg-white px-6 py-6">
        <div className="flex items-center gap-2.5">
          <h2 className="text-[10.5px] font-semibold tracking-[0.16em] text-brand-night/40 uppercase">
            1 · Qué generar
          </h2>
          <span aria-hidden="true" className="h-px flex-1 bg-brand-base" />
        </div>

        <div className="grid items-start gap-4 md:grid-cols-[1fr_220px]">
          <label className="flex min-w-0 flex-col gap-1.5">
            <span className="text-[12.5px] font-semibold text-brand-night">Temática</span>
            <select
              value={tematicaId}
              onChange={(evento) => {
                setTematicaId(evento.target.value)
                reiniciarTanda()
              }}
              className="h-11 rounded-xl border-[1.5px] border-brand-border bg-white px-3 text-sm text-brand-night focus:border-brand-teal focus:outline-none"
            >
              {tematicas.length === 0 && <option value="">Cargando temáticas…</option>}
              {tematicas.map((opcion) => (
                <option key={opcion.id} value={opcion.id}>
                  {opcion.nombre}
                </option>
              ))}
            </select>
            <span className="text-[11.5px] text-brand-night/45">
              La IA evita los lugares que ya existan en el banco de esta temática.
            </span>
          </label>

          <div className="md:col-span-2 rounded-xl border border-brand-border bg-brand-base/60 px-3.5 py-3">
            <p className="text-[11px] font-semibold tracking-[0.1em] text-brand-night/40 uppercase">
              Estilo de ilustración de la temática
            </p>
            {tematica?.promptImagen ? (
              <p className="mt-1.5 text-[12.5px] text-brand-night/70">{tematica.promptImagen}</p>
            ) : (
              <p className="mt-1.5 text-[12.5px] text-brand-night/50">
                Esta temática no tiene estilo propio, así que las imágenes saldrán con el estilo por
                defecto. Puedes definirlo en{' '}
                <Link to="/tematicas" className="font-semibold text-brand-blue hover:underline">
                  Temáticas
                </Link>
                .
              </p>
            )}
          </div>

          <div className="flex flex-col gap-1.5">
            <span className="text-[12.5px] font-semibold text-brand-night">Nº de preguntas</span>
            <div className="flex items-center gap-2.5">
              <button
                type="button"
                aria-label="Quitar una pregunta"
                onClick={() => setCantidad((actual) => Math.max(CANTIDAD_MINIMA, actual - 1))}
                className="h-11 w-9 rounded-xl border-[1.5px] border-brand-border bg-white text-lg font-bold text-brand-night/60 hover:border-brand-teal hover:text-brand-blue"
              >
                −
              </button>
              <span
                data-testid="cantidad"
                className="flex-1 text-center font-display text-2xl font-extrabold text-brand-night tabular-nums"
              >
                {cantidad}
              </span>
              <button
                type="button"
                aria-label="Añadir una pregunta"
                onClick={() => setCantidad((actual) => Math.min(CANTIDAD_MAXIMA, actual + 1))}
                className="h-11 w-9 rounded-xl border-[1.5px] border-brand-border bg-white text-lg font-bold text-brand-night/60 hover:border-brand-teal hover:text-brand-blue"
              >
                +
              </button>
            </div>
            <span className="text-[11.5px] text-brand-night/45">
              Entre {CANTIDAD_MINIMA} y {CANTIDAD_MAXIMA} por tanda.
            </span>
          </div>
        </div>

        <fieldset className="flex flex-col gap-2.5">
          <legend className="mb-2.5 text-[12.5px] font-semibold text-brand-night">
            Dificultad
          </legend>
          <div className="grid gap-2.5 sm:grid-cols-3 lg:grid-cols-5">
            {DIFICULTADES.map((opcion) => (
              <button
                key={opcion.valor}
                type="button"
                aria-pressed={dificultad === opcion.valor}
                onClick={() => setDificultad(opcion.valor)}
                className={`flex flex-col gap-1.5 rounded-xl border-[1.5px] px-3.5 py-3 text-left ${
                  dificultad === opcion.valor
                    ? 'border-brand-teal bg-brand-teal/5'
                    : 'border-brand-border bg-white hover:border-brand-teal'
                }`}
              >
                <span className="flex items-center gap-2">
                  <span
                    aria-hidden="true"
                    className={`h-2 w-2 rounded-full ${PUNTO_DIFICULTAD[opcion.valor]}`}
                  />
                  <span className="text-[13.5px] font-semibold text-brand-night">
                    {opcion.label}
                  </span>
                </span>
                <span className="text-[11.5px] text-brand-night/50">
                  {PISTA_DIFICULTAD[opcion.valor]}
                </span>
              </button>
            ))}
          </div>
        </fieldset>

        <label className="flex flex-col gap-1.5">
          <span className="text-[12.5px] font-semibold text-brand-night">
            Indicaciones extra <span className="font-medium text-brand-night/40">· opcional</span>
          </span>
          <textarea
            rows={2}
            value={indicaciones}
            onChange={(evento) => setIndicaciones(evento.target.value)}
            placeholder="Ej. solo hemisferio sur, evitar capitales europeas."
            className="resize-y rounded-xl border-[1.5px] border-brand-border bg-white px-3.5 py-3 text-sm text-brand-night focus:border-brand-teal focus:outline-none"
          />
        </label>

        <div className="flex flex-wrap items-center gap-3.5 border-t border-brand-base pt-4">
          <span className="text-[12.5px] text-brand-night/50">
            {`La IA propone ${cantidad} lugares de «${tematica?.nombre ?? '…'}». Este paso no genera imágenes ni gasta nada.`}
          </span>
          <button
            type="button"
            onClick={() => void generarPropuestas()}
            disabled={!tematica || fase === 'proponiendo'}
            style={FONDO_IA}
            className="ml-auto rounded-xl px-5 py-3.5 font-display text-base font-extrabold text-white disabled:cursor-not-allowed disabled:opacity-60"
          >
            {fase === 'configurar' ? '✦ Generar propuestas' : '✦ Regenerar propuestas'}
          </button>
        </div>
      </section>

      {/* PASO 2 */}
      {fase !== 'configurar' && (
        <section className="overflow-hidden rounded-2xl border border-brand-border bg-white">
          <div className="flex flex-wrap items-center gap-3.5 border-b border-brand-base px-6 py-5">
            <div>
              <h2 className="font-display text-lg font-extrabold text-brand-night">
                2 · Propuestas de la IA
              </h2>
              <p className="mt-1.5 text-[12.5px] text-brand-night/50">
                {fase === 'proponiendo'
                  ? 'Buscando lugares y comprobando duplicados…'
                  : `${candidatos.length} propuestas · ${tematica?.nombre ?? ''}. Descarta las que no quieras conservar.`}
              </p>
            </div>
            {fase !== 'proponiendo' && candidatos.length > 0 && (
              <div className="ml-auto flex items-center gap-2.5">
                <button
                  type="button"
                  onClick={() =>
                    setCandidatos((actuales) =>
                      actuales.map((candidato) => ({
                        ...candidato,
                        seleccionado: !todasMarcadas,
                      })),
                    )
                  }
                  className="rounded-lg border-[1.5px] border-brand-border bg-white px-3.5 py-2.5 text-[12.5px] font-semibold text-brand-night/70 hover:border-brand-teal hover:text-brand-blue"
                >
                  {todasMarcadas ? 'Desmarcar todas' : 'Marcar todas'}
                </button>
                <button
                  type="button"
                  onClick={() => void generarPropuestas()}
                  className="rounded-lg border-[1.5px] border-brand-border bg-white px-3.5 py-2.5 text-[12.5px] font-semibold text-brand-night/70 hover:border-brand-special hover:text-brand-special"
                >
                  ↻ Otra tanda
                </button>
              </div>
            )}
          </div>

          {fase === 'proponiendo' && (
            <div className="flex flex-col items-center gap-3.5 px-6 py-12">
              <Girador clase="h-8 w-8" />
              <span className="text-sm font-semibold text-brand-night">
                {`Redactando ${cantidad} preguntas de «${tematica?.nombre ?? ''}»…`}
              </span>
              <span className="text-[12.5px] text-brand-night/45">
                Comprobando duplicados y coordenadas
              </span>
            </div>
          )}

          {tandaCorta && candidatos.length > 0 && (
            <p className="border-b border-brand-base bg-brand-gold/10 px-6 py-3 text-[12.5px] font-medium text-[#996100]">
              {`La IA solo ha encontrado ${candidatos.length} lugares nuevos para esta temática y dificultad; el resto ya estaban en el banco.`}
            </p>
          )}

          {fase !== 'proponiendo' && candidatos.length === 0 && (
            <p className="px-6 py-10 text-center text-[13px] text-brand-night/50">
              La IA no ha encontrado lugares nuevos para esta temática y dificultad. Prueba con otra
              dificultad o añade indicaciones.
            </p>
          )}

          {candidatos.length > 0 && (
            <div className="overflow-x-auto">
              <table className="w-full min-w-[820px] border-collapse">
                <thead>
                  <tr className="bg-brand-base/60 text-left text-[10.5px] font-semibold tracking-[0.12em] text-brand-night/45 uppercase">
                    <th scope="col" className="w-11 px-6 py-3">
                      <span className="sr-only">Seleccionar</span>
                    </th>
                    <th scope="col" className="px-3 py-3">
                      Enunciado
                    </th>
                    <th scope="col" className="px-3 py-3">
                      Lugar
                    </th>
                    <th scope="col" className="px-3 py-3">
                      Coordenadas
                    </th>
                    <th scope="col" className="px-3 py-3">
                      Dificultad
                    </th>
                    <th scope="col" className="px-3 py-3">
                      Imagen
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {candidatos.map((candidato) => (
                    <tr
                      key={candidato.id}
                      className={`border-b border-brand-base ${
                        candidato.seleccionado ? 'bg-brand-teal/[0.04]' : 'bg-white'
                      }`}
                    >
                      <td className="px-6 py-3.5">
                        <input
                          type="checkbox"
                          checked={candidato.seleccionado}
                          aria-label={`Conservar ${candidato.nombre}`}
                          onChange={() =>
                            cambiarEstado(candidato.id, { seleccionado: !candidato.seleccionado })
                          }
                          className="h-5 w-5 accent-brand-blue"
                        />
                      </td>
                      <td className="px-3 py-3.5 text-[13.5px] text-brand-night">
                        {candidato.descripcion}
                      </td>
                      <td className="px-3 py-3.5 text-[13px] font-semibold text-brand-night">
                        {candidato.nombre}
                      </td>
                      <td className="px-3 py-3.5 text-[12.5px] text-brand-night/60 tabular-nums">
                        {formatearCoordenadas(candidato.lat, candidato.lng)}
                      </td>
                      <td className="px-3 py-3.5">
                        <span
                          className={`rounded-full px-2.5 py-1 text-[11.5px] font-semibold ${BADGE_DIFICULTAD[dificultad]}`}
                        >
                          {DIFICULTADES.find((opcion) => opcion.valor === dificultad)?.label}
                        </span>
                      </td>
                      <td className="px-3 py-3.5">
                        {candidato.urlPrevia ? (
                          <img
                            src={candidato.urlPrevia}
                            alt={`Ilustración de ${candidato.nombre}`}
                            className="h-8 w-11 rounded-lg object-cover"
                          />
                        ) : candidato.estado === 'generando' || candidato.estado === 'en_cola' ? (
                          <Girador clase="h-4 w-4" />
                        ) : (
                          <span className="text-[11px] text-brand-night/35">—</span>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          {candidatos.length > 0 && (
            <div className="flex flex-wrap items-center gap-3.5 bg-brand-base/60 px-6 py-4">
              <span className="text-[12.5px] text-brand-night/55">
                {seleccionados.length === 0
                  ? 'Marca al menos una pregunta para continuar.'
                  : `${seleccionados.length} ${
                      seleccionados.length === 1
                        ? 'pregunta seleccionada'
                        : 'preguntas seleccionadas'
                    } · se generarán ${seleccionados.length} ${
                      seleccionados.length === 1 ? 'imagen' : 'imágenes'
                    }, coste aproximado ${costeEstimado}`}
              </span>
              <div className="ml-auto flex gap-2.5">
                <button
                  type="button"
                  onClick={reiniciarTanda}
                  className="rounded-xl border-[1.5px] border-brand-border bg-white px-4 py-3 text-[13px] font-semibold text-brand-night/70 hover:border-brand-error hover:text-brand-error"
                >
                  Descartar tanda
                </button>
                <button
                  type="button"
                  onClick={() => void generarImagenes()}
                  disabled={seleccionados.length === 0 || enCurso}
                  style={FONDO_GUARDAR}
                  className="rounded-xl px-5 py-3 font-display text-[15px] font-extrabold text-white disabled:cursor-not-allowed disabled:opacity-60"
                >
                  {enCurso
                    ? '✦ Generando imágenes…'
                    : `✦ Generar imágenes (${seleccionados.length})`}
                </button>
              </div>
            </div>
          )}
        </section>
      )}

      {/* PASO 3 */}
      {(fase === 'ilustrando' || fase === 'guardado') && (
        <section className="flex flex-col gap-4 rounded-2xl border border-brand-border bg-white px-6 py-5">
          <div className="flex flex-wrap items-center gap-3.5">
            <div>
              <h2 className="font-display text-lg font-extrabold text-brand-night">
                3 · Ilustraciones estilo Pixar
              </h2>
              <p className="mt-1.5 text-[12.5px] text-brand-night/50">
                Ilustración 3D coherente con el estilo del juego, sin texto ni marcas de agua.
              </p>
            </div>
            <span className="ml-auto text-[13px] font-semibold text-brand-special tabular-nums">
              {`${listas.length} / ${seleccionados.length} listas`}
            </span>
          </div>

          <div
            role="progressbar"
            aria-valuemin={0}
            aria-valuemax={seleccionados.length}
            aria-valuenow={listas.length}
            className="h-[7px] overflow-hidden rounded-full bg-brand-base"
          >
            <span
              className="block h-[7px] rounded-full transition-[width] duration-300"
              style={{
                width: `${seleccionados.length ? Math.round((listas.length / seleccionados.length) * 100) : 0}%`,
                background: 'linear-gradient(90deg, #7C5CFF, #2BC0A8)',
              }}
            />
          </div>

          <ul className="grid gap-3.5 sm:grid-cols-2 lg:grid-cols-4">
            {seleccionados.map((candidato) => (
              <li
                key={candidato.id}
                className={`overflow-hidden rounded-2xl border-[1.5px] bg-white ${
                  candidato.estado === 'lista'
                    ? 'border-brand-teal'
                    : candidato.estado === 'fallida'
                      ? 'border-brand-error'
                      : 'border-brand-border'
                }`}
              >
                <div className="flex h-[124px] items-center justify-center bg-brand-base">
                  {candidato.urlPrevia ? (
                    <img
                      src={candidato.urlPrevia}
                      alt={`Ilustración de ${candidato.nombre}`}
                      className="h-[124px] w-full object-cover"
                    />
                  ) : candidato.estado === 'generando' ? (
                    <span className="flex flex-col items-center gap-2">
                      <Girador clase="h-6 w-6" />
                      <span className="text-[11px] font-semibold text-brand-special">
                        Ilustrando…
                      </span>
                    </span>
                  ) : candidato.estado === 'fallida' ? (
                    // El motivo lo cuenta la linea de estado de debajo; aqui solo
                    // el aviso visual, para no repetir el mismo texto dos veces.
                    <span aria-hidden="true" className="text-2xl text-brand-error">
                      ⚠
                    </span>
                  ) : (
                    <span className="text-[11px] font-semibold text-brand-night/35">
                      {ETIQUETA_ESTADO[candidato.estado]}
                    </span>
                  )}
                </div>
                <div className="px-3.5 pt-3 pb-3.5">
                  <p className="text-[13px] font-semibold text-brand-night">{candidato.nombre}</p>
                  <p className="mt-2 flex items-center gap-2">
                    <span
                      aria-hidden="true"
                      className={`h-1.5 w-1.5 rounded-full ${PUNTO_ESTADO[candidato.estado]}`}
                    />
                    <span className="text-[11.5px] font-medium text-brand-night/50">
                      {ETIQUETA_ESTADO[candidato.estado]}
                    </span>
                    {(candidato.estado === 'lista' || candidato.estado === 'fallida') && (
                      <button
                        type="button"
                        onClick={() => void rehacer(candidato)}
                        className="ml-auto rounded-lg border border-brand-border bg-white px-2 py-1 text-[11px] font-semibold text-brand-night/60 hover:border-brand-special hover:text-brand-special"
                      >
                        {candidato.estado === 'fallida'
                          ? `↻ Reintentar ${candidato.nombre}`
                          : `↻ Rehacer ${candidato.nombre}`}
                      </button>
                    )}
                  </p>
                </div>
              </li>
            ))}
          </ul>
        </section>
      )}

      {resumen && (
        <div
          role="status"
          className={`flex flex-wrap items-center gap-4 rounded-2xl border-[1.5px] px-6 py-5 ${
            resumen.noGuardados.length === 0
              ? 'border-brand-teal bg-brand-teal/5'
              : 'border-brand-gold bg-brand-gold/10'
          }`}
        >
          <div className="min-w-0">
            <p className="font-display text-[17px] font-extrabold text-brand-night">
              {`${resumen.creadas} ${
                resumen.creadas === 1 ? 'pregunta guardada' : 'preguntas guardadas'
              } en el banco`}
            </p>
            <p className="mt-1.5 text-[12.5px] text-brand-night/55">
              {`Temática «${tematica?.nombre ?? ''}» · ${
                resumen.activas ? 'activas y listas para el camino' : 'guardadas como inactivas'
              }.`}
              {resumen.noGuardados.length > 0 &&
                ` No se han podido guardar ${resumen.noGuardados.length}: ${resumen.noGuardados
                  .map((fallo) => fallo.nombre)
                  .join(', ')}. Puedes reintentar sin volver a generar las imágenes.`}
            </p>
          </div>
          <Link
            to="/preguntas"
            style={FONDO_GUARDAR}
            className="ml-auto rounded-xl px-4 py-3 font-display text-[15px] font-extrabold text-white"
          >
            Ver en el banco
          </Link>
        </div>
      )}

      {fase === 'ilustrando' && (
        <div className="sticky bottom-0 flex flex-wrap items-center gap-3 border-t border-brand-border bg-brand-base/95 py-3.5 backdrop-blur-sm">
          <span className="text-[12.5px] text-brand-night/50">
            {enCurso
              ? `Espera a que terminen las ${seleccionados.length} ilustraciones para guardar.`
              : `Se guardarán ${listas.length} ${
                  listas.length === 1 ? 'pregunta' : 'preguntas'
                } con su ilustración en el banco.`}
          </span>
          <div className="ml-auto flex items-center gap-3">
            <label className="flex cursor-pointer items-center gap-2.5 px-1.5">
              <input
                type="checkbox"
                checked={publicarActivas}
                onChange={(evento) => setPublicarActivas(evento.target.checked)}
                className="h-5 w-5 accent-brand-teal"
              />
              <span className="text-[12.5px] font-semibold text-brand-night/70">
                Publicar activas
              </span>
            </label>
            <button
              type="button"
              onClick={() => void guardar()}
              disabled={enCurso || listas.length === 0 || guardando}
              style={FONDO_GUARDAR}
              className="rounded-xl px-5 py-3.5 font-display text-base font-extrabold text-white disabled:cursor-not-allowed disabled:opacity-60"
            >
              {guardando
                ? 'Guardando…'
                : enCurso
                  ? 'Generando…'
                  : `Guardar ${listas.length} ${listas.length === 1 ? 'pregunta' : 'preguntas'}`}
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
