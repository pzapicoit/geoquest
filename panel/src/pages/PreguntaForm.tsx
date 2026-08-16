import { useEffect, useMemo, useState, type ChangeEvent, type FormEvent } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { MapaVistaPrevia } from '../components/MapaVistaPrevia'
import type { TipoDesafio } from '../lib/preguntas'
import {
  asignarPreguntaANiveles,
  fetchNivelesParaAsignar,
  fetchPregunta,
  guardarPregunta,
  validarArchivoMedia,
  type NivelParaAsignar,
} from '../lib/preguntaForm'

const TIPOS: { valor: TipoDesafio; label: string; hint: string }[] = [
  { valor: 'imagen', label: 'Imagen', hint: 'foto del lugar' },
  { valor: 'pregunta_texto', label: 'Pregunta de texto', hint: 'solo enunciado' },
  { valor: 'video', label: 'Vídeo', hint: 'clip corto' },
]

const CAMPO_BASE =
  'h-11 rounded-xl border-[1.5px] border-brand-border bg-white px-3.5 text-sm text-brand-night outline-none placeholder:text-brand-night/40 focus:border-brand-teal focus:ring-4 focus:ring-brand-teal/15'
const CAMPO_ERROR = 'border-[#E0454A] bg-[#FFF8F8] focus:border-[#E0454A] focus:ring-[#E0454A]/15'

function useObjectUrl(file: File | null): string | null {
  const url = useMemo(() => (file ? URL.createObjectURL(file) : null), [file])

  useEffect(() => {
    return () => {
      if (url) URL.revokeObjectURL(url)
    }
  }, [url])

  return url
}

function ErrorCampo({ mensaje }: { mensaje?: string }) {
  if (!mensaje) return null
  return <p className="text-xs font-medium text-[#B3282D]">{mensaje}</p>
}

function SelectorTipo({
  tipo,
  onChange,
}: {
  tipo: TipoDesafio
  onChange: (tipo: TipoDesafio) => void
}) {
  return (
    <div className="flex flex-col gap-2.5">
      <span className="text-sm font-semibold text-brand-night">
        Tipo de contenido <span className="text-[#E0454A]">*</span>
      </span>
      <div className="grid grid-cols-1 gap-2.5 sm:grid-cols-3">
        {TIPOS.map((t) => {
          const activo = tipo === t.valor
          return (
            <button
              key={t.valor}
              type="button"
              onClick={() => onChange(t.valor)}
              aria-pressed={activo}
              className={`flex items-center gap-2.5 rounded-xl border-[1.5px] px-3.5 py-3 text-left hover:border-brand-teal ${
                activo ? 'border-brand-teal bg-brand-teal/10' : 'border-brand-border bg-white'
              }`}
            >
              <span
                className={`flex h-[18px] w-[18px] flex-none items-center justify-center rounded-full border-2 ${
                  activo ? 'border-brand-teal' : 'border-brand-border'
                }`}
              >
                {activo && <span className="h-2 w-2 rounded-full bg-brand-teal" />}
              </span>
              <span className="min-w-0">
                <span className="block text-sm font-semibold text-brand-night">{t.label}</span>
                <span className="block text-xs text-brand-night/45">{t.hint}</span>
              </span>
            </button>
          )
        })}
      </div>
    </div>
  )
}

function CampoImagen({
  previewUrl,
  error,
  onChange,
}: {
  previewUrl: string | null
  error?: string
  onChange: (file: File) => void
}) {
  return (
    <div className="flex flex-col gap-2">
      <span className="text-sm font-semibold text-brand-night">
        Imagen de la pregunta <span className="text-[#E0454A]">*</span>
      </span>
      <div className="grid grid-cols-1 items-stretch gap-4 sm:grid-cols-[1fr_232px]">
        <label className="flex cursor-pointer flex-col items-center justify-center gap-1.5 rounded-xl border-[1.5px] border-dashed border-[#CFDDE3] bg-[#F8FBFC] p-6 text-center hover:border-brand-teal hover:bg-brand-teal/5">
          <span className="text-sm font-semibold text-brand-night">
            Arrastra la imagen o{' '}
            <span className="text-brand-blue underline">busca en tu equipo</span>
          </span>
          <span className="text-xs text-brand-night/45">JPG, PNG o WEBP · hasta 50 MiB</span>
          <input
            type="file"
            accept="image/jpeg,image/png,image/webp"
            className="sr-only"
            onChange={(e: ChangeEvent<HTMLInputElement>) => {
              const file = e.target.files?.[0]
              e.target.value = ''
              if (file) onChange(file)
            }}
          />
        </label>
        <div className="flex flex-col overflow-hidden rounded-xl border border-brand-border">
          <div className="flex min-h-[132px] flex-1 items-center justify-center bg-brand-blue/5">
            {previewUrl ? (
              <img src={previewUrl} alt="" className="h-full w-full object-cover" />
            ) : (
              <span className="text-xs font-medium text-brand-night/45">Sin imagen todavía</span>
            )}
          </div>
          <div className="border-t border-brand-border px-3 py-2 text-[11px] font-semibold tracking-wider text-brand-night/40 uppercase">
            Previsualización
          </div>
        </div>
      </div>
      <ErrorCampo mensaje={error} />
    </div>
  )
}

