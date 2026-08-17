import { useEffect, useMemo, useState, type DragEvent, type FormEvent } from 'react'
import { Link, useParams } from 'react-router-dom'
import type { TipoDesafio } from '../lib/preguntas'
import {
  absolutoDesdePorcentaje,
  agregarPreguntaAlRecorrido,
  distanciaMediaKm,
  fetchNivelRecorrido,
  fetchPreguntasNoAsignadas,
  guardarConfiguracionNivel,
  porcentajeDesdeAbsoluto,
  preguntasEfectivasPorPartida,
  puntajeMaximoNivel,
  quitarPreguntaDelRecorrido,
  reordenarRecorrido,
  validarConfiguracionNivel,
  type NivelRecorrido as NivelRecorridoData,
  type PreguntaBanco,
  type PreguntaRecorrido,
} from '../lib/nivelRecorrido'

const BOTON_FONDO = {
  background: 'linear-gradient(140deg, #2BC0A8, #1B6FA8)',
}

const TIPO_LABEL: Record<TipoDesafio, string> = {
  imagen: 'Imagen',
  video: 'Vídeo',
  pregunta_texto: 'Pregunta de texto',
}

const TIPO_BADGE: Record<TipoDesafio, string> = {
  imagen: 'bg-brand-blue/10 text-brand-blue',
  video: 'bg-brand-special/10 text-brand-special',
  pregunta_texto: 'bg-brand-gold/25 text-[#996100]',
}

const CAMPO_BASE =
  'h-11 rounded-xl border-[1.5px] border-brand-border bg-white px-3.5 text-sm text-brand-night outline-none placeholder:text-brand-night/40 focus:border-brand-teal focus:ring-4 focus:ring-brand-teal/15'

function textoDistanciaMedia(distanciaKm: number | null): string {
  if (distanciaKm === null) return 'cualquier distancia'
  return `≤ ~${Math.round(distanciaKm).toLocaleString('es-ES')} km`
}

function formatearPorcentaje(porcentaje: number): string {
  return String(Math.round(porcentaje * 10) / 10)
}

/** `undefined` marca una entrada no vacía pero inválida (no entero positivo). */
function parseEnteroPositivoOpcional(valor: string): number | null | undefined {
  const trim = valor.trim()
  if (trim === '') return null
  const numero = Number(trim)
  if (!Number.isInteger(numero) || numero < 1) return undefined
  return numero
}

function IconoTipo({ tipo }: { tipo: TipoDesafio }) {
  if (tipo === 'imagen') {
    return (
      <svg
        width="16"
        height="16"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      >
        <rect x="3" y="5" width="18" height="14" rx="2.5" />
        <path d="M3 16l5-4.5 4 3.5 3-2.5 6 5" />
        <circle cx="15.5" cy="9.5" r="1.4" />
      </svg>
    )
  }
  if (tipo === 'video') {
    return (
      <svg
        width="16"
        height="16"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      >
        <rect x="2.5" y="5.5" width="13" height="13" rx="2.5" />
        <path d="M15.5 11l5-3v8l-5-3z" />
      </svg>
    )
  }
  return (
    <svg
      width="16"
      height="16"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d="M5 6h14M5 11h14M5 16h8" />
    </svg>
  )
}

function IconoAsa() {
  return (
    <svg width="12" height="18" viewBox="0 0 12 18" fill="currentColor" aria-hidden="true">
      <circle cx="3" cy="3" r="1.5" />
      <circle cx="9" cy="3" r="1.5" />
      <circle cx="3" cy="9" r="1.5" />
      <circle cx="9" cy="9" r="1.5" />
      <circle cx="3" cy="15" r="1.5" />
      <circle cx="9" cy="15" r="1.5" />
    </svg>
  )
}

function Miniatura({ pregunta }: { pregunta: { tipo: TipoDesafio; imagenUrl: string | null } }) {
  const [rota, setRota] = useState(false)
  const mostrarImagen = pregunta.tipo === 'imagen' && pregunta.imagenUrl && !rota

  return (
    <div
      className={`flex h-10 w-14 flex-none items-center justify-center overflow-hidden rounded-lg ${TIPO_BADGE[pregunta.tipo]}`}
    >
      {mostrarImagen ? (
        <img
          src={pregunta.imagenUrl ?? undefined}
          alt=""
          onError={() => setRota(true)}
          className="h-full w-full object-cover"
        />
      ) : (
        <IconoTipo tipo={pregunta.tipo} />
      )}
    </div>
  )
}

