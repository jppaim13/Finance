-- 018 — titular (JP | My) de cada conta e cartão. Usado pela tela de Categorização para separar
-- as despesas por pessoa e mostrar de quem é cada origem. Padrão 'jp'; as contas/cartões da
-- Mylena são marcados 'my' abaixo (por nome). Aditiva; nenhum saldo/lançamento muda.
alter table contas  add column if not exists titular text not null default 'jp';
alter table cartoes add column if not exists titular text not null default 'jp';
alter table contas  drop constraint if exists contas_titular_chk;
alter table cartoes drop constraint if exists cartoes_titular_chk;
alter table contas  add constraint contas_titular_chk  check (titular in ('jp', 'my'));
alter table cartoes add constraint cartoes_titular_chk check (titular in ('jp', 'my'));

update contas  set titular = 'my' where nome in ('Conta Itaú', 'Mercado Pago My', 'Nubank Mylena', 'Cofrinho - Joaquim');
update cartoes set titular = 'my' where nome in ('Latam Pass', 'Magalu', 'Caixa', 'Nubank My');
