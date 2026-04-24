// ════════════════════════════════════════════════════════════════════════════
// FINANCE APP — Google Apps Script Backend
// Cole este código em: script.google.com → Novo projeto
// Substitua SPREADSHEET_ID pelo ID da sua planilha
// ════════════════════════════════════════════════════════════════════════════

const SPREADSHEET_ID = 'SEU_ID_AQUI'; // ← Substitua pelo ID da planilha
const SS = () => SpreadsheetApp.openById(SPREADSHEET_ID);

// Abas esperadas na planilha
const ABA_CONFIG_CONTAS    = 'Configurações';
const ABA_LANCAMENTOS      = 'Lançamentos';
const ABA_TRANSFERENCIAS   = 'Transferências';
const EXTRATO_PREFIX       = 'Extrato ';

// Linhas/colunas fixas (baseadas na planilha V6)
const CONTAS_START_ROW  = 6;   // primeira linha de conta em Configurações
const CONTAS_COL_NOME   = 2;   // col B
const CONTAS_COL_BANCO  = 3;   // col C
const CONTAS_COL_SALDO  = 4;   // col D
const CARTOES_START_ROW = 25;  // primeira linha de cartão
const CARTOES_COL_NOME  = 2;
const CARTOES_COL_BAND  = 3;
const CARTOES_COL_LIMITE= 4;
const CARTOES_COL_CONTA = 5;
const CARTOES_COL_FECH  = 6;
const CARTOES_COL_VENC  = 7;
const CAIXINHAS_START_ROW = 15;
const CAIXINHAS_COL_NOME  = 2;
const CAIXINHAS_COL_BANCO = 3;
const CAIXINHAS_COL_SALDO = 4;

// ════════════════════════════════════════════════════════════════════════════
// ENTRY POINTS
// ════════════════════════════════════════════════════════════════════════════

function doGet(e) {
  const action = e.parameter.action || '';
  let result;

  try {
    switch (action) {
      case 'ping':
        const ss2 = SS();
        result = { ok: true, version: '1.0', spreadsheetName: ss2.getName() };
        break;
      case 'getConfig':
        result = getConfig();
        break;
      case 'getResumo':
        result = getResumo();
        break;
      case 'getLancamentos':
        result = getLancamentos(e.parameter.mes);
        break;
      case 'testSaldo':
        result = testSaldo(e.parameter.conta);
        break;
      default:
        result = { error: 'Ação não reconhecida: ' + action };
    }
  } catch (err) {
    result = { error: err.message };
  }

  return ContentService
    .createTextOutput(JSON.stringify(result))
    .setMimeType(ContentService.MimeType.JSON);
}

function doPost(e) {
  let body, result;
  try {
    body = JSON.parse(e.postData.contents);
    const action = body.action || '';
    switch (action) {
      case 'addLancamento':        result = addLancamento(body);        break;
      case 'addLancamentoBulk':   result = addLancamentoBulk(body);   break;
      case 'addLancamentoFixo':   result = addLancamentoFixo(body);   break;
      case 'deleteLancamentoFixo':result = deleteLancamentoFixo(body);break;
      case 'addTransferencia':    result = addTransferencia(body);    break;
      case 'deleteLancamento':    result = deleteLancamento(body);    break;
      case 'editLancamento':     result = editLancamento(body);     break;
      case 'ajustarSaldo':       result = ajustarSaldo(body);       break;
      case 'pagarFatura':         result = pagarFatura(body);         break;
      case 'addConta':            result = addRegistro(body,'conta');   break;
      case 'deleteConta':         result = deleteRegistro(body,'conta');break;
      case 'addCartao':           result = addRegistro(body,'cartao');  break;
      case 'deleteCartao':        result = deleteRegistro(body,'cartao');break;
      case 'addCaixinha':         result = addRegistro(body,'caixinha');  break;
      case 'deleteCaixinha':      result = deleteRegistro(body,'caixinha');break;
      default:
        result = { error: 'Ação não reconhecida: ' + action };
    }
  } catch (err) {
    result = { error: err.message };
  }

  return ContentService
    .createTextOutput(JSON.stringify(result))
    .setMimeType(ContentService.MimeType.JSON);
}

// ════════════════════════════════════════════════════════════════════════════
// GET CONFIG — lê contas/caixinhas do Painel e cartões de Configurações
// ════════════════════════════════════════════════════════════════════════════

// Aba Painel — intervalos fixos
const ABA_PAINEL           = 'Painel';
const PAINEL_CONTAS_ROW    = 12; // B12:C16 — nomes e saldos das contas
const PAINEL_CONTAS_MAX    = 5;
const PAINEL_CAIXINHAS_ROW = 19; // B19:C23 — nomes e saldos das caixinhas
const PAINEL_CAIXINHAS_MAX = 5;
const PAINEL_COL_NOME      = 2;  // col B
const PAINEL_COL_SALDO     = 3;  // col C

