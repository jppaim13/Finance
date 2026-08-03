# Guia de implantação da Pluggy

Guia focado na **API da Pluggy em si** — autenticação, endpoints, armadilhas reais de contrato, arquitetura de sincronização — extraído de uma integração real testada contra 5 conectores bancários brasileiros. Escrito pra ser reaproveitado num projeto de tipo diferente do original (era um app de finanças pessoais); por isso a parte de "como comparar contra o meu modelo de dado" foi deixada resumida no fim — isso muda por projeto, o resto deste documento não muda.

**Escopo do que este guia cobre**: uma integração que já parte de um Item existente (conexão banco↔Pluggy criada manualmente pelo Dashboard da Pluggy) e sincroniza contas/transações/faturas periodicamente pra um espelho de leitura. **Não cobre**: o fluxo de vincular uma conta nova via Connect Widget, criação de Item via API (`POST /items`), MFA, nem webhooks — nada disso foi usado ou testado neste projeto. Se seu caso precisa que o usuário final conecte a própria conta pelo seu app (não pelo Dashboard da Pluggy), pesquise esses fluxos separadamente antes de desenhar.

## 1. Conceitos

- **Connector**: a ponte pra uma instituição financeira específica (ex: "Nubank", "Itaú"). `GET /connectors` lista os disponíveis e o que cada um exige pra autenticar.
- **Item**: uma conexão autenticada e persistente entre um usuário e um Connector. É o Item que dá acesso às contas/transações daquele banco. **A Pluggy não tem endpoint de listagem de Items** por razões de segurança deles — não tem como perguntar "quais conexões esse cliente já tem". Cada `itemId` precisa ser copiado manualmente do Dashboard da Pluggy (ou capturado no momento da criação, se você implementar o fluxo de conexão via API/Widget) e guardado no seu próprio banco. Sem essa lista própria, a sincronização não sabe quais bancos consultar — ela sincroniza silenciosamente zero contas, sem erro nenhum.
- **App/aplicação Pluggy**: o Dashboard da Pluggy organiza credenciais (`clientId`/`clientSecret`) por aplicação. Se o produto final precisa suportar múltiplos titulares com contas separadas (ver seção 8), cada titular tem sua própria aplicação Pluggy, suas próprias credenciais, seus próprios Items.
- **Connect Widget vs. API direta**: a Pluggy oferece um componente de front-end pronto (Connect Widget) pra coletar credenciais/MFA do usuário final e criar o Item. A alternativa é orquestrar `POST /items` + `GET /items/{id}` (poll de `executionStatus`) + `POST /items/{id}/mfa` você mesmo. Os dois terminam no mesmo lugar: um `itemId` utilizável. Este projeto usou Items já criados manualmente pelo Dashboard — nenhum dos dois fluxos foi implementado em código.

## 2. Autenticação

`POST /auth` com `{ clientId, clientSecret }` no corpo devolve um `apiKey`. Esse `apiKey`:
- **Expira em ~2 horas.** Não persista — gere um novo a cada execução da sua rotina de sincronização (não é caro, é uma chamada só).
- Vai no header `X-API-KEY` em toda chamada subsequente à API.
- É por aplicação Pluggy (um `clientId`/`clientSecret` por titular, se for o caso — ver seção 8). Convenção que funcionou bem: nomear os secrets com sufixo do titular (`PLUGGY_CLIENT_ID_<APELIDO>`, `PLUGGY_CLIENT_SECRET_<APELIDO>`), com o "apelido" como parâmetro de entrada da função de sincronização — dá pra rodar a mesma função pra titulares diferentes sem duplicar código.

## 3. Descobrir o que sincronizar

Com os `itemId`s guardados (seção 1), pra cada um:

`GET /accounts?itemId=<id>` devolve as contas daquele Item — cada conta tem `id`, `type` (`BANK` ou `CREDIT`), `subtype`, `name`, `number`, `balance`. É esse `id` de conta (não o `itemId`) que identifica cada conta/cartão nas chamadas seguintes de transações e faturas.

Não existe endpoint de "saldo numa data passada" pra conta bancária — `balance` é sempre o saldo **atual**, no momento da chamada. Se seu caso precisa de saldo histórico numa data de corte específica, ver a nota na seção 9.

## 4. Transações — `GET /v2/transactions`

A parte com mais armadilhas reais de contrato de API, todas encontradas testando contra 5 conectores — **não assuma que testar um conector garante o comportamento dos outros 4**. Cada achado abaixo apareceu num subconjunto dos bancos usados, não em todos.