function CampoVideo({
  previewUrl,
  error,
  onChange,
}: {
  previewUrl: string | null
  error?: string
  onChange: (file: File) => void
}) {
  return (
    <div className="flex flex-col gap-2">
      <span className="text-sm font-semibold text-brand-night">
        Vídeo de la pregunta <span className="text-[#E0454A]">*</span>
      </span>
      <div className="grid grid-cols-1 items-stretch gap-4 sm:grid-cols-[1fr_232px]">
        <label className="flex cursor-pointer flex-col items-center justify-center gap-1.5 rounded-xl border-[1.5px] border-dashed border-[#CFDDE3] bg-[#F8FBFC] p-6 text-center hover:border-brand-teal hover:bg-brand-teal/5">
          <span className="text-sm font-semibold text-brand-night">
            Arrastra el vídeo o{' '}
            <span className="text-brand-blue underline">busca en tu equipo</span>
          </span>
          <span className="text-xs text-brand-night/45">MP4 · hasta 50 MiB</span>
          <input
            type="file"
            accept="video/mp4"
            className="sr-only"
            onChange={(e: ChangeEvent<HTMLInputElement>) => {
              const file = e.target.files?.[0]
              e.target.value = ''
              if (file) onChange(file)
            }}
          />
        </label>
        <div className="flex flex-col overflow-hidden rounded-xl border border-brand-border">
          <div className="flex min-h-[132px] flex-1 items-center justify-center bg-brand-special/10">
            {previewUrl ? (
              <video src={previewUrl} controls className="h-full w-full object-cover" />
            ) : (
              <span className="text-xs font-medium text-brand-night/45">Sin vídeo todavía</span>
            )}
          </div>
          <div className="border-t border-brand-border px-3 py-2 text-[11px] font-semibold tracking-wider text-brand-night/40 uppercase">
            Previsualización
          </div>
        </div>
      </div>
      <ErrorCampo mensaje={error} />
    </div>
  )
}

