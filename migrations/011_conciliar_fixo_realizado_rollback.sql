-- ════════════════════════════════════════════════════════════════════════════
-- 011_conciliar_fixo_realizado_rollback.sql
-- Desfaz 011_conciliar_fixo_realizado.sql. Sem `lancamentos_realizados`, o
-- código volta a assumir a ocorrência fantasma incondicional pra Fixo
-- (comportamento de antes desta migration, não um estado novo) — nenhuma
-- perda de dado real, só de vínculos aprendidos.
-- Aplicar manualmente no SQL Editor.
-- ════════════════════════════════════════════════════════════════════════════

drop table if exists lancamentos_realizados;
alter table lancamentos drop column if exists pluggy_descricao_ref;
