import { useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Copy, KeyRound, Moon, Plus, Sun } from 'lucide-react'
import Badge from '../components/Badge'
import Button from '../components/Button'
import { Field, Input, Select } from '../components/FormField'
import { Loading } from '../components/Loading'
import Modal from '../components/Modal'
import Section from '../components/Section'
import { ErrorState, UnavailableState } from '../components/StatePanels'
import { useToast } from '../components/Toast'
import { useApi } from '../hooks/useApi'
import { useSession } from '../hooks/useSession'
import { useTheme } from '../hooks/useTheme'
import { formatDate, formatDateTime } from '../lib/format'
import { CONNECTION_STATUS, PAPEL_LABEL, STATUS_MEMBRO_LABEL } from '../lib/labels'
import { supabase } from '../lib/supabase'
import { apiFetch, errorMessage } from '../services/api'

const ADMIN_503 = 'Admin API indisponível: configure SUPABASE_SERVICE_ROLE_KEY no servidor.'
const RESTORE_503 = 'Restauração indisponível: configure SUPABASE_DB_URL no servidor.'

function asList(data, key) {
  if (Array.isArray(data)) return data
  return data?.[key] || data?.items || []
}

function ProfileSection() {
  const { profile, user, updateProfile, signOut } = useSession()
  const { theme, setTheme } = useTheme()
  const toast = useToast()
  const [nome, setNome] = useState(profile?.nome || '')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  useEffect(() => {
    setNome(profile?.nome || '')
  }, [profile?.nome])

  async function save(event) {
    event.preventDefault()
    setError('')
    if (!nome.trim()) {
      setError('O nome não pode ficar vazio.')
      return
    }
    setBusy(true)
    try {
      await updateProfile({ nome: nome.trim() })
      toast.push('Perfil atualizado.')
    } catch (err) {
      setError(errorMessage(err, 'Não foi possível salvar o perfil.'))
    } finally {
      setBusy(false)
    }
  }

  return (
    <Section id="perfil" title="Perfil" description="Como você aparece para a família.">
      <form onSubmit={save} className="grid gap-4 sm:grid-cols-2">
        <Field label="Nome" htmlFor="perfil-nome">
          <Input id="perfil-nome" value={nome} onChange={(event) => setNome(event.target.value)} autoComplete="name" />
        </Field>
        <Field label="E-mail" htmlFor="perfil-email" hint="O e-mail de acesso não muda por aqui.">
          <Input id="perfil-email" value={user?.email || ''} readOnly disabled />
        </Field>
        <div className="sm:col-span-2">
          {error ? (
            <p className="mb-3 text-sm text-terracota-texto" role="alert">
              {error}
            </p>
          ) : null}
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div className="flex items-center gap-2">
              <span className="text-sm text-muted">Tema</span>
              <button
                type="button"
                onClick={() => setTheme('claro')}
                aria-pressed={theme === 'claro'}
                className={`inline-flex items-center gap-1.5 rounded-control border px-3 py-1.5 text-xs ${
                  theme === 'claro' ? 'border-verde bg-verde-claro text-grafite' : 'border-linha text-muted'
                }`}
              >
                <Sun size={13} aria-hidden="true" /> Claro
              </button>
              <button
                type="button"
                onClick={() => setTheme('escuro')}
                aria-pressed={theme === 'escuro'}
                className={`inline-flex items-center gap-1.5 rounded-control border px-3 py-1.5 text-xs ${
                  theme === 'escuro' ? 'border-verde bg-verde-claro text-grafite' : 'border-linha text-muted'
                }`}
              >
                <Moon size={13} aria-hidden="true" /> Escuro
              </button>
            </div>
            <div className="flex gap-2">
              <Button type="button" variant="ghost" onClick={signOut}>
                Sair da conta
              </Button>
              <Button type="submit" loading={busy}>
                Salvar perfil
              </Button>
            </div>
          </div>
        </div>
      </form>
    </Section>
  )
}

