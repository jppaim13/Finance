-- ════════════════════════════════════════════════════════════════════════════
-- 005_marco_zero_saldos_rollback.sql
-- Desfaz 005_marco_zero_saldos.sql — valores antigos embutidos literalmente
-- (levantados antes de aplicar, ver Decisões no CLAUDE.md), não um rollback
-- genérico. Volta data_inicial pra null (comportamento de calcularSaldo
-- idêntico ao anterior ao marco zero — testado em tests.html).
-- Aplicar manualmente no SQL Editor.
-- ════════════════════════════════════════════════════════════════════════════

update contas set saldo_inicial = 20.87, data_inicial = null where nome = 'Conta Nubank JP';
update contas set saldo_inicial = 830.22, data_inicial = null where nome = 'Conta XP';
update contas set saldo_inicial = 0.00,  data_inicial = null where nome = 'Conta XP Investimentos';
update contas set saldo_inicial = 0.00,  data_inicial = null where nome = 'Mercado Pago JP';
