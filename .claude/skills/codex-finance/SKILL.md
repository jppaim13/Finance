---
name: codex-finance
description: Delega tarefas do app de finanças ao Codex (OpenAI) pelo modo não interativo do próprio Codex CLI (`codex exec`). Use quando o João ou o Opus pedirem para "mandar ao Codex", "o Codex investigar" ou "o Codex revisar".
---

# codex-finance

Delega INVESTIGAÇÃO e REVISÃO (somente leitura) ao Codex chamando `codex exec` pelo terminal, seguindo as regras deste projeto. O Codex executa; **o Claude Code continua sendo quem revisa, commita e publica.**

## Estado verificado neste computador (13/10/2026) — LER ANTES DE USAR

O backend padrão do sandbox do Codex no Windows ("elevated") **falha ao provisionar** aqui (`codex doctor`: `✗ sandbox — elevated Windows sandbox provisioning recorded a structured failure`; exige administrador). Sem corrigir isso, `codex exec` não executa comando nenhum. **Contorno adotado: todo `codex exec` leva `-c 'windows.sandbox="unelevated"'`** (modo restricted-token, sem administrador), passado na chamada — não mexemos no `config.toml` global do Codex, que o app desktop também usa.

O que foi testado com esse modo (nada persistido):
- **Escrita:** `-s read-only` tentou criar `teste.txt` num diretório temporário fora do repositório e foi **negado** (`PermissionDenied`); nenhum arquivo apareceu.
- **Rede:** um `Invoke-WebRequest` para `https://api.pluggy.ai/` dentro do sandbox teve a conexão derrubada, enquanto o mesmo comando fora do sandbox chega ao servidor (HTTP 403). Um único teste: **não é garantia** de bloqueio em todos os caminhos — o modo "unelevated" não usa as regras de firewall do modo elevado. Por isso as proibições abaixo (sem `--dangerously-bypass…`, sem `supabase`/`psql`/rede no prompt) continuam valendo e a revisão de `git status`/`git diff` continua obrigatória.
- Avisos do `codex doctor` ainda abertos, que o João pode tratar quando quiser: exclusões do Microsoft Defender não verificadas e pouco espaço em disco (4,6 GiB livres; aviso abaixo de 5 GiB).

## Pré-requisito

Codex CLI instalado e logado na conta do João (`codex login status`). Se não estiver, diga isso ao João e pare.

## Como chamar

Sempre no **clone git** do repositório `jppaim13/Finance` (o mesmo usado para commit e push), nunca na pasta de trabalho sem `.git`.

Investigação ou revisão (padrão):

```
codex exec -s read-only -c 'windows.sandbox="unelevated"' -C "<caminho do clone>" - < prompt.txt
```

**REGRA DE USO (decisão de 13/10/2026): o Codex só INVESTIGA e REVISA, em leitura, em `-s read-only` — "leia muito e diga o que achou". MUDANÇAS DE CÓDIGO o Claude Code faz direto.** Motivo medido: na investigação da lista de meses houve economia real (o Codex leu o código inteiro, ~45,6 mil tokens dele contra ~15 mil do Claude Code); na implementação dos filtros do Extrato não houve (~52 mil do Codex em duas tentativas + ~13 mil do Claude Code, que leu os mesmos trechos para revisar, aplicou o patch à mão e corrigiu um defeito). Sem `workspace-write` aqui, o fluxo patch → aplicação manual → revisão custa mais que fazer direto.

Por que não há `workspace-write`: com `windows.sandbox="unelevated"` o Codex recusa com `windows unelevated restricted-token sandbox cannot enforce split writable root sets directly; refusing to run unsandboxed` (mesmo com `exclude_tmpdir_env_var`/`exclude_slash_tmp`: o problema são as subpastas protegidas dentro da pasta gravável). Só voltaria com o sandbox elevado (administrador); se isso mudar, reavaliar esta regra.

Se um dia for preciso gerar patch mesmo assim: `-s read-only` pedindo um unified diff no relatório; os cabeçalhos `@@` costumam vir errados (`git apply --check --recount --ignore-whitespace`; se falhar, aplicar à mão). Correções ao Codex: nova chamada com o problema encontrado e o que mudar.

Regras dos parâmetros:

- Sempre `-s read-only`. Não usar `workspace-write` (não funciona aqui; ver regra de uso).
- **Nunca** use `--dangerously-bypass-approvals-and-sandbox`, nem libere acesso de rede ao sandbox. Este computador tem o Supabase CLI ligado ao banco de produção; com rede, o Codex conseguiria rodar `supabase db query` contra dados reais.
- Passe o prompt **sempre pelo stdin** (arquivo temporário fora do repositório, `-` no fim do comando). Verificado: prompt com aspas duplas direto na linha de comando quebra no atalho `codex.cmd` do npm no Windows (`unexpected argument`). No PowerShell: `Get-Content prompt.txt -Raw | codex exec ... -`.
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

- **Mudanças de código** (o Claude Code faz direto — ver regra de uso).
- Investigações em andamento que dependem do contexto da conversa (o Codex começa do zero).
- Qualquer coisa que toque dados de produção.
- Tarefas no mesmo trecho de código que o Claude Code esteja editando ao mesmo tempo.
