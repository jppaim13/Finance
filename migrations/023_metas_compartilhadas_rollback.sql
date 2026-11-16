-- Rollback da 023. Apaga as metas compartilhadas (o app volta a usar o localStorage de cada aparelho).
drop table if exists metas;
