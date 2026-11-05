import { Link } from 'react-router-dom'
import { initials } from '../lib/format'

export default function MemberAvatars({ members = [], currentId }) {
  if (!members.length) return null
  return (
    <div className="flex items-center gap-2">
      <div className="flex -space-x-2">
        {members.slice(0, 4).map((member, index) => (
          <Link
            key={member.member_id || member.id}
            to="/individual"
            className={`flex h-8 w-8 items-center justify-center rounded-full border-2 border-areia text-2xs font-medium transition-transform hover:-translate-y-0.5 ${
              index % 3 === 2 ? 'text-[#22201d]' : 'text-white'
            }`}
            style={{
              background: ['var(--verde)', 'var(--terracota)', 'var(--dourado)'][index % 3],
            }}
            title={`${member.nome}${member.papel === 'admin' ? ' — administrador' : ''}`}
            aria-label={`Abrir a página de ${member.nome}`}
          >
            {initials(member.nome)}
          </Link>
        ))}
      </div>
      <span className="text-xs text-muted">
        {members.length === 1 ? '1 pessoa' : `${members.length} pessoas`}
        {currentId ? ' na família' : ''}
      </span>
    </div>
  )
}
