-- 016 — guarda o payload bruto `bankData` de cada conta da Pluggy.
-- Motivo: o Meu Pluggy mostra um valor "Reservado" (ex.: R$ 4.032,54 no Mercado Pago da Mylena)
-- que NÃO está em `balance` — hoje a sync só grava `balance`. Guardando o bruto, dá para descobrir
-- qual campo corresponde ao "Reservado" sem adivinhar o nome. Aditiva, nullable; nenhum saldo muda.
alter table pluggy_contas add column if not exists bank_data jsonb;
