import { forwardRef } from 'react'
import { classNames } from '../lib/format'

export function Field({ label, htmlFor, hint, error, children, className }) {
  return (
    <div className={className}>
      {label ? (
        <label className="label" htmlFor={htmlFor}>
          {label}
        </label>
      ) : null}
      {children}
      {hint && !error ? <p className="mt-1.5 text-xs text-muted">{hint}</p> : null}
      {error ? (
        <p className="mt-1.5 text-xs text-terracota-texto" role="alert">
          {error}
        </p>
      ) : null}
    </div>
  )
}

export const Input = forwardRef(function Input({ className, ...props }, ref) {
  return <input ref={ref} className={classNames('field', className)} {...props} />
})

export const Select = forwardRef(function Select({ className, children, ...props }, ref) {
  return (
    <select ref={ref} className={classNames('field appearance-none pr-8', className)} {...props}>
      {children}
    </select>
  )
})

export const Textarea = forwardRef(function Textarea({ className, ...props }, ref) {
  return <textarea ref={ref} className={classNames('field min-h-[84px] resize-y', className)} {...props} />
})
