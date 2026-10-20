-- 019: subtítulo (apelido) editável nas despesas.
-- Título (descricao) continua sendo o texto da Pluggy / o que o usuário digitou
-- no lançamento manual. `apelido` é só exibição: nenhuma lógica de casamento,
-- detecção ou agrupamento lê essa coluna.
-- Aditiva, tudo nullable. Descrições renomeadas antes da 019 NÃO são
-- restauradas (decisão do João): ficam como estão, com apelido vazio.

alter table extrato add column if not exists apelido text;
alter table lancamentos add column if not exists apelido text;
-- Herança por compra, gravada só por confirmação explícita (igual à categoria).
alter table pluggy_categorias_compra add column if not exists apelido text;
