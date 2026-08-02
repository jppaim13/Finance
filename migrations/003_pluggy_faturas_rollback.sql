-- ════════════════════════════════════════════════════════════════════════════
-- 003_pluggy_faturas_rollback.sql
-- Desfaz 003_pluggy_faturas.sql — remove só o espelho de faturas. Não afeta
-- pluggy_contas/pluggy_transacoes/pluggy_sync_log (Fase 1) nem
-- extrato/lancamentos/transferencias/contas/cartoes (nunca tocadas por
-- nenhuma fase da Pluggy).
-- Aplicar manualmente no SQL Editor.
-- ════════════════════════════════════════════════════════════════════════════

drop table if exists pluggy_faturas;
