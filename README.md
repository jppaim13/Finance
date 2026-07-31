# 💰 Finance App — Guia de Instalação

Tempo estimado: **20 minutos**

---

## O que você vai precisar
- Conta no [Supabase](https://supabase.com) (gratuita)
- O arquivo `index.html` deste pacote (ou o link já hospedado, se você recebeu um)

---

## Passo 1 — Criar o projeto no Supabase

1. Acesse [supabase.com](https://supabase.com) e crie uma conta (dá pra usar login do Google)
2. Clique em **"New Project"**
3. Escolha um nome, uma senha de banco (guarde essa senha) e a região mais próxima
4. Aguarde alguns minutos até o projeto ficar pronto

---

## Passo 2 — Criar as tabelas

1. No painel do projeto, clique em **SQL Editor** (barra lateral)
2. Abra o arquivo `supabase-schema.sql` deste pacote em qualquer editor de texto
3. **Copie todo o conteúdo**, cole no SQL Editor e clique em **Run**
4. Repita o mesmo processo para cada arquivo dentro da pasta `migrations/`, **em ordem numérica** (ex: `001_auth_rls.sql` antes de qualquer outro que vier depois)
   > Cada migration tem um arquivo `_rollback.sql` correspondente — só use se algo der errado e você precisar desfazer.

---

## Passo 3 — Configurar o login (Auth)

O app exige login — sem isso, ninguém acessa os dados, nem você.

1. No painel do Supabase, vá em **Authentication → Providers → Email**
2. Desmarque **"Allow new users to sign up"** (impede que qualquer pessoa com o link crie uma conta sozinha)
3. Vá em **Authentication → Users** → **"Add user"**
4. Crie um usuário pra você (e-mail + senha)
5. Se for compartilhar com cônjuge/sócio, crie um segundo usuário pra ela(e) aqui também — cada pessoa loga com o próprio e-mail e senha

---

## Passo 4 — Pegar a URL e a chave do projeto

1. No painel do Supabase, vá em **Settings → API**
2. Copie a **Project URL** (algo como `https://xxxx.supabase.co`)
3. Copie a chave **`anon` `public`**
4. Guarde os dois — você vai usar no próximo passo

---

## Passo 5 — Configurar o App HTML

### Opção A: Abrir localmente (mais simples)
1. Abra o arquivo `index.html` no seu navegador (Chrome recomendado)
2. Na tela de login, cole a **URL do Projeto** e a **Anon Key** do Passo 4 e clique em **"Conectar"**
3. Faça login com o e-mail e senha criados no Passo 3

### Opção B: GitHub Pages (gratuito, melhor opção para acesso remoto)
1. Crie uma conta em [github.com](https://github.com) se não tiver
2. Crie um novo repositório (público — GitHub Pages em repositório privado exige plano pago) chamado `finance-app`
3. Faça upload de todos os arquivos deste pacote
4. Vá em **Settings → Pages → Source: Deploy from branch: main**
5. Aguarde ~2 minutos e acesse: `https://seuusuario.github.io/finance-app`
6. Na tela de login que aparecer, cole a URL/chave do Passo 4 e faça login

---

## Passo 6 — Adicionar ao celular como App

### iPhone (Safari)
1. Abra o app no Safari e faça login
2. Toque no botão de compartilhar (⬆️)
3. Role para baixo e toque em **"Adicionar à Tela de Início"**
4. Toque em **"Adicionar"**

### Android (Chrome)
1. Abra o app no Chrome e faça login
2. Toque nos três pontos (⋮)
3. Toque em **"Adicionar à tela inicial"**
4. Toque em **"Adicionar"**

---

## Compartilhar com cônjuge/sócio

1. Compartilhe o link do app (GitHub Pages ou onde hospedar)
2. A outra pessoa abre o link e, na tela de login, cola a mesma **URL/chave do Supabase** (Passo 4) — isso conecta ao mesmo banco
3. Cada pessoa faz login com o **próprio usuário** (criado no Passo 3) — não existe usuário compartilhado
4. Pronto — os dois lançam no mesmo banco de dados em tempo real!

---

## Solução de problemas

| Problema | Solução |
|----------|---------|
| "Erro na conexão" ao conectar | Verifique se a URL e a Anon Key do Supabase estão corretas (Passo 4) |
| "E-mail ou senha inválidos" | Confirme que o usuário foi criado em Authentication → Users (Passo 3) |
| Tela de login não sai do lugar depois de logar | Confira o Console do navegador (F12) por erros |
| Dados aparecem todos zerados mesmo logado | As tabelas/migrations podem não ter sido criadas — repita o Passo 2 |
| Tela em branco | Abra o Console do navegador (F12) e veja o erro |

---

## Estrutura dos arquivos

```
📁 Finance App
  ├── index.html            ← App principal (interface)
  ├── date-utils.js         ← Funções de data/saldo usadas pelo app (não editar isoladamente)
  ├── tests.html             ← Testes — abra no navegador pra conferir
  ├── sw.js, manifest.json  ← Suporte a instalação como app (PWA)
  ├── supabase-schema.sql   ← Estrutura das tabelas (Passo 2)
  ├── migrations/           ← Mudanças no banco aplicadas depois do schema inicial (Passo 2)
  └── README.md             ← Este guia

☁️ Supabase
  └── Seu projeto           ← Banco de dados + login (Passos 1-4)
```

---

Dúvidas? Qualquer problema no passo a passo, descreva onde travou e o que apareceu na tela.
