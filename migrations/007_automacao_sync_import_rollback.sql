-- ════════════════════════════════════════════════════════════════════════════
-- 007_automacao_sync_import_rollback.sql
-- Desfaz 007_automacao_sync_import.sql — remove a coluna `tipo`. Sem ela, o
-- guard de concorrência da importação para de funcionar (volta a não ter
-- proteção contra execução dupla) — desligar a automação no código antes
-- ou junto de aplicar este rollback.
-- Aplicar manualmente no SQL Editor.
-- ════════════════════════════════════════════════════════════════════════════

alter table pluggy_sync_log drop column if exists tipo;
