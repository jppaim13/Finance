-- *** NÃO APLICADA — decisão de 11/10/2026. Arquivada. Usar só se o deslocamento do XP voltar a
-- *** acontecer ou aparecer em outros cartões (ver CLAUDE.md, Decisões: "purchaseDate instável no XP Visa").
-- 016 — Remapeia pluggy_compra_chave / compra_chave do XP Visa para o purchaseDate ATUAL da Pluggy.
-- Contexto: o conector do XP passou a devolver purchaseDate com +3h entre 01/09 e 15/09/2026
-- (6 de 6 compras mistas, 0 de 8 nos outros cartões). Chaves gravadas antes ficaram "antigas".
-- NÃO ALTERA o formato da chave nem o código: só alinha o dado gravado com o espelho atual.
--
-- ORDEM DE USO (nada aqui deve rodar antes do passo 1):
--   1. Export fresco do banco.
--   2. Forçar sincronização COMPLETA (sem incremental) só do XP Visa, para todo
--      pluggy_transacoes dessa conta ter o purchaseDate atual.
--   3. Preencher o timestamp do resync no PASSO 0 (propositalmente inválido até editar).
--   4. Rodar PASSO 0 a PASSO 2 (só leitura / cria tabelas de mapa e log) e conferir os resultados.
--   5. Só então rodar o PASSO 3 (aplica, tudo em uma transação com travas).
-- Rollback: 016_normaliza_chave_xp_visa_rollback.sql (usa o log gravado pelo PASSO 3).

-- ============================================================ PASSO 0 — resync feito?
-- Troque o literal por o momento (UTC) em que o resync do XP Visa terminou.
-- Esperado: 0 linhas desatualizadas.
select count(*) as linhas_xp_nao_ressincronizadas
from pluggy_transacoes
where pluggy_account_id in (select pluggy_account_id from pluggy_contas where cartao_nome = 'XP Visa')
  and metadata->'creditCardMetadata'->>'purchaseDate' is not null
  and sincronizado_em < timestamptz 'TROCAR-AAAA-MM-DDTHH:MM:SSZ';

-- ============================================================ PASSO 1 — mapa chave_antiga -> chave_nova
drop table if exists pluggy_chave_migracao_016;
create table pluggy_chave_migracao_016 (
  chave_antiga text not null,
  chave_nova   text not null,
  fonte_mapa   text not null,   -- 'extrato' | 'lancamentos' | 'lancamento_por_candidato'
  primary key (chave_antiga, chave_nova)
);

with xp_pt as (
  select pt.transacao_id, pt.transacao_fonte,
         pt.metadata->'creditCardMetadata'->>'purchaseDate' as pd_atual,
         (pt.metadata->'creditCardMetadata'->>'totalInstallments')::int as tot,
         trim(upper(regexp_replace(pt.descricao, '\s+', ' ', 'g'))) as desc_norm
  from pluggy_transacoes pt
  where pt.pluggy_account_id in (select pluggy_account_id from pluggy_contas where cartao_nome = 'XP Visa')
    and pt.metadata->'creditCardMetadata'->>'purchaseDate' is not null
)
-- (a) vínculo direto: extrato.pluggy_compra_chave (antiga) <-> espelho (atual)
insert into pluggy_chave_migracao_016
select distinct e.pluggy_compra_chave, x.pd_atual, 'extrato'
from xp_pt x join extrato e on x.transacao_fonte = 'extrato' and e.id = x.transacao_id
where e.pluggy_compra_chave ~ '^\d{4}-\d\d-\d\dT' and e.pluggy_compra_chave <> x.pd_atual;

-- (b) vínculo direto: lancamentos.pluggy_compra_chave <-> espelho
insert into pluggy_chave_migracao_016
select distinct l.pluggy_compra_chave, (pt.metadata->'creditCardMetadata'->>'purchaseDate'), 'lancamentos'
from pluggy_transacoes pt
join lancamentos l on pt.transacao_fonte = 'lancamentos' and l.id = pt.transacao_id
where pt.pluggy_account_id in (select pluggy_account_id from pluggy_contas where cartao_nome = 'XP Visa')
  and l.pluggy_compra_chave ~ '^\d{4}-\d\d-\d\dT'
  and l.pluggy_compra_chave <> (pt.metadata->'creditCardMetadata'->>'purchaseDate')
on conflict do nothing;

