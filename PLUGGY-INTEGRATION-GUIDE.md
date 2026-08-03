# Guia de implantação da Pluggy — dificuldades e soluções

Documento derivado da integração real da Pluggy num app financeiro pessoal (Supabase + Deno Edge Function). Cobre da Fase 1 (espelho somente-leitura) até conciliação de fatura e ajuste de saldo. Escrito pra ser reaproveitado em outro projeto — os nomes de tabela do projeto original (`pluggy_contas`, `extrato`, `lancamentos`) aparecem só como exemplo concreto.

## 1. Arquitetura recomendada: espelho antes de escrever

Não tente ligar a Pluggy direto no modelo de produção do seu app. O padrão que funcionou:

1. **Fase 1 — espelho somente-leitura.** Tabelas próprias (`pluggy_contas`, `pluggy_transacoes`, `pluggy_sync_log`, etc.) que só recebem dados da Pluggy. Nenhuma escrita nas tabelas reais do app nessa fase. Isso separa "a sincronização funciona" de "os dados batem com o que o app já tem" — dois problemas diferentes, resolvidos em ordem.
2. **Fase de conciliação.** Só depois do espelho validado: comparar dado da Pluggy contra dado do app, relatório agregado primeiro, linha a linha depois, só se o agregado justificar o esforço.
3. **Importação/escrita**, por último, e só depois dos dois passos acima.

Pular direto pra "importar tudo automaticamente" é o erro mais caro possível — qualquer bug de sincronização ou de casamento de dado vira corrupção silenciosa de dado financeiro real.

### Modelo de tabelas do espelho

- Uma tabela de "apps"/titulares (permite múltiplos titulares/CPFs no mesmo banco — famílias/casais têm contas separadas, ver seção 7).
- Uma tabela de "items" (conexões banco↔Pluggy) — **a Pluggy não tem endpoint de listagem de items** por razões de segurança deles. Cada `itemId` é copiado manualmente do Dashboard da Pluggy e cadastrado à mão. Sem essa lista, a sincronização não sabe quais bancos consultar.
- Uma tabela de contas espelhadas, com colunas de **mapeamento manual** (a que conta/cartão do seu app aquilo corresponde) que a sincronização nunca sobrescreve — só grava as colunas que vêm da Pluggy, então um `upsert` com `onConflict` preserva o mapeamento automaticamente.
- Uma tabela de transações espelhadas.
- Uma tabela de log de sincronização (status, contagem, erro) — essencial pra debugar sem re-rodar.

### RLS / segurança

Row Level Security igual ao resto do banco. A Edge Function usa a **service role key** (ignora RLS) pra escrever; o front-end usa a chave anônima normal pra ler e pra editar só as colunas de mapeamento manual.

## 2. Armadilhas reais da API (Pluggy), uma por uma

Todas encontradas testando contra 5 conectores bancários reais — **não assuma que testar um conector garante o comportamento dos outros**. Cada achado abaixo só apareceu num subconjunto dos bancos.

### `/transactions` foi descontinuado (HTTP 410)
Use `GET /v2/transactions`. O parâmetro de data mudou de `from` para `dateFrom`.

### `pageSize` não é aceito no v2
`400 "property pageSize should not exist"`. O tamanho de página é fixo (confirmado: 500) do lado da Pluggy — não dá pra pedir menos nem mais.

### Paginação por cursor (`next`) é inconsistente entre conectores
Em alguns bancos `next` vem como URL absoluta; em outros, só como fragmento de query (`?accountId=...&after=...`), quebrando com `Invalid URL` se você tentar usar direto. Resolver com `new URL(next, baseUrl).href` — resolve os dois formatos. É a mesma técnica que o SDK oficial (`pluggy-node`) usa por precaução, então não é peculiaridade do seu conector, é conhecido.

### Truncamento silencioso quando a paginação falha no meio
Se a página 1 (500 linhas) upserta com sucesso e a página 2 falha (por exemplo, o bug do `next` acima, antes de corrigido), você fica com exatamente 500 linhas — número redondo, fácil de não notar, e nenhuma sincronização incremental futura vai reprocessar esse histórico (incremental só olha pra frente a partir da última transação salva). **Sintoma pra vigiar**: qualquer conta cujo total de transações bate exatamente no tamanho de página é suspeita de truncamento — vale conferir.
**Correção estrutural, não só do dado**: isole erros por conta num `try/catch` individual, não um só pra sincronização inteira. Sem isso, um erro na conta N aborta o loop e as contas N+1 em diante nem chegam a ser tentadas naquele run — sintoma: "sincronizou algumas contas, outras não", sem padrão aparente.

