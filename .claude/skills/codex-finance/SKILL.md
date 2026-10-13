---
name: codex-finance
description: Delega tarefas do app de finanças ao Codex (OpenAI) pelo modo não interativo do próprio Codex CLI (`codex exec`). Use quando o João ou o Opus pedirem para "mandar ao Codex", "o Codex investigar", "o Codex implementar" ou "o Codex revisar".
---

# codex-finance

Delega trabalho ao Codex chamando `codex exec` pelo terminal, seguindo as regras deste projeto. O Codex executa; **o Claude Code continua sendo quem revisa, commita e publica.**

## Estado verificado neste computador (13/10/2026) — LER ANTES DE USAR

O sandbox do Codex no Windows **não está funcional**: `codex exec -s read-only` falha em qualquer comando com `Failed to create unified exec process: helper_unknown_error: setup refresh had errors`, e `codex doctor` aponta `✗ sandbox — elevated Windows sandbox provisioning recorded a structured failure` (além de aviso de exclusões do Microsoft Defender e de pouco espaço em disco, 4,6 GiB livres). Consequências:

- Hoje o Codex **não consegue nem ler o `CLAUDE.md`** (ler arquivo também é um comando). Não delegar nada até o `codex doctor` ficar sem `✗`.
- Isso **não prova** que `read-only` bloqueia escrita: o teste de criar arquivo falhou antes de chegar ao sandbox de verdade. Depois de corrigido, repetir o teste (criar `teste.txt` num diretório temporário fora do repositório com `-s read-only`) e registrar o resultado aqui. Se o arquivo for criado, o `read-only` não segura no Windows e a única proteção passa a ser a revisão de `git status`/`git diff` — tarefas com risco de rede ficam fora do Codex.
- Corrigir o provisionamento exige privilégio de administrador e exclusões no Defender: é decisão e ação do João, não do Claude Code.

## Pré-requisito

Codex CLI instalado e logado na conta do João (`codex login status`). Se não estiver, diga isso ao João e pare.

## Como chamar

Sempre no **clone git** do repositório `jppaim13/Finance` (o mesmo usado para commit e push), nunca na pasta de trabalho sem `.git`.

Investigação ou revisão (padrão):

```
codex exec -s read-only -C "<caminho do clone>" "<prompt>"
```

Implementação (só quando a tarefa pedir mudança de arquivo):

```
codex exec -s workspace-write -C "<caminho do clone>" "<prompt>"
```

Regras dos parâmetros:

- `-s read-only` é o padrão. `workspace-write` só para implementação aprovada.
- **Nunca** use `--dangerously-bypass-approvals-and-sandbox`, nem libere acesso de rede ao sandbox. Este computador tem o Supabase CLI ligado ao banco de produção; com rede, o Codex conseguiria rodar `supabase db query` contra dados reais.
- Prompts longos: grave o texto num arquivo temporário fora do repositório e passe pelo stdin (`codex exec ... - < prompt.txt`), para evitar problemas de aspas no shell.
- O prompt precisa ser autossuficiente. O Codex não conhece a conversa: inclua contexto, caminhos e trechos necessários.

## Bloco fixo no início de todo prompt

> Leia o `CLAUDE.md` antes de qualquer coisa. Ele registra a arquitetura e as decisões do projeto, inclusive as rejeitadas. Trate o que ele diz sobre o código como hipótese e confira no código.
> Regras:
> - Nunca acesse o banco de dados nem rode `supabase`, `psql` ou chamadas de rede. Migrations são escritas como arquivo e aplicadas pelo João, depois de backup.
> - Dados financeiros só em consulta agregada, nunca linha a linha.
> - Não faça commit nem push. Deixe as mudanças no diretório para revisão.
> - Ao terminar, liste os arquivos alterados e o que não conseguiu verificar.

## Depois da resposta do Codex

1. Leia a saída inteira e rode `git status` e `git diff` no clone antes de aceitar qualquer coisa.
2. Se a tarefa era `read-only` e `git status` mostrar qualquer arquivo alterado, descarte e avise o João: o sandbox não segurou.
3. Rode a checagem de sintaxe do `index.html`; se `date-utils.js` mudou, peça ao João para abrir o `tests.html`.
4. Só então commite, indicando no commit que a implementação veio do Codex, e registre no `CLAUDE.md` quem decidiu e quem implementou.
5. Diga "concluído" só se o Codex confirmou que terminou.

## Quando não usar

- Investigações em andamento que dependem do contexto da conversa (o Codex começa do zero).
- Qualquer coisa que toque dados de produção.
- Tarefas no mesmo trecho de código que o Claude Code esteja editando ao mesmo tempo.
