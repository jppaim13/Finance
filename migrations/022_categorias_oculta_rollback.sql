-- Rollback da 022. As categorias padrão ocultadas voltam a aparecer (a coluna deixa de existir).
alter table categorias drop column if exists oculta;
