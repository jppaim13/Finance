# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A personal/family finance PWA (single page, in Portuguese). There is no build system and no package manager — it's a static site you open directly in a browser or serve as-is. There is a minimal no-framework test page (`tests.html`) covering the pure date/saldo functions.

- `index.html` — the application shell: HTML + CSS + JS (~5200 lines). Uses Chart.js and the Supabase JS SDK, both loaded from CDN `<script>` tags. No framework, no bundler, no build step.
- `date-utils.js` — a handful of **pure** functions (`parseData`, `formatarData`, `calcularDataVencimento`, `mesNomeToAnoMes`, `getVencimentoIdx`, `getInstVencIdx`, `calcularSaldo`) extracted out of `index.html` specifically so `tests.html` can exercise the real production code instead of a duplicated copy. Loaded via `<script src="date-utils.js">` before the main inline script in `index.html`; also loaded standalone by `tests.html`. This is the one deliberate exception to "single file" — see Decisões.
- `tests.html` — open directly in a browser; renders pass/fail for each assertion, no server or build needed. Covers the two bug classes most likely to fail silently (date parsing/formatting, and card competência/vencimento math) plus a fixed `calcularSaldo` fixture.
- `apps-script.gs` — legacy backend: a Google Apps Script that reads/writes a Google Sheet, deployed as a Web App (`doGet`/`doPost` action-dispatch pattern). Superseded by Supabase but still supported as a fallback.
- `supabase-schema.sql` — current backend: Postgres schema for Supabase (this is the schema actually in use).
- `migrations/` — numbered, manually-applied SQL migrations for schema/RLS changes (e.g. `001_auth_rls.sql` + matching `..._rollback.sql`). These are **not** part of the normal auto-push flow — see "Schema/RLS changes" below.
- `manifest.json`, `sw.js`, `icon*` — PWA shell (installable, offline app-shell caching). `sw.js` uses network-first for `index.html` specifically, so app updates are picked up on next load without needing cache-busting; `date-utils.js` is precached in `SHELL` since the app can't function without it.
- `README.md` — end-user setup guide (connecting a spreadsheet + Apps Script, or hosting via GitHub Pages, installing as a home-screen app).

## Commands

Nothing to build or lint. To work on the app, open `index.html` directly in a browser (Chrome recommended). To run the test suite, open `tests.html` directly in a browser — it's self-contained, no server needed. The only "backend" during local dev is whatever Supabase project the user configures via the in-app Settings/login screen (URL + anon key), which is stored in `localStorage` — never hardcode credentials into the file.

### Schema/RLS changes — different rules than code changes

Code changes to `index.html`/`date-utils.js`/etc. get committed and pushed automatically. Changes that touch the Supabase schema or RLS policies do **not** follow that flow:
1. Export a fresh backup first (Configurações → Backup → "Exportar tudo (JSON)").
2. Write the change as a new numbered file in `migrations/` plus a matching `_rollback.sql`.
3. The migration is applied **manually** by the user in the Supabase SQL Editor, announced explicitly — never bundled into an unrelated commit, never applied by Claude directly (no DB connection is available in-session).
4. One structural change at a time, each verified independently before moving to the next.

## Repository / deployment topology

The real deployment lives on GitHub at **https://github.com/jppaim13/Finance** (public repo, branch `main`), served via GitHub Pages. **This working directory is a plain folder, not a git repo** — there is no `.git` here. Treat the GitHub repo as source of truth; if things look stale, compare against a fresh clone before trusting local file contents.

## Architecture

### Dual backend, single frontend

The app supports two interchangeable backends behind the same UI, selected implicitly by what's configured:
- **Apps Script**: `doGet`/`doPost` dispatch on an `action` param, operating on fixed cell ranges/sheet names (`Painel`, `Configurações`, `Lançamentos`, `Extrato <mês>`, etc.) in a specific spreadsheet layout.
- **Supabase**: the client (`_sb`, initialized in `saveConfig()`/on load from stored URL+key) talks directly to Postgres tables via `sbSelect`/`sbInsert`/`sbUpdate`/`sbDelete` helpers — thin wrappers around `supabase-js`. This is the actively used path.

Row Level Security is **enabled** (`migrations/001_auth_rls.sql`) with a single permissive policy per table (`for all to authenticated using (true) with check (true)`) — any logged-in user (the two family members) has full read/write access; anyone without a session gets empty results. Public signup is disabled in Supabase Auth; the two users were created manually. See "Auth" below.

### Data model (Supabase tables)