### Metadado incompleto varia por conector — não é falta de dado, é o conector mesmo
Nos testes reais: um conector não trouxe `billForecastDate` em nenhuma transação (0% de cobertura, os outros 4 tinham entre 85% e 100%); outro não trouxe `billClosingDate` em quase nenhuma fatura; outro não trouxe `payments` nenhum. **Não desenhe nenhuma lógica que dependa de um campo estar sempre presente** sem checar a cobertura real por conector primeiro (`count(*) filter (where campo is not null)` agrupado por banco).

### Sobreposição de 30 dias é necessária na busca incremental
Transações `PENDING` viram `POSTED` (e o valor pode mudar) dias depois de aparecerem pela primeira vez. Buscar incrementalmente a partir de "última transação salva − 30 dias", não da data exata — o `upsert` idempotente (por `pluggy_id`/id externo) torna esse reprocessamento barato.

### Sincronizações sobrepostas
Um botão desabilitado no front-end só cobre clique duplo na mesma aba — reload de página ou aba duplicada não passa por ali. Proteção real fica no servidor: a função recusa (HTTP 409) começar se já existir um log "em andamento" recente (com uma janela de alguns minutos, pra uma execução que travou de verdade não travar sincronizações futuras pra sempre).

### `GET /bills` é um endpoint separado e melhor que somar transações
Pra cartão de crédito, existe `GET /bills?accountId=...` — devolve a fatura **real do emissor**: `id`, `dueDate`, `billClosingDate`, `totalAmount`, `minimumPaymentAmount`, `payments[]`, `financeCharges[]`. Isso é estritamente melhor que reconstruir o total da fatura somando transações — é o número que o banco/emissor já calculou, líquido de pagamentos. Só descoberto depois de já ter tentado a abordagem de somar transações; pesquisar a documentação oficial antes de reimplementar algo que a API já resolve.

Fatura **fechada vs. aberta**: não confie em `closing_date`/`status` pra decidir isso — em conectores reais esse campo veio nulo em 100% das faturas de um banco e em quase todas de outro. Use um **fato de calendário**: `due_date < hoje` ⇒ fatura conciliável (vencimento passado é necessariamente fechado, não importa o que o campo de status diga). Verificar antes de adotar: `due_date` precisa estar presente em ~100% das faturas nos conectores usados — sem isso a regra não funciona.

### `installmentNumber`/`totalInstallments` — use pra casar parcela, não infira por valor+data
Transações de cartão com metadado de cartão de crédito trazem esses dois campos quando fazem parte de um parcelamento. **Casar parcelas contra o seu modelo pelo número de parcela e valor exato é muito mais confiável que casar por valor+data** — data de compra e data de lançamento manual divergem com frequência (às vezes por semanas, se o usuário lança retroativamente), mas o valor de cada parcela e sua posição na sequência não mudam.

### `billId` como chave de junção — cobertura real importa mais que teoria
`billId` (dentro do metadado de cartão) referencia a fatura de origem de cada transação. Testado: presença de 100% nas transações de cartão nos 5 bancos usados, inclusive no conector mais pobre em outros metadados. Com essa cobertura, `billId` é uma chave de junção confiável entre transação e fatura (`/bills`), não só um cross-check auxiliar — mas **meça a cobertura real no seu caso antes de decidir**, não assuma.