function nombreNivel(nivel: Pick<NivelRecorridoData, 'nombre' | 'orden'>): string {
  const nombre = nivel.nombre?.trim()
  return nombre ? nombre : `Nivel ${nivel.orden}`
}

function EstadoVacioRecorrido({ onAnadir }: { onAnadir: () => void }) {
  return (
    <div className="flex flex-col items-center gap-2 px-6 py-16 text-center">
      <h4 className="font-display text-xl font-extrabold text-brand-night">
        Este nivel todavía no tiene preguntas
      </h4>
      <p className="max-w-md text-sm text-brand-night/55">
        Añade preguntas del banco existente o crea una nueva para construir el recorrido de este
        nivel.
      </p>
      <div className="mt-3 flex gap-2.5">
        <button
          type="button"
          onClick={onAnadir}
          className="rounded-xl border-[1.5px] border-brand-border px-4 py-2.5 text-sm font-semibold text-brand-blue"
        >
          Añadir pregunta existente
        </button>
        <Link
          to="/preguntas/nueva"
          className="flex items-center gap-2 rounded-xl px-4 py-2.5 font-display text-sm font-extrabold text-white"
          style={BOTON_FONDO}
        >
          <span className="text-base leading-none">+</span>Crear pregunta nueva
        </Link>
      </div>
    </div>
  )
}

function SelectorPreguntas({
  preguntas,
  error,
  agregandoId,
  bloqueado,
  query,
  onQueryChange,
  onAgregar,
}: {
  preguntas: PreguntaBanco[] | null
  error: string
  agregandoId: string | null
  bloqueado: boolean
  query: string
  onQueryChange: (query: string) => void
  onAgregar: (pregunta: PreguntaBanco) => void
}) {
  const q = query.trim().toLowerCase()
  const filtradas = (preguntas ?? []).filter((p) => !q || p.nombreLugar.toLowerCase().includes(q))

  return (
    <div className="flex flex-col gap-3.5 rounded-2xl border-[1.5px] border-dashed border-[#CFDDE3] bg-brand-teal/5 p-6">
      <h2 className="font-display text-lg font-extrabold text-brand-night">
        Añadir pregunta existente
      </h2>
      <div className="overflow-hidden rounded-xl border border-brand-border bg-white">
        <label className="flex h-[42px] items-center gap-2 border-b border-brand-base px-3.5">
          <svg
            width="15"
            height="15"
            viewBox="0 0 20 20"
            fill="none"
            stroke="currentColor"
            strokeWidth="1.8"
            className="text-brand-night/40"
          >
            <circle cx="8.5" cy="8.5" r="5.5" />
            <path d="M12.5 12.5 17 17" />
          </svg>
          <input
            type="search"
            value={query}
            onChange={(e) => onQueryChange(e.target.value)}
            placeholder="Buscar por nombre del lugar"
            className="min-w-0 flex-1 border-0 bg-transparent text-sm text-brand-night outline-none placeholder:text-brand-night/40"
          />
        </label>
        <div className="max-h-[260px] overflow-auto">
          {preguntas === null && !error && (
            <div className="p-6 text-center text-sm text-brand-night/45">
              Cargando preguntas del banco…
            </div>
          )}
          {error && <div className="p-6 text-center text-sm text-[#B3282D]">{error}</div>}
          {preguntas !== null && filtradas.length === 0 && (
            <div className="p-6 text-center text-sm text-brand-night/45">
              {preguntas.length === 0
                ? 'Todas las preguntas del banco ya están asignadas a este nivel.'
                : `Ninguna pregunta coincide con «${query}».`}
            </div>
          )}
          {filtradas.map((p) => (
            <button
              key={p.id}
              type="button"
              onClick={() => onAgregar(p)}
              disabled={agregandoId === p.id || bloqueado}
              className="flex w-full items-center gap-3 border-b border-brand-base px-3.5 py-2.5 text-left last:border-0 hover:bg-[#F8FBFC] disabled:cursor-not-allowed disabled:opacity-50"
            >
              <Miniatura pregunta={p} />
              <span className="min-w-0 flex-1 truncate text-sm font-semibold text-brand-night">
                {p.nombreLugar}
              </span>
              <span
                className={`inline-flex items-center rounded-full px-2.5 py-1 text-xs font-semibold ${TIPO_BADGE[p.tipo]}`}
              >
                {TIPO_LABEL[p.tipo]}
              </span>
              <span className="text-xs font-semibold text-brand-blue">
                {agregandoId === p.id ? 'Añadiendo…' : 'Añadir'}
              </span>
            </button>
          ))}
        </div>
      </div>
    </div>
  )
}