function getConfig() {
  const ss     = SS();
  const painel = ss.getSheetByName(ABA_PAINEL);
  const cfg    = ss.getSheetByName(ABA_CONFIG_CONTAS);

  if (!painel) return { contas: [], cartoes: [], caixinhas: [], error: 'Aba Painel não encontrada' };
  if (!cfg)    return { contas: [], cartoes: [], caixinhas: [], error: 'Aba Configurações não encontrada' };

  // Contas: Painel B12:C16
  const contasVals = painel.getRange(PAINEL_CONTAS_ROW, PAINEL_COL_NOME, PAINEL_CONTAS_MAX, 2).getValues();
  const contas = contasVals
    .filter(r => String(r[0]).trim())
    .map(r => ({
      nome:  String(r[0]).trim(),
      banco: '',
      saldo: Number(r[1] || 0),
    }));

  // Caixinhas: Painel B19:C23
  const caixinhasVals = painel.getRange(PAINEL_CAIXINHAS_ROW, PAINEL_COL_NOME, PAINEL_CAIXINHAS_MAX, 2).getValues();
  const caixinhas = caixinhasVals
    .filter(r => String(r[0]).trim())
    .map(r => ({
      nome:  String(r[0]).trim(),
      banco: '',
      saldo: Number(r[1] || 0),
    }));

  // Cartões: Configurações (sem mudança)
  const MAX_CARTOES  = 15;
  const cartoesVals  = cfg.getRange(CARTOES_START_ROW, CARTOES_COL_NOME, MAX_CARTOES, 6).getValues();
  const cartoes = cartoesVals
    .filter(r => String(r[0]).trim())
    .map(r => ({
      nome:       String(r[0]).trim(),
      bandeira:   String(r[1] || '').trim(),
      limite:     Number(r[2] || 0),
      conta:      String(r[3] || '').trim(),
      fechamento: Number(r[4] || 1),
      vencimento: Number(r[5] || 1),
    }));

  return { contas, cartoes, caixinhas };
}

// ════════════════════════════════════════════════════════════════════════════
// GET RESUMO — lê Resumo Mensal e retorna array de 12 meses
// ════════════════════════════════════════════════════════════════════════════

const MESES_NOMES = ['Mar-2026','Abr-2026','Mai-2026','Jun-2026','Jul-2026','Ago-2026',
                     'Set-2026','Out-2026','Nov-2026','Dez-2026','Jan-2027','Fev-2027'];
const MESES_LABELS= ['Mar/2026','Abr/2026','Mai/2026','Jun/2026','Jul/2026','Ago/2026',
                     'Set/2026','Out/2026','Nov/2026','Dez/2026','Jan/2027','Fev/2027'];
const CARTOES_NOMES = ['Nubank JP','Latam Pass','Inter Prime','XP Visa','C6 Carbon',
                       'Mercado Pago','Magalu','Caixa','Nubank My'];
const CARTOES_FECH  = {
  'Nubank JP':9,'Latam Pass':10,'Inter Prime':6,'XP Visa':17,
  'C6 Carbon':12,'Mercado Pago':12,'Magalu':10,'Caixa':10,'Nubank My':9
};

function getResumo() {
  const ss = SS();
  const res = ss.getSheetByName('Resumo Mensal');
  if (!res) return { data: [] };

  // Rows in Resumo Mensal:
  // Row 8: Total Receitas (cols C=3 to N=14)
  // Row 15: Total Despesas
  // Row 17: Saldo do Mês
  // Row 18: Saldo Acumulado
  const ROW_RECEITA = 8;
  const ROW_DESPESA = 15;
  const ROW_SALDO   = 17;
  const ROW_ACUM    = 18;
  const COL_START   = 3; // col C

  // Faturas: aba Faturas, linhas 6..14 (9 cartões), cols C..N
  const fatSheet = ss.getSheetByName('Faturas');

  const data = MESES_NOMES.map((mes, i) => {
    const col = COL_START + i;
    const receita = Number(res.getRange(ROW_RECEITA, col).getValue() || 0);
    const despesa = Number(res.getRange(ROW_DESPESA, col).getValue() || 0);
    const saldo   = Number(res.getRange(ROW_SALDO,   col).getValue() || 0);
    const acum    = Number(res.getRange(ROW_ACUM,    col).getValue() || 0);

    // Faturas por cartão
    const faturas = {};
    if (fatSheet) {
      CARTOES_NOMES.forEach((nome, ci) => {
        const fatRow = 6 + ci;
        faturas[nome] = Number(fatSheet.getRange(fatRow, col).getValue() || 0);
      });
    }

    return { mes: MESES_LABELS[i], receita, despesa, saldo, acum, faturas };
  });

  return { data };
}

