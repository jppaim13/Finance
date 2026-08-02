-- ════════════════════════════════════════════════════════════════════════════
-- 003_pluggy_faturas.sql
-- Fase 1.6 da integração Pluggy: espelho SOMENTE-LEITURA das faturas reais
-- do emissor (endpoint GET /bills?accountId=...), separado da Fase 1
-- (pluggy_transacoes/pluggy_contas) porque é um endpoint novo, com paginação
-- e contrato próprios — ver Decisões no CLAUDE.md.
--
-- Esta tabela nunca é lida por extrato/lancamentos/transferencias nem pela
-- lógica de saldo do app. Nenhuma escrita nas tabelas de produção acontece
-- nesta fase.
--
-- Pré-requisitos: backup fresco exportado (Configurações → Backup).
-- Aplicar manualmente no SQL Editor do Supabase.
-- ════════════════════════════════════════════════════════════════════════════

create table if not exists pluggy_faturas (
  bill_id            text primary key,  -- id da fatura na Pluggy (não gen_random_uuid — é o id que a Pluggy atribui)
  pluggy_account_id  text not null references pluggy_contas(pluggy_account_id),
  due_date           date,
  closing_date       date,
  total_amount       numeric(14,2),
  minimum_amount     numeric(14,2),
  -- status vem calculado pela Edge Function no momento da sincronização
  -- (closing_date no passado vs. futuro), não necessariamente um campo
  -- direto da Pluggy — ver verificação 2 (aberta vs. fechada) no CLAUDE.md.
  status             text,
  payments           jsonb default '[]',
  sincronizado_em    timestamptz default now()
);

create index if not exists idx_pluggy_faturas_conta on pluggy_faturas(pluggy_account_id, due_date);

alter table pluggy_faturas enable row level security;
create policy "familia_full" on pluggy_faturas for all to authenticated using (true) with check (true);