function FilaPregunta({
  pregunta,
  index,
  total,
  error,
  quitando,
  bloqueado,
  arrastrando,
  onDragStart,
  onDragOver,
  onDrop,
  onMover,
  onQuitar,
}: {
  pregunta: PreguntaRecorrido
  index: number
  total: number
  error?: string
  quitando: boolean
  bloqueado: boolean
  arrastrando: boolean
  onDragStart: () => void
  onDragOver: (e: DragEvent<HTMLTableRowElement>) => void
  onDrop: () => void
  onMover: (delta: number) => void
  onQuitar: () => void
}) {
  return (
    <tr
      draggable={!bloqueado}
      onDragStart={onDragStart}
      onDragOver={onDragOver}
      onDrop={onDrop}
      className={`border-b border-brand-base last:border-0 hover:bg-brand-base/40 ${arrastrando ? 'opacity-40' : ''}`}
    >
      <td className="w-10 px-3 py-3 text-center text-brand-night/30" aria-hidden="true">
        <IconoAsa />
      </td>
      <td className="px-2 py-3 text-sm font-semibold text-brand-night/50 tabular-nums">
        {index + 1}
      </td>
      <td className="px-3 py-3">
        <div className="flex items-center gap-3">
          <Miniatura pregunta={pregunta} />
          <span className="min-w-0 truncate text-sm font-semibold text-brand-night">
            {pregunta.nombreLugar}
          </span>
        </div>
      </td>
      <td className="px-3 py-3">
        <span
          className={`inline-flex items-center rounded-full px-2.5 py-1 text-xs font-semibold ${TIPO_BADGE[pregunta.tipo]}`}
        >
          {TIPO_LABEL[pregunta.tipo]}
        </span>
      </td>
      <td className="px-3 py-3">
        <div className="flex items-center justify-end gap-1.5">
          <button
            type="button"
            onClick={() => onMover(-1)}
            disabled={index === 0 || bloqueado}
            aria-label="Subir posición"
            title="Subir posición"
            className="flex h-8 w-8 items-center justify-center rounded-lg border-[1.5px] border-brand-border text-brand-night/60 hover:border-brand-blue hover:text-brand-blue disabled:cursor-not-allowed disabled:opacity-30"
          >
            ↑
          </button>
          <button
            type="button"
            onClick={() => onMover(1)}
            disabled={index === total - 1 || bloqueado}
            aria-label="Bajar posición"
            title="Bajar posición"
            className="flex h-8 w-8 items-center justify-center rounded-lg border-[1.5px] border-brand-border text-brand-night/60 hover:border-brand-blue hover:text-brand-blue disabled:cursor-not-allowed disabled:opacity-30"
          >
            ↓
          </button>
          <button
            type="button"
            onClick={onQuitar}
            disabled={quitando || bloqueado}
            title="Quitar del recorrido"
            className="rounded-lg border-[1.5px] border-brand-border px-3 py-2 text-xs font-semibold text-brand-night/60 hover:border-brand-error hover:text-brand-error disabled:cursor-not-allowed disabled:opacity-40"
          >
            Quitar del recorrido
          </button>
        </div>
        {error && <p className="mt-1.5 text-right text-[11px] text-[#B3282D]">{error}</p>}
      </td>
    </tr>
  )
}