// ════════════════════════════════════════════════════════════════════════════
// GET LANÇAMENTOS — lê extrato do mês + lançamentos fixos
// ════════════════════════════════════════════════════════════════════════════

function getLancamentos(mesNome) {
  if (!mesNome) return { data: [] };
  const ss = SS();
  const extrato = ss.getSheetByName(EXTRATO_PREFIX + mesNome);
  const lancamentos = [];

  if (extrato) {
    const lastRow = extrato.getLastRow();
    if (lastRow >= 8) {
      const range = extrato.getRange(8, 2, lastRow - 7, 9); // cols B..J
      const values = range.getValues();
      values.forEach((row, i) => {
        const data = row[0]; // col B
        const desc = row[1]; // col C
        const cat  = row[2]; // col D
        const val  = row[3]; // col E
        const conta= row[4]; // col F
        const orig = row[5]; // col G
        const parc = row[6]; // col H
        const cart = row[8]; // col J
        if (!data && !desc && !val) return;
        lancamentos.push({
          id:         `ext-${mesNome}-${i}`,
          row:        8 + i,
          data:       formatDateISO(data),
          descricao:  String(desc || ''),
          categoria:  catNameToId(String(cat || '')),
          valor:      Number(val || 0),
          contaCartao:String(cart || conta || ''),
          origem:     String(orig || '').toLowerCase() === 'cartão' ? 'cartao' : 'conta',
          parcela:    String(parc || ''),
          tipo:       'despesa',
          fonte:      'extrato',
          mes:        mesNome,
        });
      });
    }
  }

  // Também inclui Lançamentos fixos do mês
  const lanSheet = ss.getSheetByName(ABA_LANCAMENTOS);
  if (lanSheet) {
    const lastRow = lanSheet.getLastRow();
    if (lastRow >= 5) {
      const range = lanSheet.getRange(5, 2, lastRow - 4, 14); // cols B..O
      const values = range.getValues();
      const [ano, mes] = mesNomeToAnoMes(mesNome);
      values.forEach((row, i) => {
        const desc     = row[0];  // B
        const cat      = row[1];  // C
        const tipo     = row[2];  // D
        const val      = row[3];  // E
        const mesIni   = row[4];  // F
        const anoIni   = row[5];  // G
        const parcelas = row[6];  // H
        const conta    = row[8];  // J
        const orig     = row[9];  // K
        const ativo    = row[11]; // M
        const mesFim   = row[12]; // N  ← término p/ 'futuros'
        const anoFim   = row[13]; // O

        if (String(ativo).toLowerCase() !== 'sim') return;

        // Respeita término definido pelo delete 'futuros'
        if (mesFim && anoFim) {
          const fimAbs = Number(anoFim) * 12 + Number(mesFim);
          const curAbs = ano * 12 + mes;
          if (curAbs >= fimAbs) return;
        }
        if (!desc && !val) return;

        const tipoLow = String(tipo).toLowerCase();
        const isReceita = tipoLow === 'receita' || tipoLow === 'receita única' || tipoLow === 'receita unica';

        // Check if this item applies to this month
        let applies = false;
        if (tipoLow === 'fixo' || tipoLow === 'variável' || tipoLow === 'receita') {
          applies = (Number(anoIni) < ano) ||
                    (Number(anoIni) === ano && Number(mesIni) <= mes);
        } else if (tipoLow === 'receita única') {
          applies = Number(anoIni) === ano && Number(mesIni) === mes;
        } else if (tipoLow === 'parcelado') {
          const diff = (ano * 12 + mes) - (Number(anoIni) * 12 + Number(mesIni));
          applies = diff >= 0 && diff < Number(parcelas);
        }

        if (!applies) return;

        const itemVal = tipoLow === 'parcelado' ? Number(val) / Number(parcelas || 1) : Number(val);

        lancamentos.push({
          id:         `lan-${i}`,
          row:        5 + i,
          data:       `${ano}-${String(mes).padStart(2,'0')}-01`,
          descricao:  String(desc || ''),
          categoria:  catNameToId(String(cat || '')),
          valor:      itemVal,
          contaCartao:String(conta || ''),
          origem:     String(orig || '').toLowerCase() === 'cartão' ? 'cartao' : 'conta',
          tipo:       isReceita ? 'receita' : 'despesa',
          fonte:      'lancamentos',
        });
      });
    }
  }

  // Sort by date desc
  lancamentos.sort((a, b) => b.data.localeCompare(a.data));
  return { data: lancamentos };
}

