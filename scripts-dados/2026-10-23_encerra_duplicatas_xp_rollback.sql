-- Rollback de 2026-10-23_encerra_duplicatas_xp.sql
-- COMO RODAR: supabase db query --linked -f scripts-dados/2026-10-23_encerra_duplicatas_xp_rollback.sql   (use -f: passar o conteúdo como argumento falha, o CLI lê o primeiro '--' como opção) — valores ANTIGOS literais (os 3 estavam sem data de fim).
begin;
update lancamentos set mes_fim = NULL, ano_fim = NULL where id = 'bb38b71a-4651-471f-bdbe-76c26845a1c3'; -- SHOPEE manual
update lancamentos set mes_fim = NULL, ano_fim = NULL where id = '422937ea-2813-4640-9ca0-dcc6f1dcf08f'; -- LITE sem chave
update lancamentos set mes_fim = NULL, ano_fim = NULL where id = '0abd9154-0ed2-4ddc-a63e-f9b024790226'; -- LOOP LOOK
commit;
