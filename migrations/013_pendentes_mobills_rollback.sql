-- ════════════════════════════════════════════════════════════════════════════
-- 013_pendentes_mobills_rollback.sql
-- Desfaz 013_pendentes_mobills.sql (só a coluna — a inversão de
-- comportamento em calcularSaldo() é revertida no código, não aqui).
-- Aplicar manualmente no SQL Editor.
-- ════════════════════════════════════════════════════════════════════════════

alter table lancamentos_realizados drop column if exists origem;
