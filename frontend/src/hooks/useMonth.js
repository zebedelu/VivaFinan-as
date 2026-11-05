import { useCallback, useMemo } from 'react'
import { useSearchParams } from 'react-router-dom'
import { addMonths, currentMonth, formatMonth } from '../lib/format'

const MONTH_RE = /^\d{4}-(0[1-9]|1[0-2])-01$/

export function useMonth() {
  const [params, setParams] = useSearchParams()
  const raw = params.get('mes')
  const mes = raw && MONTH_RE.test(raw) ? raw : currentMonth()

  const setMes = useCallback(
    (next) => {
      const value = next || currentMonth()
      setParams(
        (prev) => {
          const copy = new URLSearchParams(prev)
          if (value === currentMonth()) copy.delete('mes')
          else copy.set('mes', value)
          return copy
        },
        { replace: true },
      )
    },
    [setParams],
  )

  const prev = useCallback(() => setMes(addMonths(mes, -1)), [mes, setMes])
  const next = useCallback(() => setMes(addMonths(mes, 1)), [mes, setMes])

  return useMemo(
    () => ({
      mes,
      setMes,
      prev,
      next,
      label: formatMonth(mes),
      shortLabel: formatMonth(mes, { short: true }),
      isCurrent: mes === currentMonth(),
    }),
    [mes, setMes, prev, next],
  )
}