function MembersSection() {
  const { profile } = useSession()
  const toast = useToast()
  const isAdmin = profile?.papel === 'admin'
  const membersApi = useApi(isAdmin ? '/admin/members' : null)
  const [editing, setEditing] = useState(null)
  const [form, setForm] = useState({ nome: '', status: 'ativo' })
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const [resetOpen, setResetOpen] = useState(false)
  const [resetEmail, setResetEmail] = useState('')
  const [resetNotice, setResetNotice] = useState('')

  const members = useMemo(() => asList(membersApi.data, 'members'), [membersApi.data])

  function openEdit(member) {
    setEditing(member)
    setForm({ nome: member.nome, status: member.status })
    setError('')
  }

  async function save(event) {
    event.preventDefault()
    setError('')
    if (!form.nome.trim()) {
      setError('O nome não pode ficar vazio.')
      return
    }
    if (editing.id === profile?.id && form.status !== 'ativo') {
      setError('Você não pode desativar a própria conta.')
      return
    }
    setBusy(true)
    try {
      await apiFetch(`/admin/members/${editing.id}`, {
        method: 'PATCH',
        body: { nome: form.nome.trim(), status: form.status },
      })
      toast.push('Membro atualizado.')
      setEditing(null)
      membersApi.refetch()
    } catch (err) {
      setError(
        err.status === 503
          ? ADMIN_503
          : errorMessage(err, 'Não foi possível atualizar o membro.'),
      )
    } finally {
      setBusy(false)
    }
  }

  async function sendReset(event) {
    event.preventDefault()
    setResetNotice('')
    const { error: authError } = await supabase.auth.resetPasswordForEmail(resetEmail.trim(), {
      redirectTo: `${window.location.origin}/reset-password`,
    })
    if (authError) {
      setResetNotice(authError.message)
      return
    }
    setResetNotice('Se existir uma conta com esse e-mail, o link de redefinição chegará em instantes.')
  }

  if (!isAdmin) {
    return (
      <Section id="membros" title="Membros" description="Só administradores podem editar o cadastro da família.">
        <p className="py-3 text-sm text-muted">
          Você faz parte como {PAPEL_LABEL[profile?.papel] || 'membro'}. Precisa de uma mudança? Fale
          com quem administra a família.
        </p>
      </Section>
    )
  }

  return (
    <Section
      id="membros"
      title="Membros"
      description="Edite nome e status. Papel e tema de outra pessoa não mudam por aqui."
      action={
        <Button variant="secondary" className="px-3 py-1.5 text-xs" onClick={() => setResetOpen(true)}>
          <KeyRound size={13} aria-hidden="true" /> Enviar redefinição
        </Button>
      }
    >
      {membersApi.loading ? <Loading label="Carregando membros" rows={2} /> : null}
      {membersApi.error?.status === 503 ? (
        <UnavailableState title="Admin API indisponível" description={ADMIN_503} onRetry={membersApi.refetch} />
      ) : null}
      {membersApi.error && membersApi.error.status !== 503 ? (
        <ErrorState error={membersApi.error} onRetry={membersApi.refetch} />
      ) : null}
      {!membersApi.loading && !membersApi.error ? (
        <ul>
          {members.map((member) => (
            <li key={member.id} className="flex flex-wrap items-center justify-between gap-3 border-b border-linha py-3.5 last:border-b-0">
              <div>
                <p className="text-sm font-medium">
                  {member.nome}
                  {member.id === profile?.id ? <span className="ml-2 text-2xs text-muted">(você)</span> : null}
                </p>
                <p className="mt-0.5 text-xs text-muted">
                  {PAPEL_LABEL[member.papel] || member.papel} · desde {formatDate(member.criado_em)}
                </p>
              </div>
              <div className="flex items-center gap-3">
                <Badge tone={member.status === 'ativo' ? 'verde' : 'neutro'}>
                  {STATUS_MEMBRO_LABEL[member.status] || member.status}
                </Badge>
                <Button variant="secondary" className="px-3 py-1.5 text-xs" onClick={() => openEdit(member)}>
                  Editar
                </Button>
              </div>
            </li>
          ))}
        </ul>
      ) : null}

      <Modal open={Boolean(editing)} onClose={() => setEditing(null)} title="Editar membro" size="sm">
        {editing ? (
          <form onSubmit={save} className="space-y-4">
            <Field label="Nome" htmlFor="membro-nome">
              <Input
                id="membro-nome"
                value={form.nome}
                onChange={(event) => setForm((current) => ({ ...current, nome: event.target.value }))}
              />
            </Field>
            <Field
              label="Status"
              htmlFor="membro-status"
              hint={
                editing.id === profile?.id
                  ? 'Sua conta precisa continuar ativa.'
                  : 'Desativar bloqueia o acesso sem apagar o histórico.'
              }
            >
              <Select
                id="membro-status"
                value={form.status}
                onChange={(event) => setForm((current) => ({ ...current, status: event.target.value }))}
                disabled={editing.id === profile?.id}
              >
                <option value="ativo">Ativo</option>
                <option value="inativo">Inativo</option>
              </Select>
            </Field>
            {error ? (
              <p className="text-sm text-terracota-texto" role="alert">
                {error}
              </p>
            ) : null}
            <div className="flex justify-end gap-2">
              <Button variant="secondary" onClick={() => setEditing(null)}>
                Cancelar
              </Button>
              <Button type="submit" loading={busy}>
                Salvar
              </Button>
            </div>
          </form>
        ) : null}
      </Modal>

      <Modal
        open={resetOpen}
        onClose={() => {
          setResetOpen(false)
          setResetNotice('')
        }}
        title="Enviar redefinição de senha"
        description="O administrador não define a senha. Enviamos um link para a pessoa criar outra."
        size="sm"
      >
        <form onSubmit={sendReset} className="space-y-4">
          <Field label="E-mail do membro" htmlFor="reset-membro-email">
            <Input
              id="reset-membro-email"
              type="email"
              value={resetEmail}
              onChange={(event) => setResetEmail(event.target.value)}
              placeholder="pessoa@exemplo.com"
              required
            />
          </Field>
          {resetNotice ? (
            <p className="rounded-control border border-linha bg-areia px-3 py-2 text-xs" role="status">
              {resetNotice}
            </p>
          ) : null}
          <Button type="submit" className="w-full">
            Enviar link
          </Button>
        </form>
      </Modal>
    </Section>
  )
}