// ════════════════════════════════════════════════════════════════════════════
// ADD LANÇAMENTO EM LOTE
// ════════════════════════════════════════════════════════════════════════════

function addLancamentoBulk(body) {
  const items = body.items || [];
  if (!items.length) return { ok: false, error: 'Nenhum item enviado' };
  let count = 0;
  for (const item of items) {
    const r = addLancamento(item);
    if (r.ok) count++;
  }
  return { ok: true, count };
}

// ════════════════════════════════════════════════════════════════════════════
// ADD LANÇAMENTO
// ════════════════════════════════════════════════════════════════════════════

function addLancamento(body) {
  const { mes, data, descricao, categoria, valor, origem, contaCartao, parcela, totalParcelas, tipo } = body;
  if (!mes || !valor) return { ok: false, error: 'Dados incompletos' };

  if (tipo === 'transferencia') {
    return addTransferencia(body);
  }

  // Receitas pontuais vão para Lançamentos como "Receita Única" —
  // o Painel só soma receitas do Extrato se houver formula específica; para garantir
  // compatibilidade com a fórmula atual, receitas são tratadas como Lançamento.
  if (tipo === 'receita') {
    const [anoNum, mesNum] = mesNomeToAnoMes(mes);
    return addLancamentoFixo({
      descricao, categoria, tipo: 'receita', valor,
      mesIni: mesNum, anoIni: anoNum,
      conta: contaCartao, origem,
      _unica: true,
    });
  }

  const ss = SS();
  let sheet = ss.getSheetByName(EXTRATO_PREFIX + mes);

  // Cria aba se não existir
  if (!sheet) {
    sheet = ss.insertSheet(EXTRATO_PREFIX + mes);
    setupExtratoSheet(sheet, mes);
  }

  // Encontra próxima linha vazia (a partir de row 8)
  let nextRow = 8;
  while (sheet.getRange(nextRow, 2).getValue() !== '' ||
         sheet.getRange(nextRow, 3).getValue() !== '') {
    nextRow++;
    if (nextRow > 600) break;
  }

  const dataFormatada = data ? new Date(data + 'T12:00:00') : new Date();
  const origLabel = origem === 'cartao' ? 'Cartão' : 'Conta';
  const catNome = catIdToName(categoria);
  const parcelaLabel = (parcela && totalParcelas) ? `${parcela}/${totalParcelas}` : '';

  sheet.getRange(nextRow, 2).setValue(dataFormatada);
  sheet.getRange(nextRow, 3).setValue(descricao || '');
  sheet.getRange(nextRow, 4).setValue(catNome);
  sheet.getRange(nextRow, 5).setValue(Number(valor));
  sheet.getRange(nextRow, 6).setValue(contaCartao || '');
  sheet.getRange(nextRow, 7).setValue(origLabel);
  sheet.getRange(nextRow, 8).setValue(parcelaLabel ? 'Sim' : 'Não');
  sheet.getRange(nextRow, 10).setValue(origem === 'cartao' ? (contaCartao || '') : '');

  // Format date
  sheet.getRange(nextRow, 2).setNumberFormat('DD/MM/YYYY');
  sheet.getRange(nextRow, 5).setNumberFormat('R$ #,##0.00');

  // Saldo calculado pelo Painel via fórmulas — não atualizar Configurações aqui

  return { ok: true, row: nextRow };
}

// ════════════════════════════════════════════════════════════════════════════
// HELPER — localiza conta ou caixinha em Configurações
// ════════════════════════════════════════════════════════════════════════════

function encontrarConta(cfg, nome) {
  const nomeNorm = String(nome).trim().toLowerCase();
  const blocos = [
    { bloco: 'conta',    start: CONTAS_START_ROW,    max: 9,  colNome: CONTAS_COL_NOME,    colSaldo: CONTAS_COL_SALDO    },
    { bloco: 'caixinha', start: CAIXINHAS_START_ROW, max: 10, colNome: CAIXINHAS_COL_NOME, colSaldo: CAIXINHAS_COL_SALDO },
  ];
  for (const b of blocos) {
    const vals = cfg.getRange(b.start, b.colNome, b.max, 2).getValues();
    for (let i = 0; i < b.max; i++) {
      if (String(vals[i][0]).trim().toLowerCase() === nomeNorm) {
        return { bloco: b.bloco, row: b.start + i, saldo: Number(vals[i][1] || 0) };
      }
    }
  }
  return null;
}

// ════════════════════════════════════════════════════════════════════════════
// ADD TRANSFERÊNCIA
// ════════════════════════════════════════════════════════════════════════════

