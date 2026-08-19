// ==UserScript==
// @name         Requisições → Painel de Pedidos (integração manual + sincronização)
// @namespace    obra-check-luiz
// @version      1.2.0
// @description  Botão "Integrar pedido" pra levar a requisição atual pro pedidos-arsen.json sob demanda, e botão "Sincronizar com L7" pra atualizar status/cotação/OC/fornecedor/datas de tudo e criar as requisições novas de uma vez.
// @match        https://build-manager-api-snriv.ondigitalocean.app/*
// @run-at       document-start
// @grant        none
// ==/UserScript==

(function () {
  'use strict';

  const API = 'https://build-manager-api-snriv.ondigitalocean.app/api/v1';
  const FILE_NAME = 'pedidos-arsen.json';

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

  // ---- Persistência em arquivo local (mesma pasta do Google Drive usada pelo painel) ----
  let fileHandle = null;

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
      await new Promise((r) => setTimeout(r, 400));
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

  async function fullSync() {
    showToast('Sincronizando com a L7... pode levar alguns segundos.');
    try {
      const buildingsRaw = await api('/buildings');
      const building = (buildingsRaw.results || buildingsRaw).find((b) => b.name.trim() === SYNC_BUILDING_NAME);
      if (!building) throw new Error(`Obra "${SYNC_BUILDING_NAME}" não encontrada.`);

      const [prRaw, quotRaw, ocRaw] = await Promise.all([
        api('/purchaserequests?page=1&pageSize=3000&expand[]=items&expand[]=items.product&expand[]=costCenter&expand[]=costCenter.building&index=true'),
        api('/quotations?page=1&pageSize=3000&index=true'),
        api('/purchaseorders?page=1&pageSize=3000&index=true'),
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
      if (!stored) throw new Error('O arquivo conectado leu vazio. Por segurança, nada foi gravado.');
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

      await writeFileData({ pedidos, categorias: stored.categorias || [] });
      showToast(`Sincronizado: ${added} nova(s), ${updated} atualizada(s).`);
    } catch (e) {
      console.error('Falha na sincronização completa', e);
      showToast('Falha ao sincronizar: ' + e.message, true);
    }
  }

  // ---- UI mínima: botão "Integrar pedido" + toast ----
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

  function updateFabState(connected) {
    fab.classList.toggle('connected', connected);
    syncFab.classList.toggle('connected', connected);
  }

  let toastTimer = null;
  function showToast(msg, isError) {
    toast.textContent = msg;
    toast.classList.toggle('error', !!isError);
    toast.style.display = 'block';
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => { toast.style.display = 'none'; }, 6000);
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
    const ok = await ensureConnected();
    if (!ok) return;
    await fullSync();
  });

  tryReconnectSilently().then((ok) => { connected = ok; updateFabState(ok); });
})();
