import { useMemo } from 'react'
import { geoContains, geoNaturalEarth1, geoPath } from 'd3-geo'
import { feature } from 'topojson-client'
import type { GeometryCollection, Topology } from 'topojson-specification'
import type { Feature, GeometryObject } from 'geojson'
import worldTopology from '../assets/world-110m.json'

const WIDTH = 760
const HEIGHT = 340

interface CountryProperties {
  name: string
}

const world = feature(
  worldTopology as unknown as Topology,
  (worldTopology as unknown as Topology).objects.countries as GeometryCollection<CountryProperties>,
)

const projection = geoNaturalEarth1().fitExtent(
  [
    [8, 10],
    [WIDTH - 8, HEIGHT - 10],
  ],
  { type: 'Sphere' },
)
const path = geoPath(projection)
const sphere = path({ type: 'Sphere' }) ?? ''
const landPaths = world.features.map((pais) => ({ pais, d: path(pais) ?? '' }))

export function MapaVistaPrevia({ lat, lng }: { lat: number | null; lng: number | null }) {
  const { pin, paisResaltado, coordsLabel, placeLabel } = useMemo(() => {
    const ok = lat !== null && lng !== null
    const punto: [number, number] | null = ok ? projection([lng, lat]) : null
    const pais: Feature<GeometryObject, CountryProperties> | undefined = ok
      ? world.features.find((f) => geoContains(f, [lng, lat]))
      : undefined

    return {
      pin: punto,
      paisResaltado: pais,
      coordsLabel: ok ? `${lat.toFixed(4)}, ${lng.toFixed(4)}` : 'Coordenadas incompletas',
      placeLabel: ok ? (pais ? pais.properties.name : 'en el mar') : '',
    }
  }, [lat, lng])

  return (
    <div className="relative">
      <svg
        viewBox={`0 0 ${WIDTH} ${HEIGHT}`}
        width="100%"
        role="img"
        aria-label="Vista previa de la ubicación en el mapa, no interactiva"
        className="block rounded-xl bg-[#F8FBFC]"
      >
        <path d={sphere} fill="#F1F6F8" stroke="#DCE6EA" strokeWidth={1} />
        {landPaths.map(({ pais, d }) => (
          <path
            key={pais.properties.name}
            d={d}
            fill={pais === paisResaltado ? 'rgba(43,192,168,.32)' : '#E4EBEE'}
            stroke="#fff"
            strokeWidth={0.7}
          />
        ))}
        {pin && (
          <g transform={`translate(${pin[0]},${pin[1]})`}>
            <circle r={13} fill="rgba(27,111,168,.16)" />
            <path
              d="M0 2c0 0 7-6.6 7-11.2A7 7 0 0 0-7-9.2C-7-4.6 0 2 0 2z"
              fill="#FF5A5F"
              stroke="#fff"
              strokeWidth={1.6}
            />
            <circle cy={-9.4} r={2.4} fill="#fff" />
          </g>
        )}
      </svg>
      <div className="absolute bottom-3 left-3 flex items-center gap-2 rounded-lg border border-brand-border bg-white/95 px-2.5 py-1.5 text-xs font-semibold text-brand-night [font-variant-numeric:tabular-nums]">
        {coordsLabel}
        {placeLabel && <span className="font-normal text-brand-night/50">{placeLabel}</span>}
      </div>
    </div>
  )
}
