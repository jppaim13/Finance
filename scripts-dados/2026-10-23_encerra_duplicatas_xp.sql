-- Encerra 3 lançamentos do XP Visa que contam em DOBRO parcelas que já estão no extrato importado da Pluggy.
-- Efeito esperado (conferido em simulação com a lógica real do app, dados de 23/10/2026):
--   XP Visa, fatura de set/2026: 7.024,13 -> 6.785,84 (= fatura real da Pluggy);
--   XP Visa, fatura de out/2026: -20,00 (LITE contado duas vezes) e a série do LITE segue só em 50ca5da8.
-- NÃO apaga nada: só preenche mes_fim/ano_fim (o histórico anterior continua contando).
-- ESTE ARQUIVO FICA FORA DE migrations/ DE PROPÓSITO (dado de produção, não entra na montagem do projeto do zero).
-- ORDEM: (1) export do banco; (2) rodar o arquivo inteiro numa única execução; (3) conferir os SELECTs do fim.
-- Rollback: 2026-10-23_encerra_duplicatas_xp_rollback.sql (valores antigos literais).

begin;

-- ===== CONFERÊNCIA ANTES: aborta se qualquer linha não estiver exatamente como foi diagnosticada =====
do $$
declare n int;
begin
  select count(*) into n from lancamentos
   where id = 'bb38b71a-4651-471f-bdbe-76c26845a1c3' and conta_nome = 'XP Visa' and ativo
     and mes_ini = 4 and ano_ini = 2026 and parcelas = 6 and mes_fim is null and ano_fim is null and valor = 135.76;
  if n <> 1 then raise exception 'SHOPEE manual (bb38b71a) não está como esperado — abortado, nada foi alterado'; end if;

  select count(*) into n from lancamentos
   where id = '422937ea-2813-4640-9ca0-dcc6f1dcf08f' and conta_nome = 'XP Visa' and ativo
     and mes_ini = 9 and ano_ini = 2026 and parcelas = 8 and mes_fim is null and ano_fim is null and pluggy_compra_chave is null;
  if n <> 1 then raise exception 'LITE sem chave (422937ea) não está como esperado — abortado'; end if;

  select count(*) into n from lancamentos
   where id = '0abd9154-0ed2-4ddc-a63e-f9b024790226' and conta_nome = 'XP Visa' and ativo
     and mes_ini = 9 and ano_ini = 2026 and parcelas = 1 and mes_fim is null and ano_fim is null and pluggy_compra_chave is null;
  if n <> 1 then raise exception 'LOOP LOOK (0abd9154) não está como esperado — abortado'; end if;

  -- a série que FICA (LITE com chave, parcelas 6..12 a partir de out) precisa existir e estar ativa
  select count(*) into n from lancamentos
   where id = '50ca5da8-011f-4232-9c78-b9d279088a76' and ativo and mes_ini = 10 and ano_ini = 2026 and parcelas = 7 and pluggy_parcelas_totais = 12;
  if n <> 1 then raise exception 'LITE que deveria ficar (50ca5da8) não encontrado — abortado'; end if;
end $$;

-- ===== APLICA =====
-- SHOPEE manual: mantém abr–jul (competências anteriores ao primeiro extrato importado, ago/set).
update lancamentos set mes_fim = 7, ano_fim = 2026 where id = 'bb38b71a-4651-471f-bdbe-76c26845a1c3';
-- LITE sem chave: encerrado ANTES de começar (mes_fim < mes_ini => zero ocorrências); 50ca5da8 cobre 6/12..12/12.
update lancamentos set mes_fim = 8, ano_fim = 2026 where id = '422937ea-2813-4640-9ca0-dcc6f1dcf08f';
-- LOOP LOOK: a única parcela restante (3/3) já está no extrato; encerrado antes de começar.
update lancamentos set mes_fim = 8, ano_fim = 2026 where id = '0abd9154-0ed2-4ddc-a63e-f9b024790226';

commit;

-- ===== CONFERÊNCIA DEPOIS (esperado: as 3 linhas com mes_fim/ano_fim preenchidos; 50ca5da8 intacto) =====
select left(id::text, 8) id, descricao, mes_ini, parcelas, mes_fim, ano_fim, ativo
from lancamentos
where id::text like any (array['bb38b71a%', '422937ea%', '0abd9154%', '50ca5da8%']) order by descricao;
