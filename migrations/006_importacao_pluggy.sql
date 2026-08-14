-- ════════════════════════════════════════════════════════════════════════════
-- 006_importacao_pluggy.sql
-- Pré-requisito da importação manual de transações da Pluggy pra extrato
-- (botão "Importar pendentes", separado de "Sincronizar agora" — ver
-- Decisões no CLAUDE.md, Fase 2 / importação a partir do marco zero).
--
-- Quatro colunas novas, todas nullable/com default seguro, todas aditivas:
--
-- 1. extrato.origem_dado ('manual' | 'pluggy') — só em extrato, não em
--    lancamentos (Parcelado/Fixo continuam manuais por natureza; a Pluggy
--    não cria recorrência, só reporta transações individuais já ocorridas).
--    Default 'manual' preserva a leitura correta de todo o histórico
--    existente sem precisar de backfill.
--
-- 2/3. pluggy_transacoes.transacao_id + transacao_fonte — vínculo de volta
--    pra linha do app que aquela transação da Pluggy gerou OU já casou.
--    transacao_fonte reusa a convenção que já existe no app
--    (_editingTx.fonte: 'extrato' | 'lancamentos' | 'transferencias') em vez
--    de inventar uma nova. Sem os dois preenchidos ficam nulos — nenhuma
--    transação já sincronizada está "processada" até a importação rodar.
--
-- 4. cartoes.data_inicial — mesmo papel de contas.data_inicial (migration
--    004), mas pra cartão: data a partir da qual a Pluggy vira fonte
--    confiável pras compras daquele cartão. Sem essa coluna, o corte de
--    data da importação de cartão cairia numa constante no código — exatamente
--    o tipo de erro que já aconteceu uma vez (01/08 vs 02/08 no marco zero).
--    Preenchida aqui pros 5 cartões cobertos pela Pluggy com a mesma data do
--    marco zero das contas (02/08/2026). Diferente do preenchimento de
--    contas.data_inicial (migration 005), preencher aqui é seguro fazer na
--    mesma migration: nenhum código hoje lê cartoes.data_inicial (calcularSaldo
--    não considera cartão — compra de cartão não toca saldo, só a linha
--    categoria='fatura' debita), então preencher não muda nenhum
--    comportamento existente, só prepara o dado pro código de importação
--    que vai ler essa coluna.
--
-- Pré-requisito: backup fresco exportado (Configurações → Backup).
-- Aplicar manualmente no SQL Editor do Supabase.
-- ════════════════════════════════════════════════════════════════════════════

alter table extrato add column if not exists origem_dado text default 'manual';

alter table pluggy_transacoes add column if not exists transacao_id uuid;
alter table pluggy_transacoes add column if not exists transacao_fonte text;

alter table cartoes add column if not exists data_inicial date;

update cartoes set data_inicial = '2026-08-02'
where nome in ('C6 Carbon', 'Inter Prime', 'Mercado Pago', 'Nubank JP', 'XP Visa');