function addTransferencia(body) {
  const { data, descricao, valor, contaOrigem, contaDest } = body;
  if (!contaOrigem || !contaDest || !valor) return { ok: false, error: 'Dados incompletos' };
  if (contaOrigem === contaDest) return { ok: false, error: 'Origem e destino iguais' };

  const ss  = SS();
  const cfg = ss.getSheetByName(ABA_CONFIG_CONTAS);

  // Caixinhas têm Painel estático (=Configurações!D) → atualizar col D diretamente
  if (cfg) {
    const origem = encontrarConta(cfg, contaOrigem);
    const dest   = encontrarConta(cfg, contaDest);
    if (origem && origem.bloco === 'caixinha') {
      cfg.getRange(origem.row, CAIXINHAS_COL_SALDO).setValue(origem.saldo - Number(valor));
      cfg.getRange(origem.row, CAIXINHAS_COL_SALDO).setNumberFormat('R$ #,##0.00');
    }
    if (dest && dest.bloco === 'caixinha') {
      cfg.getRange(dest.row, CAIXINHAS_COL_SALDO).setValue(dest.saldo + Number(valor));
      cfg.getRange(dest.row, CAIXINHAS_COL_SALDO).setNumberFormat('R$ #,##0.00');
    }
  }

  // Registra na aba Transferências (fórmula do Painel conta lê daqui)
  const sheet = ss.getSheetByName(ABA_TRANSFERENCIAS);
  if (sheet) {
    let nextRow = 8;
    while (sheet.getRange(nextRow, 2).getValue() !== '') {
      nextRow++;
      if (nextRow > 400) break;
    }
    const dataFormatada = data ? new Date(data + 'T12:00:00') : new Date();
    sheet.getRange(nextRow, 2).setValue(dataFormatada);
    sheet.getRange(nextRow, 3).setValue(Number(valor));    // col C = valor
    sheet.getRange(nextRow, 4).setValue(descricao || 'Transferência'); // col D = descrição
    sheet.getRange(nextRow, 5).setValue(contaOrigem);      // col E = origem (débito)
    sheet.getRange(nextRow, 6).setValue(contaDest);        // col F = destino (crédito)
    sheet.getRange(nextRow, 2).setNumberFormat('DD/MM/YYYY');
    sheet.getRange(nextRow, 3).setNumberFormat('R$ #,##0.00');
  }

  return { ok: true };
}

// ════════════════════════════════════════════════════════════════════════════
// PAGAR FATURA — debita da conta vinculada ao cartão
// ════════════════════════════════════════════════════════════════════════════

function pagarFatura(body) {
  const { cartaoNome, contaNome, valor, mes, data } = body;
  if (!contaNome || !valor) return { ok: false, error: 'Dados incompletos' };
  const ss = SS();

  // Saldo calculado pelo Painel via fórmulas — não atualizar Configurações aqui

  // Registra pagamento no extrato
  let sheet = ss.getSheetByName(EXTRATO_PREFIX + mes);
  if (!sheet) { sheet = ss.insertSheet(EXTRATO_PREFIX + mes); setupExtratoSheet(sheet, mes); }
  let nextRow = 8;
  while (sheet.getRange(nextRow, 2).getValue() !== '') { nextRow++; if (nextRow > 600) break; }
  const dataF = data ? new Date(data + 'T12:00:00') : new Date();
  sheet.getRange(nextRow, 2).setValue(dataF);
  sheet.getRange(nextRow, 3).setValue('Pagamento fatura ' + (cartaoNome || ''));
  sheet.getRange(nextRow, 4).setValue('Outros');
  sheet.getRange(nextRow, 5).setValue(Number(valor));
  sheet.getRange(nextRow, 6).setValue(contaNome);
  sheet.getRange(nextRow, 7).setValue('Conta');
  sheet.getRange(nextRow, 2).setNumberFormat('DD/MM/YYYY');
  sheet.getRange(nextRow, 5).setNumberFormat('R$ #,##0.00');
  return { ok: true };
}

// ════════════════════════════════════════════════════════════════════════════
// LANÇAMENTO FIXO / RECORRENTE
// ════════════════════════════════════════════════════════════════════════════