- `contas` — bank accounts AND "caixinhas" (savings/investment pockets) in one table, distinguished by `tipo IN ('conta','caixinha')`. Balance is **not stored** — it's computed client-side (see below).
- `cartoes` — credit cards, linked to a debiting account via `conta_nome` (must exactly match a `contas.nome`; there is no FK, matching is plain string equality).
- `extrato` — one-off transactions. Has **two separate** linkage columns: `conta_nome` and `cartao_nome`, mutually exclusive based on `origem` ('conta' | 'cartao') — **except** rows with `categoria = 'fatura'` (fatura payments), which use both simultaneously (see below). Any code that writes to this table must preserve this convention or transactions become silently orphaned (unmatched by any account/card in the UI).
- `lancamentos` — recurring/fixed/parcelado/receita entries. Unlike `extrato`, this table has a **single** `conta_nome` column that holds either an account name or a card name depending on `origem` — do not try to split it into two fields.
- `transferencias` — transfers between `contas`/`caixinhas`.
- `repasses` — expense-splitting with spouse; fully isolated bookkeeping, does not affect account balances.
- `categorias` — user-defined categories (merged with hardcoded `CATS_DESPESA`/`CATS_RECEITA` in JS).

### Fatura (credit card bill) payment flow

Card purchases (`extrato.origem = 'cartao'`) accumulate against the card only — `conta_nome` is left blank so they never touch any account's balance. When the user pays a bill via "Pagar Fatura", a single aggregate `extrato` row is inserted with `categoria: 'fatura'`, `origem: 'conta'`, `conta_nome` = the linked account, and `cartao_nome` = the card — this is what actually debits the account. This avoids double-counting the same spend once as a purchase and again as a payment. Category/repasse aggregations explicitly exclude `categoria === 'fatura'` for the same reason.

The fatura payment's `data` field is set to the card's computed **vencimento (due) date** for that billing cycle (not "today"), so it lands in the correct month in the Extrato regardless of when the user actually clicks pay.

Once a fatura is marked paid (`state.faturasPagas`, keyed `"<cartão>-<mêsAbrev>"`), that status is **not** revalidated against the current total if purchases are later added/moved into that billing period — deliberately, since re-showing "Pagar Fatura" would charge the *full current total* again, double-debiting the account for the part already paid. Any future fix here needs to account for partial/delta payments, not just a paid/unpaid boolean.

### Auth

`iniciarAuthGate()` subscribes to `_sb.auth.onAuthStateChange` once a Supabase client exists; it's the single source of truth for whether `#appRoot` (the whole app) or `#loginScreen` is visible — `loadData()` is never called without an active session. The login screen itself has two sub-forms toggled by whether `_sb` exists yet: `#loginConnectForm` (URL + anon key — first-time setup / no `localStorage`, e.g. a fresh browser or private tab) and `#loginAuthForm` (email + password). `conectarSupabase(url, key)` is the shared helper behind both `saveConfig()` (Configurações page) and `conectarESeguir()` (login screen) — don't duplicate the connection-test logic. Logout is `fazerLogout()` → `_sb.auth.signOut()`, which the same `onAuthStateChange` callback reacts to.

### Client-side state and rendering

Everything lives in a single global `state` object, rebuilt by `loadData()` on every month change / mutation:
- `calcularSaldo(conta, ...)` (in `date-utils.js`) computes an account's balance by summing all matching `lancamentos`/`extrato`/`transferencias` rows by **exact string match** on account name (no IDs) — case, accents, and whitespace all matter.
- `montarLancamentosMes()` flattens raw Supabase rows into the shape the UI actually renders (`state.lancamentos`) for the currently selected month. It spreads the raw row first (`{...tx, ...derived fields}`) specifically so a new/overlooked column is never silently dropped — derived/renamed fields (`valor`, `contaCartao`, `cartaoNome`, `dataObj`, `mes`, `fonte`) are listed *after* the spread and must stay after it if this function is touched again, or they'd be shadowed by the raw column of the same name.
- `calcularResumo()` produces the 12-month rollup used by charts/dashboard.
- Page routing is a single registry: `const PAGES = { dashboard: renderDashboard, extrato: renderExtrato, ... }`. `navigate(page)` calls `PAGES[page]()` when switching pages; `renderAtual()` (`PAGES[paginaAtiva()]?.()`) is called at the end of `loadData()` to refresh whatever page is currently visible. **A new page = one line in `PAGES`** — there is no second list to remember to update. (This replaced a pair of hand-maintained lists that used to drift out of sync with each other, which is exactly how the Extrato page once stopped refreshing after edits.)
- The lançamento edit modal is shared across contexts (Extrato page, Faturas page item list) and branches internally on `_editingTx.fonte` (`'extrato'` vs `'transferencias'`) and `_editingTx.categoria` (`'fatura'` gets an extra card-selector field) to decide which table/columns to update. Recurring/parcelado entries (`fonte: 'lancamentos'`) use a *separate* modal/flow (`abrirEditFixo`/`executarEditFixo`), not this one.
- `#modalLancamento` (and other modals) live outside every `.page` container in the DOM — re-rendering the active page's content never touches an open modal. Rely on this rather than adding guards against `renderAtual()` when opening new modals.

