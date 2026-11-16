-- 023 — Metas compartilhadas entre os dois usuários (antes ficavam em localStorage, só no aparelho que as criou).
-- Uma meta por categoria (limite mensal). Aditiva: tabela nova. O app importa uma vez, por aparelho, as metas
-- que existiam só no localStorage (as que a tabela já tem, prevalecem).
create table if not exists metas (
  id         uuid primary key default gen_random_uuid(),
  categoria  text not null unique,
  limite     numeric(14,2) not null check (limite > 0),
  criado_em  timestamptz not null default now()
);
alter table metas enable row level security;
create policy "familia_full" on metas for all to authenticated using (true) with check (true);