### Endpoint depreciado
`/transactions` (sem `v2`) foi descontinuado — `HTTP 410`. Use `GET /v2/transactions`. O parâmetro de filtro de data também mudou de `from` para `dateFrom`.

### `pageSize` não é aceito no v2
`400 "property pageSize should not exist"`. O tamanho de página é fixo do lado da Pluggy — **confirmado: 500** — não dá pra pedir menos nem mais.

### Paginação por cursor (`next`) é inconsistente entre conectores
A resposta paginada vem como `{ page, total, totalPages, results, next }`. Em alguns bancos `next` veio como URL absoluta; em outros, só como fragmento de query (`?accountId=...&after=...`), quebrando com `TypeError: Invalid URL` se você tentar usar direto como URL. Resolver com:

```js
proxima = pg.next ? new URL(pg.next, baseUrl).href : null;
```

`new URL(relativo, base)` resolve os dois formatos. É a mesma técnica que o SDK oficial (`pluggy-node`) usa por precaução — não é peculiaridade de um conector seu, é conhecido o bastante pra já estar tratado lá.

### Truncamento silencioso quando a paginação falha no meio da história
Se a página 1 (500 linhas) upserta com sucesso no seu banco e a página 2 falha (por exemplo, o bug do `next` acima, antes de corrigido), você fica com exatamente 500 linhas — número redondo, fácil de não notar — e **nenhuma sincronização incremental futura vai reprocessar esse histórico**, porque busca incremental só olha pra frente a partir da última transação já salva (ver próxima seção). O erro fica permanentemente escondido até alguém notar.

**Sintoma pra vigiar**: qualquer conta cujo total de transações bate exatamente no tamanho de página é candidata a truncamento — vale conferir manualmente (forçar um resync completo daquela conta e comparar o total antes/depois).

**Correção estrutural, não só do dado**: isole erros por conta num `try/catch` individual, não um só pra sincronização inteira:

```js
for (const conta of contas) {
  try {
    // paginação + upsert desta conta
  } catch (erroContaEspecifica) {
    // registra e segue pra próxima conta
  }
}
```

Sem esse isolamento, um erro na conta N aborta o loop inteiro e as contas N+1 em diante nem chegam a ser tentadas naquele run — sintoma característico: "sincronizou algumas contas, outras não", sem padrão óbvio até você olhar o log com atenção.

### Sobreposição de ~30 dias é necessária na busca incremental
Transações `status: PENDING` viram `POSTED` (e o `amount` pode mudar) dias depois de aparecerem pela primeira vez. Se você buscar incrementalmente a partir da data exata da última transação salva, uma transação que mudou de status/valor depois da primeira sincronização nunca é revisitada. Buscar a partir de "última transação salva − 30 dias" em vez da data exata; o `upsert` idempotente (por `id` da transação) torna esse reprocessamento barato — a maioria vem igual e só sobrescreve com o mesmo valor.

### Campos de metadado variam de cobertura por conector — não é falta de dado, é o conector mesmo
Testado com dado real: um conector não trouxe `billForecastDate` em **nenhuma** transação de cartão (0% de cobertura), enquanto os outros 4 tinham entre 85% e 100%. Outro não trouxe `payments` nenhum em nenhuma fatura. **Nunca desenhe lógica que dependa de um campo estar sempre presente sem medir a cobertura real por conector primeiro** — uma query de contagem agrupada por banco (`count(*) filter (where campo is not null) group by banco`) leva minutos e evita desenhar em cima de um campo que só existe hipoteticamente.

### `installmentNumber`/`totalInstallments` — parcelamento estruturado
Transações de cartão que fazem parte de um parcelamento trazem esses dois campos dentro do metadado de cartão de crédito (`creditCardMetadata`). Junto com `purchaseDate` (próxima seção), dá pra reconstruir a estrutura completa de uma compra parcelada sem inferir nada por valor ou data de cobrança.

### `purchaseDate` — data estável da compra original
Diferente de `date` (a data de cada cobrança individual — uma por mês, se for parcelado), `purchaseDate` é a **mesma em todas as parcelas de uma mesma compra**. É o campo certo pra confirmar que duas transações "candidatas" são parcelas da mesma compra, e pra ancorar qualquer comparação contra dado inserido manualmente por um usuário (que tende a registrar a data que ele *revisou* a compra, não a data real de cada cobrança — diferença observada de até 23 dias num caso real).

### `currencyCode`/`amountInAccountCurrency` — no nível raiz da transação, fácil de esquecer
A Pluggy documenta oficialmente estes dois campos **no nível raiz do objeto de transação** (não dentro de `creditCardMetadata`, `paymentData` nem nenhum dos objetos aninhados "óbvios"):