function SeccionNiveles({
  niveles,
  errorNiveles,
  seleccionados,
  query,
  onQueryChange,
  onToggle,
}: {
  niveles: NivelParaAsignar[] | null
  errorNiveles: string
  seleccionados: string[]
  query: string
  onQueryChange: (query: string) => void
  onToggle: (nivelId: string) => void
}) {
  const q = query.trim().toLowerCase()
  const filtrados = (niveles ?? []).filter(
    (n) => !q || n.tematicaNombre.toLowerCase().includes(q) || `nivel ${n.nivelOrden}`.includes(q),
  )
  const seleccionadosInfo = (niveles ?? []).filter((n) => seleccionados.includes(n.id))

  return (
    <div className="flex flex-col gap-3.5 rounded-2xl border-[1.5px] border-dashed border-[#CFDDE3] bg-brand-teal/5 p-6">
      <div className="flex flex-wrap items-center gap-2.5">
        <h2 className="font-display text-lg font-extrabold text-brand-night">
          Asignar a nivel(es) ahora
        </h2>
        <span className="rounded-full bg-brand-base px-2.5 py-1 text-[11px] font-semibold tracking-wider text-brand-night/55 uppercase">
          Opcional
        </span>
        <span className="ml-auto text-xs font-medium text-brand-night/50">
          {seleccionados.length === 0
            ? 'Ningún nivel seleccionado'
            : seleccionados.length === 1
              ? '1 nivel seleccionado'
              : `${seleccionados.length} niveles seleccionados`}
        </span>
      </div>
      <p className="max-w-xl text-sm text-brand-night/55">
        Puedes guardarla solo en el banco y asignarla más tarde desde el nivel. Una misma pregunta
        puede estar en varios niveles.
      </p>

      {seleccionadosInfo.length > 0 && (
        <div className="flex flex-wrap gap-2">
          {seleccionadosInfo.map((n) => (
            <span
              key={n.id}
              className="flex items-center gap-2 rounded-full border-[1.5px] border-brand-teal bg-white py-1.5 pr-2 pl-3.5 text-sm font-semibold text-brand-night"
            >
              {n.tematicaNombre} · Nivel {n.nivelOrden}
              <button
                type="button"
                onClick={() => onToggle(n.id)}
                title="Quitar"
                className="flex h-[18px] w-[18px] items-center justify-center rounded-full bg-brand-base text-xs font-semibold text-brand-night/55 hover:bg-[#B3282D]/15 hover:text-[#B3282D]"
              >
                ×
              </button>
            </span>
          ))}
        </div>
      )}

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
            placeholder="Buscar nivel o temática"
            className="min-w-0 flex-1 border-0 bg-transparent text-sm text-brand-night outline-none placeholder:text-brand-night/40"
          />
        </label>
        <div className="max-h-[214px] overflow-auto">
          {niveles === null && !errorNiveles && (
            <div className="p-6 text-center text-sm text-brand-night/45">Cargando niveles…</div>
          )}
          {errorNiveles && (
            <div className="p-6 text-center text-sm text-[#B3282D]">{errorNiveles}</div>
          )}
          {niveles !== null && filtrados.length === 0 && (
            <div className="p-6 text-center text-sm text-brand-night/45">
              Ningún nivel coincide con «{query}».
            </div>
          )}
          {filtrados.map((n) => {
            const on = seleccionados.includes(n.id)
            return (
              <label
                key={n.id}
                onClick={() => onToggle(n.id)}
                className={`flex cursor-pointer items-center gap-3 border-b border-brand-base px-3.5 py-2.5 last:border-0 hover:bg-[#F8FBFC] ${on ? 'bg-brand-teal/5' : 'bg-white'}`}
              >
                <span
                  className={`flex h-[18px] w-[18px] flex-none items-center justify-center rounded-[5px] border-[1.5px] text-[11px] font-bold text-white ${
                    on ? 'border-brand-blue bg-brand-blue' : 'border-[#CFDDE3] bg-white'
                  }`}
                >
                  {on ? '✓' : ''}
                </span>
                <span className="min-w-0 flex-1">
                  <span className="block text-sm font-semibold text-brand-night">
                    {n.tematicaNombre} · Nivel {n.nivelOrden}
                  </span>
                  <span className="block text-xs text-brand-night/45">
                    {n.cantidadPreguntas} {n.cantidadPreguntas === 1 ? 'pregunta' : 'preguntas'}
                  </span>
                </span>
              </label>
            )
          })}
        </div>
      </div>
    </div>
  )
}

