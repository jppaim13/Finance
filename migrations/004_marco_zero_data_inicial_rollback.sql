-- ════════════════════════════════════════════════════════════════════════════
-- 004_marco_zero_data_inicial_rollback.sql
-- Desfaz 004_marco_zero_data_inicial.sql — remove a coluna data_inicial de
-- contas. Seguro enquanto o passo C (preencher os valores) não tiver sido
-- aplicado ainda; se já tiver, os valores preenchidos se perdem com a coluna
-- (não há onde mais guardá-los depois de C — por isso C só roda com backup
-- fresco e os números conferidos, ver Decisões no CLAUDE.md).
-- Aplicar manualmente no SQL Editor.
-- ════════════════════════════════════════════════════════════════════════════

alter table contas drop column if exists data_inicial;
