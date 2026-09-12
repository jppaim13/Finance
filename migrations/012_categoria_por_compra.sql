-- ════════════════════════════════════════════════════════════════════════════
-- 012_categoria_por_compra.sql
-- Categoria pertence à COMPRA parcelada, não à parcela — pedido original do
-- usuário ("não preciso categorizar a mesma despesa todo mês"). Hoje cada
-- parcela chega em `extrato` como linha independente, categoria
-- 'nao_classificado', esperando ser categorizada de novo a cada mês mesmo
-- já tendo sido categorizada nas parcelas anteriores da MESMA compra.
--
-- extrato.pluggy_compra_chave (text, nullable): mesma chave de
-- `_pluggyCompraChave()` já usada em `lancamentos.pluggy_compra_chave`
-- (identidade estável da compra, com fallback medido pro Inter — ver
-- Decisões no CLAUDE.md). Gravada em toda parcela de cartão importada, não
-- só nas que viram lançamento futuro — é o que permite achar as parcelas
-- irmãs de uma mesma compra depois.
--
-- pluggy_categorias_compra: aprendizado persistente "esta compra é desta
-- categoria" — vínculo por IDENTIDADE (chave), não semelhança de texto
-- (diferente da sugestão por descrição que já existe, que é só um chute
-- pré-preenchido). Quando o usuário categoriza qualquer parcela de uma
-- compra, a categoria fica registrada aqui pra sempre; toda parcela
-- seguinte da mesma compra entra JÁ categorizada na importação, sem passar
-- pela tela de Categorização.
--
-- Aplicar manualmente no SQL Editor do Supabase.
-- ════════════════════════════════════════════════════════════════════════════

alter table extrato add column if not exists pluggy_compra_chave text;

create table if not exists pluggy_categorias_compra (
  compra_chave   text primary key,
  categoria      text not null,
  atualizado_em  timestamptz not null default now()
);

alter table pluggy_categorias_compra enable row level security;
create policy "familia_full" on pluggy_categorias_compra for all to authenticated using (true) with check (true);