### `currencyCode`/`amountInAccountCurrency` — no nível raiz da transação, fácil de esquecer de capturar
A Pluggy documenta esses dois campos **no nível raiz do objeto de transação**, não dentro do metadado de cartão de crédito. `amount` pode vir na moeda original da compra (ex: USD pra assinatura internacional); `amountInAccountCurrency` já vem convertido pra moeda da conta. **Se você só captura os campos "óbvios" (metadado de cartão, categoria, merchant), value vai silenciosamente ficar na moeda errada pra compra internacional** — sem erro, sem transação faltando, só um valor 4-6x menor que o real, com `status: POSTED` (não é atraso de sincronização, é o valor final mesmo). Capture os dois campos desde o início; se não puder validar todo o histórico retroativamente (a busca incremental não revisita meses antigos), pelo menos capture daqui pra frente.
**Detector direto**: `currencyCode != 'BRL'` (ou a moeda local do seu caso). Quando marcado, prefira `amountInAccountCurrency` a `amount` se ele existir; se não existir mesmo com moeda estrangeira marcada, trate como suspeito e não confie no valor sem revisão.

### `purchaseDate` — data estável da compra original, igual em todas as parcelas
Diferente de `date` (a data de cada cobrança individual), `purchaseDate` é a mesma em todas as parcelas de uma mesma compra parcelada. Útil pra: (1) confirmar que duas transações "candidatas" são de fato parcelas da mesma compra; (2) ancorar comparação quando o usuário lançou parcelas com data de revisão em vez de data real de cobrança (padrão comum quando alguém digita retroativamente).

## 3. Padrões de engenharia que valeram a pena

- **Upsert em lote por página, não por linha.** Centenas/milhares de round-trips individuais ao banco numa sincronização só é o jeito mais provável de estourar o tempo de execução de uma function serverless — o sintoma é o log de sincronização ficando com status "em andamento" pra sempre, mesmo com os dados já tendo chegado corretamente. Trocar por um upsert por página resolve.
- **Contador de "criadas vs. atualizadas" via `count` de upsert não funciona.** Um `upsert` sempre "afeta" 1 linha por registro, seja inserindo ou atualizando — não dá pra distinguir os dois casos por aí sem o truque de `xmax` do Postgres (que exige um `select` extra). Não finja que distingue; um contador só de "processadas" é mais honesto que um "criadas"/"atualizadas" que mente com confiança.
- **Nunca normalizar/inverter sinal na ingestão.** Se um conector devolver valor com sinal diferente do esperado, registre isso como uma decisão documentada, não corrija silenciosamente na função de sincronização — esconder a inversão tira informação que uma fase futura (reconciliação, importação) pode precisar.
- **Debug de dado real da Pluggy: só query agregada, nunca linha crua**, em qualquer lugar que persista texto (chat com IA, ticket, log público). Descrição de transação e valor são dado financeiro real de pessoa real. Sempre que precisar verificar um padrão (sinal, fuso, moeda), desenhe a verificação como contagem/booleano por banco, não como amostra de linhas.

## 4. Fuso horário

A Pluggy devolve toda data em ISO8601 UTC. Transações de cartão costumam vir como `"...T00:00:00.000Z"` — isso é um **marcador de dia**, não um instante real (a Pluggy não sabe a hora exata da compra). Converter isso direto pro fuso local sem cuidado desloca o dia (ex: meia-noite UTC vira 21h do dia anterior em GMT-3).

Regra: hora exatamente `00:00:00.000Z` → usa a data crua (`YYYY-MM-DD`) direto, sem conversão. Qualquer outra hora → é instante real, converter usando **fuso nomeado** (`Intl.DateTimeFormat` com `timeZone`, tipo `"America/Sao_Paulo"`), não um deslocamento fixo tipo `-3h` — um offset fixo quebra silenciosamente se o país voltar a ter horário de verão. Guarde sempre o valor original intocado numa coluna separada (`data_utc` ou similar) — se essa heurística estiver errada pra algum conector, dá pra recalcular sem re-sincronizar.

## 5. Reconciliação: comparar dado do seu app contra a Pluggy

Esta foi a parte mais cara em retrabalho da integração inteira — quatro rodadas de relatório até o método ficar certo.

### O erro raiz: assumir que seu app guarda dado num lugar só
Se o seu modelo de dado espalha informação parecida em mais de uma tabela (no projeto original: compras avulsas numa tabela, compras parceladas/recorrentes em outra), **qualquer comparação que olhe só uma delas produz "só na Pluggy" inflado e "só no app" incompleto** — porque metade do que o app já sabe fica invisível pro relatório. Isso se repetiu quatro vezes na mesma sessão antes de virar regra: sempre que for comparar "o que o app sabe" contra uma fonte externa, levante **todas** as tabelas que podem conter aquele tipo de dado, não só a mais óbvia.

