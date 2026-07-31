-- ════════════════════════════════════════════════════════════════════════════
-- 001_auth_rls_rollback.sql
-- Desfaz 001_auth_rls.sql: remove as policies e desliga RLS, voltando ao
-- comportamento anterior (acesso total via anon key, sem exigir login).
--
-- Usar apenas se algo quebrar após aplicar a migration principal — por
-- exemplo, um acesso (aparelho/navegador) que ainda não pegou a tela de
-- login e passou a ver tudo vazio. Aplicar manualmente no SQL Editor.
-- ════════════════════════════════════════════════════════════════════════════

drop policy if exists "familia_full" on contas;
drop policy if exists "familia_full" on cartoes;
drop policy if exists "familia_full" on extrato;
drop policy if exists "familia_full" on lancamentos;
drop policy if exists "familia_full" on transferencias;
drop policy if exists "familia_full" on repasses;
drop policy if exists "familia_full" on categorias;

alter table contas          disable row level security;
alter table cartoes         disable row level security;
alter table extrato         disable row level security;
alter table lancamentos     disable row level security;
alter table transferencias  disable row level security;
alter table repasses        disable row level security;
alter table categorias      disable row level security;
