-- 021 — Agenda de lembretes de pagamento (água, luz, aluguel, parcelas...).
-- São só lembretes visuais: NENHUMA outra tabela/relatório/saldo lê estas duas.
-- Aditiva (duas tabelas novas). Tipos:
--   fixa      = todo mês a partir de (mes_ini, ano_ini), até (mes_fim, ano_fim) se houver
--   parcelada = `parcelas` meses seguidos a partir de (mes_ini, ano_ini)
--   avulsa    = uma vez, no mês (mes_ini, ano_ini)
-- `dia` = dia do vencimento (1–31; em mês curto vale o último dia).
-- `agenda_pagos` marca o mês de cada lembrete como pago.
create table if not exists agenda_lembretes (
  id         uuid primary key default gen_random_uuid(),
  descricao  text not null,
  valor      numeric(14,2),
  tipo       text not null check (tipo in ('fixa','parcelada','avulsa')),
  dia        int  not null check (dia between 1 and 31),
  mes_ini    int  not null check (mes_ini between 1 and 12),
  ano_ini    int  not null,
  parcelas   int  check (parcelas is null or parcelas >= 1),
  mes_fim    int  check (mes_fim is null or mes_fim between 1 and 12),
  ano_fim    int,
  ativo      boolean not null default true,
  criado_em  timestamptz not null default now()
);

create table if not exists agenda_pagos (
  id          uuid primary key default gen_random_uuid(),
  lembrete_id uuid not null references agenda_lembretes(id) on delete cascade,
  ano         int  not null,
  mes         int  not null check (mes between 1 and 12),
  pago_em     timestamptz not null default now(),
  unique (lembrete_id, ano, mes)
);

alter table agenda_lembretes enable row level security;
alter table agenda_pagos     enable row level security;
create policy "familia_full" on agenda_lembretes for all to authenticated using (true) with check (true);
create policy "familia_full" on agenda_pagos     for all to authenticated using (true) with check (true);
