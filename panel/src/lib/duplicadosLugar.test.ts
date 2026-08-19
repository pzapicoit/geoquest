import { describe, it, expect } from 'vitest'
import {
  UMBRAL_DUPLICADO_KM,
  distanciaKm,
  esMismoLugar,
  filtrarCandidatosNuevos,
  mismoNombreLugar,
  normalizarNombreLugar,
} from './duplicadosLugar'

const EIFFEL = { nombre: 'Torre Eiffel, París', lat: 48.8584, lng: 2.2945 }
const COLISEO = { nombre: 'Coliseo, Roma', lat: 41.8902, lng: 12.4922 }
const MACHU = { nombre: 'Machu Picchu', lat: -13.1631, lng: -72.545 }

describe('normalizarNombreLugar', () => {
  it('quita acentos, mayúsculas y puntuación', () => {
    expect(normalizarNombreLugar('Torre Eiffel, París')).toBe('torre eiffel paris')
    expect(normalizarNombreLugar('  Angkor   Wat!  ')).toBe('angkor wat')
    expect(normalizarNombreLugar('MOÑOÑO-ÑÚ')).toBe('monono nu')
  })
})

describe('mismoNombreLugar', () => {
  it('reconoce el mismo nombre escrito distinto', () => {
    expect(mismoNombreLugar('Torre Eiffel', 'torre eiffel')).toBe(true)
    expect(mismoNombreLugar('Machu Picchu', 'MACHU PICCHU')).toBe(true)
  })

  it('reconoce el nombre del banco dentro del nombre que da la IA', () => {
    expect(mismoNombreLugar('Coliseo', 'Coliseo, Roma')).toBe(true)
    expect(mismoNombreLugar('Iguazú', 'Cataratas del Iguazú, Argentina')).toBe(true)
  })

  it('no confunde lugares distintos que comparten palabras de relleno', () => {
    expect(mismoNombreLugar('La Paz', 'La Habana')).toBe(false)
    expect(mismoNombreLugar('Templo de Karnak', 'Templo de Angkor')).toBe(false)
  })

  it('no dice nada de un nombre sin palabras significativas', () => {
    expect(mismoNombreLugar('de la', 'Coliseo')).toBe(false)
  })
})

describe('distanciaKm', () => {
  it('mide la distancia entre dos coordenadas conocidas', () => {
    // París-Roma son unos 1 100 km en línea recta.
    expect(distanciaKm(EIFFEL, COLISEO)).toBeGreaterThan(1080)
    expect(distanciaKm(EIFFEL, COLISEO)).toBeLessThan(1120)
  })

  it('da cero para el mismo punto', () => {
    expect(distanciaKm(EIFFEL, EIFFEL)).toBe(0)
  })
})

describe('esMismoLugar', () => {
  it('considera duplicado un nombre distinto a menos del umbral', () => {
    const eiffelEnIngles = { nombre: 'Eiffel Tower', lat: 48.86, lng: 2.295 }

    expect(mismoNombreLugar(eiffelEnIngles.nombre, EIFFEL.nombre)).toBe(false)
    expect(esMismoLugar(eiffelEnIngles, EIFFEL)).toBe(true)
  })

  it('no considera duplicados dos lugares lejanos con nombres distintos', () => {
    expect(esMismoLugar(EIFFEL, MACHU)).toBe(false)
  })

  it('respeta el umbral de distancia por ambos lados', () => {
    const base = { nombre: 'Uno', lat: 0, lng: 0 }
    // 1 grado de latitud son ~111 km, así que 0,08 grados quedan dentro de 10 km
    // y 0,1 grados fuera.
    const dentro = { nombre: 'Dos', lat: 0.08, lng: 0 }
    const fuera = { nombre: 'Tres', lat: 0.1, lng: 0 }

    expect(distanciaKm(base, dentro)).toBeLessThanOrEqual(UMBRAL_DUPLICADO_KM)
    expect(distanciaKm(base, fuera)).toBeGreaterThan(UMBRAL_DUPLICADO_KM)
    expect(esMismoLugar(base, dentro)).toBe(true)
    expect(esMismoLugar(base, fuera)).toBe(false)
  })
})

describe('filtrarCandidatosNuevos', () => {
  it('descarta los que ya están en el banco y conserva el orden', () => {
    const nuevos = filtrarCandidatosNuevos([EIFFEL, MACHU, COLISEO], [{ ...COLISEO }])

    expect(nuevos.map((lugar) => lugar.nombre)).toEqual([EIFFEL.nombre, MACHU.nombre])
  })

  it('descarta duplicados dentro del propio lote', () => {
    const repetido = { nombre: 'Eiffel Tower', lat: 48.8585, lng: 2.2946 }

    const nuevos = filtrarCandidatosNuevos([EIFFEL, repetido, MACHU], [])

    expect(nuevos.map((lugar) => lugar.nombre)).toEqual([EIFFEL.nombre, MACHU.nombre])
  })

  it('deja pasar todo cuando el banco está vacío y no hay repeticiones', () => {
    expect(filtrarCandidatosNuevos([EIFFEL, COLISEO, MACHU], [])).toHaveLength(3)
  })

  it('no compara contra lugares de otras temáticas, porque no se le pasan', () => {
    // El llamador solo pasa el banco de la temática elegida: un lugar cercano de
    // otra temática no está en `existentes` y por tanto no descarta nada.
    const cercanoDeOtraTematica = { nombre: 'Arco de Constantino', lat: 41.8898, lng: 12.4907 }

    expect(filtrarCandidatosNuevos([cercanoDeOtraTematica], [])).toHaveLength(1)
    expect(filtrarCandidatosNuevos([cercanoDeOtraTematica], [COLISEO])).toHaveLength(0)
  })
})
