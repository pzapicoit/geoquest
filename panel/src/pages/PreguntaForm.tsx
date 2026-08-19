import { useEffect, useMemo, useState, type ChangeEvent, type FormEvent } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { MapaVistaPrevia } from '../components/MapaVistaPrevia'
import type { TipoDesafio } from '../lib/preguntas'
import { DIFICULTADES, type Dificultad } from '../lib/dificultad'
import {
  fetchPregunta,
  fetchTematicasParaPregunta,
  guardarPregunta,
  validarArchivoMedia,
  type TematicaOpcion,
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

function SeccionHeader({ numero, titulo }: { numero: number; titulo: string }) {
  return (
    <div className="flex items-center gap-2.5">
      <span className="text-[10.5px] font-semibold tracking-widest text-brand-night/38 uppercase">
        {numero} · {titulo}
      </span>
      <span className="h-px flex-1 bg-brand-base" />
    </div>
  )
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

function SelectorTematicaYDificultad({
  tematicaId,
  tematicas,
  errorTematicas,
  dificultad,
  errorTematicaId,
  errorDificultad,
  onTematicaChange,
  onDificultadChange,
}: {
  tematicaId: string
  tematicas: TematicaOpcion[] | null
  errorTematicas: string
  dificultad: Dificultad | ''
  errorTematicaId?: string
  errorDificultad?: string
  onTematicaChange: (tematicaId: string) => void
  onDificultadChange: (dificultad: Dificultad) => void
}) {
  return (
    <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
      <label className="flex flex-col gap-1.5">
        <span className="text-sm font-semibold text-brand-night">
          Temática <span className="text-[#E0454A]">*</span>
        </span>
        <select
          value={tematicaId}
          onChange={(e) => onTematicaChange(e.target.value)}
          disabled={tematicas === null}
          className={`${CAMPO_BASE} ${errorTematicaId ? CAMPO_ERROR : ''}`}
        >
          <option value="">
            {tematicas === null ? 'Cargando temáticas…' : 'Selecciona una temática'}
          </option>
          {(tematicas ?? []).map((t) => (
            <option key={t.id} value={t.id}>
              {t.nombre}
            </option>
          ))}
        </select>
        <ErrorCampo mensaje={errorTematicas || errorTematicaId} />
      </label>

      <label className="flex flex-col gap-1.5">
        <span className="text-sm font-semibold text-brand-night">
          Dificultad <span className="text-[#E0454A]">*</span>
        </span>
        <select
          value={dificultad}
          onChange={(e) => onDificultadChange(e.target.value as Dificultad)}
          className={`${CAMPO_BASE} ${errorDificultad ? CAMPO_ERROR : ''}`}
        >
          <option value="">Selecciona una dificultad</option>
          {DIFICULTADES.map((d) => (
            <option key={d.valor} value={d.valor}>
              {d.label}
            </option>
          ))}
        </select>
        <ErrorCampo mensaje={errorDificultad} />
      </label>
    </div>
  )
}

export function PreguntaForm() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const esEdicion = Boolean(id)

  const [cargando, setCargando] = useState(esEdicion)
  const [errorCarga, setErrorCarga] = useState('')

  const [nombre, setNombre] = useState('')
  const [tipo, setTipo] = useState<TipoDesafio>('imagen')
  const [archivoImagen, setArchivoImagen] = useState<File | null>(null)
  const [archivoVideo, setArchivoVideo] = useState<File | null>(null)
  const [imagenUrlActual, setImagenUrlActual] = useState<string | null>(null)
  const [videoUrlActual, setVideoUrlActual] = useState<string | null>(null)
  const [textoPregunta, setTextoPregunta] = useState('')
  const [lat, setLat] = useState('')
  const [lng, setLng] = useState('')
  const [nombreLugar, setNombreLugar] = useState('')
  const [pista, setPista] = useState('')
  const [activo, setActivo] = useState(true)
  const [tematicaId, setTematicaId] = useState('')
  const [dificultad, setDificultad] = useState<Dificultad | ''>('')

  const [tematicas, setTematicas] = useState<TematicaOpcion[] | null>(null)
  const [errorTematicas, setErrorTematicas] = useState('')

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
          setNombre(pregunta.nombre)
          setTipo(pregunta.tipo)
          setTextoPregunta(pregunta.textoPregunta ?? '')
          setImagenUrlActual(pregunta.imagenUrl)
          setVideoUrlActual(pregunta.videoUrl)
          setLat(String(pregunta.latReal))
          setLng(String(pregunta.lngReal))
          setNombreLugar(pregunta.nombreLugar)
          setPista(pregunta.pista ?? '')
          setActivo(pregunta.activo)
          setTematicaId(pregunta.tematicaId)
          setDificultad(pregunta.dificultad)
        })
        .catch((error: unknown) => {
          if (!isMounted) return
          console.error('Error cargando la pregunta:', error)
          setErrorCarga('No se ha podido cargar la pregunta.')
        })
        .finally(() => {
          if (isMounted) setCargando(false)
        })
    }

    fetchTematicasParaPregunta()
      .then((lista) => {
        if (isMounted) setTematicas(lista)
      })
      .catch((error: unknown) => {
        console.error('Error cargando las temáticas:', error)
        if (isMounted) setErrorTematicas('No se han podido cargar las temáticas.')
      })

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

  function validar(): Record<string, string> {
    const erroresLocal: Record<string, string> = {}

    if (!nombre.trim()) {
      erroresLocal.nombre = 'El nombre es obligatorio.'
    }
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
    if (!tematicaId) {
      erroresLocal.tematicaId = 'Selecciona una temática.'
    }
    if (!dificultad) {
      erroresLocal.dificultad = 'Selecciona una dificultad.'
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
      await guardarPregunta({
        id: id ?? null,
        nombre: nombre.trim(),
        tipo,
        nombreLugar: nombreLugar.trim(),
        pista: pista.trim() ? pista.trim() : null,
        textoPregunta: tipo === 'pregunta_texto' ? textoPregunta.trim() : null,
        latReal: latNum,
        lngReal: lngNum,
        activo,
        tematicaId,
        dificultad: dificultad as Dificultad,
        archivo: tipo === 'imagen' ? archivoImagen : tipo === 'video' ? archivoVideo : null,
        imagenUrlActual,
        videoUrlActual,
      })

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
          Los campos marcados con <span className="text-[#E0454A]">*</span> son obligatorios.
        </p>
      </div>

      <form onSubmit={handleGuardar} noValidate className="flex flex-col gap-5">
        <div className="flex flex-col gap-6 rounded-2xl border border-brand-border bg-white p-6">
          <label className="flex max-w-[440px] flex-col gap-1.5">
            <span className="text-sm font-semibold text-brand-night">
              Nombre <span className="text-[#E0454A]">*</span>
            </span>
            <input
              type="text"
              value={nombre}
              onChange={(e) => {
                setNombre(e.target.value)
                limpiarError('nombre')
              }}
              placeholder="Ej. Torre Eiffel"
              className={`${CAMPO_BASE} ${errores.nombre ? CAMPO_ERROR : ''}`}
            />
            <span className="text-xs text-brand-night/45">
              Identifica esta pregunta en el panel y se muestra al jugador junto al objetivo de la
              temática.
            </span>
            <ErrorCampo mensaje={errores.nombre} />
          </label>

          <SeccionHeader numero={1} titulo="Contenido" />
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

          <SeccionHeader numero={2} titulo="Ubicación" />

          <div className="flex flex-col gap-3">
            <div>
              <span className="block text-sm font-semibold text-brand-night">
                Ubicación real <span className="text-[#E0454A]">*</span>
              </span>
              <span className="mt-1 block text-xs text-brand-night/45">
                Grados decimales. La puntuación se calcula por distancia a este punto.
              </span>
            </div>
            <div className="grid grid-cols-1 items-start gap-4 sm:grid-cols-[1fr_268px]">
              <div className="flex flex-col gap-3">
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
                <ErrorCampo mensaje={errores.lat ?? errores.lng} />
              </div>

              <div className="flex flex-col gap-2">
                <div className="flex items-baseline gap-2">
                  <span className="text-[10.5px] font-semibold tracking-wider text-brand-night/45 uppercase">
                    Vista previa
                  </span>
                  <span className="text-[10.5px] text-brand-night/35">no editable</span>
                </div>
                <div className="overflow-hidden rounded-xl border border-brand-border bg-[#F8FBFC]">
                  <MapaVistaPrevia
                    lat={coordsValidas ? latNum : null}
                    lng={coordsValidas ? lngNum : null}
                  />
                </div>
              </div>
            </div>
          </div>

          <SeccionHeader numero={3} titulo="Clasificación" />

          <SelectorTematicaYDificultad
            tematicaId={tematicaId}
            tematicas={tematicas}
            errorTematicas={errorTematicas}
            dificultad={dificultad}
            errorTematicaId={errores.tematicaId}
            errorDificultad={errores.dificultad}
            onTematicaChange={(valor) => {
              setTematicaId(valor)
              limpiarError('tematicaId')
            }}
            onDificultadChange={(valor) => {
              setDificultad(valor)
              limpiarError('dificultad')
            }}
          />

          <SeccionHeader numero={4} titulo="Datos y estado" />

          <label className="flex max-w-[440px] flex-col gap-1.5">
            <span className="text-sm font-semibold text-brand-night">
              Respuesta real (lugar que se revela) <span className="text-[#E0454A]">*</span>
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
              El lugar real que se revela al jugador al terminar el desafío. No es el nombre de la
              pregunta.
            </span>
            <ErrorCampo mensaje={errores.nombreLugar} />
          </label>

          <label className="flex max-w-[440px] flex-col gap-1.5">
            <span className="text-sm font-semibold text-brand-night">
              Pista <span className="font-medium text-brand-night/40">· opcional</span>
            </span>
            <textarea
              rows={2}
              value={pista}
              onChange={(e) => setPista(e.target.value)}
              placeholder="Pista adicional en texto sobre la pregunta"
              className={`${CAMPO_BASE} h-auto resize-y py-2.5`}
            />
            <span className="text-xs text-brand-night/45">
              Por ahora no se muestra en la app ni en el listado, solo aquí.
            </span>
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
                  ? 'Puede salir en partidas de su temática y dificultad.'
                  : 'Se guarda en el banco pero no se muestra a los jugadores.'}
              </span>
            </span>
          </label>
        </div>

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
