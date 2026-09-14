-- ════════════════════════════════════════════════════════════════════════════
-- 014_import_guard_atomico.sql
--
-- Fecha uma corrida de concorrência real em importarPendentes(): o guard
-- antigo (_importGuardIniciar) fazia um SELECT pra checar se já havia uma
-- importação em andamento e só DEPOIS um INSERT pra marcar a sua própria
-- execução como "em andamento" — duas operações separadas, não atômicas.
-- Duas chamadas quase simultâneas (o disparo automático ao abrir o app +
-- um clique manual em "Importar pendentes" logo em seguida, ou duas
-- abas/aparelhos) podiam ambas passar pelo SELECT antes que qualquer uma
-- terminasse o INSERT — resultado real observado em 14/09/2026: as mesmas
-- 8 transações pendentes viraram 16 linhas em `extrato` (cada uma
-- duplicada uma vez), corrigido manualmente depois.
--
-- Este índice único parcial faz o próprio Postgres recusar a segunda
-- tentativa de INSERT enquanto a primeira ainda não terminou (status IS
-- NULL) — sem essa janela de corrida, não importa quantas chamadas
-- cheguem ao mesmo tempo, só uma consegue criar a linha "em andamento".
-- ════════════════════════════════════════════════════════════════════════════

create unique index if not exists pluggy_sync_log_import_em_andamento
  on pluggy_sync_log (app_id)
  where tipo = 'import' and status is null;
