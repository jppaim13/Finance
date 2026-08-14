-- ════════════════════════════════════════════════════════════════════════════
-- 006_importacao_pluggy_rollback.sql
-- Desfaz 006_importacao_pluggy.sql. Seguro mesmo depois de a importação ter
-- rodado, DESDE QUE você aceite perder o vínculo transacao_id/transacao_fonte
-- e o marcador origem_dado — as linhas de extrato já importadas continuam
-- existindo normalmente (essa migration nunca apaga extrato, só as colunas
-- de controle). cartoes.data_inicial some junto; se isso rodar depois de já
-- ter começado a importar por cartão, refazer o preenchimento manualmente
-- antes de tentar importar de novo.
-- Aplicar manualmente no SQL Editor.
-- ════════════════════════════════════════════════════════════════════════════

alter table extrato drop column if exists origem_dado;
alter table pluggy_transacoes drop column if exists transacao_id;
alter table pluggy_transacoes drop column if exists transacao_fonte;
alter table cartoes drop column if exists data_inicial;
