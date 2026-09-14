-- ════════════════════════════════════════════════════════════════════════════
-- 014_import_guard_atomico_rollback.sql
-- Desfaz 014_import_guard_atomico.sql. Aplicar manualmente no SQL Editor.
-- ════════════════════════════════════════════════════════════════════════════

drop index if exists pluggy_sync_log_import_em_andamento;
