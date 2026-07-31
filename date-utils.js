// ════════════════════════════════════════════════════════════════════════════
// date-utils.js — funções puras de data/saldo compartilhadas entre index.html
// e tests.html. Extraídas do arquivo único de propósito: testar o código de
// verdade (sem build), em vez de duplicar cópias que podem divergir.
//
// Todas as funções aqui são puras: recebem parâmetros, devolvem valor, nunca
// tocam `state` nem o DOM. Isso que as torna seguras de extrair sem mexer no
// resto da arquitetura single-file do app.
// ════════════════════════════════════════════════════════════════════════════

// Parseia uma data "YYYY-MM-DD" em horário LOCAL. new Date("YYYY-MM-DD")
// interpreta a string como UTC meia-noite, o que em fusos negativos (Brasil)
// pode "voltar" um dia — usar sempre isto no lugar de new Date(string) pra
// datas vindas do banco (extrato.data, lancamentos, etc).
function parseData(dataStr) {
  if (!dataStr) return null;
  if (dataStr instanceof Date) return dataStr;
  const [ano, mes, dia] = String(dataStr).split('-').map(Number);
  if (!ano || !mes || !dia) return null;
  return new Date(ano, mes - 1, dia);
}

// Par simétrico de parseData(): formata um Date em "YYYY-MM-DD" usando os
// getters LOCAIS (getFullYear/getMonth/getDate), nunca toISOString(). Um
// Date com hora (ex: criado às 21h30 em GMT-3) via toISOString().split('T')[0]
// grava o dia seguinte, porque toISOString() converte pra UTC antes de
// cortar a hora fora. Usar sempre isto pra gravar `data` no banco.
function formatarData(d) {
  if (!d) return '';
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

function ultimoDiaDoMes(ano, mes) {
  return new Date(ano, mes, 0).getDate();
}

// Data de vencimento de um cartão no mês informado, travando no último dia
// válido do mês (ex: vencimento configurado como dia 31 numa fatura de
// fevereiro cai no dia 28/29, não estoura pra março).
function calcularDataVencimento(ano, mes, diaVencimento) {
  const dia = Math.min(diaVencimento || 10, ultimoDiaDoMes(ano, mes));
  return new Date(ano, mes - 1, dia);
}

const _MES_MAP = {Mar:3,Abr:4,Mai:5,Jun:6,Jul:7,Ago:8,Set:9,Out:10,Nov:11,Dez:12,Jan:1,Fev:2};

function mesNomeToAnoMes(mesNome) {
  const [nome, ano] = mesNome.split('-');
  return [Number(ano), _MES_MAP[nome]];
}

// Retorna o índice (ano*12+mes) do mês de VENCIMENTO de uma compra no cartão.
// Regra: se dia <= fechamento → fatura fecha neste mês; senão → fecha no mês seguinte.
// Vencimento: se vencimento >= fechamento → mesmo mês do fechamento; senão → mês seguinte.
function getVencimentoIdx(dataStr, fechamento, vencimento) {
  const [ano, mes, dia] = dataStr.split('-').map(Number);
  const fec = fechamento || 1;
  const ven = vencimento  || 10;
  let fecMes = mes, fecAno = ano;
  if (dia > fec) { fecMes++; if (fecMes > 12) { fecMes = 1; fecAno++; } }
  let venMes = fecMes, venAno = fecAno;
  if (ven < fec)  { venMes++; if (venMes > 12) { venMes = 1; venAno++; } }
  return venAno * 12 + venMes;
}

// Vencimento (índice) da parcela N (0-based) de um lancamento parcelado/fixo via cartão
function getInstVencIdx(lan, offset, fec, ven) {
  const baseIdx = Number(lan.ano_ini) * 12 + Number(lan.mes_ini);
  const absIdx  = baseIdx + offset;
  const instMes = ((absIdx - 1) % 12) + 1;
  const instAno = (absIdx - instMes) / 12;
  const dia     = Math.min(Number(lan.dia_ini) || 1, new Date(instAno, instMes, 0).getDate());
  const dateStr = `${instAno}-${String(instMes).padStart(2,'0')}-${String(dia).padStart(2,'0')}`;
  return getVencimentoIdx(dateStr, fec, ven);
}

// Calcula saldo atual de uma conta com base em todos os dados históricos.
// Pura: recebe os arrays já carregados, não busca nada sozinha.
function calcularSaldo(conta, lancamentos, extrato, transferencias) {
  let saldo = Number(conta.saldo_inicial || 0);
  const nome = conta.nome;

  const hoje     = new Date();
  const anoHoje  = hoje.getFullYear();
  const mesHoje  = hoje.getMonth() + 1;
  const nowIdx   = anoHoje * 12 + mesHoje;

  for (const lan of lancamentos) {
    if (lan.conta_nome !== nome || !lan.ativo) continue;
    const mesIni   = Number(lan.mes_ini || 1);
    const anoIni   = Number(lan.ano_ini || anoHoje);
    const startIdx = anoIni * 12 + mesIni;
    if (startIdx > nowIdx) continue;
    const tipo  = (lan.tipo || '').toLowerCase().trim();
    const valor = Number(lan.valor || 0);

    if (tipo === 'receita única' || tipo === 'receita unica') {
      saldo += valor;
    } else if (tipo === 'receita') {
      const anoFim = lan.ano_fim ? Number(lan.ano_fim) : anoHoje;
      const mesFim = lan.mes_fim ? Number(lan.mes_fim) : mesHoje;
      const endIdx = Math.min(anoFim * 12 + mesFim, nowIdx);
      saldo += valor * Math.max(0, endIdx - startIdx + 1);
    } else if (tipo === 'fixo' || tipo === 'variável' || tipo === 'variavel') {
      const anoFim = lan.ano_fim ? Number(lan.ano_fim) : anoHoje;
      const mesFim = lan.mes_fim ? Number(lan.mes_fim) : mesHoje;
      const endIdx = Math.min(anoFim * 12 + mesFim, nowIdx);
      saldo -= valor * Math.max(0, endIdx - startIdx + 1);
    } else if (tipo === 'parcelado') {
      const parcelas = Number(lan.parcelas || 1);
      const count    = Math.min(parcelas, Math.max(0, nowIdx - startIdx + 1));
      saldo -= valor * count;
    }
  }

  for (const tx of extrato) {
    if (tx.conta_nome !== nome) continue;
    saldo += tx.tipo === 'receita' ? Number(tx.valor || 0) : -Number(tx.valor || 0);
  }

  for (const tr of transferencias) {
    const v = Number(tr.valor || 0);
    if (tr.conta_dest   === nome) saldo += v;
    if (tr.conta_origem === nome) saldo -= v;
  }

  return saldo;
}
