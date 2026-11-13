-- 022 — "Excluir" categoria padrão (as que estão no código, ex.: Pets, Viagem).
-- Categoria padrão não existe na tabela, então não dá para apagá-la: a exclusão grava uma linha em
-- `categorias` com oculta = true e a categoria deixa de aparecer nos menus. Lançamentos antigos continuam
-- com o id e o nome. "Restaurar" em Configurações volta oculta para false.
-- Aditiva: uma coluna nova com padrão false; nenhuma linha existente muda de comportamento.
alter table categorias add column if not exists oculta boolean not null default false;
