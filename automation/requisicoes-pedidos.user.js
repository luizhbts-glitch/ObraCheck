// ==UserScript==
// @name         Requisições → Painel de Pedidos + PDFs de OC (sincronização unificada)
// @namespace    obra-check-luiz
// @version      2.0.0
// @description  Botão "Integrar pedido" pra levar a requisição atual pro pedidos-arsen.json sob demanda. Botão "Sincronizar com L7" atualiza status/cotação/OC/fornecedor/datas de tudo, cria as requisições novas, e já baixa o PDF de qualquer OC nova ou com status mudado. Roda sozinho às 7:20, 11:20 e 15:00 com a aba aberta.
// @match        https://build-manager-api-snriv.ondigitalocean.app/*
// @run-at       document-start
// @grant        none
// ==/UserScript==

(function () {
  'use strict';

  const API = 'https://build-manager-api-snriv.ondigitalocean.app/api/v1';
  const HOME_URL = 'https://build-manager-api-snriv.ondigitalocean.app';
  const FILE_NAME = 'pedidos-arsen.json';

  function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }

  // ---- Captura do token Bearer + memória passiva da última requisição vista (sem disparar nada sozinho) ----
  let authToken = null;
  let lastSeenRequestId = null;

  function noteIfSingleRequest(url, responseText) {
    if (!/\/purchaserequests(\/\d+)?(\?.*)?$/.test(url || '')) return;
    try {
      const data = JSON.parse(responseText);
      if (data && data.id && !data.results) lastSeenRequestId = data.id;
    } catch (e) { /* não era um objeto de requisição único */ }
  }

  const origOpen = XMLHttpRequest.prototype.open;
  XMLHttpRequest.prototype.open = function (method, url) {
    this.__method = method;
    this.__url = url;
    return origOpen.apply(this, arguments);
  };

  const origSetHeader = XMLHttpRequest.prototype.setRequestHeader;
  XMLHttpRequest.prototype.setRequestHeader = function (name, value) {
    if (name.toLowerCase() === 'authorization') authToken = value;
    return origSetHeader.apply(this, arguments);
  };

  const origSend = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.send = function (body) {
    this.addEventListener('load', function () {
      if (this.status < 200 || this.status >= 300) return;
      noteIfSingleRequest(this.__url, this.responseText);
    });
    return origSend.apply(this, arguments);
  };

  const origFetch = window.fetch;
  window.fetch = function (...args) {
    const [, opts] = args;
    if (opts && opts.headers) {
      const h = opts.headers;
      const auth = h instanceof Headers ? h.get('authorization') : (h.Authorization || h.authorization);
      if (auth) authToken = auth;
    }
    return origFetch.apply(this, args);
  };

  function waitForToken(timeoutMs = 8000) {
    return new Promise((resolve, reject) => {
      if (authToken) return resolve();
      const start = Date.now();
      const iv = setInterval(() => {
        if (authToken) { clearInterval(iv); resolve(); }
        else if (Date.now() - start > timeoutMs) { clearInterval(iv); reject(new Error('Token não capturado a tempo.')); }
      }, 100);
    });
  }

  function api(path, opts = {}) {
    if (!authToken) throw new Error('Token ainda não capturado.');
    return origFetch(API + path, {
      ...opts,
      headers: { 'Accept': 'application/json', 'Content-Type': 'application/json', 'Authorization': authToken, ...(opts.headers || {}) },
    }).then(async (r) => {
      const text = await r.text();
      const data = text ? JSON.parse(text) : null;
      if (!r.ok) throw new Error((data && data.message) || `Erro HTTP ${r.status}`);
      return data;
    });
  }

  // ---- IndexedDB compartilhado pra guardar handles de arquivo/pasta (File System Access API) ----
  function idbHandles(mode) {
    return new Promise((resolve, reject) => {
      const req = indexedDB.open('requisicoes-pedidos-fs', 1);
      req.onupgradeneeded = () => req.result.createObjectStore('handles');
      req.onsuccess = () => resolve(req.result.transaction('handles', mode).objectStore('handles'));
      req.onerror = () => reject(req.error);
    });
  }
  async function idbGet(key) {
    const store = await idbHandles('readonly');
    return new Promise((resolve, reject) => {
      const r = store.get(key);
      r.onsuccess = () => resolve(r.result);
      r.onerror = () => reject(r.error);
    });
  }
  async function idbSet(key, value) {
    const store = await idbHandles('readwrite');
    return new Promise((resolve, reject) => {
      const r = store.put(value, key);
      r.onsuccess = () => resolve();
      r.onerror = () => reject(r.error);
    });
  }

  // ---- Arquivo pedidos-arsen.json ----
  let fileHandle = null;

  async function tryReconnectSilently() {
    if (!window.showOpenFilePicker) return false;
    try {
      const saved = await idbGet('fileHandle');
      if (!saved) return false;
      fileHandle = saved;
      return (await fileHandle.queryPermission({ mode: 'readwrite' })) === 'granted';
    } catch (e) { return false; }
  }

  // Usa showOpenFilePicker (não showSaveFilePicker): este script sempre espera um arquivo
  // já existente pra ler e regravar — nunca deve "criar/substituir" nada sozinho.
  async function connectFile() {
    if (!window.showOpenFilePicker) {
      alert('Seu navegador não suporta acesso a arquivos locais. Use Chrome ou Edge.');
      return false;
    }
    try {
      if (fileHandle) {
        const perm = await fileHandle.requestPermission({ mode: 'readwrite' });
        if (perm === 'granted') return true;
      }
      const [handle] = await window.showOpenFilePicker({
        types: [{ description: 'JSON', accept: { 'application/json': ['.json'] } }],
        excludeAcceptAllOption: false,
      });
      fileHandle = handle;
      await idbSet('fileHandle', fileHandle);
      return true;
    } catch (e) {
      console.error('Falha ao conectar arquivo de pedidos', e);
      return false;
    }
  }

  async function readFileData() {
    const read = async () => {
      const file = await fileHandle.getFile();
      return (await file.text()).trim();
    };
    let text = await read();
    if (!text) {
      // pode ser uma trava momentânea de sincronização (ex: Google Drive) — tenta de novo antes de concluir que está vazio
      await sleep(400);
      text = await read();
    }
    return text ? JSON.parse(text) : null;
  }
  async function writeFileData(obj) {
    const writable = await fileHandle.createWritable();
    await writable.write(JSON.stringify(obj, null, 1));
    await writable.close();
  }

  // ---- Integração sob demanda: pega a requisição atual e faz merge no arquivo de pedidos ----
  function getCurrentRequestId() {
    const m = location.pathname.match(/\/requisicoes\/(\d+)/);
    if (m) return Number(m[1]);
    return lastSeenRequestId;
  }

  async function integrateRequest(id) {
    if (!fileHandle) {
      showToast(`Requisição #${id}: arquivo de pedidos não está conectado.`, true);
      return;
    }
    try {
      const record = await api(`/purchaserequests/${id}?expand[]=items&expand[]=items.product&expand[]=costCenter&expand[]=costCenter.building`);
      await mergeIntoPedidos(record);
      showToast(`Requisição #${id} sincronizada com o painel de pedidos.`);
    } catch (e) {
      console.error('Falha ao sincronizar requisição', e);
      showToast(`Falha ao sincronizar requisição #${id}: ${e.message}`, true);
    }
  }

  async function mergeIntoPedidos(record) {
    const stored = await readFileData();
    if (!stored) {
      // Leitura vazia num arquivo que deveria já ter pedidos: nunca segue como se fosse
      // "começar do zero" — isso é o que causou perda de dados antes. Aborta e avisa.
      throw new Error('O arquivo conectado leu vazio. Por segurança, nada foi gravado — confira o arquivo e tente de novo.');
    }
    const pedidos = stored.pedidos || [];
    const items = record.items || [];

    let pedido = pedidos.find((p) => String(p.req) === String(record.id));
    if (!pedido) {
      const firstItem = items[0];
      pedido = {
        id: 'req-' + record.id,
        req: String(record.id),
        categoria: (record.referenceCategoryName || '').trim(),
        material: firstItem && firstItem.product ? firstItem.product.name : '',
        descricao: record.observation ||
          items.map((it) => `${it.product ? it.product.name : ''}${it.product && it.product.description ? ' - ' + it.product.description : ''} x${it.quantity}`).join('; '),
        dataPedido: record.createdAt ? record.createdAt.slice(0, 10) : '',
        aprovacao: record.approvedAt ? record.approvedAt.slice(0, 10) : '',
        itens: [],
      };
      pedidos.push(pedido);
    }

    pedido.itens = pedido.itens || [];
    const existingProductIds = new Set(pedido.itens.map((it) => it.productId).filter((v) => v != null));
    items.forEach((it) => {
      if (existingProductIds.has(it.productId)) return;
      pedido.itens.push({
        id: 'item-' + Date.now() + '-' + Math.random().toString(36).slice(2, 6),
        productId: it.productId,
        material: it.product ? it.product.name : '',
        quantidade: String(it.quantity ?? ''),
        unidade: it.product ? it.product.unit : '',
        fornecedor: '', cotacaoId: '', ocId: '', compra: '', chegou: '', problema: false, obs: '',
      });
    });

    await writeFileData({ pedidos, categorias: stored.categorias || [] });
  }

  // ---- Sincronização completa: atualiza status/cotação/OC/fornecedor/datas de tudo
  // e cria as requisições novas que ainda não estão no arquivo. ----
  const SYNC_BUILDING_NAME = 'Arsen Sabiá';
  const SYNC_SINCE = '2025-03-16'; // data da OC mais antiga do Luiz — base sólida, sem cortar pedidos ainda ativos

  // Status da requisição/OC (fonte da verdade da L7) -> status usado no painel.
  // OC tem status próprio: "partial" (entrega parcial), "approved" (aprovada, aguardando
  // entrega), e baseStatus "closed" quando totalmente finalizada.
  function determineApiStatus(p, oc) {
    if (oc) {
      if (oc.status === 'partial') return 'Chegada parcial';
      if (oc.baseStatus === 'closed') return 'Finalizado';
      return 'OC Emitida';
    }
    // Requisição pode ficar "closed" mesmo sem OC vinculada (fluxo antigo/manual) — trata como finalizada.
    if (p.status === 'closed' || p.baseStatus === 'closed') return 'Finalizado';
    if (p.status === 'quoting') return 'Cotação';
    return 'Aprovação';
  }

  async function mapWithConcurrency(items, limit, fn) {
    const results = new Array(items.length);
    let next = 0;
    async function worker() {
      while (next < items.length) {
        const i = next++;
        results[i] = await fn(items[i], i);
      }
    }
    await Promise.all(Array.from({ length: Math.min(limit, items.length) }, worker));
    return results;
  }

  async function fullSync() {
    showToast('Sincronizando pedidos com a L7...');
    const buildingsRaw = await api('/buildings');
    const building = (buildingsRaw.results || buildingsRaw).find((b) => b.name.trim() === SYNC_BUILDING_NAME);
    if (!building) throw new Error(`Obra "${SYNC_BUILDING_NAME}" não encontrada.`);

    const [prRaw, quotRaw, ocRaw, costCentersRaw] = await Promise.all([
      api('/purchaserequests?page=1&pageSize=3000&expand[]=items&expand[]=items.product&expand[]=costCenter&expand[]=costCenter.building&index=true'),
      api('/quotations?page=1&pageSize=3000&index=true'),
      api('/purchaseorders?page=1&pageSize=3000&index=true'),
      api('/costcenters?order=%7B%22name%22:%22ASC%22%7D'),
    ]);

    const arsen = (prRaw.results || prRaw).filter((p) => {
      if (p.costCenter && p.costCenter.buildingId !== building.id) return false;
      if ((p.createdAt || '') < SYNC_SINCE) return false;
      if (p.status === 'rejected' || p.baseStatus === 'rejected') return false; // não aprovadas ficam de fora
      return true;
    });

    const quotationByReq = {};
    (quotRaw.results || quotRaw).forEach((q) => {
      const cur = quotationByReq[q.purchaseRequestId];
      if (!cur || q.createdAt > cur.createdAt) quotationByReq[q.purchaseRequestId] = q;
    });
    const ocById = {};
    (ocRaw.results || ocRaw).forEach((o) => { ocById[o.id] = o; });

    const stored = await readFileData();
    if (!stored) throw new Error('O arquivo de pedidos conectado leu vazio. Por segurança, nada foi gravado.');
    const pedidos = stored.pedidos || [];
    const byReq = new Map(pedidos.map((p, i) => [String(p.req), i]));

    let added = 0, updated = 0;
    arsen.forEach((p) => {
      const items = p.items || [];
      const ocId = (p.purchaseOrderIds && p.purchaseOrderIds[0]) || null;
      const oc = ocId ? ocById[ocId] : null;
      const quotation = quotationByReq[p.id];
      const cotacaoId = quotation ? quotation.id : null;
      const compra = oc ? (oc.approvedAt || oc.createdAt || '').slice(0, 10) : '';
      const chegou = oc && (oc.status === 'partial' || oc.baseStatus === 'closed') ? (oc.updatedAt || '').slice(0, 10) : '';
      const fornecedor = oc ? (oc.supplierName || '').trim() : '';
      const apiStatus = determineApiStatus(p, oc);

      const key = String(p.id);
      let pedido;
      if (byReq.has(key)) {
        pedido = pedidos[byReq.get(key)];
        updated++;
      } else {
        pedido = { id: 'req-' + p.id, req: key, itens: [] };
        pedidos.push(pedido);
        byReq.set(key, pedidos.length - 1);
        added++;
      }

      pedido.categoria = (p.referenceCategoryName || '').trim();
      pedido.material = items[0] && items[0].product ? items[0].product.name : '';
      pedido.descricao = items.map((it) => `${it.product ? it.product.name : ''}${it.product && it.product.description ? ' - ' + it.product.description : ''} x${it.quantity}`).join('; ');
      pedido.dataPedido = (p.createdAt || '').slice(0, 10);
      pedido.aprovacao = (p.approvedAt || '').slice(0, 10);
      pedido.apiStatus = apiStatus;

      pedido.itens = pedido.itens || [];
      const itemByProduct = new Map(pedido.itens.map((it) => [it.productId, it]));
      items.forEach((it) => {
        let existing = itemByProduct.get(it.productId);
        if (!existing) {
          existing = {
            id: 'item-' + it.id, productId: it.productId,
            material: '', quantidade: '', unidade: '',
            fornecedor: '', cotacaoId: '', ocId: '', compra: '', chegou: '',
            problema: false, obs: '',
          };
          pedido.itens.push(existing);
          itemByProduct.set(it.productId, existing);
        }
        // Dados factuais vindos da API são sempre atualizados; "problema"/"obs" são
        // observações suas e nunca são mexidos por aqui.
        existing.material = it.product ? it.product.name : '';
        existing.quantidade = String(it.quantity ?? '');
        existing.unidade = it.product ? it.product.unit : '';
        if (fornecedor) existing.fornecedor = fornecedor;
        if (cotacaoId) existing.cotacaoId = String(cotacaoId);
        if (ocId) existing.ocId = String(ocId);
        if (compra) existing.compra = compra;
        if (chegou) existing.chegou = chegou;
      });
    });

    // ---- Requisições excluídas na L7: se o pedido local tem nº de requisição mas esse
    // id não existe MAIS em nenhum lugar da base (nem em outra obra, nem rejeitada — prRaw
    // não tem filtro nenhum aplicado), foi excluída de verdade. Não apaga o pedido local
    // (perderia o histórico) — só marca o status, pra não sumir do controle sem explicação.
    // Fica agrupado com "Finalizado" no painel (mesmo toggle "Mostrar finalizados").
    const allRequestIds = new Set((prRaw.results || prRaw).map((p) => String(p.id)));
    pedidos.forEach((pedido) => {
      if (pedido.req && !allRequestIds.has(String(pedido.req))) {
        pedido.apiStatus = 'Excluída';
      }
    });

    // ---- OCs "órfãs": criadas direto no módulo de Ordem de Compra, sem passar por
    // requisição/cotação (ex: reposição manual de uma OC excluída). Como não tem requisição,
    // nunca apareceriam no painel — aqui entram como pedido próprio, sem nº de requisição. ----
    const costCenterNameById = {};
    (costCentersRaw.results || costCentersRaw).forEach((c) => { costCenterNameById[c.id] = (c.name || '').trim(); });

    const linkedOcIds = new Set();
    (prRaw.results || prRaw).forEach((p) => (p.purchaseOrderIds || []).forEach((id) => linkedOcIds.add(id)));

    const orphanOcs = (ocRaw.results || ocRaw).filter((oc) => {
      if ((oc.buildingName || '').trim() !== SYNC_BUILDING_NAME) return false;
      if ((oc.createdAt || '') < SYNC_SINCE) return false;
      if (linkedOcIds.has(oc.id)) return false;
      return true;
    });

    const byOcId = new Map(pedidos.filter((p) => p.ocId).map((p, i) => [String(p.ocId), pedidos.indexOf(p)]));

    // Item "sintético" = placeholder sem produto real, criado quando ainda não tínhamos
    // conseguido os itens verdadeiros da OC (ver bloco abaixo).
    const isSynthetic = (itens) => itens && itens.length === 1 && itens[0].productId == null;

    // A listagem de OCs não traz os itens — só o detalhe (expand[]=items). Busca o detalhe
    // só de quem realmente precisa: OC nova, ou OC que só tem o placeholder sintético ainda.
    const orphansNeedingItems = orphanOcs.filter((oc) => {
      const idx = byOcId.get(String(oc.id));
      const existing = idx != null ? pedidos[idx] : null;
      return !existing || !existing.itens || !existing.itens.length || isSynthetic(existing.itens);
    });
    const ocDetailById = {};
    if (orphansNeedingItems.length) {
      showToast(`Buscando itens de ${orphansNeedingItems.length} OC(s) sem requisição...`);
      await mapWithConcurrency(orphansNeedingItems, 5, async (oc) => {
        try {
          ocDetailById[oc.id] = await api(`/purchaseorders/${oc.id}?expand[]=items&expand[]=items.product&expand[]=costCenter&expand[]=costCenter.building&expand[]=supplier`);
        } catch (e) {
          console.error(`Falha ao buscar itens da OC órfã #${oc.id}`, e);
        }
      });
    }

    let addedOc = 0, updatedOc = 0;
    orphanOcs.forEach((oc) => {
      const key = String(oc.id);
      const compra = (oc.approvedAt || oc.createdAt || '').slice(0, 10);
      const chegou = (oc.status === 'partial' || oc.baseStatus === 'closed') ? (oc.updatedAt || '').slice(0, 10) : '';
      const fornecedor = (oc.supplierName || '').trim();
      const apiStatus = determineApiStatus(null, oc);

      let pedido;
      if (byOcId.has(key)) {
        pedido = pedidos[byOcId.get(key)];
        updatedOc++;
      } else {
        pedido = { id: 'oc-' + oc.id, req: '', ocId: key, itens: [] };
        pedidos.push(pedido);
        byOcId.set(key, pedidos.length - 1);
        addedOc++;
      }

      const ocFull = ocDetailById[oc.id];
      const realItems = ocFull ? (ocFull.items || []) : null;

      pedido.categoria = costCenterNameById[oc.costCenterId] ||
        (ocFull && ocFull.costCenter ? (ocFull.costCenter.name || '').trim() : '') || pedido.categoria || '';
      pedido.dataPedido = (oc.createdAt || '').slice(0, 10);
      pedido.aprovacao = (oc.approvedAt || '').slice(0, 10);
      pedido.apiStatus = apiStatus;

      if (realItems && realItems.length) {
        // Itens reais da OC (produto, quantidade, unidade) — troca o placeholder por eles.
        pedido.material = realItems[0].product ? realItems[0].product.name : '';
        pedido.descricao = realItems.map((it) => `${it.product ? it.product.name : ''}${it.product && it.product.description ? ' - ' + it.product.description : ''} x${it.quantity}`).join('; ');
        if (isSynthetic(pedido.itens)) pedido.itens = [];
        const itemByProduct = new Map(pedido.itens.map((it) => [it.productId, it]));
        realItems.forEach((it) => {
          let existing = itemByProduct.get(it.productId);
          if (!existing) {
            existing = {
              id: 'item-' + it.id, productId: it.productId,
              material: '', quantidade: '', unidade: '',
              fornecedor: '', cotacaoId: '', ocId: '', compra: '', chegou: '', problema: false, obs: '',
            };
            pedido.itens.push(existing);
            itemByProduct.set(it.productId, existing);
          }
          existing.material = it.product ? it.product.name : '';
          existing.quantidade = String(it.quantity ?? '');
          existing.unidade = it.product ? it.product.unit : '';
          existing.fornecedor = fornecedor;
          existing.ocId = key;
          if (compra) existing.compra = compra;
          if (chegou) existing.chegou = chegou;
        });
      } else if (!pedido.itens.length || isSynthetic(pedido.itens)) {
        // Sem itens reais ainda (busca falhou ou OC não tem itens) — mantém o placeholder.
        pedido.material = pedido.material || `OC direta - ${fornecedor}`;
        pedido.descricao = pedido.descricao || `Ordem de compra sem requisição vinculada (criada direto no sistema). Fornecedor: ${fornecedor}.`;
        pedido.itens = [{
          id: 'item-oc-' + oc.id, productId: null,
          material: `OC direta - ${fornecedor}`, quantidade: '', unidade: '',
          fornecedor, cotacaoId: '', ocId: key, compra, chegou, problema: false, obs: '',
        }];
      } else {
        // Já tinha itens reais de uma sincronização anterior: só atualiza dados factuais.
        pedido.itens.forEach((item) => {
          item.fornecedor = fornecedor;
          item.ocId = key;
          if (compra) item.compra = compra;
          if (chegou) item.chegou = chegou;
        });
      }
    });

    await writeFileData({ pedidos, categorias: stored.categorias || [] });
    showToast(`Pedidos sincronizados: ${added} nova(s), ${updated} atualizada(s). OCs sem requisição: ${addedOc} nova(s), ${updatedOc} atualizada(s).`);
  }

  // ==================================================================================
  // ---- PDFs de Ordem de Compra: gera (clicando "Imprimir O.C.") e salva na pasta ----
  // ==================================================================================
  const OC_QUEUE_KEY = 'ocpdf_queue_v1';
  const AUTO_LAST_RUN_KEY = 'sync_lastAutoRun_v1'; // guarda "AAAA-MM-DD HH:MM" do último disparo automático
  const AUTO_TIMES = ['07:20', '11:20', '15:00'];

  let dirHandle = null;

  // queryPermission só confirma a permissão da origem — não confirma que a pasta ainda existe
  // no disco. Se ela foi movida/renomeada/excluída (ex: reorganização de pastas), qualquer
  // operação real (getFileHandle, entries) falha com NotFoundError. Checa isso aqui pra
  // detectar pasta "fantasma" e forçar reconexão em vez de dar erro só na hora de salvar.
  async function verifyDirHandle(handle) {
    try {
      await handle.entries().next();
      return true;
    } catch (e) { return false; }
  }

  async function tryReconnectFolderSilently() {
    if (!window.showDirectoryPicker) return false;
    try {
      const saved = await idbGet('ocDirHandle');
      if (!saved) return false;
      if ((await saved.queryPermission({ mode: 'readwrite' })) !== 'granted') return false;
      if (!(await verifyDirHandle(saved))) { await idbSet('ocDirHandle', null); return false; }
      dirHandle = saved;
      return true;
    } catch (e) { return false; }
  }

  async function connectFolder() {
    if (!window.showDirectoryPicker) {
      alert('Seu navegador não suporta escolher uma pasta local. Use Chrome ou Edge.');
      return false;
    }
    try {
      if (dirHandle) {
        const perm = await dirHandle.requestPermission({ mode: 'readwrite' });
        if (perm === 'granted' && (await verifyDirHandle(dirHandle))) return true;
        dirHandle = null; // pasta antiga não existe mais nesse caminho — pede de novo
      }
      // "id" faz o navegador lembrar essa escolha: da 2ª vez em diante, o seletor já abre
      // direto na última pasta usada aqui, sem precisar navegar de novo.
      dirHandle = await window.showDirectoryPicker({ mode: 'readwrite', id: 'oc-sistema-folder' });
      await idbSet('ocDirHandle', dirHandle);
      return true;
    } catch (e) {
      console.error('Falha ao conectar pasta de OCs', e);
      return false;
    }
  }

  async function listExistingOcFiles() {
    const map = new Map(); // ocId (string) -> { name, statusLabel }
    for await (const [name, handle] of dirHandle.entries()) {
      if (handle.kind !== 'file') continue;
      const m = name.match(/^OC - (\d+) - .*? - (A receber|Recebido)\.pdf$/);
      if (m) map.set(m[1], { name, statusLabel: m[2] });
    }
    return map;
  }

  function sanitizeForFilename(s) {
    return (s || '').replace(/[\\/:*?"<>|]/g, '-').trim();
  }
  function ocStatusLabel(oc) {
    return oc.baseStatus === 'closed' ? 'Recebido' : 'A receber';
  }
  function supplierNameOf(oc) {
    // A listagem traz "supplierName" solto; o registro individual (com expand=supplier) traz "supplier.name".
    return oc.supplierName || (oc.supplier && oc.supplier.name) || 'Fornecedor desconhecido';
  }
  function ocFileName(oc) {
    return `OC - ${oc.id} - ${sanitizeForFilename(supplierNameOf(oc))} - ${ocStatusLabel(oc)}.pdf`;
  }

  async function saveBlobAs(name, blob) {
    const handle = await dirHandle.getFileHandle(name, { create: true });
    const writable = await handle.createWritable();
    await writable.write(blob);
    await writable.close();
  }
  async function removeFileIfExists(name) {
    try { await dirHandle.removeEntry(name); } catch (e) { /* já não existe, tudo bem */ }
  }

  async function buildOcQueue() {
    await waitForToken();
    const ocRaw = await api('/purchaseorders?page=1&pageSize=3000&index=true');
    const all = ocRaw.results || ocRaw;
    const arsen = all.filter((o) => (o.buildingName || '').trim() === SYNC_BUILDING_NAME);

    const existing = await listExistingOcFiles();
    const todo = [];
    arsen.forEach((oc) => {
      const key = String(oc.id);
      const wantLabel = ocStatusLabel(oc);
      const found = existing.get(key);
      if (found && found.statusLabel === wantLabel) return; // já tem, e status bate — pula
      todo.push({ id: oc.id, oldFileName: found ? found.name : null });
    });
    return todo;
  }

  function getOcQueueState() {
    try { return JSON.parse(localStorage.getItem(OC_QUEUE_KEY) || 'null'); } catch (e) { return null; }
  }
  function setOcQueueState(state) {
    if (state) localStorage.setItem(OC_QUEUE_KEY, JSON.stringify(state));
    else localStorage.removeItem(OC_QUEUE_KEY);
  }

  async function startOcQueue(todo) {
    if (!todo.length) { showToast('PDFs de OC: nada pra baixar, já está tudo atualizado.'); return; }
    setOcQueueState({ ids: todo.map((t) => t.id), oldNames: todo.map((t) => t.oldFileName), index: 0, total: todo.length });
    showToast(`PDFs de OC: iniciando, ${todo.length} pra baixar...`);
    await gotoCurrentOcStep();
  }

  async function gotoCurrentOcStep() {
    const state = getOcQueueState();
    if (!state) return;
    const id = state.ids[state.index];
    const target = `/ordemdecompra/${id}`;
    if (location.pathname !== target) {
      location.href = target;
      return;
    }
    await processCurrentOc();
  }

  async function waitForEl(fn, timeoutMs) {
    const start = Date.now();
    while (Date.now() - start < timeoutMs) {
      const v = fn();
      if (v) return v;
      await sleep(200);
    }
    return null;
  }

  async function processCurrentOc() {
    const state = getOcQueueState();
    if (!state) return;
    const id = state.ids[state.index];
    const oldName = state.oldNames[state.index];
    showToast(`PDF de OC ${state.index + 1}/${state.total} (#${id})...`);

    try {
      await waitForToken();
      const ocFull = await api(`/purchaseorders/${id}?expand[]=items&expand[]=items.product&expand[]=costCenter&expand[]=costCenter.building&expand[]=supplier`);

      const btn = await waitForEl(() => Array.from(document.querySelectorAll('button, span')).find((b) => b.textContent.trim() === 'Imprimir O.C.'), 12000);
      if (!btn) throw new Error('Botão "Imprimir O.C." não apareceu.');
      await sleep(400);
      btn.click();

      const iframe = await waitForEl(() => document.querySelector('iframe[src^="blob:"]'), 15000);
      if (!iframe) throw new Error('Prévia do PDF não carregou.');
      await sleep(300);

      const blob = await origFetch(iframe.src).then((r) => r.blob());
      if (blob.type !== 'application/pdf' || blob.size < 1000) throw new Error('Conteúdo capturado não parece um PDF válido.');

      const name = ocFileName(ocFull);
      if (oldName && oldName !== name) await removeFileIfExists(oldName);
      await saveBlobAs(name, blob);
    } catch (e) {
      console.error(`Falha na OC #${id}`, e);
      showToast(`Erro na OC #${id}: ${e.message} — pulando.`, true);
    }

    const nextIndex = state.index + 1;
    if (nextIndex >= state.total) {
      setOcQueueState(null);
      showToast(`PDFs de OC concluídos: ${state.total} processadas.`);
      await sleep(1200); // dá tempo do toast aparecer antes de sair da página
      location.href = HOME_URL;
      return;
    }
    setOcQueueState({ ...state, index: nextIndex });
    await sleep(300);
    await gotoCurrentOcStep();
  }

  // ---- Sincronização combinada: pedidos + PDFs de OC, manual ou automática ----
  async function runFullSyncWithOcPdfs() {
    await fullSync();
    const ok = dirHandle ? true : await tryReconnectFolderSilently();
    if (!ok) {
      showToast('Pedidos sincronizados. PDFs de OC pulados: pasta não conectada ainda.', true);
      return;
    }
    const todo = await buildOcQueue();
    await startOcQueue(todo);
  }

  // ---- Checagem automática 3x/dia (só funciona com a aba aberta) ----
  function checkAutoSchedule() {
    if (getOcQueueState()) return; // fila de PDF já rodando — não conta esse horário como "feito", só espera
    const now = new Date();
    const hhmm = String(now.getHours()).padStart(2, '0') + ':' + String(now.getMinutes()).padStart(2, '0');
    if (!AUTO_TIMES.includes(hhmm)) return;
    const slotKey = now.toISOString().slice(0, 10) + ' ' + hhmm;
    if (localStorage.getItem(AUTO_LAST_RUN_KEY) === slotKey) return; // já rodou nesse horário hoje
    localStorage.setItem(AUTO_LAST_RUN_KEY, slotKey);
    (async () => {
      const pedidosOk = await tryReconnectSilently();
      if (!pedidosOk) { showToast('Sincronização automática pulada: arquivo de pedidos não conectado.', true); return; }
      try {
        await runFullSyncWithOcPdfs();
      } catch (e) {
        console.error('Falha na sincronização automática', e);
        showToast('Falha na sincronização automática: ' + e.message, true);
      }
    })();
  }
  setInterval(checkAutoSchedule, 20000);

  // ---- UI: botões "Integrar pedido" e "Sincronizar com L7" + toast ----
  const style = document.createElement('style');
  style.textContent = `
    #rp-fab{ position:fixed; right:20px; bottom:160px; z-index:999999; background:#6d4fe0; color:#fff;
      border:none; border-radius:999px; padding:10px 16px; font:600 13px/1 system-ui, sans-serif;
      box-shadow:0 4px 14px rgba(0,0,0,.3); cursor:pointer; }
    #rp-fab:not(.connected)::after{ content:" (conectar)"; opacity:.85; }
    #rp-sync-fab{ position:fixed; right:20px; bottom:280px; z-index:999999; background:#0f5c9c; color:#fff;
      border:none; border-radius:999px; padding:10px 16px; font:600 13px/1 system-ui, sans-serif;
      box-shadow:0 4px 14px rgba(0,0,0,.3); cursor:pointer; }
    #rp-sync-fab:not(.connected)::after{ content:" (conectar)"; opacity:.85; }
    #rp-toast{ position:fixed; right:20px; bottom:210px; z-index:999999; max-width:340px;
      background:#16202e; color:#fff; padding:10px 14px; border-radius:8px; font:13px/1.4 system-ui, sans-serif;
      box-shadow:0 4px 14px rgba(0,0,0,.3); display:none; }
    #rp-toast.error{ background:#b3261e; }
  `;
  document.head.appendChild(style);

  const fab = document.createElement('button');
  fab.id = 'rp-fab';
  fab.textContent = '➕ Integrar pedido';
  const syncFab = document.createElement('button');
  syncFab.id = 'rp-sync-fab';
  syncFab.textContent = '🔄 Sincronizar com L7';
  const toast = document.createElement('div');
  toast.id = 'rp-toast';

  function mount() {
    document.body.appendChild(fab);
    document.body.appendChild(syncFab);
    document.body.appendChild(toast);
  }
  if (document.body) mount(); else document.addEventListener('DOMContentLoaded', mount);

  function updateFabState(pedidosConnected) {
    fab.classList.toggle('connected', pedidosConnected);
  }
  function updateSyncFabState() {
    syncFab.classList.toggle('connected', connected && !!dirHandle);
  }

  let toastTimer = null;
  function showToast(msg, isError) {
    toast.textContent = msg;
    toast.classList.toggle('error', !!isError);
    toast.style.display = 'block';
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => { toast.style.display = 'none'; }, 7000);
  }

  // "connected" reflete permissão CONFIRMADA (não apenas se existe um handle salvo) —
  // é o que estava faltando: um handle salvo sem permissão ainda válida causava erro
  // silencioso ao tentar ler o arquivo direto, sem repassar por connectFile().
  let connected = false;

  async function ensureConnected() {
    if (connected) return true;
    const ok = await connectFile();
    connected = ok;
    updateFabState(ok);
    updateSyncFabState();
    return ok;
  }

  fab.addEventListener('click', async () => {
    const ok = await ensureConnected();
    if (!ok) return;
    const id = getCurrentRequestId();
    if (!id) {
      showToast('Não consegui identificar a requisição atual. Abra ou salve uma requisição primeiro.', true);
      return;
    }
    await integrateRequest(id);
  });

  syncFab.addEventListener('click', async () => {
    const pedidosOk = await ensureConnected();
    if (!pedidosOk) return;
    if (!dirHandle) {
      showToast('Agora escolha a pasta onde salvar os PDFs de OC...');
      const folderOk = await connectFolder();
      if (!folderOk) { showToast('PDFs de OC cancelados: pasta não conectada.', true); return; }
    }
    updateSyncFabState();
    try {
      await runFullSyncWithOcPdfs();
    } catch (e) {
      console.error('Falha na sincronização', e);
      showToast('Falha ao sincronizar: ' + e.message, true);
    }
  });

  // Se a página recarregou no meio de uma fila de PDF em andamento, continua de onde parou.
  (async function init() {
    const pedidosOk = await tryReconnectSilently();
    connected = pedidosOk;
    updateFabState(pedidosOk);
    const folderOk = await tryReconnectFolderSilently();
    updateSyncFabState();
    if (folderOk && getOcQueueState()) {
      await waitForToken().catch(() => {});
      await gotoCurrentOcStep();
    }
  })();
})();
