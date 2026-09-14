-- ════════════════════════════════════════════════════════════════════════════
-- 015_sync_guard_atomico_rollback.sql
-- Desfaz 015_sync_guard_atomico.sql. Aplicar manualmente no SQL Editor.
-- ════════════════════════════════════════════════════════════════════════════

drop index if exists pluggy_sync_log_sync_em_andamento;