| Campo | O que é |
|---|---|
| `amount` | Valor da transação — pode vir na **moeda original** da compra, não necessariamente na moeda da conta |
| `currencyCode` | Código ISO da moeda da transação (`BRL`, `USD`, etc.) |
| `amountInAccountCurrency` | Valor já convertido pra moeda da conta, presente quando a transação é internacional |

**Se sua ingestão só captura os campos "óbvios" (metadado de cartão, categoria, merchant) e esquece esses dois, uma compra internacional entra com o valor na moeda errada — silenciosamente, sem erro, sem transação faltando.** Achado real: uma assinatura mensal em dólar ficou registrada com **1/5 do valor real** por vários meses seguidos, sempre com `status: POSTED` (não era atraso de sincronização — era o valor final mesmo, só que sem conversão). A razão entre o valor errado e o valor real batia com a cotação USD/local do período, o que confirmou a causa.

Capture os dois campos desde o primeiro dia de implementação, mesmo que sua ingestão inicial não vá usá-los — não custa nada capturar, e busca incremental **não revisita meses antigos automaticamente**, então um campo esquecido no começo fica faltando no histórico até alguém forçar um resync completo daquela conta especificamente.

**Detector direto pra revisão**: `currencyCode` diferente da moeda local. Quando marcado, prefira `amountInAccountCurrency` a `amount` cru se ele existir; se não existir mesmo com moeda estrangeira marcada, trate como suspeito e não confie no valor sem revisão humana — não tente estimar a conversão você mesmo (a cotação usada pelo emissor no momento da compra é desconhecida; estimar produz um segundo erro em cima do primeiro).

## 5. Faturas de cartão — `GET /bills`

Endpoint separado de `/v2/transactions`, fácil de não descobrir se você for direto pra "vou somar as transações do mês pra calcular o total da fatura". `GET /bills?accountId=<id da conta CREDIT>` devolve a fatura **real do emissor**, paginada por número de página (`page`, `total`, `totalPages`, `results` — paginação diferente da de transações, que é por cursor):

| Campo | O que é |
|---|---|
| `id` | Identificador da fatura |
| `dueDate` | Vencimento — data real informada pelo emissor |
| `billClosingDate` | Fechamento — data real informada pelo emissor (nem sempre presente, ver abaixo) |
| `totalAmount` | Total da fatura |
| `minimumPaymentAmount` | Mínimo pagável |
| `allowsInstallments` | Se aceita parcelamento da fatura |
| `financeCharges[]` | Juros/multas aplicados |
| `payments[]` | Pagamentos já registrados pelo emissor (`amount`, `paymentDate`, `paymentMode`, `valueType`) |

Isso é **estritamente melhor** que reconstruir o total somando transações — é o número que o emissor já calculou, líquido de pagamentos, direto da fonte. Vale pesquisar a documentação oficial da API inteira antes de reimplementar algo que ela já resolve pronto (este endpoint só foi descoberto depois de já ter uma implementação funcionando por soma de transações).

### Fatura aberta vs. fechada: não confie em `status`/`billClosingDate`
Testado com dado real: `billClosingDate` veio nulo em **100% das faturas** de um conector (mesmo em faturas de meses claramente encerrados) e em quase todas de outro. Não é um proxy confiável de "está fechada".

**Use um fato de calendário em vez de heurística**: `dueDate < hoje` ⇒ fatura conciliável/fechada. Um vencimento que já passou está necessariamente fechado, não importa o que o conector diga sobre `status`/`billClosingDate`. Efeito colateral útil: faturas *futuras* (parcelamentos já projetados por compras já feitas, com `dueDate` no futuro) caem fora desse filtro automaticamente — e o `totalAmount` delas costuma ser parcial por construção (só as parcelas já conhecidas), então nem deveriam entrar mesmo que entrassem por engano.

**Antes de adotar essa regra, meça**: `dueDate` precisa estar presente em ~100% das faturas dos conectores que você usa. Um segundo sinal de corroboração (não como regra sozinha): nenhuma fatura com `payments` preenchido deveria ter `dueDate` no futuro — se aparecer um caso desses, a leitura de datas tem algo mal entendido, vale investigar antes de confiar de novo.

### `billId` como chave de junção entre transação e fatura
Cada transação de cartão parcelada carrega um `billId` (dentro de `creditCardMetadata`) referenciando a fatura de origem. **Meça a cobertura real** (`count(*) filter (where billId is not null) group by banco`) antes de decidir se ele é confiável como chave primária de junção ou só um cross-check auxiliar — no caso testado, cobertura de 100% em todos os conectores usados, inclusive no mais pobre em outros metadados, o que tornou seguro usar como chave, não só verificação.

