import { useEffect, useState, type DragEvent } from 'react'
import {
  actualizarEstrellasRequeridas,
  agregarNivelAlCamino,
  fetchCamino,
  fetchNivelesNoAsignados,
  quitarDelCamino,
  reordenarCamino,
  type NivelDisponible,
  type PosicionCamino,
} from '../lib/camino'

const BOTON_FONDO = {
  background: 'linear-gradient(140deg, #2BC0A8, #1B6FA8)',
}

const CAMPO_BASE =
  'h-10 rounded-lg border-[1.5px] border-brand-border bg-white px-3 text-sm text-brand-night outline-none focus:border-brand-teal focus:ring-4 focus:ring-brand-teal/15'

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

function IconoCamino() {
  return (
    <svg
      width="18"
      height="18"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.7"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <circle cx="5" cy="19" r="2" />
      <circle cx="12" cy="10" r="2" />
      <circle cx="19" cy="5" r="2" />
      <path d="M6.4 17.6 10.6 11.6M13.4 8.4 17.6 6.4" />
    </svg>
  )
}

function EstadoVacio({ onAnadir }: { onAnadir: () => void }) {
  return (
    <div className="flex flex-col items-center gap-2 px-6 py-16 text-center">
      <div className="mb-3 flex h-[78px] w-[78px] items-center justify-center rounded-[22px] bg-brand-teal/10 text-brand-blue">
        <IconoCamino />
      </div>
      <h4 className="font-display text-xl font-extrabold text-brand-night">El camino está vacío</h4>
      <p className="max-w-md text-sm text-brand-night/55">
        El camino define en qué orden juega el jugador los niveles, pudiendo intercalar temáticas
        libremente. Añade el primer nivel para empezar.
      </p>
      <button
        type="button"
        onClick={onAnadir}
        className="mt-3 flex items-center gap-2 rounded-xl px-4 py-2.5 font-display text-sm font-extrabold text-white"
        style={BOTON_FONDO}
      >
        <span className="text-base leading-none">+</span>Añadir nivel al camino
      </button>
    </div>
  )
}

function SelectorNiveles({
  niveles,
  error,
  agregandoId,
  bloqueado,
  query,
  onQueryChange,
  onAgregar,
}: {
  niveles: NivelDisponible[] | null
  error: string
  agregandoId: string | null
  bloqueado: boolean
  query: string
  onQueryChange: (query: string) => void
  onAgregar: (nivel: NivelDisponible) => void
}) {
  const q = query.trim().toLowerCase()
  const filtrados = (niveles ?? []).filter(
    (n) => !q || n.nombre.toLowerCase().includes(q) || n.tematicaNombre.toLowerCase().includes(q),
  )

  return (
    <div className="flex flex-col gap-3.5 rounded-2xl border-[1.5px] border-dashed border-[#CFDDE3] bg-brand-teal/5 p-6">
      <h2 className="font-display text-lg font-extrabold text-brand-night">
        Añadir nivel al camino
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
            placeholder="Buscar por nivel o temática"
            className="min-w-0 flex-1 border-0 bg-transparent text-sm text-brand-night outline-none placeholder:text-brand-night/40"
          />
        </label>
        <div className="max-h-[260px] overflow-auto">
          {niveles === null && !error && (
            <div className="p-6 text-center text-sm text-brand-night/45">Cargando niveles…</div>
          )}
          {error && <div className="p-6 text-center text-sm text-[#B3282D]">{error}</div>}
          {niveles !== null && filtrados.length === 0 && (
            <div className="p-6 text-center text-sm text-brand-night/45">
              {niveles.length === 0
                ? 'Todos los niveles ya están en el camino.'
                : `Ningún nivel coincide con «${query}».`}
            </div>
          )}
          {filtrados.map((nivel) => (
            <button
              key={nivel.id}
              type="button"
              onClick={() => onAgregar(nivel)}
              disabled={agregandoId === nivel.id || bloqueado}
              className="flex w-full items-center gap-3 border-b border-brand-base px-3.5 py-2.5 text-left last:border-0 hover:bg-[#F8FBFC] disabled:cursor-not-allowed disabled:opacity-50"
            >
              <span className="min-w-0 flex-1 truncate text-sm font-semibold text-brand-night">
                {nivel.nombre}
              </span>
              <span className="truncate text-xs text-brand-night/50">{nivel.tematicaNombre}</span>
              <span className="flex-none text-xs font-semibold text-brand-blue">
                {agregandoId === nivel.id ? 'Añadiendo…' : 'Añadir'}
              </span>
            </button>
          ))}
        </div>
      </div>
    </div>
  )
}

