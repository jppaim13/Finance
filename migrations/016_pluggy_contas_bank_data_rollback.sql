-- Rollback da 016. Perde só o JSON bruto guardado (a Pluggy reenvia na próxima sync, se a função ainda gravar).
alter table pluggy_contas drop column if exists bank_data;
