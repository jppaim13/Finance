-- ════════════════════════════════════════════════════════════════════════════
-- 002_pluggy_espelho.sql
-- Fase 1 da integração Pluggy: espelho SOMENTE-LEITURA dos dados bancários.
-- Estas tabelas nunca são lidas por extrato/lancamentos/transferencias nem
-- pela lógica de saldo do app — servem só pra tela de conciliação (saldo
-- real da Pluggy vs. saldo calculado pelo app). Nenhuma escrita nas tabelas
-- de produção acontece nesta fase.
--
-- Pré-requisitos: backup fresco exportado (Configurações → Backup).
-- Aplicar manualmente no SQL Editor do Supabase.
-- ════════════════════════════════════════════════════════════════════════════

-- 1. Apps Pluggy (hoje só 'jp', mas deixa aberto pra outros titulares depois)
create table if not exists pluggy_apps (
  id         uuid primary key default gen_random_uuid(),
  apelido    text not null unique,
  criado_em  timestamptz default now()
);

-- 2. Items (conexões banco↔Pluggy). A Pluggy não tem endpoint de listagem de
-- items — cada itemId é copiado manualmente do Dashboard e cadastrado aqui.
create table if not exists pluggy_items (
  id             uuid primary key default gen_random_uuid(),
  app_id         uuid not null references pluggy_apps(id) on delete cascade,
  pluggy_item_id text not null unique,
  banco          text not null,      -- 'Nubank', 'XP Banking', ...
  criado_em      timestamptz default now()
);

-- 3. Contas/cartões espelhados da Pluggy. conta_nome/cartao_nome/ignorar são
-- preenchidos manualmente na tela de Sincronização (mapeamento pra conta/
-- cartão do app) e NUNCA sobrescritos pela sincronização — o upsert da Edge
-- Function só envia as colunas vindas da Pluggy, então o ON CONFLICT preserva
-- essas três automaticamente.
create table if not exists pluggy_contas (
  id                   uuid primary key default gen_random_uuid(),
  app_id               uuid not null references pluggy_apps(id) on delete cascade,
  pluggy_account_id    text not null unique,
  pluggy_item_id       text not null references pluggy_items(pluggy_item_id),
  nome                 text not null,
  tipo                 text,
  subtipo              text,
  numero               text,
  saldo                numeric(12,2),
  saldo_atualizado_em  timestamptz,
  -- mapeamento manual, preservado entre sincronizações:
  conta_nome           text,    -- nome exato em contas.nome, se essa conta bancária tem par no app
  cartao_nome          text,    -- nome exato em cartoes.nome, se este é um cartão de crédito
  ignorar              boolean default false,  -- ex: conta corrente PJ que não interessa ao app pessoal
  criado_em            timestamptz default now()
);

-- 4. Transações espelhadas. valor segue a convenção crua da Pluggy (sinal
-- pode variar por conector/tipo de conta — não normalizar aqui, registrar
-- em Decisões se algum conector vier invertido).
create table if not exists pluggy_transacoes (
  id                 uuid primary key default gen_random_uuid(),
  app_id             uuid not null references pluggy_apps(id) on delete cascade,
  pluggy_id          text not null unique,
  pluggy_account_id  text not null references pluggy_contas(pluggy_account_id),
  data               date not null,        -- já convertido (paraDataLocal)
  data_utc           timestamptz not null, -- valor original da Pluggy, intocado
  descricao          text,
  descricao_raw      text,
  valor              numeric(14,2) not null,
  tipo               text,
  status             text,
  metadata           jsonb default '{}',
  sincronizado_em    timestamptz default now()
);

-- 5. Log de cada execução da sincronização.
create table if not exists pluggy_sync_log (
  id            uuid primary key default gen_random_uuid(),
  app_id        uuid not null references pluggy_apps(id) on delete cascade,
  iniciado_em   timestamptz default now(),
  terminado_em  timestamptz,
  status        text,   -- 'ok' | 'erro', null enquanto em andamento
  criadas       int default 0,
  atualizadas   int default 0,
  erro          text
);

-- ════════════════════════════════════════════════════════════════════════════
-- ÍNDICES
-- ════════════════════════════════════════════════════════════════════════════
create index if not exists idx_pluggy_contas_app        on pluggy_contas(app_id);
create index if not exists idx_pluggy_contas_item        on pluggy_contas(pluggy_item_id);
create index if not exists idx_pluggy_transacoes_conta   on pluggy_transacoes(pluggy_account_id, data);
create index if not exists idx_pluggy_transacoes_app     on pluggy_transacoes(app_id);
create index if not exists idx_pluggy_sync_log_app       on pluggy_sync_log(app_id);

-- ════════════════════════════════════════════════════════════════════════════
-- RLS — mesma policy permissiva das outras 7 tabelas (ver 001_auth_rls.sql):
-- qualquer usuário autenticado tem acesso completo. A tela de Sincronização
-- precisa poder ATUALIZAR conta_nome/cartao_nome/ignorar em pluggy_contas
-- diretamente pelo navegador, então "for all" (não só select) é necessário
-- aqui também. A Edge Function usa a service role key e ignora RLS.
-- ════════════════════════════════════════════════════════════════════════════
alter table pluggy_apps        enable row level security;
alter table pluggy_items       enable row level security;
alter table pluggy_contas      enable row level security;
alter table pluggy_transacoes  enable row level security;
alter table pluggy_sync_log    enable row level security;

create policy "familia_full" on pluggy_apps        for all to authenticated using (true) with check (true);
create policy "familia_full" on pluggy_items       for all to authenticated using (true) with check (true);
create policy "familia_full" on pluggy_contas      for all to authenticated using (true) with check (true);
create policy "familia_full" on pluggy_transacoes  for all to authenticated using (true) with check (true);
create policy "familia_full" on pluggy_sync_log    for all to authenticated using (true) with check (true);