function InvitesSection() {
  const { profile } = useSession()
  const toast = useToast()
  const isAdmin = profile?.papel === 'admin'
  const invitesApi = useApi(isAdmin ? '/admin/invites' : null)
  const [form, setForm] = useState({ email: '', nome: '' })
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const [created, setCreated] = useState(null)
  const invites = useMemo(() => asList(invitesApi.data, 'invites'), [invitesApi.data])

  if (!isAdmin) return null

  async function create(event) {
    event.preventDefault()
    setError('')
    if (!form.email.trim()) {
      setError('Informe o e-mail de quem você quer convidar.')
      return
    }
    setBusy(true)
    try {
      const result = await apiFetch('/admin/invites', {
        method: 'POST',
        body: { email: form.email.trim(), ...(form.nome.trim() ? { nome: form.nome.trim() } : {}) },
      })
      setCreated(result)
      setForm({ email: '', nome: '' })
      toast.push('Convite criado.')
      invitesApi.refetch()
    } catch (err) {
      setError(
        err.status === 503
          ? ADMIN_503
          : err.status === 409
            ? 'Já existe um convite pendente para este e-mail.'
            : errorMessage(err, 'Não foi possível criar o convite.'),
      )
    } finally {
      setBusy(false)
    }
  }

  async function cancel(invite) {
    try {
      await apiFetch(`/admin/invites/${invite.id}`, { method: 'DELETE' })
      toast.push('Convite cancelado.')
      invitesApi.refetch()
    } catch (err) {
      toast.push(errorMessage(err, 'Não foi possível cancelar o convite.'), 'error')
    }
  }

  async function copy(token) {
    const link = `${window.location.origin}/invite/${token}`
    try {
      await navigator.clipboard.writeText(link)
      toast.push('Link copiado.')
    } catch {
      toast.push('Copie o link no campo abaixo.', 'error')
    }
  }

  return (
    <Section
      id="convites"
      title="Convites"
      description="Convide por e-mail. O link também pode ser copiado e enviado por mensagem."
    >
      <form onSubmit={create} className="flex flex-wrap items-end gap-2 border-y border-linha py-4">
        <Field label="E-mail" htmlFor="convite-email" className="min-w-[12rem] flex-1">
          <Input
            id="convite-email"
            type="email"
            value={form.email}
            onChange={(event) => setForm((current) => ({ ...current, email: event.target.value }))}
            placeholder="pessoa@exemplo.com"
            required
          />
        </Field>
        <Field label="Nome" htmlFor="convite-nome" className="min-w-[10rem] flex-1">
          <Input
            id="convite-nome"
            value={form.nome}
            onChange={(event) => setForm((current) => ({ ...current, nome: event.target.value }))}
            placeholder="Opcional"
          />
        </Field>
        <Button type="submit" loading={busy} className="mb-0.5">
          <Plus size={15} aria-hidden="true" /> Convidar
        </Button>
      </form>

      {error ? (
        <p className="mt-3 rounded-control border border-terracota/30 bg-terracota/5 px-3 py-2 text-sm text-terracota-texto" role="alert">
          {error}
        </p>
      ) : null}

      {created?.token ? (
        <div className="mt-4 rounded-card border border-verde/30 bg-verde-claro p-3">
          <p className="text-sm">Convite para {created.email || form.email} criado.</p>
          <div className="mt-2 flex flex-wrap items-center gap-2">
            <Input readOnly value={`${window.location.origin}/invite/${created.token}`} aria-label="Link do convite" />
            <Button variant="secondary" className="shrink-0" onClick={() => copy(created.token)}>
              <Copy size={14} aria-hidden="true" /> Copiar
            </Button>
          </div>
        </div>
      ) : null}

      {invitesApi.loading ? <Loading label="Carregando convites" rows={2} /> : null}
      {invitesApi.error?.status === 503 ? (
        <div className="mt-4">
          <UnavailableState title="Admin API indisponível" description={ADMIN_503} onRetry={invitesApi.refetch} />
        </div>
      ) : null}
      {invitesApi.error && invitesApi.error.status !== 503 ? (
        <div className="mt-4">
          <ErrorState error={invitesApi.error} onRetry={invitesApi.refetch} />
        </div>
      ) : null}
      {!invitesApi.loading && !invitesApi.error ? (
        invites.length ? (
          <ul className="mt-2">
            {invites.map((invite) => (
              <li key={invite.id} className="flex flex-wrap items-center justify-between gap-3 border-b border-linha py-3 last:border-b-0">
                <div className="min-w-0">
                  <p className="truncate text-sm">{invite.email}</p>
                  <p className="text-xs text-muted">
                    {invite.nome ? `${invite.nome} · ` : ''}
                    {invite.status || 'pendente'}
                  </p>
                </div>
                <div className="flex items-center gap-2">
                  {invite.token ? (
                    <button
                      type="button"
                      className="btn-ghost px-2 py-1.5 text-xs"
                      onClick={() => copy(invite.token)}
                      aria-label={`Copiar link do convite de ${invite.email}`}
                    >
                      <Copy size={13} aria-hidden="true" /> Copiar link
                    </button>
                  ) : null}
                  <button
                    type="button"
                    className="btn-ghost px-2 py-1.5 text-xs text-terracota-texto"
                    onClick={() => cancel(invite)}
                  >
                    Cancelar
                  </button>
                </div>
              </li>
            ))}
          </ul>
        ) : (
          <p className="py-4 text-sm text-muted">Nenhum convite pendente.</p>
        )
      ) : null}
    </Section>
  )
}

