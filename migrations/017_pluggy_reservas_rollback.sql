-- Rollback da 017. Perde o espelho das reservas e os vínculos caixinha↔reserva (os saldos manuais
-- das caixinhas voltam a valer; saldo_inicial/data_inicial das caixinhas não são tocados por esta migration).
alter table contas drop column if exists pluggy_reserva_id;
drop table if exists pluggy_reservas;