### Valor + data não é chave, é coincidência quando há parcelamento envolvido
Comparar transações por valor exato + janela de data (ex: ±3 dias) funciona bem pra compra avulsa. Mas quando há parcelamento no jogo, duas armadilhas simétricas aparecem:

1. **Falso positivo**: uma parcela pode coincidir por valor+data com uma linha completamente não relacionada. Consequência real, não teórica: se uma importação automática tivesse rodado em cima desse casamento errado, a transação de verdade teria sido marcada como "já registrada" e **nunca importada** — perda silenciosa, pior que duplicata (duplicata pelo menos aparece pra alguém notar).
2. **Falso negativo**: se o usuário lança parcelas avulsas diretamente na tabela "principal" (sem usar o mecanismo de recorrência do app), a data que ele lança é a data em que **revisou/lançou** a compra, não a data real de cada cobrança — diferença observada de até 23 dias num caso real. Casar só por essa data janela perde o match.

**Correção**: separe o pool de comparação por estrutura (`installmentNumber` presente vs. ausente) pra evitar o falso positivo — mas depois **compare cada lado do seu app contra os dois pools da Pluggy** (não só um), porque o usuário pode ter lançado uma parcela na tabela "errada" do ponto de vista do seu modelo. Quando o casamento por data falhar mas o valor bater com uma parcela real, trate como candidato de método antes de contar como divergência genuína — e cheque `purchaseDate` (mesma em todas as parcelas de uma compra) pra confirmar.

### Ordem de trabalho que valeu a pena
1. **Relatório agregado primeiro** (contagem e soma por categoria de conta/competência) — responde "vale o esforço de casar linha a linha, ou é melhor importar direto?" antes de gastar tempo linha a linha.
2. Se valer o esforço: casamento automático com os critérios acima, saída ainda agregada (nunca linha crua em chat/log).
3. Só o que sobrar sem casar automaticamente vira revisão manual — e mesmo aí, cheque campos estruturados (tipo `purchaseDate`) antes de assumir que é divergência real. Na prática: de um lote de 18 linhas "sem match automático", só 3 eram divergência real depois da revisão — o resto era o método de comparação não olhando o lugar certo.
4. Regra dura, desde o início: **dado que existe só no app nunca é apagado automaticamente** por um relatório de comparação. "A Pluggy não viu isso" é informação (pode ser lacuna do conector, duplicata, erro de lançamento) — não é autorização pra deletar. Sinalize, não apague.

## 6. Ajuste de saldo inicial ("marco zero")

Se o objetivo final é usar a Pluggy como fonte de verdade do saldo (em vez de reconciliar todo o histórico manual, o que costuma ser trabalho grande e sem retorno — melhor não tentar), o padrão que funcionou foi: ajustar o saldo inicial de cada conta pro saldo real reportado numa data de corte, sem reconciliar os meses anteriores, e passar a confiar na Pluggy dali em diante.

### O bloqueio que quase gerou saldo duplicado
Se a sua função de cálculo de saldo soma **todo** o histórico de lançamentos sem nenhum conceito de "ponto de partida" (ex: `saldo = saldo_inicial + soma de tudo que já foi lançado, sem filtro de data`), simplesmente atualizar `saldo_inicial` pro valor novo da Pluggy **conta cada lançamento manual anterior à data de corte duas vezes** — uma vez embutido no novo saldo inicial (que já reflete tudo até aquela data), outra vez somado de novo pela função. Isso é bug garantido, silencioso, no dia seguinte à mudança. **Verifique explicitamente se sua função de saldo tem esse conceito de corte antes de escrever qualquer migration** — não assuma que existe só porque "faz sentido que exista".

### O corte tem que ser na ocorrência, não no registro
Lançamentos recorrentes (assinatura mensal, parcelamento) não são uma linha histórica — são uma regra que gera ocorrências (uma por mês, ou uma por parcela). Um lançamento recorrente começado **antes** da data de corte continua válido e ativo; só as ocorrências **anteriores** ao corte é que não podem somar de novo (já estão embutidas no novo saldo inicial). As ocorrências posteriores ao corte — inclusive futuras — continuam contando normal. Filtrar o **registro inteiro** por data de início erraria isso: perderia a recorrência inteira, inclusive os meses futuros que ainda precisam contar.

