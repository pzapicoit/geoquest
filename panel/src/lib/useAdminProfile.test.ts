import { describe, it, expect, vi, beforeEach } from 'vitest'
import { renderHook, waitFor } from '@testing-library/react'
import { useAdminProfile } from './useAdminProfile'

const getSession = vi.fn()
const onAuthStateChange = vi.fn()
const from = vi.fn()

vi.mock('./supabaseClient', () => ({
  supabase: {
    auth: {
      getSession: (...args: unknown[]) => getSession(...args),
      onAuthStateChange: (...args: unknown[]) => onAuthStateChange(...args),
    },
    from: (...args: unknown[]) => from(...args),
  },
}))

beforeEach(() => {
  getSession.mockReset()
  onAuthStateChange
    .mockReset()
    .mockReturnValue({ data: { subscription: { unsubscribe: vi.fn() } } })
  from.mockReset()
})

describe('useAdminProfile', () => {
  it('devuelve el nombre del admin autenticado', async () => {
    getSession.mockResolvedValue({ data: { session: { user: { id: 'admin-1' } } } })
    from.mockReturnValue({
      select: () => ({
        eq: () => ({
          single: () => Promise.resolve({ data: { nombre: 'Valoe Márquez' }, error: null }),
        }),
      }),
    })

    const { result } = renderHook(() => useAdminProfile())

    await waitFor(() => expect(result.current.nombre).toBe('Valoe Márquez'))
    expect(result.current.loading).toBe(false)
    expect(from).toHaveBeenCalledWith('profiles')
  })

  it('sin sesión no consulta profiles y deja nombre en null', async () => {
    getSession.mockResolvedValue({ data: { session: null } })

    const { result } = renderHook(() => useAdminProfile())

    await waitFor(() => expect(result.current.loading).toBe(false))
    expect(result.current.nombre).toBeNull()
    expect(from).not.toHaveBeenCalled()
  })
})
