-- ════════════════════════════════════════════════════════════════════════════
-- 010_pluggy_limite_cartao.sql
-- Espelha o limite de crédito reportado pela Pluggy (creditData.creditLimit/
-- availableCreditLimit, confirmado via docs.pluggy.ai/reference/accounts-list)
-- pra permitir sincronizar `cartoes.limite` automaticamente em vez de manter
-- só manual. Duas colunas aditivas, nullable — mesmo padrão de sempre.
--
-- pluggy_contas.limite: creditData.creditLimit (limite total do cartão).
-- pluggy_contas.limite_disponivel: creditData.availableCreditLimit (quanto
-- ainda dá pra gastar) — guardado por completude, mas o app não lê esse
-- campo hoje; `calcularLimiteDisponivel()` já calcula o "disponível" a
-- partir das próprias compras registradas, é uma métrica derivada diferente.
--
-- Aplicar manualmente no SQL Editor do Supabase.
-- ════════════════════════════════════════════════════════════════════════════

alter table pluggy_contas add column if not exists limite numeric(12,2);
alter table pluggy_contas add column if not exists limite_disponivel numeric(12,2);