function CategoriesSection() {
  const toast = useToast()
  const categoriesApi = useApi('/categories')
  const [modal, setModal] = useState({ open: false, category: null })
  const [form, setForm] = useState({ nome: '', tipo: 'despesa' })
  const [deleting, setDeleting] = useState(null)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const categories = useMemo(() => asList(categoriesApi.data, 'categories'), [categoriesApi.data])

  function open(category) {
    setModal({ open: true, category })
    setForm({ nome: category?.nome || '', tipo: category?.tipo || 'despesa' })
    setError('')
  }

  async function save(event) {
    event.preventDefault()
    setError('')
    if (!form.nome.trim()) {
      setError('Dê um nome para a categoria.')
      return
    }
    setBusy(true)
    try {
      if (modal.category) {
        await apiFetch(`/categories/${modal.category.id}`, {
          method: 'PATCH',
          body: { nome: form.nome.trim() },
        })
        toast.push('Categoria atualizada.')
      } else {
        await apiFetch('/categories', {
          method: 'POST',
          body: { nome: form.nome.trim(), tipo: form.tipo },
        })
        toast.push('Categoria criada.')
      }
      setModal({ open: false, category: null })
      categoriesApi.refetch()
    } catch (err) {
      setError(errorMessage(err, 'Não foi possível salvar a categoria.'))
    } finally {
      setBusy(false)
    }
  }

  async function toggleHidden(category) {
    try {
      await apiFetch(`/categories/${category.id}`, {
        method: 'PATCH',
        body: { oculta: !category.oculta },
      })
      toast.push(category.oculta ? 'Categoria visível de novo.' : 'Categoria ocultada.')
      categoriesApi.refetch()
    } catch (err) {
      toast.push(errorMessage(err, 'Não foi possível alterar a categoria.'), 'error')
    }
  }

  async function remove() {
    if (!deleting) return
    setBusy(true)
    try {
      await apiFetch(`/categories/${deleting.id}`, { method: 'DELETE' })
      toast.push('Categoria excluída.')
      setDeleting(null)
      categoriesApi.refetch()
    } catch (err) {
      toast.push(errorMessage(err, 'Não foi possível excluir a categoria.'), 'error')
    } finally {
      setBusy(false)
    }
  }

  return (
    <Section
      id="categorias"
      title="Categorias"
      description="As padrão só podem ser ocultadas. As personalizadas você edita e exclui."
      action={
        <Button variant="secondary" className="px-3 py-1.5 text-xs" onClick={() => open(null)}>
          <Plus size={13} aria-hidden="true" /> Nova categoria
        </Button>
      }
    >
      {categoriesApi.loading ? <Loading label="Carregando categorias" rows={2} /> : null}
      {categoriesApi.error ? <ErrorState error={categoriesApi.error} onRetry={categoriesApi.refetch} /> : null}
      {!categoriesApi.loading && !categoriesApi.error
        ? ['despesa', 'receita'].map((tipo) => {
            const list = categories.filter((category) => category.tipo === tipo)
            return (
              <div key={tipo} className="mt-4 first:mt-0">
                <p className="mb-1 text-xs font-medium text-muted">
                  {tipo === 'despesa' ? 'Despesas' : 'Receitas'}
                </p>
                <ul>
                  {list.map((category) => (
                    <li
                      key={category.id}
                      className="flex flex-wrap items-center justify-between gap-2 border-b border-linha py-2.5 last:border-b-0"
                    >
                      <span className={`text-sm ${category.oculta ? 'text-muted line-through' : ''}`}>
                        {category.nome}
                        {category.personalizada ? null : <span className="ml-2 text-2xs text-muted">padrão</span>}
                      </span>
                      <div className="flex items-center gap-1">
                        <button
                          type="button"
                          className="px-2 py-1 text-xs text-muted hover:text-grafite"
                          onClick={() => toggleHidden(category)}
                        >
                          {category.oculta ? 'Mostrar' : 'Ocultar'}
                        </button>
                        {category.personalizada ? (
                          <>
                            <button
                              type="button"
                              className="px-2 py-1 text-xs text-muted hover:text-grafite"
                              onClick={() => open(category)}
                            >
                              Editar
                            </button>
                            <button
                              type="button"
                              className="px-2 py-1 text-xs text-terracota-texto"
                              onClick={() => setDeleting(category)}
                            >
                              Excluir
                            </button>
                          </>
                        ) : null}
                      </div>
                    </li>
                  ))}
                  {list.length === 0 ? <li className="py-2 text-sm text-muted">Nenhuma categoria.</li> : null}
                </ul>
              </div>
            )
          })
        : null}

      <Modal
        open={modal.open}
        onClose={() => setModal({ open: false, category: null })}
        title={modal.category ? 'Editar categoria' : 'Nova categoria'}
        size="sm"
      >
        <form onSubmit={save} className="space-y-4">
          <Field label="Nome" htmlFor="categoria-nome">
            <Input
              id="categoria-nome"
              value={form.nome}
              onChange={(event) => setForm((current) => ({ ...current, nome: event.target.value }))}
              placeholder="Educação, Pets, Freelas…"
            />
          </Field>
          {!modal.category ? (
            <Field label="Tipo" htmlFor="categoria-tipo">
              <Select
                id="categoria-tipo"
                value={form.tipo}
                onChange={(event) => setForm((current) => ({ ...current, tipo: event.target.value }))}
              >
                <option value="despesa">Despesa</option>
                <option value="receita">Receita</option>
              </Select>
            </Field>
          ) : null}
          {error ? (
            <p className="text-sm text-terracota-texto" role="alert">
              {error}
            </p>
          ) : null}
          <div className="flex justify-end gap-2">
            <Button variant="secondary" onClick={() => setModal({ open: false, category: null })}>
              Cancelar
            </Button>
            <Button type="submit" loading={busy}>
              Salvar categoria
            </Button>
          </div>
        </form>
      </Modal>

      <Modal
        open={Boolean(deleting)}
        onClose={() => setDeleting(null)}
        title="Excluir categoria?"
        description="Os lançamentos antigos continuam com o nome guardado; a categoria sai das listas."
        size="sm"
        footer={
          <>
            <Button variant="secondary" onClick={() => setDeleting(null)}>
              Cancelar
            </Button>
            <Button variant="danger" onClick={remove} loading={busy}>
              Excluir
            </Button>
          </>
        }
      >
        <p className="text-sm text-muted">{deleting?.nome}</p>
      </Modal>
    </Section>
  )
}

