-- Rollback da 018 (perde a marcação de titular; a Categorização volta a não separar por pessoa).
alter table contas  drop constraint if exists contas_titular_chk;
alter table cartoes drop constraint if exists cartoes_titular_chk;
alter table contas  drop column if exists titular;
alter table cartoes drop column if exists titular;