### Checagem de fronteira, não suposição
A API pode só devolver o saldo **atual** de uma conta bancária (sem endpoint de "saldo numa data passada"). Antes de assumir que "saldo atual" equivale ao "saldo de fechamento do dia anterior" (a data de corte pretendida), **confira se existe alguma transação já processada entre a data de corte e agora** — se não existir nenhuma, os dois saldos coincidem na prática; se existir, é preciso descontar. Essa checagem expira: se a migration demorar dias pra ser aplicada, refaça antes de aplicar.

### Separar em passos por risco, não em um só
Divida em (A) mudança de schema aditiva e sem efeito (coluna nova, nullable, sem preencher), (B) mudança de código que passa a respeitar essa coluna — com critério de aceitação explícito de "nenhum comportamento muda enquanto a coluna estiver vazia" (teste de regressão comparando explicitamente o resultado com e sem o corte, não só o caso novo), (C) preencher os valores de verdade, só depois de (B) validado. Se (B) tiver bug, nada mudou ainda porque (C) não rodou. Rollback de (C) precisa ter os valores antigos **gravados literalmente** no próprio arquivo de rollback (levantados antes de aplicar) — um rollback genérico (voltar tudo pra zero/null) não desfaz um ajuste de valor real.

## 7. Múltiplos titulares / fronteira de CPF

Planos gratuitos de open finance geralmente cobrem só contas nominais do próprio titular que criou a aplicação/API key. Se o app é usado por um casal/família com contas separadas, **contas da segunda pessoa não vão aparecer nunca, e isso não é bug nem setup incompleto** — é a fronteira do plano. Desenhe o modelo de app_id/titular desde o início pra suportar múltiplas aplicações Pluggy (uma por pessoa, com seu próprio conjunto de secrets/itemIds) mesmo que só uma esteja em uso — evita ter que redesenhar depois.

**Consequência pra qualquer critério de automação** ("confiar no saldo sem precisar abrir o app"): esse critério só vale pra contas efetivamente cobertas pela integração. Aplicar automação silenciosa numa conta não coberta produz saldo confiante e errado — pior que visivelmente desatualizado, porque não há sinal nenhum de que está errado. Registre essa exceção **antes** de implementar qualquer automação, não depois de alguém notar o saldo errado.

**Como saber o que está coberto**: reuse a tabela de mapeamento manual (seção 1) como fonte única da verdade — não crie uma coluna redundante tipo `coberto_por_integracao` em outro lugar só pra "ser mais rápido de checar". Duas fontes da mesma informação dessincronizam (alguém mapeia numa tela e esquece de marcar a outra, ou vice-versa); uma fonte só não tem como dessincronizar de si mesma.

## 8. Disciplina de verificação (a lição mais cara)

A maior fonte de retrabalho nesta integração não foi a API da Pluggy — foi tratar **descrição de comportamento de código como fato antes de verificar**. Isso aconteceu pelo menos duas vezes: uma especificação de contrato de API escrita "de memória" (custou uma rodada inteira de debug até bater com a documentação oficial), e uma suposição de que uma função de cálculo de saldo já tinha um conceito de "data de corte" que na verdade não existia no código.

Prática que reduziu isso a zero depois de adotada: **antes de implementar em cima de qualquer alegação sobre como o código ou a API se comporta — sua ou de outra pessoa/IA — grep o código de verdade ou teste a chamada de verdade.** "Provavelmente funciona assim" não é a mesma coisa que "confirmei que funciona assim". Isso vale em dobro pra dinheiro.

Outras práticas de verificação que compensaram o custo:
- Rodar aggregate diagnostics (contagem/booleano por conector) antes de confiar que um campo está sempre presente.
- Depois de qualquer correção de bug de sincronização, re-sincronizar e conferir o número final contra o que o usuário vê no app/extrato oficial do banco — validação agregada (total bate) **não substitui** validação de linha (um erro pequeno se esconde dentro de um total que ainda bate).
- Quando um teste de função pura depende de "hoje" (data atual), injete a data como parâmetro opcional em vez de deixar a função ler o relógio real — sem isso o teste é não-determinístico e vai quebrar sozinho mês que vem.