function addLancamentoFixo(body) {
  const { descricao, categoria, tipo, valor, mesIni, anoIni, conta, origem, _unica } = body;
  if (!descricao || !valor) return { ok: false, error: 'Dados incompletos' };
  const ss    = SS();
  const sheet = ss.getSheetByName(ABA_LANCAMENTOS);
  if (!sheet) return { ok: false, error: 'Aba Lançamentos não encontrada' };

  let nextRow = 5;
  while (sheet.getRange(nextRow, 2).getValue() !== '') { nextRow++; if (nextRow > 500) break; }

  // _unica=true → lançamento pontual (não recorrente); tipo receita recorrente = 'Receita'
  const tipoLabel = tipo === 'receita' ? (_unica ? 'Receita Única' : 'Receita') : 'Fixo';
  const origLabel = origem === 'cartao' ? 'Cartão' : 'Conta';
  sheet.getRange(nextRow, 2).setValue(descricao);
  sheet.getRange(nextRow, 3).setValue(catIdToName(categoria || 'outros'));
  sheet.getRange(nextRow, 4).setValue(tipoLabel);
  sheet.getRange(nextRow, 5).setValue(Number(valor));
  sheet.getRange(nextRow, 6).setValue(Number(mesIni  || 1));
  sheet.getRange(nextRow, 7).setValue(Number(anoIni  || new Date().getFullYear()));
  sheet.getRange(nextRow, 8).setValue('');   // parcelas
  sheet.getRange(nextRow, 9).setValue('');
  sheet.getRange(nextRow, 10).setValue(conta || '');
  sheet.getRange(nextRow, 11).setValue(origLabel);
  sheet.getRange(nextRow, 13).setValue('Sim'); // ativo
  sheet.getRange(nextRow, 5).setNumberFormat('R$ #,##0.00');
  return { ok: true, row: nextRow };
}

function deleteLancamentoFixo(body) {
  // escopo: 'todos' | 'futuros' | 'atual'
  // Para 'atual': tratado no frontend via localStorage de exclusões
  // Para 'futuros': registra mesTermino/anoTermino na col N/O
  // Para 'todos': marca ativo = Não
  const { row, escopo, mesAtual, anoAtual } = body;
  if (!row) return { ok: false };
  const ss    = SS();
  const sheet = ss.getSheetByName(ABA_LANCAMENTOS);
  if (!sheet) return { ok: false };

  if (escopo === 'todos') {
    sheet.getRange(row, 13).setValue('Não'); // col M = ativo
  } else if (escopo === 'futuros') {
    // Guarda mês/ano de término nas cols N(14) e O(15)
    sheet.getRange(row, 14).setValue(Number(mesAtual));
    sheet.getRange(row, 15).setValue(Number(anoAtual));
  }
  // 'atual' é tratado via exclusões no localStorage (frontend)
  return { ok: true };
}

// ════════════════════════════════════════════════════════════════════════════
// CRUD CONTAS / CARTÕES / CAIXINHAS
// ════════════════════════════════════════════════════════════════════════════

const REGISTRO_META = {
  conta:    { start: CONTAS_START_ROW,    max: 10, cols: ['nome','banco','saldo'],   colNome: CONTAS_COL_NOME    },
  caixinha: { start: CAIXINHAS_START_ROW, max: 10, cols: ['nome','banco','saldo'],   colNome: CAIXINHAS_COL_NOME },
  cartao:   { start: CARTOES_START_ROW,   max: 15, cols: ['nome','bandeira','limite','conta','fechamento','vencimento'], colNome: CARTOES_COL_NOME },
};

function addRegistro(body, tipo) {
  const meta  = REGISTRO_META[tipo];
  const ss    = SS();
  const cfg   = ss.getSheetByName(ABA_CONFIG_CONTAS);
  if (!cfg || !meta) return { ok: false };

  // Acha próxima linha vazia
  let nextRow = meta.start;
  while (nextRow < meta.start + meta.max) {
    if (!cfg.getRange(nextRow, meta.colNome).getValue()) break;
    nextRow++;
  }
  if (nextRow >= meta.start + meta.max) return { ok: false, error: 'Limite atingido' };

  if (tipo === 'conta' || tipo === 'caixinha') {
    cfg.getRange(nextRow, CONTAS_COL_NOME ).setValue(body.nome  || '');
    cfg.getRange(nextRow, CONTAS_COL_BANCO).setValue(body.banco || '');
    cfg.getRange(nextRow, CONTAS_COL_SALDO).setValue(Number(body.saldo || 0));
    cfg.getRange(nextRow, CONTAS_COL_SALDO).setNumberFormat('R$ #,##0.00');
  } else if (tipo === 'cartao') {
    cfg.getRange(nextRow, CARTOES_COL_NOME ).setValue(body.nome      || '');
    cfg.getRange(nextRow, CARTOES_COL_BAND ).setValue(body.bandeira  || '');
    cfg.getRange(nextRow, CARTOES_COL_LIMITE).setValue(Number(body.limite || 0));
    cfg.getRange(nextRow, CARTOES_COL_CONTA ).setValue(body.conta     || '');
    cfg.getRange(nextRow, CARTOES_COL_FECH  ).setValue(Number(body.fechamento || 1));
    cfg.getRange(nextRow, CARTOES_COL_VENC  ).setValue(Number(body.vencimento || 1));
    cfg.getRange(nextRow, CARTOES_COL_LIMITE).setNumberFormat('R$ #,##0.00');
  }
  return { ok: true, row: nextRow };
}