## 6. Fuso horário

A Pluggy devolve toda data em ISO8601 UTC. Transações de cartão costumam vir como `"...T00:00:00.000Z"` — isso é um **marcador de dia**, não um instante real (a Pluggy não sabe a hora exata da compra, só o dia). Converter isso direto pro fuso local sem cuidado desloca o dia — meia-noite UTC vira ~21h do dia anterior em GMT-3, por exemplo.

**Regra que funcionou**: hora exatamente `00:00:00.000Z` → usa a data crua (`YYYY-MM-DD`) direto, sem nenhuma conversão de fuso. Qualquer outra hora → é instante real, converter usando **fuso nomeado** (`Intl.DateTimeFormat` com `timeZone: "America/Sao_Paulo"` ou equivalente), nunca um deslocamento fixo tipo `-3h` — um offset fixo quebra silenciosamente se o país voltar a ter horário de verão (não é hipotético: o Brasil já teve e removeu). Guarde sempre o valor original UTC intocado numa coluna separada — se essa heurística estiver errada pra algum conector específico, dá pra recalcular a data local sem precisar re-sincronizar nada.

## 7. Arquitetura de sincronização

Padrão que funcionou bem numa Edge Function (Deno/Supabase, mas o padrão é genérico):

```
1. POST /auth → apiKey (gerar a cada execução, não persistir)
2. Ler a lista própria de Items (itemId + titular)
3. Para cada Item:
   Para cada conta (GET /accounts?itemId=):
     try {
       upsert conta (preservando qualquer campo de mapeamento manual seu)
       calcular "desde" = última transação salva − 30 dias (ou início de janela, se for a primeira vez)
       paginar GET /v2/transactions?accountId=&dateFrom=
         upsert em LOTE por página (não por linha, ver abaixo)
       se for conta CREDIT: paginar GET /bills?accountId=
         upsert em lote
     } catch (erroDestaConta) {
       registrar erro, seguir pra próxima conta — não abortar o run inteiro
     }
4. Gravar log da execução (status, quantidade processada, erro se houver)
```

Pontos que custaram retrabalho até acertar:

- **Upsert em lote por página, não por linha.** Centenas ou milhares de round-trips individuais ao seu banco numa sincronização só é o jeito mais fácil de estourar o tempo de execução de uma function serverless. Sintoma: o log de sincronização fica marcado como "em andamento" pra sempre, mesmo com os dados já tendo chegado corretamente no banco — parece um bug de dado quando é um bug de timeout. Trocar por um `upsert` (com `onConflict` no id externo da Pluggy) por página inteira, não por transação individual, resolve.
- **Guard contra sincronizações sobrepostas fica no servidor, não só desabilitando o botão do front-end.** Um botão desabilitado só cobre clique duplo na mesma aba já carregada — reload de página ou aba duplicada não passa por ali. Proteção real: a função recusa (HTTP 409) começar se já existir um log de execução "em andamento" recente pro mesmo titular (com uma janela de alguns minutos de tolerância, pra uma execução que travou de verdade não bloquear sincronizações futuras pra sempre).
- **Contador de "criadas vs. atualizadas" via `count` de upsert não funciona.** Um `upsert` sempre "afeta" 1 linha por registro, seja inserindo ou atualizando — não dá pra distinguir os dois casos por aí sem o truque de `xmax` do Postgres (que exige um `select` extra por linha, caro demais pra valer a pena aqui). Não finja que distingue; um contador só de "processadas" (inserido + atualizado junto) é mais honesto que um par "criadas"/"atualizadas" que mente com confiança em todo log.
- **Nunca normalizar ou inverter sinal de valor na ingestão.** Se um tipo de transação (`DEBIT`/`CREDIT`) vier com o sinal que "parece errado" pro seu modelo, registre isso como decisão documentada e ajuste na leitura, não corrija silenciosamente dentro da função de sincronização — esconder a inversão tira informação que uma fase futura (reconciliação, importação, auditoria) pode precisar pra entender um caso estranho.
- **Debug de dado real da Pluggy: só query agregada, nunca linha crua**, em qualquer lugar que persista texto (chat com IA, ticket de suporte, log público, PR description). Descrição de transação e valor são dado financeiro real de pessoa real. Sempre que precisar verificar um padrão (sinal, fuso, moeda, cobertura de campo), desenhe a verificação como contagem/booleano agrupado por banco, nunca como amostra de linhas.

## 8. Múltiplos titulares / fronteira de CPF

