// supabase/functions/pluggy-sync/index.ts
//
// FASE 1 — espelho somente-leitura.
// Esta função NUNCA escreve em extrato / lancamentos / transferencias.
// Ela só popula as tabelas pluggy_* e o log de sincronização.
//
// Deploy:  supabase functions deploy pluggy-sync
// Secrets: PLUGGY_CLIENT_ID_<APELIDO>, PLUGGY_CLIENT_SECRET_<APELIDO>
//          (SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY já existem por padrão)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const PLUGGY = "https://api.pluggy.ai";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
};

// ---------------------------------------------------------------------------
// Datas: Pluggy devolve ISO8601 em UTC.
//
// ARMADILHA: muitas transações vêm como "2026-03-05T00:00:00.000Z", que é um
// marcador de dia, não um instante real. Converter isso para GMT-3 daria
// 04/03 às 21h — ou seja, o dia ERRADO, e justamente o mesmo off-by-one que
// acabamos de eliminar do app.
//
// Regra adotada: se a hora for exatamente 00:00:00.000Z, trata-se como
// data pura e usamos o YYYY-MM-DD cru. Caso contrário, é instante real e
// convertemos para o horário de Brasília usando a timezone NOMEADA
// ('America/Sao_Paulo'), não um deslocamento fixo de -3h. O Brasil não tem
// horário de verão desde 2019, então hoje os dois dão o mesmo resultado —
// mas um -3h fixo quebraria silenciosamente (transação no dia errado) se
// o horário de verão voltar; a timezone nomeada segue a regra vigente
// automaticamente. Confirmado nos 5 bancos que os dois métodos batem
// (ver Decisões no CLAUDE.md).
//
// Guardamos SEMPRE o valor original em data_utc — se a heurística estiver
// errada para algum conector, dá para recalcular tudo sem re-sincronizar.
// ---------------------------------------------------------------------------
const _formatadorDataBR = new Intl.DateTimeFormat("en-CA", {
  timeZone: "America/Sao_Paulo",
  year: "numeric", month: "2-digit", day: "2-digit",
});

function paraDataLocal(iso: string): string {
  if (/T00:00:00(\.000)?Z$/.test(iso)) return iso.slice(0, 10);
  // locale en-CA formata datas como YYYY-MM-DD nativamente
  return _formatadorDataBR.format(new Date(iso));
}

async function pluggyAuth(clientId: string, clientSecret: string) {
  const r = await fetch(`${PLUGGY}/auth`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ clientId, clientSecret }),
  });
  if (!r.ok) throw new Error(`auth Pluggy falhou: ${r.status} ${await r.text()}`);
  return (await r.json()).apiKey as string; // expira em 2h, nunca persistir
}