-- (c) lançamentos sem vínculo e sem mapa ainda: candidato só se for ÚNICO
--     (mesma data da chave antiga, mesmo total de parcelas, mesma descrição normalizada).
--     Ambíguo ou sem candidato NÃO é adivinhado — aparece na verificação V6.
insert into pluggy_chave_migracao_016
select l.pluggy_compra_chave, min(c.pd_atual), 'lancamento_por_candidato'
from lancamentos l
join (
  select distinct metadata->'creditCardMetadata'->>'purchaseDate' as pd_atual,
         (metadata->'creditCardMetadata'->>'totalInstallments')::int as tot,
         trim(upper(regexp_replace(descricao, '\s+', ' ', 'g'))) as desc_norm
  from pluggy_transacoes
  where pluggy_account_id in (select pluggy_account_id from pluggy_contas where cartao_nome = 'XP Visa')
    and metadata->'creditCardMetadata'->>'purchaseDate' is not null
) c on left(c.pd_atual, 10) = left(l.pluggy_compra_chave, 10)
   and c.tot = l.pluggy_parcelas_totais
   and left(c.desc_norm, 10) = left(trim(upper(regexp_replace(l.descricao, '\s+', ' ', 'g'))), 10)
where l.pluggy_compra_chave ~ '^\d{4}-\d\d-\d\dT'
  and l.pluggy_compra_chave not in (select chave_antiga from pluggy_chave_migracao_016)
  and l.pluggy_compra_chave not in (select metadata->'creditCardMetadata'->>'purchaseDate'
        from pluggy_transacoes where metadata->'creditCardMetadata'->>'purchaseDate' is not null)
group by l.pluggy_compra_chave
having count(distinct c.pd_atual) = 1;

-- ============================================================ PASSO 2 — verificações (todas devem passar)
-- V1: nenhuma chave antiga com mais de uma chave nova (esperado: 0 linhas)
select chave_antiga, count(*) as novas from pluggy_chave_migracao_016 group by 1 having count(*) > 1;

-- V2: nenhuma chave nova junta compras diferentes no espelho (esperado: 0 linhas)
select m.chave_nova, count(distinct (tot, d12)) as compras_distintas
from pluggy_chave_migracao_016 m
join (select metadata->'creditCardMetadata'->>'purchaseDate' pd,
             (metadata->'creditCardMetadata'->>'totalInstallments')::int tot,
             left(trim(upper(regexp_replace(descricao,'\s+',' ','g'))),12) d12
      from pluggy_transacoes
      where metadata->'creditCardMetadata'->>'purchaseDate' is not null) p on p.pd = m.chave_nova
group by 1 having count(distinct (tot, d12)) > 1;

-- V3: nenhuma chave nova colide com categoria DIFERENTE já gravada em pluggy_categorias_compra
--     (esperado: 0 linhas; o caso LOOP LOOK STORE entra aqui como "mesma categoria", não conflito)
select m.chave_antiga, m.chave_nova, a.categoria as cat_antiga, n.categoria as cat_nova
from pluggy_chave_migracao_016 m
join pluggy_categorias_compra a on a.compra_chave = m.chave_antiga
join pluggy_categorias_compra n on n.compra_chave = m.chave_nova
where a.categoria <> n.categoria;

-- (Chave nova já gravada é esperada nas compras mistas; a junção indevida de compras é coberta por V2.)

-- V5: tamanho da operação por tabela
select 'extrato' t, count(*) linhas from extrato where pluggy_compra_chave in (select chave_antiga from pluggy_chave_migracao_016)
union all select 'lancamentos', count(*) from lancamentos where pluggy_compra_chave in (select chave_antiga from pluggy_chave_migracao_016)
union all select 'pluggy_categorias_compra', count(*) from pluggy_categorias_compra where compra_chave in (select chave_antiga from pluggy_chave_migracao_016);

-- V6: chaves ISO do XP Visa gravadas que NÃO ficaram mapeadas e NÃO existem no espelho atual
--     (esperado: 0; se aparecer, LISTAR e decidir à mão — a migração não adivinha)
with atuais as (select distinct metadata->'creditCardMetadata'->>'purchaseDate' pd from pluggy_transacoes
                where metadata->'creditCardMetadata'->>'purchaseDate' is not null)
select 'lancamentos' t, pluggy_compra_chave as chave, descricao from lancamentos
 where pluggy_compra_chave ~ '^\d{4}-\d\d-\d\dT' and pluggy_compra_chave not in (select pd from atuais)
   and pluggy_compra_chave not in (select chave_antiga from pluggy_chave_migracao_016)
union all
select 'extrato', pluggy_compra_chave, descricao from extrato
 where pluggy_compra_chave ~ '^\d{4}-\d\d-\d\dT' and pluggy_compra_chave not in (select pd from atuais)
   and pluggy_compra_chave not in (select chave_antiga from pluggy_chave_migracao_016)