Planos de open finance (inclusive o gratuito) geralmente cobrem só contas nominais do titular que criou a aplicação Pluggy/API key — não é possível, no plano básico, uma única aplicação enxergar contas de duas pessoas diferentes (ex: casal, sócios) mesmo que ambas usem o mesmo produto final. **Contas da segunda pessoa não vão aparecer nunca via essa aplicação, e isso não é bug nem setup incompleto — é a fronteira do plano.**

Desenhe o modelo de dado desde o início assumindo múltiplos titulares (um registro de "aplicação Pluggy" por titular, cada um com seu próprio conjunto de credenciais/Items), mesmo que só um esteja em uso no começo — evita redesenhar depois. Se/quando o segundo titular quiser integrar: aplicação própria dele no Dashboard da Pluggy, `itemId`s dele, um novo conjunto de secrets (mesma convenção de nome com sufixo do titular da seção 2), uma linha nova na sua tabela de "aplicações" — nenhuma mudança de código deveria ser necessária além disso, se o "titular" já for um parâmetro de entrada da sua função de sincronização desde o início.

**Consequência prática pra qualquer lógica que decida confiar automaticamente no dado sincronizado** (por exemplo, "não precisa mais lançar manual, o saldo vem sozinho"): essa lógica só pode valer pra contas efetivamente cobertas por uma integração. Aplicar isso a uma conta não coberta produz confiança falsa — pior que um dado visivelmente desatualizado, porque não sobra nenhum sinal de que está errado. Registre essa exceção **antes** de implementar qualquer automação, não depois de alguém notar o problema.

## 9. O que muda por projeto (fora do escopo deste guia)

Duas coisas dependem inteiramente do seu modelo de dado, não da Pluggy — resumidas aqui só pra você saber que existem, sem o detalhe específico do projeto original:

- **Comparar/casar o que a Pluggy trouxe contra o que seu app já tinha antes da integração.** Se seu app guarda dado parecido em mais de um lugar (ex: lançamento avulso numa tabela, lançamento recorrente/parcelado em outra), qualquer comparação que olhe só um dos lugares vai superestimar "não encontrado". `purchaseDate` + `installmentNumber`/`totalInstallments` (seção 4) ajudam bastante a casar parcelas contra parcelamentos manuais existentes, se for o caso do seu domínio. Regra que vale em qualquer domínio: **nunca apague dado existente automaticamente** só porque a Pluggy não trouxe correspondência — ausência é informação (lacuna do conector, duplicata, erro de lançamento), não autorização pra deletar.
- **Ajustar um saldo/total calculado internamente pra bater com o valor real reportado pela Pluggy numa data de corte**, sem reconciliar retroativamente todo o histórico anterior. Se seu app calcula esse total somando histórico sem nenhum conceito de "ponto de partida com data", simplesmente trocar o valor base sem também cortar a soma por data conta tudo duas vezes — bug silencioso. Se esse for o seu caso, trate como mudança de código (testável) separada da mudança de dado, nessa ordem: schema aditivo sem efeito → código que respeita o corte, com teste de regressão provando que nada muda enquanto o corte não for preenchido → só então preencher os valores reais.

## 10. Disciplina de verificação (a lição mais cara)

A maior fonte de retrabalho nesta integração não foi a API da Pluggy em si — foi tratar **descrição de comportamento de API ou de código como fato antes de verificar**. Um contrato de endpoint foi especificado de memória (`/transactions` em vez de `/v2/transactions`, `from` em vez de `dateFrom`, `pageSize` que não existe no v2) e custou uma rodada inteira de debug até bater com a documentação oficial de verdade.

Prática que eliminou isso depois de virar hábito: **antes de implementar em cima de qualquer alegação sobre como uma API ou um código se comporta — sua, de outra pessoa ou de uma IA — confira a documentação oficial atual ou teste a chamada de verdade.** "Provavelmente funciona assim" não é a mesma coisa que "confirmei que funciona assim", e a diferença custa uma rodada de debug toda vez que aparece.

Outras práticas de verificação que compensaram o custo, específicas de trabalhar com a Pluggy:
- Rodar diagnóstico agregado (contagem/booleano por conector) antes de confiar que um campo vem sempre presente — cobertura real varia por banco, sempre.
- Depois de qualquer correção de bug de sincronização, re-sincronizar e conferir o número final contra a fonte oficial (extrato/fatura real do banco) — validação agregada (o total bate) **não substitui** validação de linha (um erro pequeno se esconde dentro de um total que ainda bate, se for pequeno o suficiente em relação ao todo).
- Nunca assumir que testar um conector garante o comportamento dos outros — cada achado de contrato/metadado deste guia apareceu só num subconjunto dos 5 bancos testados.