async function get(url: string, apiKey: string) {
  const r = await fetch(url, { headers: { "X-API-KEY": apiKey } });
  if (!r.ok) throw new Error(`${url} → ${r.status} ${await r.text()}`);
  return r.json();
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const url = Deno.env.get("SUPABASE_URL")!;
  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  // --- 1. exige sessão válida do app (mesma regra da RLS) -------------------
  const authHeader = req.headers.get("Authorization") ?? "";
  const asUser = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user } } = await asUser.auth.getUser();
  if (!user) {
    return new Response(JSON.stringify({ erro: "não autenticado" }), {
      status: 401,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }

  const { apelido = "jp" } = await req.json().catch(() => ({}));

  const { data: app } = await admin
    .from("pluggy_apps").select("*").eq("apelido", apelido).single();
  if (!app) {
    return new Response(JSON.stringify({ erro: `app '${apelido}' não existe` }), {
      status: 400,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }

  const suf = apelido.toUpperCase();
  const clientId = Deno.env.get(`PLUGGY_CLIENT_ID_${suf}`);
  const clientSecret = Deno.env.get(`PLUGGY_CLIENT_SECRET_${suf}`);
  if (!clientId || !clientSecret) {
    return new Response(
      JSON.stringify({ erro: `secrets PLUGGY_*_${suf} ausentes` }),
      { status: 500, headers: { ...cors, "Content-Type": "application/json" } },
    );
  }

  // Guarda contra sincronizações sobrepostas. O botão no front já fica
  // desabilitado durante a chamada, mas isso só cobre clique duplo na MESMA
  // aba — reload de página ou aba duplicada durante uma sincronização em
  // andamento não passa por ali. Recusa iniciar se já existir um log sem
  // status (em andamento) recente pra esse app; 5 min de janela porque uma
  // execução que travou de verdade (crash, deploy no meio) não deve travar
  // sincronizações futuras pra sempre.
  const { data: emAndamento } = await admin
    .from("pluggy_sync_log")
    .select("id, iniciado_em")
    .eq("app_id", app.id)
    .is("status", null)
    .gte("iniciado_em", new Date(Date.now() - 5 * 60 * 1000).toISOString())
    .limit(1)
    .maybeSingle();
  if (emAndamento) {
    return new Response(
      JSON.stringify({ erro: `já existe uma sincronização em andamento desde ${emAndamento.iniciado_em}` }),
      { status: 409, headers: { ...cors, "Content-Type": "application/json" } },
    );
  }

  const { data: log } = await admin
    .from("pluggy_sync_log").insert({ app_id: app.id }).select().single();

  // `atualizadas` fica sempre 0 de propósito (ver comentário mais abaixo,
  // onde `processadas` é somado) — não dá pra distinguir insert de update
  // via upsert em lote sem o truque de xmax, então não fingimos que
  // distinguimos. `processadas` é gravado na coluna `criadas` do log por
  // compatibilidade com o schema existente (ver Decisões no CLAUDE.md).
  let processadas = 0;
  const atualizadas = 0;

  try {
    const apiKey = await pluggyAuth(clientId, clientSecret);

    // --- 2. items vêm da NOSSA base ---------------------------------------
    // A Pluggy não oferece endpoint para listar items ("por razões de
    // segurança"); cada cliente guarda os itemId. Foram copiados à mão do
    // Dashboard para pluggy_items.
    const { data: items } = await admin
      .from("pluggy_items").select("*").eq("app_id", app.id);

    for (const item of items ?? []) {
      const contas = await get(
        `${PLUGGY}/accounts?itemId=${item.pluggy_item_id}`, apiKey);

      for (const c of contas.results ?? []) {
        // preserva o mapeamento manual (conta_nome/cartao_nome/ignorar):
        // onConflict atualiza só os campos vindos da Pluggy.
        await admin.from("pluggy_contas").upsert({
          app_id: app.id,
          pluggy_account_id: c.id,
          pluggy_item_id: item.pluggy_item_id,
          nome: c.name,
          tipo: c.type,
          subtipo: c.subtype,
          numero: c.number,
          saldo: c.balance,
          saldo_atualizado_em: new Date().toISOString(),
        }, { onConflict: "pluggy_account_id" });

        // --- 3. transações, incremental por data ---------------------------
        const { data: ultima } = await admin
          .from("pluggy_transacoes")
          .select("data").eq("pluggy_account_id", c.id)
          .order("data", { ascending: false }).limit(1).maybeSingle();

        // 30 dias de sobreposição: PENDING vira POSTED e valores mudam
        // retroativamente. Sem essa folga, transação atualizada nunca é revista.
        const desde = ultima
          ? new Date(new Date(ultima.data).getTime() - 30 * 864e5)
            .toISOString().slice(0, 10)
          : new Date(Date.now() - 365 * 864e5).toISOString().slice(0, 10);

        // /transactions (sem v2) foi descontinuado pela Pluggy (HTTP 410) em
        // favor de /v2/transactions com paginação por cursor. O parâmetro de
        // data também mudou de `from` para `dateFrom`. `pageSize` não é
        // aceito no v2 (400 "property pageSize should not exist") — o
        // tamanho de página parece ser fixo (500) do lado da Pluggy agora.
        //
        // `next` é INCONSISTENTE entre conectores: no Nubank veio como URL
        // completa; em outro (XP/Mercado Pago/Inter, ainda não isolado qual)
        // veio só como fragmento de query ("?accountId=...&after=..."), o
        // que quebrava com "Invalid URL" ao tentar usar direto como URL.
        // O próprio SDK oficial (pluggy-node) já lida com essa ambiguidade
        // via `new URL(next, baseUrl)`, que resolve tanto absoluta quanto
        // relativa — mesma solução aqui, usando o endpoint como base pra
        // preservar o path (`/v2/transactions`) quando next é só a query.
        const baseTransacoes = `${PLUGGY}/v2/transactions`;
        let proxima: string | null =
          `${baseTransacoes}?accountId=${c.id}&dateFrom=${desde}`;

        while (proxima) {
          const pg = await get(proxima, apiKey);

          // Upsert em LOTE (uma chamada por página, não uma por transação).
          // Antes eram ~1.858 round-trips numa sincronização só (5 bancos) —
          // motivo mais provável do timeout que deixava pluggy_sync_log com
          // status null. Agora são ~10 (uma por página de resultados).
          const lote = (pg.results ?? []).map((t: any) => ({
            pluggy_id: t.id,
            pluggy_account_id: c.id,
            app_id: app.id,
            data: paraDataLocal(t.date),
            data_utc: t.date,
            descricao: t.description,
            descricao_raw: t.descriptionRaw,
            valor: t.amount, // convenção crua da Pluggy — não normalizar
            tipo: t.type,
            status: t.status,
            metadata: {
              creditCardMetadata: t.creditCardMetadata ?? null,
              paymentData: t.paymentData ?? null,
              merchant: t.merchant ?? null,
              category: t.category ?? null,
              operationType: t.operationType ?? null,
            },
            sincronizado_em: new Date().toISOString(),
          }));

          if (lote.length) {
            const { error } = await admin
              .from("pluggy_transacoes")
              .upsert(lote, { onConflict: "pluggy_id" });
            if (error) throw error;
            // upsert sempre "afeta" 1 linha por registro, seja insert ou
            // update — count===1 não distingue os dois (bug real: fazia
            // `atualizadas` nunca incrementar). Sem o truque de xmax não dá
            // pra separar barato via PostgREST, então só contamos o total
            // processado — ver Decisões no CLAUDE.md.
            processadas += lote.length;
          }

          // new URL(next, base) resolve tanto next absoluto quanto relativo
          // (só query string) — ver comentário acima sobre a inconsistência
          // entre conectores.
          proxima = pg.next ? new URL(pg.next, baseTransacoes).href : null;
        }
      }
    }

    await admin.from("pluggy_sync_log").update({
      terminado_em: new Date().toISOString(),
      status: "ok", criadas: processadas, atualizadas,
    }).eq("id", log!.id);

    return new Response(JSON.stringify({ ok: true, processadas }), {
      headers: { ...cors, "Content-Type": "application/json" },
    });

  } catch (e) {
    await admin.from("pluggy_sync_log").update({
      terminado_em: new Date().toISOString(),
      status: "erro", erro: String(e), criadas: processadas, atualizadas,
    }).eq("id", log!.id);

    return new Response(JSON.stringify({ ok: false, erro: String(e) }), {
      status: 500,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }
});
