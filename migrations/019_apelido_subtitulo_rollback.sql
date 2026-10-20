-- Rollback da 019. Perde os subtítulos gravados desde então.
alter table pluggy_categorias_compra drop column if exists apelido;
alter table lancamentos drop column if exists apelido;
alter table extrato drop column if exists apelido;