## Decisões

Registro de escolhas não óbvias a partir do código — principalmente as que foram cogitadas e rejeitadas, pra não serem re-tentadas sem o contexto do porquê.

- **Fatura "paga" revalidada contra o total atual (booleano) — REJEITADA.** Uma versão do fix fazia a fatura voltar a "pendente" se o total mudasse depois de marcada como paga (ex: compra movida/adicionada pra aquele cartão+mês). Revertida a pedido do usuário: o botão "Pagar Fatura" reaparecia cobrando o **total atual inteiro**, não a diferença — risco real de pagamento duplicado sobre o que já tinha sido debitado da conta. Não reintroduzir essa forma específica (comparar `state.faturasPagas[key]` booleano contra o total recalculado).
  **Direção aceita para o mesmo problema, ainda não implementada:** tabela `pagamentos_fatura (cartao_id, conta_id, competencia, valor, data)` — cada pagamento fica registrado individualmente, e o status/falta é derivado por `total − soma(pagamentos)` em vez de um booleano único. Isso permite pagamento parcial e recompra depois de pago sem duplicar cobrança. É uma peça da migração maior de Auth/RLS (ver Fase 0) — não implementar isolada.

- **Visibilidade do repositório (público/privado) é uma decisão separada de Auth/RLS.** Repo público hoje não é risco de segurança por si só (nenhum segredo commitado — URL/chave do Supabase ficam em `localStorage`, nunca no código). O risco real de exposição de dados é a ausência de autenticação/RLS no banco. Se só uma dessas duas puder ser endereçada primeiro, priorizar Auth/RLS — tornar o repo privado sem RLS não protege os dados financeiros, só esconde o código-fonte.

- **Auth/RLS implementado em ordem estrita (Fase 0), não tudo de uma vez.** Sequência: (1) botão de export/backup primeiro — é o rollback manual de tudo que vem depois; (2) cadastro público desligado + os 2 usuários criados manualmente no Supabase Auth *antes* de qualquer código de login, porque a policy do RLS libera tudo pra qualquer `authenticated`, e cadastro aberto = qualquer um vira `authenticated`; (3) tela de login construída e testada com RLS **ainda desligada**, validando o fluxo de auth sem risco de derrubar o acesso; (4) só então a migration de RLS. Motivo: religar RLS antes do login existir (ou antes do cadastro público estar fechado) transforma engano de sequência em "app mostra R$0,00 pra todo mundo" sem erro nenhum no console.
  **Bug descoberto durante a Fase 0.5 (e corrigido):** o gate de login só ativava se já existisse URL/chave do Supabase salva em `localStorage`. Numa aba anônima (storage vazio) o app caía no fluxo antigo "não configurado" e mostrava a casca inteira do app (sidebar, dashboard zerado) sem nunca pedir login — risco baixo na prática (nenhuma query real roda sem cliente Supabase), mas inconsistente. Corrigido unificando as duas telas: `showLoginScreen()` agora sempre aparece antes do app, alternando entre sub-formulário de conexão (sem `_sb`) e de login (com `_sb`, sem sessão).

- **`date-utils.js` extraído do `index.html` — única exceção deliberada ao "single file".** Contém só funções puras (sem `state`, sem DOM): `parseData`, `formatarData`, `calcularDataVencimento`, `mesNomeToAnoMes`, `getVencimentoIdx`, `getInstVencIdx`, `calcularSaldo`. Motivo: sem isso, `tests.html` testaria uma cópia colada do código, que diverge da versão real em produção sem avisar ninguém — o oposto do que os testes existem pra garantir. Não é o primeiro passo da refatoração "unificar extrato+lancamentos numa tabela" (essa continua rejeitada por enquanto, ver `## Architecture`) — é uma extração cirúrgica de funções que já eram puras e isoladas, sem tocar o resto da arquitetura.

- **`calcularDataVencimento()` trava no último dia válido do mês — bug real encontrado ao escrever os testes.** `renderFaturas()` calculava a data de vencimento com `new Date(ano, mes, cartao.vencimento)` sem checar se aquele dia existe no mês — um cartão com vencimento dia 31 numa fatura de fevereiro estourava pra março (JS normaliza dia inválido silenciosamente). Corrigido reaproveitando o padrão de clamp (`Math.min(dia, últimoDiaDoMes)`) que já existia em outro lugar do código (`montarLancamentosMes`) mas não tinha sido aplicado aqui.