function deleteRegistro(body, tipo) {
  const meta = REGISTRO_META[tipo];
  const ss   = SS();
  const cfg  = ss.getSheetByName(ABA_CONFIG_CONTAS);
  if (!cfg || !meta) return { ok: false };
  for (let r = meta.start; r < meta.start + meta.max; r++) {
    if (String(cfg.getRange(r, meta.colNome).getValue()) === String(body.nome)) {
      const numCols = tipo === 'cartao' ? 6 : 3;
      cfg.getRange(r, meta.colNome, 1, numCols).clearContent();
      return { ok: true };
    }
  }
  return { ok: false, error: 'Não encontrado' };
}

// ════════════════════════════════════════════════════════════════════════════
// DELETE LANÇAMENTO
// ════════════════════════════════════════════════════════════════════════════

function deleteLancamento(body) {
  const { mes, row, origem, contaCartao, valor, tipo } = body;
  if (!mes || !row) return { ok: false };
  const ss    = SS();
  const sheet = ss.getSheetByName(EXTRATO_PREFIX + mes);
  if (!sheet) return { ok: false };
  sheet.getRange(row, 2, 1, 9).clearContent();

  // Saldo calculado pelo Painel via fórmulas — não reverter em Configurações

  return { ok: true };
}

function editLancamento(body) {
  const { mes, row, data, descricao, categoria, valor, origem, contaCartao, tipo,
          oldValor, oldOrigem, oldContaCartao, oldTipo } = body;
  if (!mes || !row) return { ok: false };
  const ss    = SS();
  const sheet = ss.getSheetByName(EXTRATO_PREFIX + mes);
  if (!sheet) return { ok: false };

  const dataF    = data ? new Date(data + 'T12:00:00') : new Date();
  const origLabel= origem === 'cartao' ? 'Cartão' : 'Conta';
  sheet.getRange(row, 2).setValue(dataF);
  sheet.getRange(row, 3).setValue(descricao || '');
  sheet.getRange(row, 4).setValue(catIdToName(categoria || 'outros'));
  sheet.getRange(row, 5).setValue(Number(valor));
  sheet.getRange(row, 6).setValue(contaCartao || '');
  sheet.getRange(row, 7).setValue(origLabel);
  sheet.getRange(row, 10).setValue(origem === 'cartao' ? (contaCartao || '') : '');
  sheet.getRange(row, 2).setNumberFormat('DD/MM/YYYY');
  sheet.getRange(row, 5).setNumberFormat('R$ #,##0.00');

  // Saldo calculado pelo Painel via fórmulas — não atualizar Configurações aqui

  return { ok: true };
}

function ajustarSaldo(body) {
  const { contaNome, novoSaldo, saldoAtual, mes, tipoConta } = body;
  if (!contaNome || novoSaldo === undefined) return { ok: false };
  const ss    = SS();
  const cfg   = ss.getSheetByName(ABA_CONFIG_CONTAS);
  const delta = Number(novoSaldo) - Number(saldoAtual);
  if (!delta) return { ok: true }; // sem mudança

  if (tipoConta === 'caixinha') {
    // Caixinha: Painel lê Configurações D diretamente → atualizar lá
    const found = cfg ? encontrarConta(cfg, contaNome) : null;
    if (found && cfg) {
      cfg.getRange(found.row, CAIXINHAS_COL_SALDO).setValue(Number(novoSaldo));
      cfg.getRange(found.row, CAIXINHAS_COL_SALDO).setNumberFormat('R$ #,##0.00');
    }
    return { ok: true, delta };
  } else {
    // Conta: Painel lê Lançamentos (receitas) e Extrato (despesas)
    // delta > 0 → Receita Única em Lançamentos (Painel soma)
    // delta < 0 → Despesa no Extrato (Painel subtrai)
    const mesNome = mes || MESES_NOMES[0];
    const [anoNum, mesNum] = mesNomeToAnoMes(mesNome);
    const descAjuste = 'Ajuste de saldo – ' + contaNome;

    if (delta > 0) {
      addLancamentoFixo({
        descricao: descAjuste, categoria: 'outros', tipo: 'receita',
        valor: delta, mesIni: mesNum, anoIni: anoNum,
        conta: contaNome, origem: 'conta', _unica: true,
      });
    } else {
      let sheet = ss.getSheetByName(EXTRATO_PREFIX + mesNome);
      if (!sheet) { sheet = ss.insertSheet(EXTRATO_PREFIX + mesNome); setupExtratoSheet(sheet, mesNome); }
      let nextRow = 8;
      while (sheet.getRange(nextRow, 2).getValue() !== '') { nextRow++; if (nextRow > 600) break; }
      sheet.getRange(nextRow, 2).setValue(new Date());
      sheet.getRange(nextRow, 3).setValue(descAjuste);
      sheet.getRange(nextRow, 4).setValue('Outros');
      sheet.getRange(nextRow, 5).setValue(Math.abs(delta));
      sheet.getRange(nextRow, 6).setValue(contaNome);
      sheet.getRange(nextRow, 7).setValue('Conta');
      sheet.getRange(nextRow, 2).setNumberFormat('DD/MM/YYYY');
      sheet.getRange(nextRow, 5).setNumberFormat('R$ #,##0.00');
    }
  }
  return { ok: true, delta };
}