function BankingSection() {
  const toast = useToast()
  const connectionsApi = useApi('/banking/connections')
  const [deleting, setDeleting] = useState(null)
  const [busy, setBusy] = useState(false)
  const connections = useMemo(() => asList(connectionsApi.data, 'connections'), [connectionsApi.data])

  async function disconnect() {
    if (!deleting) return
    setBusy(true)
    try {
      await apiFetch(`/banking/connections/${deleting.id}`, { method: 'DELETE' })
      toast.push('Conexão desativada. As transações importadas continuam.')
      setDeleting(null)
      connectionsApi.refetch()
    } catch (err) {
      toast.push(errorMessage(err, 'Não foi possível desconectar.'), 'error')
    } finally {
      setBusy(false)
    }
  }

  return (
    <Section id="contas-bancarias" title="Contas bancárias" description="Desconectar não apaga lançamentos já importados.">
      {connectionsApi.loading ? <Loading label="Carregando conexões" rows={1} /> : null}
      {connectionsApi.error?.status === 503 ? (
        <UnavailableState
          title="Integração indisponível"
          description="Configure a chave da Pluggy no servidor para gerenciar conexões reais."
          onRetry={connectionsApi.refetch}
        />
      ) : null}
      {connectionsApi.error && connectionsApi.error.status !== 503 ? (
        <ErrorState error={connectionsApi.error} onRetry={connectionsApi.refetch} />
      ) : null}
      {!connectionsApi.loading && !connectionsApi.error ? (
        connections.length ? (
          <ul>
            {connections.map((connection) => {
              const status = CONNECTION_STATUS[connection.status] || CONNECTION_STATUS.inativa
              return (
                <li key={connection.id} className="flex flex-wrap items-center justify-between gap-3 border-b border-linha py-3 last:border-b-0">
                  <div>
                    <p className="text-sm font-medium">
                      {connection.institution_name || connection.account_name || 'Conta'}
                      {connection.is_demo_sync ? <span className="ml-2 text-2xs text-muted">demo</span> : null}
                    </p>
                    <p className="text-xs text-muted">
                      {connection.account_number_masked || 'Sem número'} ·{' '}
                      {connection.ultima_sync_em ? formatDateTime(connection.ultima_sync_em) : 'Nunca sincronizada'}
                    </p>
                  </div>
                  <div className="flex items-center gap-2">
                    <Badge tone={status.tone}>{status.label}</Badge>
                    {connection.status !== 'inativa' ? (
                      <button
                        type="button"
                        className="px-2 py-1 text-xs text-terracota-texto"
                        onClick={() => setDeleting(connection)}
                      >
                        Desconectar
                      </button>
                    ) : null}
                  </div>
                </li>
              )
            })}
          </ul>
        ) : (
          <p className="py-3 text-sm text-muted">Nenhuma conta conectada.</p>
        )
      ) : null}

      <Modal
        open={Boolean(deleting)}
        onClose={() => setDeleting(null)}
        title="Desconectar conta?"
        description="A leitura do banco para. Os lançamentos já importados permanecem."
        size="sm"
        footer={
          <>
            <Button variant="secondary" onClick={() => setDeleting(null)}>
              Cancelar
            </Button>
            <Button variant="danger" onClick={disconnect} loading={busy}>
              Desconectar
            </Button>
          </>
        }
      >
        <p className="text-sm text-muted">
          {deleting?.institution_name || deleting?.account_name || 'Conta conectada'}
        </p>
      </Modal>
    </Section>
  )
}

