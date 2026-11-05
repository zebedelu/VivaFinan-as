import { useCallback, useEffect, useState } from 'react'
import { apiFetch } from '../services/api'

export function useApi(path, { enabled = true } = {}) {
  const [state, setState] = useState({
    data: null,
    error: null,
    loading: Boolean(path && enabled),
  })
  const [tick, setTick] = useState(0)

  useEffect(() => {
    if (!path || !enabled) {
      setState((prev) => ({ ...prev, loading: false }))
      return undefined
    }

    const controller = new AbortController()
    setState((prev) => ({ ...prev, loading: true, error: null }))

    apiFetch(path, { signal: controller.signal })
      .then((data) => {
        setState({ data, error: null, loading: false })
      })
      .catch((error) => {
        if (error?.name === 'AbortError') return
        setState({ data: null, error, loading: false })
      })

    return () => controller.abort()
  }, [path, enabled, tick])

  const refetch = useCallback(() => setTick((value) => value + 1), [])

  return {
    ...state,
    refetch,
    unavailable: state.error?.status === 503,
  }
}
