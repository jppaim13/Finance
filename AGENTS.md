# AGENTS.md — instruções para o Codex neste repositório

Antes de qualquer coisa, leia o `CLAUDE.md` da raiz: ele registra a arquitetura e as decisões do projeto (FinanceApp, SPA única em `index.html` + Supabase), inclusive as rejeitadas. Trate o que ele diz sobre o código como hipótese e confira no código.

Regras:

- Nunca acesse o banco de dados nem rode `supabase`, `psql` ou chamadas de rede. Migrations são escritas como arquivo e aplicadas pelo João, depois de backup.
- Dados financeiros só em consulta agregada, nunca linha a linha.
- Não faça commit nem push. Deixe as mudanças no diretório para revisão; quem revisa, commita e publica é o Claude Code.
- Ao terminar, liste os arquivos alterados e o que não conseguiu verificar.
- Se a tarefa for investigação, não altere nenhum arquivo.
