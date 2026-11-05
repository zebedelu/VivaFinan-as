export function Loading({ label = 'Carregando', rows = 3 }) {
  return (
    <div role="status" aria-live="polite" aria-label={label} className="space-y-3 py-4">
      <span className="sr-only">{label}</span>
      <div className="h-8 w-40 animate-pulse rounded bg-linha/70" />
      {Array.from({ length: rows }).map((_, index) => (
        <div key={index} className="h-14 w-full animate-pulse rounded-card bg-linha/40" />
      ))}
    </div>
  )
}

export function SkeletonLine({ className = '' }) {
  return <div className={`h-4 animate-pulse rounded bg-linha/60 ${className}`} aria-hidden="true" />
}
