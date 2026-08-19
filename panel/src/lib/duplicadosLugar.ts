// Detección de lugares duplicados para la generación con IA (INT-113, D9).
//
// El nombre por sí solo no basta ("Torre Eiffel" vs "Eiffel Tower") y la
// coordenada por sí sola tampoco (dos monumentos distintos a 3 km en el centro
// de Roma no son el mismo lugar). Se usan las dos señales, y cualquiera de las
// dos basta para considerar que un candidato ya está en el banco.

export const UMBRAL_DUPLICADO_KM = 10

export interface LugarComparable {
  nombre: string
  lat: number
  lng: number
}

// Palabras que solo dan estructura al nombre: si contaran como significativas,
// un banco con "La Paz" haría duplicado a cualquier candidato con "la".
const PALABRAS_VACIAS = new Set([
  'de',
  'del',
  'la',
  'las',
  'el',
  'los',
  'y',
  'en',
  'a',
  'al',
  'of',
  'the',
])

export function normalizarNombreLugar(nombre: string): string {
  return nombre
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
}

function palabrasSignificativas(nombre: string): Set<string> {
  return new Set(
    normalizarNombreLugar(nombre)
      .split(' ')
      .filter((palabra) => palabra.length > 0 && !PALABRAS_VACIAS.has(palabra)),
  )
}

function esSubconjunto(menor: Set<string>, mayor: Set<string>): boolean {
  for (const palabra of menor) {
    if (!mayor.has(palabra)) return false
  }
  return true
}

// La IA nombra los lugares con su ciudad ("Coliseo, Roma") y el banco a menudo
// no ("Coliseo"), así que la igualdad exacta se quedaría corta: basta con que
// las palabras significativas de uno estén contenidas en las del otro.
export function mismoNombreLugar(unNombre: string, otroNombre: string): boolean {
  const unas = palabrasSignificativas(unNombre)
  const otras = palabrasSignificativas(otroNombre)
  if (unas.size === 0 || otras.size === 0) return false

  return unas.size <= otras.size ? esSubconjunto(unas, otras) : esSubconjunto(otras, unas)
}

const RADIO_TIERRA_KM = 6371

function aRadianes(grados: number): number {
  return (grados * Math.PI) / 180
}

export function distanciaKm(uno: LugarComparable, otro: LugarComparable): number {
  const dLat = aRadianes(otro.lat - uno.lat)
  const dLng = aRadianes(otro.lng - uno.lng)
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(aRadianes(uno.lat)) * Math.cos(aRadianes(otro.lat)) * Math.sin(dLng / 2) ** 2

  return 2 * RADIO_TIERRA_KM * Math.asin(Math.min(1, Math.sqrt(a)))
}

export function esMismoLugar(uno: LugarComparable, otro: LugarComparable): boolean {
  return mismoNombreLugar(uno.nombre, otro.nombre) || distanciaKm(uno, otro) <= UMBRAL_DUPLICADO_KM
}

// Descarta los candidatos que dupliquen el banco de la temática o a otro
// candidato ya aceptado del mismo lote, preservando el orden de llegada.
export function filtrarCandidatosNuevos<T extends LugarComparable>(
  candidatos: T[],
  existentes: LugarComparable[],
): T[] {
  const aceptados: T[] = []

  for (const candidato of candidatos) {
    const duplicado =
      existentes.some((existente) => esMismoLugar(candidato, existente)) ||
      aceptados.some((aceptado) => esMismoLugar(candidato, aceptado))

    if (!duplicado) aceptados.push(candidato)
  }

  return aceptados
}
