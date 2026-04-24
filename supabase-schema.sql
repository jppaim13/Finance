-- ════════════════════════════════════════════════════════════════════════════
-- FINANCE APP — Supabase Schema
-- Cole no SQL Editor do Supabase (https://app.supabase.com → SQL Editor)
-- ════════════════════════════════════════════════════════════════════════════

-- 1. CONTAS (inclui caixinhas/investimentos, diferenciadas por tipo)
CREATE TABLE IF NOT EXISTS contas (
  id          UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
  nome        TEXT    NOT NULL UNIQUE,
  banco       TEXT    DEFAULT '',
  saldo_inicial NUMERIC(12,2) DEFAULT 0,
  tipo        TEXT    NOT NULL DEFAULT 'conta' CHECK (tipo IN ('conta','caixinha')),
  criado_em   TIMESTAMPTZ DEFAULT NOW()
);

-- 2. CARTÕES
CREATE TABLE IF NOT EXISTS cartoes (
  id          UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
  nome        TEXT    NOT NULL UNIQUE,
  bandeira    TEXT    DEFAULT '',
  limite      NUMERIC(12,2) DEFAULT 0,
  conta_nome  TEXT    DEFAULT '',   -- nome da conta vinculada
  fechamento  INT     DEFAULT 1,
  vencimento  INT     DEFAULT 1,
  criado_em   TIMESTAMPTZ DEFAULT NOW()
);

-- 3. EXTRATO (lançamentos pontuais — despesas e pagamentos de fatura)
CREATE TABLE IF NOT EXISTS extrato (
  id          UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
  data        DATE    NOT NULL,
  descricao   TEXT    DEFAULT '',
  categoria   TEXT    DEFAULT 'outros',
  valor       NUMERIC(12,2) NOT NULL,
  tipo        TEXT    DEFAULT 'despesa' CHECK (tipo IN ('despesa','receita')),
  conta_nome  TEXT    DEFAULT '',   -- conta debitada (ou cartão se origem=cartao)
  origem      TEXT    DEFAULT 'conta' CHECK (origem IN ('conta','cartao')),
  cartao_nome TEXT    DEFAULT '',   -- preenchido quando origem=cartao
  parcela     TEXT    DEFAULT '',
  criado_em   TIMESTAMPTZ DEFAULT NOW()
);

-- 4. LANÇAMENTOS FIXOS / RECORRENTES / PARCELADOS / RECEITAS
CREATE TABLE IF NOT EXISTS lancamentos (
  id          UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
  descricao   TEXT    NOT NULL,
  categoria   TEXT    DEFAULT 'outros',
  -- tipo: 'Fixo' | 'Receita' | 'Receita Única' | 'Parcelado' | 'Variável'
  tipo        TEXT    NOT NULL,
  valor       NUMERIC(12,2) NOT NULL,
  mes_ini     INT,
  ano_ini     INT,
  parcelas    INT     DEFAULT 0,
  conta_nome  TEXT    DEFAULT '',
  origem      TEXT    DEFAULT 'conta',
  ativo       BOOLEAN DEFAULT TRUE,
  dia_ini     INT     DEFAULT 1, -- dia do mês da 1ª parcela/competência
  mes_fim     INT,    -- preenchido ao deletar 'futuros'
  ano_fim     INT,
  criado_em   TIMESTAMPTZ DEFAULT NOW()
);

-- Coluna adicionada após criação inicial (rodar se já tiver a tabela):
-- ALTER TABLE lancamentos ADD COLUMN IF NOT EXISTS dia_ini INT DEFAULT 1;

-- 5. TRANSFERÊNCIAS (entre contas e/ou caixinhas)
CREATE TABLE IF NOT EXISTS transferencias (
  id           UUID   DEFAULT gen_random_uuid() PRIMARY KEY,
  data         DATE   NOT NULL,
  descricao    TEXT   DEFAULT 'Transferência',
  valor        NUMERIC(12,2) NOT NULL,
  conta_origem TEXT   NOT NULL,
  conta_dest   TEXT   NOT NULL,
  criado_em    TIMESTAMPTZ DEFAULT NOW()
);

-- 6. REPASSES (divisão de despesas com a esposa — isolado, não afeta saldos)
-- valor efetivo = valor_direto (se manual) OU valor_total * percentual / 100
-- positivo = você deve pra ela · negativo = ela deve pra você
CREATE TABLE IF NOT EXISTS repasses (
  id           UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
  data         DATE    NOT NULL,
  descricao    TEXT    DEFAULT '',
  valor_total  NUMERIC(12,2) DEFAULT 0,
  percentual   NUMERIC(5,2)  DEFAULT 100,  -- pode ser negativo (ela deve pra mim)
  valor_direto NUMERIC(12,2),              -- usado em entradas manuais (pode ser negativo)
  status       TEXT    DEFAULT 'pendente' CHECK (status IN ('pendente','quitado')),
  ref_key      TEXT,   -- 'extrato:<uuid>' ou 'lan:<uuid>:<mesNome>'
  criado_em    TIMESTAMPTZ DEFAULT NOW()
);

-- 7. CATEGORIAS PERSONALIZADAS
CREATE TABLE IF NOT EXISTS categorias (
  id         TEXT    PRIMARY KEY,
  nome       TEXT    NOT NULL,
  emoji      TEXT    DEFAULT '📦',
  tipo       TEXT    NOT NULL CHECK (tipo IN ('despesa','receita')),
  neutro     BOOLEAN DEFAULT FALSE,
  criado_em  TIMESTAMPTZ DEFAULT NOW()
);

-- ════════════════════════════════════════════════════════════════════════════
-- ÍNDICES (performance para consultas por data e nome)
-- ════════════════════════════════════════════════════════════════════════════
CREATE INDEX IF NOT EXISTS idx_extrato_data        ON extrato(data);
CREATE INDEX IF NOT EXISTS idx_extrato_conta       ON extrato(conta_nome);
CREATE INDEX IF NOT EXISTS idx_transferencias_data ON transferencias(data);
CREATE INDEX IF NOT EXISTS idx_lancamentos_ativo   ON lancamentos(ativo);
CREATE INDEX IF NOT EXISTS idx_repasses_data       ON repasses(data);
CREATE INDEX IF NOT EXISTS idx_repasses_status     ON repasses(status);

-- ════════════════════════════════════════════════════════════════════════════
-- ROW LEVEL SECURITY (opcional — habilite se quiser proteger os dados)
-- Por padrão, desabilitado para uso pessoal sem autenticação.
-- Para habilitar: descomente as linhas abaixo e configure auth no app.
-- ════════════════════════════════════════════════════════════════════════════
-- ALTER TABLE contas        ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE cartoes       ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE extrato       ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE lancamentos   ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE transferencias ENABLE ROW LEVEL SECURITY;

-- ════════════════════════════════════════════════════════════════════════════
-- DADOS INICIAIS (opcional — insira suas contas e cartões aqui)
-- Substitua pelos seus dados reais antes de rodar.
-- ════════════════════════════════════════════════════════════════════════════

-- Exemplo de contas:
-- INSERT INTO contas (nome, banco, saldo_inicial, tipo) VALUES
--   ('Conta Nubank JP', 'Nubank',  0, 'conta'),
--   ('Conta Itaú',      'Itaú',    0, 'conta'),
--   ('Conta XP',        'XP',      0, 'conta'),
--   ('CDB XP',          'XP',      0, 'caixinha'),
--   ('Tesouro Direto',  'B3',      0, 'caixinha');

-- Exemplo de cartões:
-- INSERT INTO cartoes (nome, bandeira, limite, conta_nome, fechamento, vencimento) VALUES
--   ('Nubank JP',   'Mastercard', 5000, 'Conta Nubank JP', 9,  19),
--   ('XP Visa',     'Visa',       8000, 'Conta XP',        17, 27);
