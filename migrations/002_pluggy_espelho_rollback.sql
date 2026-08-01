-- ════════════════════════════════════════════════════════════════════════════
-- 002_pluggy_espelho_rollback.sql
-- Desfaz 002_pluggy_espelho.sql por completo — remove as 5 tabelas e tudo
-- que elas contêm (histórico de sincronização, transações espelhadas,
-- mapeamento manual conta/cartão). Não afeta extrato/lancamentos/
-- transferencias/contas/cartoes — essas nunca foram tocadas pela Fase 1.
-- Aplicar manualmente no SQL Editor.
-- ════════════════════════════════════════════════════════════════════════════

drop table if exists pluggy_sync_log;
drop table if exists pluggy_transacoes;
drop table if exists pluggy_contas;
drop table if exists pluggy_items;
drop table if exists pluggy_apps;
