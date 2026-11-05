import { classNames } from '../lib/format'

const VARIANTS = {
  primary: 'btn-primary',
  secondary: 'btn-secondary',
  ghost: 'btn-ghost',
  danger: 'btn-danger',
}

export default function Button({
  children,
  variant = 'primary',
  type = 'button',
  className,
  loading = false,
  disabled,
  ...props
}) {
  return (
    <button
      type={type}
      className={classNames(VARIANTS[variant] || VARIANTS.primary, className)}
      disabled={disabled || loading}
      aria-busy={loading || undefined}
      {...props}
    >
      {loading ? (
        <span
          className="h-3.5 w-3.5 animate-spin rounded-full border-2 border-current border-t-transparent"
          aria-hidden="true"
        />
      ) : null}
      {children}
    </button>
  )
}
