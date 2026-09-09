-- ════════════════════════════════════════════════════════════════════════════
-- 010_pluggy_limite_cartao_rollback.sql
-- Desfaz 010_pluggy_limite_cartao.sql. Sem essas colunas, o app volta a
-- depender só do limite cadastrado manualmente em `cartoes.limite` — nenhum
-- dado de `cartoes` é perdido, só para de ser atualizado pela Pluggy.
-- Aplicar manualmente no SQL Editor.
-- ════════════════════════════════════════════════════════════════════════════

alter table pluggy_contas drop column if exists limite;
alter table pluggy_contas drop column if exists limite_disponivel;