function FilaCamino({
  posicion,
  index,
  total,
  estrellasValor,
  error,
  guardandoEstrellas,
  quitando,
  bloqueado,
  arrastrando,
  onDragStart,
  onDragOver,
  onDrop,
  onMover,
  onEstrellasChange,
  onEstrellasBlur,
  onQuitar,
}: {
  posicion: PosicionCamino
  index: number
  total: number
  estrellasValor: string
  error?: string
  guardandoEstrellas: boolean
  quitando: boolean
  bloqueado: boolean
  arrastrando: boolean
  onDragStart: () => void
  onDragOver: (e: DragEvent<HTMLTableRowElement>) => void
  onDrop: () => void
  onMover: (delta: number) => void
  onEstrellasChange: (valor: string) => void
  onEstrellasBlur: () => void
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
        <div className="min-w-0">
          <div className="truncate text-sm font-semibold text-brand-night">
            {posicion.nivelNombre}
          </div>
          <div className="truncate text-xs text-brand-night/50">{posicion.tematicaNombre}</div>
        </div>
      </td>
      <td className="px-3 py-3">
        <div className="flex items-center gap-1.5">
          <span className="text-brand-gold">★</span>
          <input
            type="number"
            min={0}
            step={1}
            value={estrellasValor}
            disabled={guardandoEstrellas}
            onChange={(e) => onEstrellasChange(e.target.value)}
            onBlur={onEstrellasBlur}
            className={`${CAMPO_BASE} w-20 tabular-nums`}
          />
        </div>
        {error && <p className="mt-1.5 text-[11px] text-[#B3282D]">{error}</p>}
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
            title="Quitar del camino"
            className="rounded-lg border-[1.5px] border-brand-border px-3 py-2 text-xs font-semibold text-brand-night/60 hover:border-brand-error hover:text-brand-error disabled:cursor-not-allowed disabled:opacity-40"
          >
            Quitar del camino
          </button>
        </div>
      </td>
    </tr>
  )
}