export function PreguntaForm() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const esEdicion = Boolean(id)

  const [cargando, setCargando] = useState(esEdicion)
  const [errorCarga, setErrorCarga] = useState('')

  const [tipo, setTipo] = useState<TipoDesafio>('imagen')
  const [archivoImagen, setArchivoImagen] = useState<File | null>(null)
  const [archivoVideo, setArchivoVideo] = useState<File | null>(null)
  const [imagenUrlActual, setImagenUrlActual] = useState<string | null>(null)
  const [videoUrlActual, setVideoUrlActual] = useState<string | null>(null)
  const [textoPregunta, setTextoPregunta] = useState('')
  const [lat, setLat] = useState('')
  const [lng, setLng] = useState('')
  const [nombreLugar, setNombreLugar] = useState('')
  const [activo, setActivo] = useState(true)

  const [niveles, setNiveles] = useState<NivelParaAsignar[] | null>(null)
  const [errorNiveles, setErrorNiveles] = useState('')
  const [nivelesSeleccionados, setNivelesSeleccionados] = useState<string[]>([])
  const [levelQuery, setLevelQuery] = useState('')

  const [errores, setErrores] = useState<Record<string, string>>({})
  const [errorGuardado, setErrorGuardado] = useState('')
  const [guardando, setGuardando] = useState(false)

  const previewImagen = useObjectUrl(archivoImagen) ?? (!archivoImagen ? imagenUrlActual : null)
  const previewVideo = useObjectUrl(archivoVideo) ?? (!archivoVideo ? videoUrlActual : null)

  useEffect(() => {
    let isMounted = true

    if (id) {
      fetchPregunta(id)
        .then((pregunta) => {
          if (!isMounted) return
          setTipo(pregunta.tipo)
          setTextoPregunta(pregunta.textoPregunta ?? '')
          setImagenUrlActual(pregunta.imagenUrl)
          setVideoUrlActual(pregunta.videoUrl)
          setLat(String(pregunta.latReal))
          setLng(String(pregunta.lngReal))
          setNombreLugar(pregunta.nombreLugar)
          setActivo(pregunta.activo)
        })
        .catch((error: unknown) => {
          if (!isMounted) return
          console.error('Error cargando la pregunta:', error)
          setErrorCarga('No se ha podido cargar la pregunta.')
        })
        .finally(() => {
          if (isMounted) setCargando(false)
        })
    } else {
      fetchNivelesParaAsignar()
        .then((lista) => {
          if (isMounted) setNiveles(lista)
        })
        .catch((error: unknown) => {
          console.error('Error cargando los niveles disponibles:', error)
          if (isMounted) setErrorNiveles('No se han podido cargar los niveles disponibles.')
        })
    }

    return () => {
      isMounted = false
    }
  }, [id])

  const { latNum, lngNum, coordsValidas } = useMemo(() => {
    const nlat = lat.trim() === '' ? NaN : Number(lat)
    const nlng = lng.trim() === '' ? NaN : Number(lng)
    const validas =
      Number.isFinite(nlat) &&
      nlat >= -90 &&
      nlat <= 90 &&
      Number.isFinite(nlng) &&
      nlng >= -180 &&
      nlng <= 180
    return { latNum: nlat, lngNum: nlng, coordsValidas: validas }
  }, [lat, lng])

  function limpiarError(campo: string) {
    setErrores((actual) => {
      if (!(campo in actual)) return actual
      const resto = { ...actual }
      delete resto[campo]
      return resto
    })
  }

  function handleImagenSeleccionada(file: File) {
    const error = validarArchivoMedia('imagen', file)
    if (error) {
      setErrores((actual) => ({ ...actual, imagen: error }))
      return
    }
    limpiarError('imagen')
    setArchivoImagen(file)
  }

  function handleVideoSeleccionado(file: File) {
    const error = validarArchivoMedia('video', file)
    if (error) {
      setErrores((actual) => ({ ...actual, video: error }))
      return
    }
    limpiarError('video')
    setArchivoVideo(file)
  }

  function toggleNivel(nivelId: string) {
    setNivelesSeleccionados((actual) =>
      actual.includes(nivelId) ? actual.filter((n) => n !== nivelId) : [...actual, nivelId],
    )
  }

  function validar(): Record<string, string> {
    const erroresLocal: Record<string, string> = {}

    if (!nombreLugar.trim()) {
      erroresLocal.nombreLugar = 'El nombre del lugar es obligatorio.'
    }
    if (lat.trim() === '' || !Number.isFinite(latNum) || latNum < -90 || latNum > 90) {
      erroresLocal.lat = 'La latitud debe ser un número entre -90 y 90.'
    }
    if (lng.trim() === '' || !Number.isFinite(lngNum) || lngNum < -180 || lngNum > 180) {
      erroresLocal.lng = 'La longitud debe ser un número entre -180 y 180.'
    }
    if (tipo === 'imagen' && !archivoImagen && !imagenUrlActual) {
      erroresLocal.imagen = 'Selecciona una imagen.'
    }
    if (tipo === 'video' && !archivoVideo && !videoUrlActual) {
      erroresLocal.video = 'Selecciona un vídeo.'
    }
    if (tipo === 'pregunta_texto' && !textoPregunta.trim()) {
      erroresLocal.textoPregunta = 'Escribe el enunciado de la pregunta.'
    }

    return erroresLocal
  }

  async function handleGuardar(e: FormEvent) {
    e.preventDefault()
    if (guardando) return

    const erroresValidacion = validar()
    if (Object.keys(erroresValidacion).length > 0) {
      setErrores(erroresValidacion)
      return
    }

    setErrores({})
    setErrorGuardado('')
    setGuardando(true)

    try {
      const { id: idGuardado } = await guardarPregunta({
        id: id ?? null,
        tipo,
        nombreLugar: nombreLugar.trim(),
        textoPregunta: tipo === 'pregunta_texto' ? textoPregunta.trim() : null,
        latReal: latNum,
        lngReal: lngNum,
        activo,
        archivo: tipo === 'imagen' ? archivoImagen : tipo === 'video' ? archivoVideo : null,
        imagenUrlActual,
        videoUrlActual,
      })

      if (!esEdicion && nivelesSeleccionados.length > 0) {
        const resultados = await asignarPreguntaANiveles(idGuardado, nivelesSeleccionados)
        const fallidos = resultados.filter((r) => r.error)
        if (fallidos.length > 0) {
          window.alert(
            `La pregunta se creó, pero no se pudo asignar a ${
              fallidos.length === 1 ? '1 nivel' : `${fallidos.length} niveles`
            }. Puedes asignarla manualmente desde el nivel.`,
          )
        }
      }

      navigate('/preguntas')
    } catch (error) {
      setErrorGuardado(
        error instanceof Error ? error.message : 'No se ha podido guardar la pregunta.',
      )
    } finally {
      setGuardando(false)
    }
  }

  if (cargando) {
    return <div className="p-8 text-sm text-brand-night/55">Cargando…</div>
  }

  if (errorCarga) {
    return (
      <div className="rounded-2xl border border-brand-error/40 bg-brand-error/10 p-5 text-sm text-[#B3282D]">
        {errorCarga}
      </div>
    )
  }

  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="font-display text-3xl font-extrabold tracking-tight text-brand-night">
          {esEdicion ? 'Editar pregunta' : 'Nueva pregunta'}
        </h1>
        <p className="mt-1.5 text-sm text-brand-night/55">
          Los campos marcados con <span className="text-[#E0454A]">*</span> son obligatorios. Se
          guarda en el banco; asignarla a un nivel es opcional.
        </p>
      </div>

      <form onSubmit={handleGuardar} noValidate className="flex flex-col gap-5">
        <div className="flex flex-col gap-6 rounded-2xl border border-brand-border bg-white p-6">
          <SelectorTipo tipo={tipo} onChange={setTipo} />

          {tipo === 'imagen' && (
            <CampoImagen
              previewUrl={previewImagen}
              error={errores.imagen}
              onChange={handleImagenSeleccionada}
            />
          )}
          {tipo === 'video' && (
            <CampoVideo
              previewUrl={previewVideo}
              error={errores.video}
              onChange={handleVideoSeleccionado}
            />
          )}
          {tipo === 'pregunta_texto' && (
            <label className="flex flex-col gap-1.5">
              <span className="text-sm font-semibold text-brand-night">
                Texto de la pregunta <span className="text-[#E0454A]">*</span>
              </span>
              <textarea
                rows={4}
                value={textoPregunta}
                onChange={(e) => {
                  setTextoPregunta(e.target.value)
                  limpiarError('textoPregunta')
                }}
                placeholder="Ej. Ciudadela inca situada a 2 430 m de altitud, sobre el valle del Urubamba."
                className={`resize-y rounded-xl border-[1.5px] px-3.5 py-3 text-sm text-brand-night outline-none placeholder:text-brand-night/40 focus:border-brand-teal focus:ring-4 focus:ring-brand-teal/15 ${
                  errores.textoPregunta ? CAMPO_ERROR : 'border-brand-border bg-white'
                }`}
              />
              <span className="text-xs text-brand-night/45">
                Es lo único que verá el jugador. Sin nombrar el lugar ni el país.
              </span>
              <ErrorCampo mensaje={errores.textoPregunta} />
            </label>
          )}

          <div className="h-px bg-brand-base" />

          <div className="flex flex-col gap-3">
            <div>
              <span className="block text-sm font-semibold text-brand-night">
                Ubicación real <span className="text-[#E0454A]">*</span>
              </span>
              <span className="mt-1 block text-xs text-brand-night/45">
                Grados decimales. La puntuación se calcula por distancia a este punto.
              </span>
            </div>
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <label className="flex flex-col gap-1.5">
                <span className="text-xs font-medium text-brand-night/60">Latitud</span>
                <input
                  type="number"
                  step="0.0001"
                  min={-90}
                  max={90}
                  value={lat}
                  onChange={(e) => {
                    setLat(e.target.value)
                    limpiarError('lat')
                  }}
                  placeholder="-90 a 90"
                  className={`${CAMPO_BASE} [font-variant-numeric:tabular-nums] ${errores.lat ? CAMPO_ERROR : ''}`}
                />
              </label>
              <label className="flex flex-col gap-1.5">
                <span className="text-xs font-medium text-brand-night/60">Longitud</span>
                <input
                  type="number"
                  step="0.0001"
                  min={-180}
                  max={180}
                  value={lng}
                  onChange={(e) => {
                    setLng(e.target.value)
                    limpiarError('lng')
                  }}
                  placeholder="-180 a 180"
                  className={`${CAMPO_BASE} [font-variant-numeric:tabular-nums] ${errores.lng ? CAMPO_ERROR : ''}`}
                />
              </label>
            </div>
            <ErrorCampo mensaje={errores.lat ?? errores.lng} />

            <div className="mt-1 flex flex-col gap-2">
              <div className="flex items-baseline gap-2.5">
                <span className="text-[11px] font-semibold tracking-wider text-brand-night/45 uppercase">
                  Vista previa del punto
                </span>
                <span className="text-xs text-brand-night/40">
                  solo comprobación visual · no editable
                </span>
              </div>
              <div className="overflow-hidden rounded-xl border border-brand-border bg-[#F8FBFC]">
                <MapaVistaPrevia
                  lat={coordsValidas ? latNum : null}
                  lng={coordsValidas ? lngNum : null}
                />
              </div>
            </div>
          </div>

          <div className="h-px bg-brand-base" />

          <label className="flex max-w-[440px] flex-col gap-1.5">
            <span className="text-sm font-semibold text-brand-night">
              Nombre del lugar <span className="text-[#E0454A]">*</span>
            </span>
            <input
              type="text"
              value={nombreLugar}
              onChange={(e) => {
                setNombreLugar(e.target.value)
                limpiarError('nombreLugar')
              }}
              placeholder="Ej. Torre Eiffel, París"
              className={`${CAMPO_BASE} ${errores.nombreLugar ? CAMPO_ERROR : ''}`}
            />
            <span className="text-xs text-brand-night/45">
              Se muestra al jugador al revelar la respuesta.
            </span>
            <ErrorCampo mensaje={errores.nombreLugar} />
          </label>

          <label className="flex cursor-pointer items-center gap-3.5">
            <input
              type="checkbox"
              checked={activo}
              onChange={(e) => setActivo(e.target.checked)}
              className="peer sr-only"
            />
            <span className="relative h-[26px] w-11 flex-none rounded-full bg-brand-border transition-colors peer-checked:bg-brand-teal">
              <span className="absolute top-[3px] left-[3px] h-5 w-5 rounded-full bg-white shadow transition-transform peer-checked:translate-x-[18px]" />
            </span>
            <span>
              <span className="block text-sm font-semibold text-brand-night">
                {activo ? 'Activa' : 'Inactiva'}
              </span>
              <span className="mt-1 block text-xs text-brand-night/45">
                {activo
                  ? 'Puede salir en partidas de los niveles donde esté asignada.'
                  : 'Se guarda en el banco pero no se muestra a los jugadores.'}
              </span>
            </span>
          </label>
        </div>

        {!esEdicion && (
          <SeccionNiveles
            niveles={niveles}
            errorNiveles={errorNiveles}
            seleccionados={nivelesSeleccionados}
            query={levelQuery}
            onQueryChange={setLevelQuery}
            onToggle={toggleNivel}
          />
        )}

        <div className="sticky bottom-0 flex flex-wrap items-center gap-3 border-t border-brand-border bg-brand-base/90 py-3.5 backdrop-blur-sm">
          {errorGuardado && (
            <span className="text-sm font-medium text-[#B3282D]">{errorGuardado}</span>
          )}
          <div className="ml-auto flex gap-2.5">
            <button
              type="button"
              onClick={() => navigate('/preguntas')}
              className="rounded-xl border-[1.5px] border-[#CFDDE3] bg-white px-4.5 py-3 text-sm font-semibold text-brand-night/70 hover:border-brand-error hover:text-brand-error"
            >
              Cancelar
            </button>
            <button
              type="submit"
              disabled={guardando}
              className="rounded-xl px-5.5 py-3.5 font-display text-base font-extrabold text-white disabled:cursor-not-allowed disabled:opacity-60"
              style={{ background: 'linear-gradient(140deg, #2BC0A8, #1B6FA8)' }}
            >
              {guardando ? 'Guardando…' : 'Guardar pregunta'}
            </button>
          </div>
        </div>
      </form>
    </div>
  )
}
