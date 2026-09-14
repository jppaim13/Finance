-- ════════════════════════════════════════════════════════════════════════════
-- 015_sync_guard_atomico.sql
--
-- Mesmo padrão da migration 014, aplicado ao guard de SINCRONIZAÇÃO na Edge
-- Function (pluggy-sync/index.ts) — identificado como o mesmo tipo de bug
-- (SELECT pra checar "em andamento?" e só DEPOIS um INSERT pra marcar a
-- própria execução, não atômico), só que sem ter causado dano visível ainda
-- ("funcionou por sorte de timing", ver Decisões no CLAUDE.md). Impacto de
-- uma corrida aqui é baixo (o upsert do espelho é idempotente por
-- pluggy_id, só suja o log com uma segunda execução desnecessária) — mas
-- a correção já estava escrita e provada na 014, então vale fechar agora
-- em vez de esperar um "terceiro caso" pra levar a sério o padrão.
-- ════════════════════════════════════════════════════════════════════════════

create unique index if not exists pluggy_sync_log_sync_em_andamento
  on pluggy_sync_log (app_id)
  where tipo = 'sync' and status is null;
