# 💰 Finance App — Guia de Instalação

Tempo estimado: **15 minutos**

---

## O que você vai precisar
- Conta Google (Gmail)
- A planilha `Controle_Financeiro_V6.xlsx` já no seu Google Drive
- Os arquivos `index.html` e `apps-script.gs` deste pacote

---

## Passo 1 — Preparar a planilha no Google Drive

1. Abra o [Google Drive](https://drive.google.com)
2. Faça upload do arquivo `Controle_Financeiro_V6.xlsx`
3. Clique com botão direito → **"Abrir com" → "Planilhas Google"**
4. A planilha vai abrir como Planilha Google — aguarde
5. Copie o **ID da planilha** da URL:
   - URL exemplo: `docs.google.com/spreadsheets/d/`**`1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgVE2upms`**`/edit`
   - O ID é a parte em negrito acima (entre `/d/` e `/edit`)
   - Guarde esse ID — você vai precisar no próximo passo

---

## Passo 2 — Configurar o Apps Script (backend)

1. Na planilha aberta, clique em **"Extensões"** → **"Apps Script"**
2. Uma nova aba vai abrir com um editor de código
3. **Apague todo o código** que aparece lá (selecione tudo e delete)
4. Abra o arquivo `apps-script.gs` deste pacote em qualquer editor de texto
5. **Copie todo o conteúdo** e cole no editor do Apps Script
6. Na linha 8, substitua `SEU_ID_AQUI` pelo ID que você copiou no Passo 1:
   ```javascript
   const SPREADSHEET_ID = '1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgVE2upms'; // seu ID aqui
   ```
7. Clique no ícone de **salvar** (💾) ou pressione `Ctrl+S`

---

## Passo 3 — Publicar como Web App

1. No Apps Script, clique em **"Implantar"** (botão azul, canto superior direito)
2. Clique em **"Nova implantação"**
3. Clique no ícone de engrenagem ⚙️ ao lado de "Tipo" e selecione **"App da Web"**
4. Preencha assim:
   - **Descrição:** Finance App
   - **Executar como:** Eu mesmo (seu email)
   - **Quem tem acesso:** Qualquer pessoa
5. Clique em **"Implantar"**
6. Uma janela vai pedir permissão — clique em **"Autorizar acesso"**
7. Escolha sua conta Google → clique em **"Avançado"** → **"Acessar Finance App (não seguro)"** → **"Permitir"**
   > ⚠️ Essa mensagem aparece porque o app não foi verificado pelo Google, mas o código é seu — é seguro.
8. Copie a **URL da implantação** que aparece (começa com `https://script.google.com/macros/s/...`)
9. **Guarde essa URL** — você vai usar no próximo passo

---

## Passo 4 — Configurar o App HTML

### Opção A: Abrir localmente (mais simples)
1. Abra o arquivo `index.html` no seu navegador (Chrome recomendado)
2. Clique em **"Configurações"** (último ícone da barra de navegação)
3. Cole a URL do Apps Script no campo **"URL do Google Apps Script"**
4. Clique em **"Salvar e Testar Conexão"**
5. Se aparecer **"✅ Conectado com sucesso!"** — está funcionando!

### Opção B: Hospedar no Google Drive (acesso de qualquer lugar)
1. Faça upload do `index.html` para uma pasta no Google Drive
2. Clique com botão direito → **"Compartilhar"** → **"Qualquer pessoa com o link pode ver"**
3. Copie o link e abra no navegador
   > Nota: pelo Drive o arquivo HTML abre como prévia — para funcionar melhor, veja Opção C.

### Opção C: GitHub Pages (gratuito, melhor opção para acesso remoto)
1. Crie uma conta em [github.com](https://github.com) se não tiver
2. Crie um novo repositório público chamado `finance-app`
3. Faça upload do `index.html`
4. Vá em **Settings** → **Pages** → **Source: Deploy from branch: main**
5. Aguarde ~2 minutos e acesse: `https://seuusuario.github.io/finance-app`

---

## Passo 5 — Adicionar ao celular como App

### iPhone (Safari)
1. Abra o app no Safari
2. Toque no botão de compartilhar (⬆️)
3. Role para baixo e toque em **"Adicionar à Tela de Início"**
4. Toque em **"Adicionar"**

### Android (Chrome)
1. Abra o app no Chrome
2. Toque nos três pontos (⋮)
3. Toque em **"Adicionar à tela inicial"**
4. Toque em **"Adicionar"**

---

## Compartilhar com cônjuge/sócio

1. Compartilhe o link do app (GitHub Pages ou onde hospedar)
2. A outra pessoa abre o link, vai em Configurações e cola a mesma URL do Apps Script
3. Pronto — vocês dois lançam no mesmo banco de dados em tempo real!

---

## Atualizar o Apps Script depois de mudanças

Se você precisar atualizar o código do backend:
1. Abra o Apps Script
2. Faça as alterações
3. Clique em **"Implantar"** → **"Gerenciar implantações"**
4. Clique no lápis ✏️ → **"Versão: Nova versão"** → **"Implantar"**

---

## Solução de problemas

| Problema | Solução |
|----------|---------|
| "Erro na conexão" | Verifique se a URL do Apps Script está correta e se publicou como "Qualquer pessoa" |
| Dados não carregam | Verifique se o ID da planilha está correto no código |
| Lançamento não salva | Confirme que a aba `Extrato Mar-2026` existe na planilha |
| Tela em branco | Abra o Console do navegador (F12) e veja o erro |
| Permissão negada | Repita o Passo 3 e aceite todas as permissões |

---

## Estrutura dos arquivos

```
📁 Finance App
  ├── index.html        ← App principal (interface)
  ├── apps-script.gs    ← Backend (cola no Apps Script)
  └── README.md         ← Este guia

📊 Google Drive
  └── Controle_Financeiro_V6.xlsx ← Banco de dados
```

---

Dúvidas? Qualquer problema no passo a passo, descreva onde travou e o que apareceu na tela.
