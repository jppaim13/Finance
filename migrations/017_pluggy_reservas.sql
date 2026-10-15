-- 017 — reservas ("Reservado" do Meu Pluggy) espelhadas + vínculo com as caixinhas do app.
-- A sync passa a gravar `pluggy_reservas` a partir de `bankData.reservedBalances` de cada conta
-- (ver 016: bank_data). `contas.pluggy_reserva_id` guarda a `identificacao` da reserva a que uma
-- caixinha está ligada; o app mostra o valor da reserva como saldo dessa caixinha.
-- Aditiva. Nenhum saldo existente muda por esta migration.
create table if not exists pluggy_reservas (
  id                uuid primary key default gen_random_uuid(),
  app_id            uuid not null references pluggy_apps(id) on delete cascade,
  pluggy_account_id text not null references pluggy_contas(pluggy_account_id) on delete cascade,
  identificacao     text not null,
  nome              text not null,
  valor             numeric(14,2) not null,
  remuneracao       jsonb,
  atualizado_em     timestamptz not null default now(),
  unique (pluggy_account_id, identificacao)
);
create index if not exists idx_pluggy_reservas_app on pluggy_reservas(app_id);

alter table pluggy_reservas enable row level security;
create policy "familia_full" on pluggy_reservas for all to authenticated using (true) with check (true);

alter table contas add column if not exists pluggy_reserva_id text;
