---
name: codex-finance
description: Delega tarefas do app de finanças ao Codex (OpenAI) pelo modo não interativo do próprio Codex CLI (`codex exec`). Use quando o João ou o Opus pedirem para "mandar ao Codex", "o Codex investigar", "o Codex implementar" ou "o Codex revisar".
---

# codex-finance

Delega trabalho ao Codex chamando `codex exec` pelo terminal, seguindo as regras deste projeto. O Codex executa; **o Claude Code continua sendo quem revisa, commita e publica.**

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

Implementação (ver "modo patch" abaixo — `workspace-write` não funciona neste computador; mantido aqui só como referência para um sandbox elevado):

```
codex exec -s workspace-write -c 'windows.sandbox="unelevated"' -C "<caminho do clone>" - < prompt.txt
```

**Implementação neste computador = modo patch (verificado em 13/10/2026).** `-s workspace-write` NÃO funciona com `windows.sandbox="unelevated"`: o Codex recusa com `windows unelevated restricted-token sandbox cannot enforce split writable root sets directly; refusing to run unsandboxed` (mesmo com `exclude_tmpdir_env_var`/`exclude_slash_tmp`, que deixam uma só pasta gravável — o problema são as subpastas protegidas dentro dela). Só voltaria a funcionar com o sandbox elevado (administrador). Por isso a implementação é feita em **`-s read-only` pedindo o PATCH** (unified diff num bloco ```diff, caminhos `a/…`/`b/…`) no relatório; o Claude Code aplica no clone, revisa linha a linha e publica. Os cabeçalhos `@@` e o contexto dos patches gerados costumam estar levemente errados (`git apply --check --recount --ignore-whitespace` primeiro; se falhar, aplicar os hunks à mão — o que também serve de revisão).

**Correções.** O Claude Code pode devolver correções ao Codex (nova chamada com o patch, o problema encontrado e o que mudar) — vale para correções maiores ou de lógica. Ajustes pequenos (um defeito pontual, hunks que não casam) são mais baratos de fazer direto; nesse caso, registrar em Decisões o que foi mudado em relação ao patch.

Regras dos parâmetros:

- `-s read-only` é o padrão. `workspace-write` só para implementação aprovada.
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

- Investigações em andamento que dependem do contexto da conversa (o Codex começa do zero).
- Qualquer coisa que toque dados de produção.
- Tarefas no mesmo trecho de código que o Claude Code esteja editando ao mesmo tempo.
