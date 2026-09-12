-- ════════════════════════════════════════════════════════════════════════════
-- 012_categoria_por_compra_rollback.sql
-- Desfaz 012_categoria_por_compra.sql. Sem `pluggy_categorias_compra`, cada
-- parcela volta a precisar de categorização própria na tela de
-- Categorização (comportamento de antes desta migration, não um estado
-- novo) — nenhuma categoria já aplicada em `extrato` é desfeita.
-- Aplicar manualmente no SQL Editor.
-- ════════════════════════════════════════════════════════════════════════════

drop table if exists pluggy_categorias_compra;
alter table extrato drop column if exists pluggy_compra_chave;