export function Camino() {
  const [camino, setCamino] = useState<PosicionCamino[] | null>(null)
  const [error, setError] = useState('')
  const [rowErrors, setRowErrors] = useState<Record<string, string>>({})
  const [quitandoIds, setQuitandoIds] = useState<Set<string>>(new Set())
  const [errorOrden, setErrorOrden] = useState('')
  const [dragIndex, setDragIndex] = useState<number | null>(null)
  const [operandoCamino, setOperandoCamino] = useState(false)

  const [mostrarSelector, setMostrarSelector] = useState(false)
  const [nivelesDisponibles, setNivelesDisponibles] = useState<NivelDisponible[] | null>(null)
  const [errorSelector, setErrorSelector] = useState('')
  const [agregandoId, setAgregandoId] = useState<string | null>(null)
  const [querySelector, setQuerySelector] = useState('')

  const [estrellasEditando, setEstrellasEditando] = useState<Record<string, string>>({})
  const [guardandoEstrellasIds, setGuardandoEstrellasIds] = useState<Set<string>>(new Set())

  function cargar() {
    fetchCamino()
      .then((resultado) => setCamino(resultado))
      .catch((cargaError: unknown) => {
        console.error('Error cargando el camino:', cargaError)
        setError('No se ha podido cargar el camino.')
      })
  }

  useEffect(() => {
    cargar()
  }, [])

  if (error) {
    return (
      <div className="rounded-2xl border border-brand-error/40 bg-brand-error/10 p-5 text-sm text-[#B3282D]">
        {error}
      </div>
    )
  }

  const lista = camino ?? []
  const total = lista.length

  function abrirSelector() {
    setMostrarSelector(true)
    if (nivelesDisponibles !== null) return

    fetchNivelesNoAsignados()
      .then((resultado) => setNivelesDisponibles(resultado))
      .catch((nivelesError: unknown) => {
        console.error('Error cargando los niveles disponibles:', nivelesError)
        setErrorSelector('No se han podido cargar los niveles disponibles.')
      })
  }

  async function handleAgregar(nivel: NivelDisponible) {
    if (agregandoId || operandoCamino) return

    setAgregandoId(nivel.id)
    setOperandoCamino(true)
    try {
      const { id } = await agregarNivelAlCamino(nivel.id)
      setCamino((actual) => [
        ...(actual ?? []),
        {
          id,
          orden: (actual?.length ?? 0) + 1,
          nivelId: nivel.id,
          nivelNombre: nivel.nombre,
          tematicaNombre: nivel.tematicaNombre,
          estrellasRequeridas: 0,
        },
      ])
      setNivelesDisponibles((actual) => actual?.filter((n) => n.id !== nivel.id) ?? actual)
    } catch (agregarError) {
      setErrorSelector(
        agregarError instanceof Error ? agregarError.message : 'No se ha podido añadir el nivel.',
      )
    } finally {
      setAgregandoId(null)
      setOperandoCamino(false)
    }
  }

  function persistirOrden(nuevoOrden: PosicionCamino[]) {
    if (operandoCamino) return

    const anterior = lista
    const renumeradas = nuevoOrden.map((p, i) => ({ ...p, orden: i + 1 }))
    setCamino(renumeradas)
    setErrorOrden('')
    setOperandoCamino(true)

    reordenarCamino(renumeradas.map((p) => p.id))
      .catch((reordenarError: unknown) => {
        setCamino(anterior)
        setErrorOrden(
          reordenarError instanceof Error
            ? reordenarError.message
            : 'No se ha podido reordenar el camino.',
        )
      })
      .finally(() => setOperandoCamino(false))
  }

  function handleMover(index: number, delta: number) {
    if (operandoCamino) return
    const destino = index + delta
    if (destino < 0 || destino >= lista.length) return
    const reordenadas = [...lista]
    const [item] = reordenadas.splice(index, 1)
    reordenadas.splice(destino, 0, item)
    persistirOrden(reordenadas)
  }

  function handleDrop(index: number) {
    if (dragIndex === null || dragIndex === index || operandoCamino) {
      setDragIndex(null)
      return
    }
    const reordenadas = [...lista]
    const [item] = reordenadas.splice(dragIndex, 1)
    reordenadas.splice(index, 0, item)
    persistirOrden(reordenadas)
    setDragIndex(null)
  }

  async function handleEstrellasBlur(posicion: PosicionCamino) {
    const valorTexto = estrellasEditando[posicion.id] ?? String(posicion.estrellasRequeridas)
    const valor = Number(valorTexto)

    if (valorTexto.trim() === '' || !Number.isInteger(valor) || valor < 0) {
      setRowErrors((actual) => ({
        ...actual,
        [posicion.id]: 'Debe ser un número entero igual o mayor a 0.',
      }))
      return
    }

    if (valor === posicion.estrellasRequeridas) return

    setGuardandoEstrellasIds((actual) => new Set(actual).add(posicion.id))
    try {
      await actualizarEstrellasRequeridas(posicion.id, valor)
      setCamino(
        (actual) =>
          actual?.map((p) => (p.id === posicion.id ? { ...p, estrellasRequeridas: valor } : p)) ??
          actual,
      )
      setRowErrors((actual) => {
        if (!(posicion.id in actual)) return actual
        const resto = { ...actual }
        delete resto[posicion.id]
        return resto
      })
    } catch (guardarError) {
      setRowErrors((actual) => ({
        ...actual,
        [posicion.id]:
          guardarError instanceof Error ? guardarError.message : 'No se ha podido guardar.',
      }))
    } finally {
      setGuardandoEstrellasIds((actual) => {
        const siguiente = new Set(actual)
        siguiente.delete(posicion.id)
        return siguiente
      })
    }
  }

  async function handleQuitar(posicion: PosicionCamino) {
    if (quitandoIds.has(posicion.id) || operandoCamino) return

    const confirmado = window.confirm(
      `¿Quitar "${posicion.nivelNombre}" del camino? El nivel seguirá existiendo en su temática.`,
    )
    if (!confirmado) return

    setQuitandoIds((actual) => new Set(actual).add(posicion.id))
    setOperandoCamino(true)
    try {
      await quitarDelCamino(posicion.id)
      setCamino((actual) =>
        (actual ?? []).filter((p) => p.id !== posicion.id).map((p, i) => ({ ...p, orden: i + 1 })),
      )
      setNivelesDisponibles((actual) =>
        actual
          ? [
              ...actual,
              {
                id: posicion.nivelId,
                nombre: posicion.nivelNombre,
                tematicaNombre: posicion.tematicaNombre,
              },
            ]
          : actual,
      )
      setRowErrors((actual) => {
        if (!(posicion.id in actual)) return actual
        const resto = { ...actual }
        delete resto[posicion.id]
        return resto
      })
    } catch (quitarError) {
      setRowErrors((actual) => ({
        ...actual,
        [posicion.id]:
          quitarError instanceof Error ? quitarError.message : 'No se ha podido quitar del camino.',
      }))
    } finally {
      setQuitandoIds((actual) => {
        const siguiente = new Set(actual)
        siguiente.delete(posicion.id)
        return siguiente
      })
      setOperandoCamino(false)
    }
  }

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="font-display text-3xl font-extrabold tracking-tight text-brand-night">
            Camino
          </h1>
          <p className="mt-1.5 text-sm text-brand-night/55">
            {total === 0
              ? 'Ninguna posición definida todavía'
              : `${total} ${total === 1 ? 'posición' : 'posiciones'} · el orden define la secuencia de juego`}
          </p>
        </div>
        {total > 0 && (
          <button
            type="button"
            onClick={abrirSelector}
            className="flex items-center gap-2 rounded-xl px-6 py-4 font-display text-base font-extrabold text-white"
            style={BOTON_FONDO}
          >
            <span className="text-xl leading-none">+</span>Añadir nivel al camino
          </button>
        )}
      </div>

      {mostrarSelector && (
        <SelectorNiveles
          niveles={nivelesDisponibles}
          error={errorSelector}
          agregandoId={agregandoId}
          bloqueado={operandoCamino}
          query={querySelector}
          onQueryChange={setQuerySelector}
          onAgregar={handleAgregar}
        />
      )}

      <div className="overflow-hidden rounded-2xl border border-brand-border bg-white">
        {camino !== null && total === 0 ? (
          <EstadoVacio onAnadir={abrirSelector} />
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
                  <th className="px-3 py-3 font-semibold">Nivel</th>
                  <th className="px-3 py-3 font-semibold">Estrellas para desbloquear</th>
                  <th className="px-3 py-3 text-right font-semibold">Acciones</th>
                </tr>
              </thead>
              <tbody>
                {lista.map((posicion, index) => (
                  <FilaCamino
                    key={posicion.id}
                    posicion={posicion}
                    index={index}
                    total={lista.length}
                    estrellasValor={
                      estrellasEditando[posicion.id] ?? String(posicion.estrellasRequeridas)
                    }
                    error={rowErrors[posicion.id]}
                    guardandoEstrellas={guardandoEstrellasIds.has(posicion.id)}
                    quitando={quitandoIds.has(posicion.id)}
                    bloqueado={operandoCamino}
                    arrastrando={dragIndex === index}
                    onDragStart={() => setDragIndex(index)}
                    onDragOver={(e) => e.preventDefault()}
                    onDrop={() => handleDrop(index)}
                    onMover={(delta) => handleMover(index, delta)}
                    onEstrellasChange={(valor) =>
                      setEstrellasEditando((actual) => ({ ...actual, [posicion.id]: valor }))
                    }
                    onEstrellasBlur={() => handleEstrellasBlur(posicion)}
                    onQuitar={() => handleQuitar(posicion)}
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
