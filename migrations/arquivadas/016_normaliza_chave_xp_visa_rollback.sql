-- *** NÃO APLICADA (a 016 foi arquivada em 11/10/2026) — este rollback também não tem uso até a 016 ser aplicada.
-- Rollback da 016. Usa o log gravado pelo PASSO 3 (pluggy_chave_migracao_016_log), que guarda por linha a chave antiga.
-- Observação: a propagação de categoria feita no fim da 016 (linhas que eram 'nao_classificado') NÃO é desfeita
-- automaticamente — se necessário, reverter à mão pelas linhas listadas na consulta abaixo.

begin;

update extrato e set pluggy_compra_chave = g.chave_antiga
  from pluggy_chave_migracao_016_log g where g.tabela = 'extrato' and g.linha_id = e.id::text;
update lancamentos l set pluggy_compra_chave = g.chave_antiga
  from pluggy_chave_migracao_016_log g where g.tabela = 'lancamentos' and g.linha_id = l.id::text;

-- recria as chaves antigas de categoria; remove as novas que a 016 criou (as que já existiam ficam)
insert into pluggy_categorias_compra (compra_chave, categoria, atualizado_em)
select g.chave_antiga, g.categoria, g.atualizado_em
from pluggy_chave_migracao_016_log g where g.tabela = 'pluggy_categorias_compra'
on conflict (compra_chave) do nothing;
delete from pluggy_categorias_compra
 where compra_chave in (select m.chave_nova from pluggy_chave_migracao_016 m
                        join pluggy_chave_migracao_016_log g on g.tabela = 'pluggy_categorias_compra' and g.chave_antiga = m.chave_antiga
                        where g.nova_pre_existia = false);

commit;

-- Depois de conferir, limpar:
-- drop table pluggy_chave_migracao_016; drop table pluggy_chave_migracao_016_log;