// ════════════════════════════════════════════════════════════════════════════
// SETUP NOVA ABA EXTRATO
// ════════════════════════════════════════════════════════════════════════════

function setupExtratoSheet(sheet, mesNome) {
  sheet.getRange(1, 2).setValue('📋  EXTRATO – ' + mesNome.toUpperCase().replace('-',' '));
  sheet.getRange(7, 2).setValue('Data');
  sheet.getRange(7, 3).setValue('Descrição');
  sheet.getRange(7, 4).setValue('Categoria');
  sheet.getRange(7, 5).setValue('Valor (R$)');
  sheet.getRange(7, 6).setValue('Conta / Cartão');
  sheet.getRange(7, 7).setValue('Origem');
  sheet.getRange(7, 8).setValue('Parcela?');
  sheet.getRange(7, 10).setValue('Cartão (se cartão)');
}

// ════════════════════════════════════════════════════════════════════════════
// HELPERS
// ════════════════════════════════════════════════════════════════════════════

function mesNomeToAnoMes(mesNome) {
  const map = {
    'Mar-2026':[2026,3],'Abr-2026':[2026,4],'Mai-2026':[2026,5],'Jun-2026':[2026,6],
    'Jul-2026':[2026,7],'Ago-2026':[2026,8],'Set-2026':[2026,9],'Out-2026':[2026,10],
    'Nov-2026':[2026,11],'Dez-2026':[2026,12],'Jan-2027':[2027,1],'Fev-2027':[2027,2],
  };
  return map[mesNome] || [2026,3];
}

function formatDateISO(date) {
  if (!date) return '';
  if (date instanceof Date) {
    const y = date.getFullYear();
    const m = String(date.getMonth()+1).padStart(2,'0');
    const d = String(date.getDate()).padStart(2,'0');
    return `${y}-${m}-${d}`;
  }
  return String(date);
}

const CAT_ID_MAP = {
  'alimentação':'alimentacao','moradia':'moradia','transporte':'transporte',
  'saúde':'saude','educação':'educacao','entretenimento':'lazer','lazer':'lazer',
  'comunicação':'comunicacao','vestuário':'vestuario','eletrônicos':'eletronicos',
  'viagem':'viagem','pets':'pets','outros':'outros','receita':'salario',
  'receita extra':'freelance','bônus':'bonus',
};
const CAT_NAME_MAP = {
  'alimentacao':'Alimentação','moradia':'Moradia','transporte':'Transporte',
  'saude':'Saúde','educacao':'Educação','lazer':'Lazer','comunicacao':'Comunicação',
  'vestuario':'Vestuário','eletronicos':'Eletrônicos','viagem':'Viagem',
  'pets':'Pets','outros':'Outros','salario':'Receita','freelance':'Receita Extra','bonus':'Bônus',
};

function catNameToId(name) { return CAT_ID_MAP[name.toLowerCase()] || 'outros'; }
function catIdToName(id) { return CAT_NAME_MAP[id] || 'Outros'; }

// Diagnóstico: ?action=testSaldo&conta=NomeDaConta
// Retorna o saldo atual e confirma se a conta foi encontrada
function testSaldo(nomeConta) {
  const ss  = SS();
  const cfg = ss.getSheetByName(ABA_CONFIG_CONTAS);
  if (!cfg) return { error: 'Aba Configurações não encontrada' };
  const config = getConfig();
  const todasContas = [...config.contas, ...config.caixinhas];
  if (nomeConta) {
    const c = todasContas.find(c => c.nome.trim().toLowerCase() === String(nomeConta).trim().toLowerCase());
    return c
      ? { encontrada: true, nome: c.nome, saldo: c.saldo }
      : { encontrada: false, nomeBuscado: nomeConta, contasDisponiveis: todasContas.map(c=>c.nome) };
  }
  return { contas: config.contas, caixinhas: config.caixinhas };
}
