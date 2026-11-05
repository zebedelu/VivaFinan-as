import { Link } from 'react-router-dom'

export default function AuthLayout({ children }) {
  return (
    <div className="min-h-screen bg-areia lg:grid lg:grid-cols-[1.05fr_1fr]">
      <section className="relative hidden flex-col justify-between overflow-hidden bg-verde-forte p-12 text-sobre-verde lg:flex">
        <div
          className="pointer-events-none absolute inset-0 opacity-[0.12]"
          style={{
            backgroundImage:
              'repeating-linear-gradient(to bottom, transparent 0 47px, rgba(244,239,230,.7) 47px 48px)',
          }}
          aria-hidden="true"
        />
        <Link to="/login" className="relative font-display text-2xl no-underline">
          VivaFinanças
        </Link>

        <div className="relative max-w-md">
          <p className="font-display text-[3.4rem] leading-[1.02] tracking-tight text-balance">
            O mês da sua família, em uma página.
          </p>
          <p className="mt-6 max-w-sm text-sm leading-relaxed text-sobre-verde/70">
            Receitas, despesas, contas a confirmar e metas no mesmo lugar. Sem planilha, sem
            susto no fim do mês.
          </p>
          <div className="mt-10 max-w-xs border-t border-white/20 pt-4 text-xs text-sobre-verde/65">
            Um caderno de contas para quem divide a vida — e as contas.
          </div>
        </div>

        <p className="relative text-2xs text-sobre-verde/65">
          Seus dados ficam na sua família. Ninguém vê o detalhe do outro.
        </p>
      </section>

      <main className="flex min-h-screen flex-col px-5 py-7 sm:px-10 lg:px-16">
        <Link to="/login" className="font-display text-xl no-underline lg:hidden">
          VivaFinanças
        </Link>
        <div className="mx-auto flex w-full max-w-md flex-1 flex-col justify-center py-8">{children}</div>
      </main>
    </div>
  )
}
