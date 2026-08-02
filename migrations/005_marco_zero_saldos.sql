-- ════════════════════════════════════════════════════════════════════════════
-- 005_marco_zero_saldos.sql
-- Passo C do marco zero de saldos (ver Decisões no CLAUDE.md, "Marco zero,
-- não reconciliação retroativa"). Só depois de (A) e (B) validados: coluna
-- contas.data_inicial existe (004) e calcularSaldo() já respeita esse corte,
-- testado em tests.html (35/35 passaram, incluindo regressão com
-- data_inicial nulo).
--
-- Ajusta saldo_inicial das 4 contas cobertas pela Pluggy pro saldo real
-- reportado na sincronização de 02/08/2026 (verificado: zero transações
-- datadas 02/08 nessas contas na hora da captura, então esse saldo coincide
-- com o fechamento do dia anterior). data_inicial = 2026-08-02: a partir
-- dessa data, extrato/lancamentos/transferencias dessas contas voltam a
-- somar normalmente sobre esse novo ponto de partida.
--
-- Nubank JP: valor de mercado (R$4.494,13) conferido pelo usuário direto no
-- app do banco, difere do saldo reportado pela Pluggy (R$4.571,56, R$77,43
-- a mais) — sem transação pendente nos dados que explique a diferença.
-- Usado o valor real conferido, não o da Pluggy. Registrar se acontecer de
-- novo com outra conta.
--
-- NÃO reconcilia março-julho (decisão já registrada). NÃO toca cartões/
-- faturas (compra de cartão tem conta_nome em branco, não participa de
-- saldo de conta). NÃO toca contas da esposa (fora do escopo da Pluggy).
--
-- Pré-requisito: backup fresco exportado (Configurações → Backup →
-- "Exportar tudo (JSON)") — não é rollback, é o registro histórico de
-- quanto a defasagem custava (saldo declarado vs. real em 02/08/2026).
-- Aplicar manualmente no SQL Editor do Supabase.
-- ════════════════════════════════════════════════════════════════════════════

update contas set saldo_inicial = 4494.13, data_inicial = '2026-08-02' where nome = 'Conta Nubank JP';
update contas set saldo_inicial = 0.69,    data_inicial = '2026-08-02' where nome = 'Conta XP';
update contas set saldo_inicial = 158.77,  data_inicial = '2026-08-02' where nome = 'Conta XP Investimentos';
update contas set saldo_inicial = 58.57,   data_inicial = '2026-08-02' where nome = 'Mercado Pago JP';
