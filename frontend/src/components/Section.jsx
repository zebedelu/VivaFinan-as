import { classNames } from '../lib/format'

export default function Section({ title, description, action, children, className, id }) {
  return (
    <section className={classNames('rule scroll-mt-24 pt-6', className)} aria-labelledby={id}>
      <div className="mb-4 flex flex-wrap items-end justify-between gap-3">
        <div>
          <h2 id={id} className="section-title">
            {title}
          </h2>
          {description ? <p className="mt-1 text-sm text-muted">{description}</p> : null}
        </div>
        {action}
      </div>
      {children}
    </section>
  )
}
