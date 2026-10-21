-- Rollback da 020: devolve os privilégios padrão do Supabase.
do $$
declare t text;
begin
  for t in select tablename from pg_tables where schemaname = 'public' loop
    execute format('grant all on table public.%I to anon', t);
    execute format('grant all on table public.%I to authenticated', t);
  end loop;
end $$;
alter default privileges in schema public grant all on tables to anon;
