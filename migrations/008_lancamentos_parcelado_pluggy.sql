-- ════════════════════════════════════════════════════════════════════════════
-- 008_lancamentos_parcelado_pluggy.sql
-- Suporte a "lançar despesa futura": quando a Pluggy detecta uma compra
-- parcelada em andamento sem lançamento correspondente no app, o app passa a
-- criar um `lancamentos` tipo Parcelado cobrindo só as parcelas AINDA NÃO
-- cobradas — nunca reconstrói o passado (ver Decisões no CLAUDE.md, desenho
-- revisado pelo Opus depois de uma primeira proposta ter sido descartada por
-- arriscar contaminar fatura já fechada).
--
-- Três colunas aditivas, todas nullable/com default seguro:
--
-- lancamentos.origem_dado ('manual' | 'pluggy', default 'manual') — mesmo
-- papel de extrato.origem_dado (migration 006): registro de quem criou a
-- linha, não mecanismo de correção. calcularResumo()/calcularSaldo() não
-- leem esta coluna — a segurança contra fatura histórica contaminada vem de
-- `parcelas` e `mes_ini`/`ano_ini` nunca apontarem pro passado quando a
-- Pluggy cria a linha (garantido no código de criação, não aqui).
--
-- lancamentos.pluggy_data_compra (date, nullable) e
-- lancamentos.pluggy_parcelas_totais (integer, nullable) — os FATOS reais da
-- compra (purchaseDate e totalInstallments que a Pluggy reporta), usados
-- EXCLUSIVAMENTE por _pluggyJaExisteNoApp() pra casar uma parcela futura que
-- sincronizar depois contra este lançamento — nunca por calcularResumo()/
-- calcularSaldo(), que continuam lendo só `parcelas`/`mes_ini`/`ano_ini` como
-- sempre. Necessário porque, pra este tipo de lançamento, `parcelas` guarda
-- só as parcelas RESTANTES (não o total real da compra) — sem estes dois
-- campos, o casamento por total (`lan.parcelas === totalInstallments`, usado
-- pra lançamento manual) nunca bateria pra um lançamento criado pela Pluggy.
--
-- Aplicar manualmente no SQL Editor do Supabase.
-- ════════════════════════════════════════════════════════════════════════════

alter table lancamentos add column if not exists origem_dado text default 'manual';
alter table lancamentos add column if not exists pluggy_data_compra date;
alter table lancamentos add column if not exists pluggy_parcelas_totais integer;
