-- ════════════════════════════════════════════════════════════════════════════
-- 001_auth_rls.sql
-- Habilita Row Level Security nas 7 tabelas e libera acesso total para
-- qualquer usuário autenticado (Supabase Auth). Sem RLS ligada, a chave
-- anon publica dá acesso irrestrito de leitura/escrita a quem tiver a
-- URL + anon key do projeto, sem exigir login.
--
-- Pré-requisitos (nesta ordem, ver CLAUDE.md / Fase 0):
--   1. Backup exportado (botão "Exportar tudo (JSON)" em Configurações)
--   2. Cadastro público desligado em Authentication → Providers → Email
--   3. Os 2 usuários já criados manualmente em Authentication → Users
--   4. Tela de login já testada e funcionando em todos os acessos, com
--      RLS ainda desligada
--
-- Aplicar manualmente no SQL Editor do Supabase. Não faz parte do fluxo
-- de push automático do app.
-- ════════════════════════════════════════════════════════════════════════════

alter table contas          enable row level security;
alter table cartoes         enable row level security;
alter table extrato         enable row level security;
alter table lancamentos     enable row level security;
alter table transferencias  enable row level security;
alter table repasses        enable row level security;
alter table categorias      enable row level security;

create policy "familia_full" on contas          for all to authenticated using (true) with check (true);
create policy "familia_full" on cartoes         for all to authenticated using (true) with check (true);
create policy "familia_full" on extrato         for all to authenticated using (true) with check (true);
create policy "familia_full" on lancamentos     for all to authenticated using (true) with check (true);
create policy "familia_full" on transferencias  for all to authenticated using (true) with check (true);
create policy "familia_full" on repasses        for all to authenticated using (true) with check (true);
create policy "familia_full" on categorias      for all to authenticated using (true) with check (true);
