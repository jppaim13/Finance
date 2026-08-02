-- ════════════════════════════════════════════════════════════════════════════
-- 004_marco_zero_data_inicial.sql
-- Passo A do marco zero de saldos (ver Decisões no CLAUDE.md). Só adiciona a
-- coluna, NÃO preenche nenhum valor — puramente aditiva, sem efeito nenhum
-- até que:
--   (A) esta migration seja aplicada;
--   (B) calcularSaldo() em date-utils.js passe a respeitar a coluna
--       (mudança de código separada, já testada em tests.html antes de
--       qualquer conta ter data_inicial preenchida);
--   (C) uma migration futura preencha data_inicial/saldo_inicial por conta,
--       só depois de (B) estar validado.
--
-- calcularSaldo() ignora coluna que não lê — enquanto data_inicial estiver
-- nula em todas as contas (estado logo após esta migration), nenhum saldo
-- muda. Rollback trivial: remove a coluna.
--
-- Aplicar manualmente no SQL Editor do Supabase.
-- ════════════════════════════════════════════════════════════════════════════

alter table contas add column if not exists data_inicial date;
