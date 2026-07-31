# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A personal/family finance PWA (single page, in Portuguese). There is no build system, no package manager, and no test suite — it's a static site you open directly in a browser or serve as-is.

- `index.html` — the entire application: HTML + CSS + JS in one file (~5000 lines). Uses Chart.js and the Supabase JS SDK, both loaded from CDN `<script>` tags. No framework, no bundler, no modules.
- `apps-script.gs` — legacy backend: a Google Apps Script that reads/writes a Google Sheet, deployed as a Web App (`doGet`/`doPost` action-dispatch pattern). Superseded by Supabase but still supported as a fallback.
- `supabase-schema.sql` — current backend: Postgres schema for Supabase (this is the schema actually in use).
- `manifest.json`, `sw.js`, `icon*` — PWA shell (installable, offline app-shell caching). `sw.js` uses network-first for `index.html` specifically, so app updates are picked up on next load without needing cache-busting.
- `README.md` — end-user setup guide (connecting a spreadsheet + Apps Script, or hosting via GitHub Pages, installing as a home-screen app).

## Commands

There is nothing to build, lint, or test. To work on the app, open `index.html` directly in a browser (Chrome recommended). The only "backend" during local dev is whatever Supabase project the user configures via the in-app Settings screen (URL + anon key), which is stored in `localStorage` — never hardcode credentials into the file.

## Repository / deployment topology

The real deployment lives on GitHub at **https://github.com/jppaim13/Finance** (public repo, branch `main`), served via GitHub Pages. **This working directory is a plain folder, not a git repo** — there is no `.git` here. Treat the GitHub repo as source of truth; if things look stale, compare against a fresh clone before trusting local file contents.

## Architecture

### Dual backend, single frontend

The app supports two interchangeable backends behind the same UI, selected implicitly by what's configured:
- **Apps Script**: `doGet`/`doPost` dispatch on an `action` param, operating on fixed cell ranges/sheet names (`Painel`, `Configurações`, `Lançamentos`, `Extrato <mês>`, etc.) in a specific spreadsheet layout.
- **Supabase**: the client (`_sb`, initialized in `saveConfig()`/on load from stored URL+key) talks directly to Postgres tables via `sbSelect`/`sbInsert`/`sbUpdate`/`sbDelete` helpers — thin wrappers around `supabase-js`. This is the actively used path.

Row Level Security is **disabled by default** in `supabase-schema.sql` — anyone holding the URL + anon key (which the user shares with his wife so both can use the app) has full read/write access, no auth. This is intentional per the schema comments, not an oversight to "fix" unprompted.

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

### Client-side state and rendering

Everything lives in a single global `state` object, rebuilt by `loadData()` on every month change / mutation:
- `calcularSaldo(conta, ...)` computes an account's balance by summing all matching `lancamentos`/`extrato`/`transferencias` rows by **exact string match** on account name (no IDs) — case, accents, and whitespace all matter.
- `montarLancamentosMes()` flattens raw Supabase rows into the shape the UI actually renders (`state.lancamentos`) for the currently selected month. **This is a common source of bugs**: a raw column that isn't explicitly copied through here (e.g. `cartao_nome`) becomes invisible to the UI/edit forms even though it exists in the DB — check this function first when "a field can't be edited" or "shows blank" despite being present in Supabase.
- `calcularResumo()` produces the 12-month rollup used by charts/dashboard.
- There's no router/framework: `navigate(page)` toggles a `.page.active` class and calls that page's `render*()` function from a hardcoded dispatch list. `loadData()` also has its own hardcoded list of "if page X is currently active, re-render it" checks — **any page that supports in-place editing/deleting must be added to this list**, or edits will silently save correctly to Supabase while the visible list keeps showing stale data until the user navigates away and back.
- The lançamento edit modal is shared across contexts (Extrato page, Faturas page item list) and branches internally on `_editingTx.fonte` (`'extrato'` vs `'transferencias'`) and `_editingTx.categoria` (`'fatura'` gets an extra card-selector field) to decide which table/columns to update. Recurring/parcelado entries (`fonte: 'lancamentos'`) use a *separate* modal/flow (`abrirEditFixo`/`executarEditFixo`), not this one.
