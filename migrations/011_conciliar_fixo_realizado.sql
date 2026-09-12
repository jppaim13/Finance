-- ════════════════════════════════════════════════════════════════════════════
-- 011_conciliar_fixo_realizado.sql
-- Fixo (`lancamentos`) nunca reconciliava contra a Pluggy — a ocorrência
-- mensal fantasma sempre contava, mesmo quando a transação real já tinha
-- sido importada em `extrato` (achado real: aluguel duplicado, uma vez
-- como Fixo em "Conta XP", outra vez como despesa real em outra conta —
-- ver Decisões no CLAUDE.md, "conciliar Fixo/Parcelado com realizado").
-- Causa raiz: a conta que paga não é uma propriedade fixa do lançamento,
-- é circunstância de cada mês (mesmo padrão já resolvido pra fatura de
-- cartão) — 3 meses seguidos do mesmo aluguel, 3 contas diferentes,
-- nenhuma delas a cadastrada.
--
-- lancamentos.pluggy_descricao_ref (text, nullable): a descrição real da
-- Pluggy pra esse Fixo, aprendida na primeira vez que o usuário confirma um
-- vínculo. A partir daí, mês+valor+descrição compatível é considerado
-- confiável o bastante pra suprimir a ocorrência fantasma automaticamente,
-- sem esperar confirmação — mesmo padrão de "chave de identidade guardada
-- explicitamente, não recalculada" já usado em `pluggy_compra_chave`.
--
-- lancamentos_realizados: liga uma ocorrência específica (lancamento_id +
-- ano + mes) à transação real de `extrato` que a cobriu.
-- `confirmado_em` NULL = sugestão pendente (só mês+valor bateram, sem
-- descrição de referência ainda — risco de falso positivo medido como real,
-- não teórico: colisão de valor+mês encontrada nos dados de julho/2026,
-- coincidindo justamente com o valor do aluguel) — a ocorrência CONTINUA
-- contando até confirmar. `confirmado_em` preenchido = suprime a ocorrência
-- em calcularSaldo()/calcularResumo() (ver date-utils.js/index.html) —
-- preenchido automaticamente quando o casamento já usa `pluggy_descricao_ref`
-- conhecida (confiança alta), ou manualmente quando o usuário clica
-- "Confirmar" na tela (que também aprende a descrição pra próxima vez).
--
-- Aplicar manualmente no SQL Editor do Supabase.
-- ════════════════════════════════════════════════════════════════════════════

alter table lancamentos add column if not exists pluggy_descricao_ref text;

create table if not exists lancamentos_realizados (
  id             uuid primary key default gen_random_uuid(),
  lancamento_id  uuid not null references lancamentos(id) on delete cascade,
  ano            int  not null,
  mes            int  not null,
  transacao_id   uuid references extrato(id) on delete set null,
  confirmado_em  timestamptz,
  criado_em      timestamptz not null default now(),
  unique (lancamento_id, ano, mes)
);

create index if not exists idx_lancamentos_realizados_lancamento on lancamentos_realizados(lancamento_id);

alter table lancamentos_realizados enable row level security;
create policy "familia_full" on lancamentos_realizados for all to authenticated using (true) with check (true);