function DemoSection() {
  const { family, signOut } = useSession()
  const toast = useToast()
  const navigate = useNavigate()
  const [confirming, setConfirming] = useState(false)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  if (!family?.is_demo) return null

  async function restore() {
    setError('')
    setBusy(true)
    try {
      await apiFetch('/demo/restore', { method: 'POST', body: {} })
      toast.push('Demonstração restaurada. Entre de novo para continuar.')
      await signOut()
      navigate('/login', { replace: true })
    } catch (err) {
      setError(err.status === 503 ? RESTORE_503 : errorMessage(err, 'Não foi possível restaurar a demonstração.'))
    } finally {
      setBusy(false)
    }
  }

  return (
    <Section
      id="demo"
      title="Família de demonstração"
      description="Volta os dados de Ana, Carlos e Lucas para o estado inicial."
    >
      <p className="max-w-xl text-sm text-muted">
        Restaurar apaga o que foi criado na demo e recria os seis meses de histórico. Você volta para o
        login. O acesso atual pode continuar valendo até expirar, então entre de novo para usar a demo
        limpa.
      </p>
      {error ? (
        <p className="mt-3 rounded-control border border-terracota/30 bg-terracota/5 px-3 py-2 text-sm text-terracota-texto" role="alert">
          {error}
        </p>
      ) : null}
      <Button variant="secondary" className="mt-4" onClick={() => setConfirming(true)}>
        Restaurar demonstração
      </Button>

      <Modal
        open={confirming}
        onClose={() => setConfirming(false)}
        title="Restaurar a demonstração?"
        description="Tudo o que foi criado na demo é substituído pelos dados originais."
        size="sm"
        footer={
          <>
            <Button variant="secondary" onClick={() => setConfirming(false)}>
              Cancelar
            </Button>
            <Button variant="danger" onClick={restore} loading={busy}>
              Restaurar
            </Button>
          </>
        }
      >
        <p className="text-sm text-muted">Você será desconectado ao final.</p>
      </Modal>
    </Section>
  )
}