export function NivelRecorrido() {
  const { id } = useParams<{ id: string }>()
  const nivelId = id ?? ''

  const [nivel, setNivel] = useState<NivelRecorridoData | null>(null)
  const [preguntas, setPreguntas] = useState<PreguntaRecorrido[]>([])
  const [cargando, setCargando] = useState(true)
  const [errorCarga, setErrorCarga] = useState('')

  const [nombre, setNombre] = useState('')
  const [puntajeMinimo, setPuntajeMinimo] = useState('')
  const [umbral2Porcentaje, setUmbral2Porcentaje] = useState('')
  const [umbral3Porcentaje, setUmbral3Porcentaje] = useState('')
  const [preguntasPorPartida, setPreguntasPorPartida] = useState('')
  const [errorConfig, setErrorConfig] = useState('')
  const [guardandoConfig, setGuardandoConfig] = useState(false)
  const [guardadoOk, setGuardadoOk] = useState(false)

  const [rowErrors, setRowErrors] = useState<Record<string, string>>({})
  const [quitandoIds, setQuitandoIds] = useState<Set<string>>(new Set())
  const [errorOrden, setErrorOrden] = useState('')
  const [dragIndex, setDragIndex] = useState<number | null>(null)
  // Serializa reordenar/quitar/añadir: sin este flag, una operación que falla
  // puede revertir al estado anterior a otra que ya se resolvió mientras
  // tanto (revisión adversarial de INT-84).
  const [operandoRecorrido, setOperandoRecorrido] = useState(false)

  const [mostrarSelector, setMostrarSelector] = useState(false)
  const [preguntasBanco, setPreguntasBanco] = useState<PreguntaBanco[] | null>(null)
  const [errorBanco, setErrorBanco] = useState('')
  const [agregandoId, setAgregandoId] = useState<string | null>(null)
  const [queryBanco, setQueryBanco] = useState('')

  useEffect(() => {
    let isMounted = true

    fetchNivelRecorrido(nivelId)
      .then((resultado) => {
        if (!isMounted) return
        setNivel(resultado)
        setPreguntas(resultado.preguntas)
        setNombre(resultado.nombre ?? '')
        setPuntajeMinimo(String(resultado.puntajeMinimoSuperar))
        const maximoCargado = puntajeMaximoNivel(
          resultado.preguntasPorPartida,
          resultado.preguntas.length,
        )
        setUmbral2Porcentaje(
          formatearPorcentaje(porcentajeDesdeAbsoluto(resultado.umbralEstrella2, maximoCargado)),
        )
        setUmbral3Porcentaje(
          formatearPorcentaje(porcentajeDesdeAbsoluto(resultado.umbralEstrella3, maximoCargado)),
        )
        setPreguntasPorPartida(
          resultado.preguntasPorPartida === null ? '' : String(resultado.preguntasPorPartida),
        )
      })
      .catch((error: unknown) => {
        if (!isMounted) return
        console.error('Error cargando el nivel:', error)
        setErrorCarga('No se ha podido cargar el nivel.')
      })
      .finally(() => {
        if (isMounted) setCargando(false)
      })

    return () => {
      isMounted = false
    }
  }, [nivelId])

  const preguntasPorPartidaLive = useMemo(() => {
    const parseado = parseEnteroPositivoOpcional(preguntasPorPartida)
    return typeof parseado === 'number' ? parseado : null
  }, [preguntasPorPartida])

  const preguntasEfectivas = preguntasEfectivasPorPartida(preguntasPorPartidaLive, preguntas.length)
  const maximoNivel = puntajeMaximoNivel(preguntasPorPartidaLive, preguntas.length)

  const numeros = useMemo(() => {
    const umbral2 = absolutoDesdePorcentaje(Number(umbral2Porcentaje), maximoNivel)
    const umbral3 = absolutoDesdePorcentaje(Number(umbral3Porcentaje), maximoNivel)
    return {
      puntajeMinimo: Number(puntajeMinimo),
      umbral2Pct: Number(umbral2Porcentaje),
      umbral3Pct: Number(umbral3Porcentaje),
      umbral2,
      umbral3,
    }
  }, [puntajeMinimo, umbral2Porcentaje, umbral3Porcentaje, maximoNivel])

  const distanciaMinimo = distanciaMediaKm(numeros.puntajeMinimo, preguntasEfectivas)
  const distanciaUmbral2 = distanciaMediaKm(numeros.umbral2, preguntasEfectivas)
  const distanciaUmbral3 = distanciaMediaKm(numeros.umbral3, preguntasEfectivas)

  async function handleGuardarConfig(e: FormEvent) {
    e.preventDefault()
    if (guardandoConfig) return

    if (
      Number.isNaN(numeros.puntajeMinimo) ||
      Number.isNaN(numeros.umbral2Pct) ||
      Number.isNaN(numeros.umbral3Pct)
    ) {
      setErrorConfig('El puntaje mínimo y los umbrales deben ser números.')
      return
    }

    const preguntasPorPartidaValor = parseEnteroPositivoOpcional(preguntasPorPartida)
    if (preguntasPorPartidaValor === undefined) {
      setErrorConfig('Las preguntas por partida deben ser un número entero mayor que 0.')
      return
    }

    const nombreTrim = nombre.trim()
    const config = {
      nombre: nombreTrim ? nombreTrim : null,
      puntajeMinimoSuperar: numeros.puntajeMinimo,
      umbralEstrella2: numeros.umbral2,
      umbralEstrella3: numeros.umbral3,
      preguntasPorPartida: preguntasPorPartidaValor,
    }

    const errorValidacion = validarConfiguracionNivel(config, preguntas.length)
    if (errorValidacion) {
      setErrorConfig(errorValidacion)
      return
    }

    setErrorConfig('')
    setGuardadoOk(false)
    setGuardandoConfig(true)
    try {
      await guardarConfiguracionNivel(nivelId, config, preguntas.length)
      setGuardadoOk(true)
    } catch (error) {
      setErrorConfig(
        error instanceof Error ? error.message : 'No se ha podido guardar la configuración.',
      )
    } finally {
      setGuardandoConfig(false)
    }
  }

  function persistirOrden(nuevoOrden: PreguntaRecorrido[]) {
    if (operandoRecorrido) return

    const anterior = preguntas
    const renumeradas = nuevoOrden.map((p, i) => ({ ...p, orden: i + 1 }))
    setPreguntas(renumeradas)
    setErrorOrden('')
    setOperandoRecorrido(true)

    reordenarRecorrido(
      nivelId,
      renumeradas.map((p) => p.desafioId),
    )
      .catch((error: unknown) => {
        setPreguntas(anterior)
        setErrorOrden(
          error instanceof Error ? error.message : 'No se ha podido reordenar el recorrido.',
        )
      })
      .finally(() => setOperandoRecorrido(false))
  }

  function handleMover(index: number, delta: number) {
    if (operandoRecorrido) return
    const destino = index + delta
    if (destino < 0 || destino >= preguntas.length) return
    const reordenadas = [...preguntas]
    const [item] = reordenadas.splice(index, 1)
    reordenadas.splice(destino, 0, item)
    persistirOrden(reordenadas)
  }

  function handleDrop(index: number) {
    if (dragIndex === null || dragIndex === index || operandoRecorrido) {
      setDragIndex(null)
      return
    }
    const reordenadas = [...preguntas]
    const [item] = reordenadas.splice(dragIndex, 1)
    reordenadas.splice(index, 0, item)
    persistirOrden(reordenadas)
    setDragIndex(null)
  }

  async function handleQuitar(pregunta: PreguntaRecorrido) {
    if (quitandoIds.has(pregunta.desafioId) || operandoRecorrido) return

    const confirmado = window.confirm(
      `¿Quitar "${pregunta.nombreLugar}" del recorrido? Seguirá disponible en el banco de preguntas.`,
    )
    if (!confirmado) return

    setQuitandoIds((actual) => new Set(actual).add(pregunta.desafioId))
    setOperandoRecorrido(true)
    try {
      await quitarPreguntaDelRecorrido(nivelId, pregunta.desafioId)
      setPreguntas((actual) =>
        actual
          .filter((p) => p.desafioId !== pregunta.desafioId)
          .map((p, i) => ({ ...p, orden: i + 1 })),
      )
      setRowErrors((actual) => {
        if (!(pregunta.desafioId in actual)) return actual
        const resto = { ...actual }
        delete resto[pregunta.desafioId]
        return resto
      })
    } catch (error) {
      setRowErrors((actual) => ({
        ...actual,
        [pregunta.desafioId]:
          error instanceof Error ? error.message : 'No se ha podido quitar la pregunta.',
      }))
    } finally {
      setQuitandoIds((actual) => {
        const siguiente = new Set(actual)
        siguiente.delete(pregunta.desafioId)
        return siguiente
      })
      setOperandoRecorrido(false)
    }
  }

  function abrirSelector() {
    setMostrarSelector(true)
    if (preguntasBanco !== null) return

    fetchPreguntasNoAsignadas(nivelId)
      .then((lista) => setPreguntasBanco(lista))
      .catch((error: unknown) => {
        console.error('Error cargando las preguntas del banco:', error)
        setErrorBanco('No se han podido cargar las preguntas del banco.')
      })
  }

  async function handleAgregar(pregunta: PreguntaBanco) {
    if (agregandoId || operandoRecorrido) return

    setAgregandoId(pregunta.id)
    setOperandoRecorrido(true)
    try {
      await agregarPreguntaAlRecorrido(nivelId, pregunta.id)
      setPreguntas((actual) => [
        ...actual,
        {
          desafioId: pregunta.id,
          orden: actual.length + 1,
          tipo: pregunta.tipo,
          nombreLugar: pregunta.nombreLugar,
          imagenUrl: pregunta.imagenUrl,
        },
      ])
      setPreguntasBanco((actual) => actual?.filter((p) => p.id !== pregunta.id) ?? actual)
    } catch (error) {
      setErrorBanco(error instanceof Error ? error.message : 'No se ha podido añadir la pregunta.')
    } finally {
      setAgregandoId(null)
      setOperandoRecorrido(false)
    }
  }

  if (cargando) {
    return <div className="p-8 text-sm text-brand-night/55">Cargando…</div>
  }

  if (errorCarga || !nivel) {
    return (
      <div className="rounded-2xl border border-brand-error/40 bg-brand-error/10 p-5 text-sm text-[#B3282D]">
        {errorCarga || 'No se ha podido cargar el nivel.'}
      </div>
    )
  }

  const etiquetaNivel = nombreNivel(nivel)

  return (
    <div className="flex flex-col gap-6">
      <nav aria-label="Miga de pan" className="text-sm text-brand-night/50">
        Temáticas <span className="mx-1.5">›</span> {nivel.tematicaNombre}{' '}
        <span className="mx-1.5">›</span>{' '}
        <span className="font-semibold text-brand-night">{etiquetaNivel}</span>
      </nav>

      <div>
        <h1 className="font-display text-3xl font-extrabold tracking-tight text-brand-night">
          {etiquetaNivel}
        </h1>
        <p className="mt-1.5 text-sm text-brand-night/55">{nivel.tematicaNombre}</p>
      </div>

      <form
        onSubmit={handleGuardarConfig}
        className="flex flex-col gap-5 rounded-2xl border border-brand-border bg-white p-6"
      >
        <h2 className="font-display text-lg font-extrabold text-brand-night">
          Configuración del nivel
        </h2>

        <label className="flex max-w-[440px] flex-col gap-1.5">
          <span className="text-sm font-semibold text-brand-night">Nombre del nivel</span>
          <input
            type="text"
            value={nombre}
            onChange={(e) => setNombre(e.target.value)}
            placeholder={`Nivel ${nivel.orden}`}
            className={CAMPO_BASE}
          />
        </label>

        <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
          <label className="flex flex-col gap-1.5">
            <span className="text-xs font-medium text-brand-night/60">Puntaje mínimo</span>
            <input
              type="number"
              min={0}
              value={puntajeMinimo}
              onChange={(e) => setPuntajeMinimo(e.target.value)}
              className={`${CAMPO_BASE} tabular-nums`}
            />
            <span className="text-[11px] text-brand-night/45">
              {textoDistanciaMedia(distanciaMinimo)}
            </span>
          </label>
          <label className="flex flex-col gap-1.5">
            <span className="text-xs font-medium text-brand-night/60">Umbral 2 estrellas (%)</span>
            <input
              type="number"
              min={0}
              max={100}
              value={umbral2Porcentaje}
              onChange={(e) => setUmbral2Porcentaje(e.target.value)}
              className={`${CAMPO_BASE} tabular-nums`}
            />
            <span className="text-[11px] text-brand-night/45">
              {numeros.umbral2} pts · {textoDistanciaMedia(distanciaUmbral2)}
            </span>
          </label>
          <label className="flex flex-col gap-1.5">
            <span className="text-xs font-medium text-brand-night/60">Umbral 3 estrellas (%)</span>
            <input
              type="number"
              min={0}
              max={100}
              value={umbral3Porcentaje}
              onChange={(e) => setUmbral3Porcentaje(e.target.value)}
              className={`${CAMPO_BASE} tabular-nums`}
            />
            <span className="text-[11px] text-brand-night/45">
              {numeros.umbral3} pts · {textoDistanciaMedia(distanciaUmbral3)}
            </span>
          </label>
          <label className="flex flex-col gap-1.5">
            <span className="text-xs font-medium text-brand-night/60">Preguntas por partida</span>
            <input
              type="number"
              min={1}
              placeholder="Todas"
              value={preguntasPorPartida}
              onChange={(e) => setPreguntasPorPartida(e.target.value)}
              className={`${CAMPO_BASE} tabular-nums`}
            />
          </label>
        </div>

        <div className="flex items-center gap-3">
          {errorConfig && <span className="text-sm font-medium text-[#B3282D]">{errorConfig}</span>}
          {guardadoOk && !errorConfig && (
            <span className="text-sm font-medium text-brand-success">Configuración guardada.</span>
          )}
          <button
            type="submit"
            disabled={guardandoConfig}
            className="ml-auto rounded-xl px-5 py-3 font-display text-sm font-extrabold text-white disabled:cursor-not-allowed disabled:opacity-60"
            style={BOTON_FONDO}
          >
            {guardandoConfig ? 'Guardando…' : 'Guardar cambios'}
          </button>
        </div>
      </form>

      <div className="flex flex-wrap items-center justify-between gap-4">
        <p className="text-sm font-semibold text-brand-night/70">
          {preguntas.length} {preguntas.length === 1 ? 'pregunta' : 'preguntas'} en este recorrido
        </p>
        {preguntas.length > 0 && (
          <div className="flex gap-2.5">
            <button
              type="button"
              onClick={abrirSelector}
              className="rounded-xl border-[1.5px] border-brand-border px-4 py-2.5 text-sm font-semibold text-brand-blue"
            >
              Añadir pregunta existente
            </button>
            <Link
              to="/preguntas/nueva"
              className="flex items-center gap-2 rounded-xl px-4 py-2.5 font-display text-sm font-extrabold text-white"
              style={BOTON_FONDO}
            >
              <span className="text-base leading-none">+</span>Crear pregunta nueva
            </Link>
          </div>
        )}
      </div>

      {mostrarSelector && (
        <SelectorPreguntas
          preguntas={preguntasBanco}
          error={errorBanco}
          agregandoId={agregandoId}
          bloqueado={operandoRecorrido}
          query={queryBanco}
          onQueryChange={setQueryBanco}
          onAgregar={handleAgregar}
        />
      )}

      <div className="overflow-hidden rounded-2xl border border-brand-border bg-white">
        {preguntas.length === 0 ? (
          <EstadoVacioRecorrido onAnadir={abrirSelector} />
        ) : (
          <>
            {errorOrden && (
              <p className="border-b border-brand-base px-5 py-2.5 text-xs font-medium text-[#B3282D]">
                {errorOrden}
              </p>
            )}
            <table className="w-full border-collapse text-left">
              <thead>
                <tr className="border-b border-brand-border bg-brand-base/60 text-[11px] font-semibold tracking-wider text-brand-night/45 uppercase">
                  <th className="w-10 px-3 py-3" aria-hidden="true" />
                  <th className="px-2 py-3 font-semibold">#</th>
                  <th className="px-3 py-3 font-semibold">Pregunta</th>
                  <th className="px-3 py-3 font-semibold">Tipo</th>
                  <th className="px-3 py-3 text-right font-semibold">Acciones</th>
                </tr>
              </thead>
              <tbody>
                {preguntas.map((pregunta, index) => (
                  <FilaPregunta
                    key={pregunta.desafioId}
                    pregunta={pregunta}
                    index={index}
                    total={preguntas.length}
                    error={rowErrors[pregunta.desafioId]}
                    quitando={quitandoIds.has(pregunta.desafioId)}
                    bloqueado={operandoRecorrido}
                    arrastrando={dragIndex === index}
                    onDragStart={() => setDragIndex(index)}
                    onDragOver={(e) => e.preventDefault()}
                    onDrop={() => handleDrop(index)}
                    onMover={(delta) => handleMover(index, delta)}
                    onQuitar={() => handleQuitar(pregunta)}
                  />
                ))}
              </tbody>
            </table>
          </>
        )}
      </div>
    </div>
  )
}
