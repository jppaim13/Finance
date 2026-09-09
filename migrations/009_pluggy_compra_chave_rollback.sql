-- ════════════════════════════════════════════════════════════════════════════
-- 009_pluggy_compra_chave_rollback.sql
-- Desfaz 009_pluggy_compra_chave.sql. Como a coluna substituída
-- (pluggy_data_compra) nunca chegou a ter linha real (ver comentário na
-- migration), este rollback não precisa restaurar dado — só a forma.
-- Aplicar manualmente no SQL Editor.
-- ════════════════════════════════════════════════════════════════════════════

alter table lancamentos add column if not exists pluggy_data_compra date;
alter table lancamentos drop column if exists pluggy_compra_chave;