export default function Settings() {
  const { profile, family } = useSession()
  // Restaurar demo só em dev/teste. No build de produção a seção não aparece.
  const showDemo = import.meta.env.DEV || import.meta.env.VITE_SHOW_DEMO_LOGIN === 'true'
  const sections = [
    { id: 'perfil', label: 'Perfil' },
    ...(profile?.papel === 'admin'
      ? [
          { id: 'membros', label: 'Membros' },
          { id: 'convites', label: 'Convites' },
        ]
      : []),
    { id: 'categorias', label: 'Categorias' },
    { id: 'contas-bancarias', label: 'Contas bancárias' },
    ...(showDemo && family?.is_demo ? [{ id: 'demo', label: 'Demonstração' }] : []),
  ]

  return (
    <div>
      <header>
        <p className="text-sm text-muted">Configurações</p>
        <h1 className="mt-1 font-display text-3xl">A casa arrumada</h1>
        <p className="mt-2 max-w-xl text-sm text-muted">
          Perfil, família, categorias e contas. O que é pessoal continua pessoal.
        </p>
      </header>

      <div className="mt-8 grid gap-10 lg:grid-cols-[10rem_1fr]">
        <nav aria-label="Seções das configurações" className="hidden lg:block">
          <ul className="sticky top-24 space-y-1 text-sm">
            {sections.map((section) => (
              <li key={section.id}>
                <a href={`#${section.id}`} className="block rounded-control px-2 py-1.5 text-muted hover:text-grafite">
                  {section.label}
                </a>
              </li>
            ))}
          </ul>
        </nav>

        <div className="space-y-10">
          <ProfileSection />
          {profile?.papel === 'admin' ? <MembersSection /> : null}
          {profile?.papel === 'admin' ? <InvitesSection /> : null}
          <CategoriesSection />
          <BankingSection />
          {showDemo ? <DemoSection /> : null}
        </div>
      </div>
    </div>
  )
}
