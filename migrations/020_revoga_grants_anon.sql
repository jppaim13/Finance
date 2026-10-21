-- 020: defesa em profundidade — tira os privilégios de `anon` nas tabelas e limita `authenticated`.
-- Hoje (conferido em 21/10/2026): RLS ligado nas 16 tabelas e SEM política para `anon`, então um
-- visitante sem login lê vazio e não escreve (testado com a chave pública). Mesmo assim `anon` e
-- `authenticated` têm TODOS os privilégios de tabela (default do Supabase), inclusive TRUNCATE,
-- TRIGGER e REFERENCES — o RLS é a única trava. Esta migration remove a segunda camada que falta.
-- Efeito esperado: nenhum no app (o app só usa `authenticated` com SELECT/INSERT/UPDATE/DELETE;
-- o login usa o endpoint de Auth, que não depende de privilégio de tabela; a Edge Function usa
-- service_role, que não é afetado). NÃO aplicar sem export de backup antes (regra do projeto).

do $$
declare t text;
begin
  for t in select tablename from pg_tables where schemaname = 'public' loop
    execute format('revoke all on table public.%I from anon', t);
    execute format('revoke truncate, trigger, references on table public.%I from authenticated', t);
  end loop;
end $$;

-- tabelas criadas no futuro não nascem com acesso para anon
alter default privileges in schema public revoke all on tables from anon;
