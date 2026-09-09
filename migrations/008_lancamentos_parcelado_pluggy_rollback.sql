-- ════════════════════════════════════════════════════════════════════════════
-- 008_lancamentos_parcelado_pluggy_rollback.sql
-- Desfaz 008_lancamentos_parcelado_pluggy.sql. Remover estas colunas com
-- lançamentos criados pela Pluggy já existentes faz esses lançamentos
-- passarem a se comportar como manuais comuns (sem afetar saldo/fatura —
-- `parcelas`/`mes_ini`/`ano_ini` continuam intactos) mas quebra o casamento
-- de deduplicação: parcelas futuras dessa compra vão reimportar como linha
-- nova em extrato em vez de casar com o lançamento. Desligar a criação
-- automática no código antes ou junto de aplicar este rollback.
-- Aplicar manualmente no SQL Editor.
-- ════════════════════════════════════════════════════════════════════════════

alter table lancamentos drop column if exists origem_dado;
alter table lancamentos drop column if exists pluggy_data_compra;
alter table lancamentos drop column if exists pluggy_parcelas_totais;