union all
select 'pluggy_categorias_compra', compra_chave, categoria from pluggy_categorias_compra
 where compra_chave ~ '^\d{4}-\d\d-\d\dT' and compra_chave not in (select pd from atuais)
   and compra_chave not in (select chave_antiga from pluggy_chave_migracao_016);

-- ============================================================ PASSO 3 — aplicar (só se V1..V3 e V6 vieram vazios)
create table if not exists pluggy_chave_migracao_016_log (
  tabela text not null, linha_id text not null, chave_antiga text not null,
  categoria text, atualizado_em timestamptz, nova_pre_existia boolean,
  primary key (tabela, linha_id)
);

begin;

do $$
begin
  if exists (select 1 from pluggy_chave_migracao_016 group by chave_antiga having count(*) > 1) then
    raise exception '016 abortada: chave antiga com mais de uma chave nova (V1)';
  end if;
  if exists (select 1 from pluggy_chave_migracao_016 m
             join pluggy_categorias_compra a on a.compra_chave = m.chave_antiga
             join pluggy_categorias_compra n on n.compra_chave = m.chave_nova
             where a.categoria <> n.categoria) then
    raise exception '016 abortada: colisão de categoria em pluggy_categorias_compra (V3)';
  end if;
end $$;

insert into pluggy_chave_migracao_016_log (tabela, linha_id, chave_antiga)
select 'extrato', e.id::text, e.pluggy_compra_chave from extrato e
 join pluggy_chave_migracao_016 m on m.chave_antiga = e.pluggy_compra_chave;
insert into pluggy_chave_migracao_016_log (tabela, linha_id, chave_antiga)
select 'lancamentos', l.id::text, l.pluggy_compra_chave from lancamentos l
 join pluggy_chave_migracao_016 m on m.chave_antiga = l.pluggy_compra_chave;
insert into pluggy_chave_migracao_016_log (tabela, linha_id, chave_antiga, categoria, atualizado_em, nova_pre_existia)
select 'pluggy_categorias_compra', a.compra_chave, a.compra_chave, a.categoria, a.atualizado_em,
       exists (select 1 from pluggy_categorias_compra n where n.compra_chave = m.chave_nova)
from pluggy_categorias_compra a join pluggy_chave_migracao_016 m on m.chave_antiga = a.compra_chave;

update extrato e set pluggy_compra_chave = m.chave_nova
  from pluggy_chave_migracao_016 m where e.pluggy_compra_chave = m.chave_antiga;
update lancamentos l set pluggy_compra_chave = m.chave_nova
  from pluggy_chave_migracao_016 m where l.pluggy_compra_chave = m.chave_antiga;

insert into pluggy_categorias_compra (compra_chave, categoria, atualizado_em)
select m.chave_nova, a.categoria, a.atualizado_em
from pluggy_categorias_compra a join pluggy_chave_migracao_016 m on m.chave_antiga = a.compra_chave
on conflict (compra_chave) do nothing;
delete from pluggy_categorias_compra where compra_chave in (select chave_antiga from pluggy_chave_migracao_016);

-- Propagação do que o usuário JÁ confirmou (mesma regra de _aplicarCategoriaPorCompra):
-- só linhas ainda 'nao_classificado' e só das chaves migradas (ex.: LOOP LOOK STORE -> joaquim).
update extrato e set categoria = c.categoria
  from pluggy_categorias_compra c
  where e.pluggy_compra_chave = c.compra_chave and e.categoria = 'nao_classificado'
    and c.compra_chave in (select chave_nova from pluggy_chave_migracao_016);
update lancamentos l set categoria = c.categoria
  from pluggy_categorias_compra c
  where l.pluggy_compra_chave = c.compra_chave and l.categoria = 'nao_classificado'
    and c.compra_chave in (select chave_nova from pluggy_chave_migracao_016);

-- Pós-condição: nenhuma chave antiga restou; nenhuma compra ficou com duas chaves.
do $$
begin
  if exists (select 1 from extrato where pluggy_compra_chave in (select chave_antiga from pluggy_chave_migracao_016))
     or exists (select 1 from lancamentos where pluggy_compra_chave in (select chave_antiga from pluggy_chave_migracao_016))
     or exists (select 1 from pluggy_categorias_compra where compra_chave in (select chave_antiga from pluggy_chave_migracao_016)) then
    raise exception '016 abortada: sobrou chave antiga após o update';
  end if;
end $$;

commit;
