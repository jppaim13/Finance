-- Rollback da 021. Apaga a agenda inteira (lembretes e pagamentos marcados).
drop table if exists agenda_pagos;
drop table if exists agenda_lembretes;
