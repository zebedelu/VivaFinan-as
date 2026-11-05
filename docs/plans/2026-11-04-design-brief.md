# Design brief — VivaFinanças v1

**Data:** 2026-11-04
**Direção aprovada na spec:** “Editorial acolhedor” (§2.3).
**Público:** famílias brasileiras de classe média, uso principal no celular.
**Trabalho da tela:** entender o mês em menos de um minuto e registrar um lançamento em até 3 toques.

## Tokens

| Token | Valor | Uso |
|---|---|---|
| `--verde` | `#1F4D3A` | marca, navegação, ações primárias |
| `--areia` | `#F4EFE6` | fundo claro |
| `--superficie` | `#FBF8F2` | cartões, formulários |
| `--grafite` | `#22201D` | texto |
| `--terracota` | `#C46A4A` | despesas, alertas |
| `--dourado` | `#C9A227` | metas, progresso |
| `--linha` | `#D9D1C4` | réguas de 1px |
| `--sombra` | `0 1px 2px rgba(34,32,29,.06)` | sombra discreta |

Tipografia: **Fraunces** (títulos, saldo, números grandes) e **IBM Plex Sans** (corpo, formulários, navegação). Números com `font-variant-numeric: tabular-nums`. Escala: 12/14/16/20/28/40/56; line-height 1.5 no corpo e 1.1 nos títulos.

Raio: 12px em cartões, 8px em inputs/botões, 999px em avatares. Borda 1px `--linha`; sem gradientes roxos.

## Layout

Mobile-first, 390px de referência; desktop 1280px com sidebar de 240px e conteúdo até 1200px.

```text
mobile                         desktop
┌──────────────────────┐       ┌──────┬─────────────────────────┐
│ Olá, Ana        sino │       │ nav  │ título + mês + ações    │
│ saldo do mês         │       │      │ ┌───────┬─────────────┐ │
│ receitas | despesas  │       │      │ │ saldo │ 6 meses     │ │
│ linha 6 meses        │       │      │ └───────┴─────────────┘ │
│ rosca categorias     │       │      │ metas | sugestões | IA  │
│ metas | sugestões    │       │      │                         │
│ [Início][Lanç.][Extr.]│       │      │                         │
└──────────────────────┘       └──────┴─────────────────────────┘
```

Alinhamento à esquerda para texto e títulos; valores monetários à direita, alinhados pela vírgula. O saldo do mês é o elemento mais forte da página; o resto fica quieto.

## Princípios

1. **Caderno de contas, não dashboard de SaaS.** Réguas finas, listas com linhas discretas, números tabulares e espaço em branco fazem a identidade. Evitar o kit de cartões idênticos com sombra igual.
2. **Uma ousadia por tela.** No painel, o saldo; na individual, a saudação e o resumo; no extrato, a régua da lista. O resto é disciplina.
3. **Terracota só com significado.** Despesa, alerta, atraso. Verde para marca e ações; dourado para meta. Nunca como decoração.
4. **Movimento que responde.** Fade/slide só na entrada da página; transições em abrir modal, confirmar, importar. Respeitar `prefers-reduced-motion`.
5. **Acessibilidade como piso.** Foco visível, contraste AA, labels associados, tabela alternativa para gráficos, navegação por teclado.

## Copy

Verbos no imperativo e sentence case: “Salvar”, “Confirmar”, “Importar”, “Desfazer”. O botão e o toast usam o mesmo verbo. Erros dizem o que aconteceu e o que fazer; estados vazios convidam à ação. Sem CAIXA ALTA em labels, sem “→” no fim de botões, sem jargão de sistema.

## Crítica antes de codar

A paleta areia + terracota é um default de design gerado; aqui ela é decisão explícita da spec. A diferenciação vem da tipografia Fraunces, das réguas de caderno e da hierarquia do saldo — não de gradientes ou badges. Se a tela parecer um kit genérico de cartões, remover um cartão e deixar a régua contar a história.

## Handoff

A lane de frontend deve carregar `frontend-design` antes de escrever JSX/Tailwind, preservar estes tokens e wireframes, e registrar qualquer mudança de intenção visual no progresso do deepwork. Copy pode ser revisada sem mudar a estrutura visual.
