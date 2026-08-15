import { useEffect, useState } from 'react'
import { eliminarPregunta, fetchPreguntas, type Pregunta, type TipoDesafio } from '../lib/preguntas'

const PAGE_SIZE = 10
const TODAS_TEMATICAS = 'Todas las temáticas'
const TODOS_NIVELES = 'Todos los niveles'

type FiltroTipo = 'todos' | TipoDesafio
type FiltroEstado = 'todos' | 'activo' | 'inactivo'

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

const BOTON_DESHABILITADO =
  'flex cursor-not-allowed items-center gap-2 rounded-xl font-display font-extrabold text-white/70'
const BOTON_DESHABILITADO_FONDO = {
  background: 'linear-gradient(140deg, rgba(43,192,168,.55), rgba(27,111,168,.55))',
}

function IconoTipo({ tipo }: { tipo: TipoDesafio }) {
  if (tipo === 'imagen') {
    return (
      <svg
        width="18"
        height="18"
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
        width="18"
        height="18"
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
      width="18"
      height="18"
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

function IconoEditar() {
  return (
    <svg
      width="14"
      height="14"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.9"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d="M4 20h4L19.5 8.5a2 2 0 0 0 0-2.8l-1.2-1.2a2 2 0 0 0-2.8 0L4 16z" />
    </svg>
  )
}

function IconoEliminar() {
  return (
    <svg
      width="14"
      height="14"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.9"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d="M5 7h14M9.5 7V5h5v2M7 7l.9 12.1A1.5 1.5 0 0 0 9.4 20h5.2a1.5 1.5 0 0 0 1.5-.9L17 7" />
    </svg>
  )
}

function Miniatura({ pregunta }: { pregunta: Pregunta }) {
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

function FilaPregunta({
  pregunta,
  error,
  onEliminar,
}: {
  pregunta: Pregunta
  error?: string
  onEliminar: () => void
}) {
  return (
    <tr className="border-b border-brand-base last:border-0 hover:bg-brand-base/40">
      <td className="px-5 py-3">
        <div className="flex items-center gap-3">
          <Miniatura pregunta={pregunta} />
          <div className="min-w-0">
            <div className="truncate text-sm font-semibold text-brand-night">
              {pregunta.nombreLugar}
            </div>
            {pregunta.tipo === 'pregunta_texto' && pregunta.textoPregunta && (
              <div className="truncate text-xs text-brand-night/50">{pregunta.textoPregunta}</div>
            )}
          </div>
        </div>
      </td>
      <td className="px-5 py-3">
        <span
          className={`inline-flex items-center rounded-full px-2.5 py-1 text-xs font-semibold ${TIPO_BADGE[pregunta.tipo]}`}
        >
          {TIPO_LABEL[pregunta.tipo]}
        </span>
      </td>
      <td className="px-5 py-3">
        <span
          className={`inline-flex items-center gap-1.5 text-xs font-semibold ${pregunta.activo ? 'text-brand-success' : 'text-brand-night/45'}`}
        >
          <span
            className={`h-1.5 w-1.5 rounded-full ${pregunta.activo ? 'bg-brand-success' : 'bg-brand-border'}`}
          />
          {pregunta.activo ? 'Activo' : 'Inactivo'}
        </span>
      </td>
      <td className="px-5 py-3">
        {pregunta.usos.length === 0 ? (
          <span className="text-xs font-medium text-brand-night/45">Sin asignar</span>
        ) : (
          <details>
            <summary className="inline-flex cursor-pointer list-none items-center gap-1 text-xs font-semibold text-brand-blue">
              Usado en {pregunta.usos.length} {pregunta.usos.length === 1 ? 'nivel' : 'niveles'}
            </summary>
            <ul className="mt-1.5 flex flex-col gap-0.5 text-xs text-brand-night/60">
              {pregunta.usos.map((uso) => (
                <li key={uso.nivelId}>
                  {uso.tematicaNombre} · Nivel {uso.nivelOrden}
                </li>
              ))}
            </ul>
          </details>
        )}
      </td>
      <td className="px-5 py-3">
        <div className="flex justify-end gap-2">
          <span
            aria-disabled="true"
            aria-label="Editar"
            title="Próximamente"
            className="flex h-8 w-8 cursor-not-allowed items-center justify-center rounded-lg border-[1.5px] border-brand-border text-brand-night/30"
          >
            <IconoEditar />
          </span>
          <button
            type="button"
            onClick={onEliminar}
            title="Eliminar"
            className="flex h-8 w-8 items-center justify-center rounded-lg border-[1.5px] border-brand-border text-brand-night/60 hover:border-brand-error hover:text-brand-error"
          >
            <IconoEliminar />
          </button>
        </div>
        {error && (
          <p className="mt-1.5 max-w-[220px] text-right text-[11px] text-[#B3282D]">{error}</p>
        )}
      </td>
    </tr>
  )
}

function Paginacion({
  total,
  inicio,
  cantidad,
  pagina,
  pageCount,
  onCambiarPagina,
}: {
  total: number
  inicio: number
  cantidad: number
  pagina: number
  pageCount: number
  onCambiarPagina: (pagina: number) => void
}) {
  return (
    <div className="flex flex-wrap items-center gap-3.5 p-4">
      <span className="text-xs text-brand-night/50">
        Mostrando {cantidad === 0 ? 0 : inicio + 1}–{inicio + cantidad} de {total}
      </span>
      <div className="ml-auto flex items-center gap-1.5">
        <button
          type="button"
          disabled={pagina <= 1}
          onClick={() => onCambiarPagina(Math.max(1, pagina - 1))}
          className="h-8 rounded-lg border-[1.5px] border-brand-border px-3 text-xs font-semibold text-brand-night/70 disabled:cursor-not-allowed disabled:opacity-40"
        >
          Anterior
        </button>
        {Array.from({ length: pageCount }, (_, i) => i + 1).map((p) => (
          <button
            key={p}
            type="button"
            onClick={() => onCambiarPagina(p)}
            aria-current={p === pagina ? 'page' : undefined}
            className={`h-8 min-w-8 rounded-lg border-[1.5px] px-2 text-xs font-semibold ${
              p === pagina
                ? 'border-brand-blue bg-brand-blue text-white'
                : 'border-brand-border text-brand-night/70'
            }`}
          >
            {p}
          </button>
        ))}
        <button
          type="button"
          disabled={pagina >= pageCount}
          onClick={() => onCambiarPagina(Math.min(pageCount, pagina + 1))}
          className="h-8 rounded-lg border-[1.5px] border-brand-border px-3 text-xs font-semibold text-brand-night/70 disabled:cursor-not-allowed disabled:opacity-40"
        >
          Siguiente
        </button>
      </div>
    </div>
  )
}

function EstadoVacioFiltros({ onLimpiar }: { onLimpiar: () => void }) {
  return (
    <div className="flex flex-col items-center gap-2 px-6 py-16 text-center">
      <h4 className="font-display text-xl font-extrabold text-brand-night">
        Ninguna pregunta coincide
      </h4>
      <p className="max-w-md text-sm text-brand-night/55">
        Prueba a quitar algún filtro o a buscar solo por el nombre del lugar.
      </p>
      <button
        type="button"
        onClick={onLimpiar}
        className="mt-3 rounded-xl border-[1.5px] border-brand-border px-4 py-2.5 text-sm font-semibold text-brand-blue"
      >
        Limpiar filtros
      </button>
    </div>
  )
}

function EstadoVacioBanco() {
  return (
    <div className="flex flex-col items-center gap-2 px-6 py-16 text-center">
      <h4 className="font-display text-xl font-extrabold text-brand-night">
        Todavía no hay preguntas
      </h4>
      <p className="max-w-md text-sm text-brand-night/55">
        Crea la primera pregunta del banco para empezar a construir niveles.
      </p>
      <span
        aria-disabled="true"
        title="Próximamente"
        className={`mt-3 px-4 py-2.5 text-sm ${BOTON_DESHABILITADO}`}
        style={BOTON_DESHABILITADO_FONDO}
      >
        <span className="text-base leading-none">+</span>Crear la primera pregunta
      </span>
    </div>
  )
}

export function Preguntas() {
  const [preguntas, setPreguntas] = useState<Pregunta[] | null>(null)
  const [error, setError] = useState('')
  const [rowErrors, setRowErrors] = useState<Record<string, string>>({})

  const [query, setQuery] = useState('')
  const [topic, setTopic] = useState(TODAS_TEMATICAS)
  const [level, setLevel] = useState(TODOS_NIVELES)
  const [tipo, setTipo] = useState<FiltroTipo>('todos')
  const [estado, setEstado] = useState<FiltroEstado>('todos')
  const [sinAsignar, setSinAsignar] = useState(false)
  const [page, setPage] = useState(1)

  useEffect(() => {
    let isMounted = true

    fetchPreguntas()
      .then((resultado) => {
        if (!isMounted) return
        setPreguntas(resultado)
      })
      .catch((cargaError: unknown) => {
        if (!isMounted) return
        console.error('Error cargando el listado de preguntas:', cargaError)
        setError('No se ha podido cargar el listado de preguntas.')
      })

    return () => {
      isMounted = false
    }
  }, [])

  if (error) {
    return (
      <div className="rounded-2xl border border-brand-error/40 bg-brand-error/10 p-5 text-sm text-[#B3282D]">
        {error}
      </div>
    )
  }

  async function handleEliminar(pregunta: Pregunta) {
    const confirmado = window.confirm(
      `¿Eliminar "${pregunta.nombreLugar}"? Esta acción no se puede deshacer.`,
    )
    if (!confirmado) return

    try {
      await eliminarPregunta(pregunta.id)
      setPreguntas((actual) => actual?.filter((p) => p.id !== pregunta.id) ?? actual)
      setRowErrors((actual) => {
        if (!(pregunta.id in actual)) return actual
        const resto = { ...actual }
        delete resto[pregunta.id]
        return resto
      })
    } catch (eliminarError) {
      setRowErrors((actual) => ({
        ...actual,
        [pregunta.id]:
          eliminarError instanceof Error
            ? eliminarError.message
            : 'No se ha podido eliminar la pregunta.',
      }))
    }
  }

  const total = preguntas?.length ?? 0
  const bancoVacio = preguntas !== null && total === 0

  const topicOptions = [
    TODAS_TEMATICAS,
    ...new Set((preguntas ?? []).flatMap((p) => p.usos.map((uso) => uso.tematicaNombre))),
  ]

  const nivelesPool = (preguntas ?? []).flatMap((p) => p.usos)
  const nivelesScope =
    topic === TODAS_TEMATICAS
      ? nivelesPool
      : nivelesPool.filter((uso) => uso.tematicaNombre === topic)
  const nivelesUnicos = new Map(nivelesScope.map((uso) => [uso.nivelId, uso]))
  const levelOptions = [
    { id: TODOS_NIVELES, label: TODOS_NIVELES },
    ...[...nivelesUnicos.values()]
      .sort((a, b) => a.nivelOrden - b.nivelOrden)
      .map((uso) => ({
        id: uso.nivelId,
        label: `${uso.tematicaNombre} · Nivel ${uso.nivelOrden}`,
      })),
  ]

  const q = query.trim().toLowerCase()
  const filtradas = (preguntas ?? []).filter((p) => {
    const matchQuery =
      !q ||
      p.nombreLugar.toLowerCase().includes(q) ||
      (p.textoPregunta ?? '').toLowerCase().includes(q)
    const matchTopic =
      topic === TODAS_TEMATICAS || p.usos.some((uso) => uso.tematicaNombre === topic)
    const matchLevel = level === TODOS_NIVELES || p.usos.some((uso) => uso.nivelId === level)
    const matchTipo = tipo === 'todos' || p.tipo === tipo
    const matchEstado = estado === 'todos' || (estado === 'activo') === p.activo
    const matchSinAsignar = !sinAsignar || p.usos.length === 0
    return matchQuery && matchTopic && matchLevel && matchTipo && matchEstado && matchSinAsignar
  })

  const hasFilters =
    q.length > 0 ||
    topic !== TODAS_TEMATICAS ||
    level !== TODOS_NIVELES ||
    tipo !== 'todos' ||
    estado !== 'todos' ||
    sinAsignar

  const pageCount = Math.max(1, Math.ceil(filtradas.length / PAGE_SIZE))
  const paginaActual = Math.min(page, pageCount)
  const inicio = (paginaActual - 1) * PAGE_SIZE
  const pagina = filtradas.slice(inicio, inicio + PAGE_SIZE)

  function limpiarFiltros() {
    setQuery('')
    setTopic(TODAS_TEMATICAS)
    setLevel(TODOS_NIVELES)
    setTipo('todos')
    setEstado('todos')
    setSinAsignar(false)
    setPage(1)
  }

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="font-display text-3xl font-extrabold tracking-tight text-brand-night">
            Preguntas / Desafíos
          </h1>
          <p className="mt-1.5 text-sm text-brand-night/55">
            {total} {total === 1 ? 'pregunta' : 'preguntas'} en el banco
            {preguntas
              ? ` · ${preguntas.filter((p) => p.usos.length === 0).length} sin asignar`
              : ''}
          </p>
        </div>
        <span
          aria-disabled="true"
          title="Próximamente"
          className={`px-6 py-4 text-base ${BOTON_DESHABILITADO}`}
          style={BOTON_DESHABILITADO_FONDO}
        >
          <span className="text-xl leading-none">+</span>Nueva pregunta
        </span>
      </div>

      <div className="overflow-hidden rounded-2xl border border-brand-border bg-white">
        <div className="flex flex-wrap items-center gap-2.5 border-b border-brand-base p-4">
          <label className="flex h-10 max-w-96 min-w-[240px] flex-1 items-center gap-2 rounded-xl border-[1.5px] border-brand-border bg-brand-base/60 px-3.5 focus-within:border-brand-teal">
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
              onChange={(e) => {
                setQuery(e.target.value)
                setPage(1)
              }}
              placeholder="Buscar por lugar o texto de la pregunta"
              className="min-w-0 flex-1 border-0 bg-transparent text-sm text-brand-night outline-none placeholder:text-brand-night/40"
            />
          </label>

          <select
            aria-label="Filtrar por temática"
            value={topic}
            onChange={(e) => {
              setTopic(e.target.value)
              setLevel(TODOS_NIVELES)
              setPage(1)
            }}
            className="h-10 rounded-xl border-[1.5px] border-brand-border bg-white px-3 text-sm font-medium text-brand-night/75"
          >
            {topicOptions.map((o) => (
              <option key={o} value={o}>
                {o}
              </option>
            ))}
          </select>

          <select
            aria-label="Filtrar por nivel"
            value={level}
            onChange={(e) => {
              setLevel(e.target.value)
              setPage(1)
            }}
            className="h-10 rounded-xl border-[1.5px] border-brand-border bg-white px-3 text-sm font-medium text-brand-night/75"
          >
            {levelOptions.map((o) => (
              <option key={o.id} value={o.id}>
                {o.label}
              </option>
            ))}
          </select>

          <select
            aria-label="Filtrar por tipo"
            value={tipo}
            onChange={(e) => {
              setTipo(e.target.value as FiltroTipo)
              setPage(1)
            }}
            className="h-10 rounded-xl border-[1.5px] border-brand-border bg-white px-3 text-sm font-medium text-brand-night/75"
          >
            <option value="todos">Todos los tipos</option>
            <option value="imagen">Imagen</option>
            <option value="video">Vídeo</option>
            <option value="pregunta_texto">Pregunta de texto</option>
          </select>

          <select
            aria-label="Filtrar por estado"
            value={estado}
            onChange={(e) => {
              setEstado(e.target.value as FiltroEstado)
              setPage(1)
            }}
            className="h-10 rounded-xl border-[1.5px] border-brand-border bg-white px-3 text-sm font-medium text-brand-night/75"
          >
            <option value="todos">Todos los estados</option>
            <option value="activo">Activo</option>
            <option value="inactivo">Inactivo</option>
          </select>

          <label className="flex h-10 items-center gap-2 rounded-xl border-[1.5px] border-brand-border bg-white px-3 text-sm font-medium text-brand-night/75">
            <input
              type="checkbox"
              checked={sinAsignar}
              onChange={(e) => {
                setSinAsignar(e.target.checked)
                setPage(1)
              }}
            />
            Sin asignar a ningún nivel
          </label>

          {hasFilters && (
            <button
              type="button"
              onClick={limpiarFiltros}
              className="text-xs font-semibold text-brand-blue underline underline-offset-2"
            >
              Limpiar filtros
            </button>
          )}
        </div>

        {bancoVacio ? (
          <EstadoVacioBanco />
        ) : filtradas.length === 0 ? (
          <EstadoVacioFiltros onLimpiar={limpiarFiltros} />
        ) : (
          <>
            <table className="w-full border-collapse text-left">
              <thead>
                <tr className="border-b border-brand-border bg-brand-base/60 text-[11px] font-semibold tracking-wider text-brand-night/45 uppercase">
                  <th className="px-5 py-3 font-semibold">Pregunta</th>
                  <th className="px-5 py-3 font-semibold">Tipo</th>
                  <th className="px-5 py-3 font-semibold">Estado</th>
                  <th className="px-5 py-3 font-semibold">Usado en</th>
                  <th className="px-5 py-3 text-right font-semibold">Acciones</th>
                </tr>
              </thead>
              <tbody>
                {pagina.map((p) => (
                  <FilaPregunta
                    key={p.id}
                    pregunta={p}
                    error={rowErrors[p.id]}
                    onEliminar={() => handleEliminar(p)}
                  />
                ))}
              </tbody>
            </table>

            <Paginacion
              total={filtradas.length}
              inicio={inicio}
              cantidad={pagina.length}
              pagina={paginaActual}
              pageCount={pageCount}
              onCambiarPagina={setPage}
            />
          </>
        )}
      </div>
    </div>
  )
}
