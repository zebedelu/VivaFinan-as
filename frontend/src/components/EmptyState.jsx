export default function EmptyState({ icon: Icon, title, description, action, className = '' }) {
  return (
    <div className={`flex flex-col items-start gap-3 py-10 ${className}`}>
      {Icon ? (
        <span className="flex h-10 w-10 items-center justify-center rounded-full border border-linha text-muted">
          <Icon size={18} aria-hidden="true" />
        </span>
      ) : null}
      <div>
        <p className="font-display text-xl">{title}</p>
        {description ? <p className="mt-1 max-w-md text-sm text-muted">{description}</p> : null}
      </div>
      {action}
    </div>
  )
}
