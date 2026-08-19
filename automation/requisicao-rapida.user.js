// ==UserScript==
// @name         Requisição Rápida - Busca de Materiais
// @namespace    obra-check-luiz
// @version      3.0.0
// @description  Painel de busca rápida nos materiais (por nome/descrição, sem precisar navegar por categoria) pra montar uma requisição com complemento e quantidade, revisar tudo, e lançar como rascunho direto (via API) com um resumo de confirmação antes de enviar.
// @match        https://build-manager-api-snriv.ondigitalocean.app/*
// @run-at       document-start
// @grant        none
// ==/UserScript==

(function () {
  'use strict';

  const API = 'https://build-manager-api-snriv.ondigitalocean.app/api/v1';

  // ---- Captura do token Bearer que o próprio app injeta nas chamadas ----
  let authToken = null;
  const origSetHeader = XMLHttpRequest.prototype.setRequestHeader;
  XMLHttpRequest.prototype.setRequestHeader = function (name, value) {
    if (name.toLowerCase() === 'authorization') authToken = value;
    return origSetHeader.apply(this, arguments);
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
    if (!authToken) throw new Error('Token ainda não capturado. Navegue pelo portal uma vez antes de abrir o painel.');
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

  function normalize(s) {
    return (s || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
  }

  // ---- Catálogos (carregados uma vez, reaproveitados entre aberturas do painel) ----
  let buildingsCache = null;
  let categoriesCache = null;
  let productsCache = null;

  async function ensureCatalogs() {
    if (!buildingsCache) buildingsCache = (await api('/buildings')).results;
    if (!categoriesCache) {
      const raw = await api('/categories?order=%7B%22name%22:%22ASC%22%7D');
      categoriesCache = raw.results || raw;
    }
    if (!productsCache) {
      const raw = await api('/products?index=true&order=%7B%22name%22:%22ASC%22%7D');
      const list = raw.results || raw;
      productsCache = list.map((p) => ({ ...p, __search: normalize(`${p.name} ${p.description || ''}`) }));
    }
  }

  // ---- UI ----
  const style = document.createElement('style');
  style.textContent = `
    #rr-fab{ position:fixed; right:20px; bottom:220px; z-index:999999; background:#0f5c9c; color:#fff;
      border:none; border-radius:999px; padding:10px 16px; font:600 13px/1 system-ui, sans-serif;
      box-shadow:0 4px 14px rgba(0,0,0,.3); cursor:pointer; }
    #rr-overlay{ position:fixed; inset:0; background:rgba(0,0,0,.5); z-index:1000000;
      display:flex; align-items:flex-start; justify-content:center; padding:30px 16px; overflow:auto; }
    #rr-panel{ background:#fff; width:1160px; max-width:100%; border-radius:10px; padding:20px;
      font:14px/1.4 system-ui, sans-serif; color:#1a1a1a; display:grid; grid-template-columns:380px 1fr; gap:22px; }
    #rr-panel h2{ grid-column:1 / -1; margin:0 0 4px; font-size:18px; }
    #rr-panel h3{ margin:14px 0 8px; font-size:14px; color:#0f5c9c; border-top:1px solid #eee; padding-top:12px; }
    #rr-left h3:first-of-type, #rr-right h3:first-of-type{ border-top:none; padding-top:0; margin-top:0; }
    #rr-panel label{ display:block; font-weight:600; margin-bottom:4px; font-size:12px; color:#444; }
    #rr-panel select, #rr-panel input[type=text], #rr-panel textarea{
      width:100%; padding:6px 8px; border:1px solid #ccc; border-radius:6px; margin-bottom:10px; font-family:inherit; box-sizing:border-box; }
    .rr-row{ display:flex; gap:10px; }
    .rr-row > div{ flex:1; }
    #rr-search{ font-size:15px; padding:10px 12px; }
    #rr-picked{ background:#f4f8fc; border:1px solid #d6e6f5; border-radius:8px; padding:10px; margin-bottom:14px; flex-shrink:0; }
    #rr-picked input:disabled{ background:#eee; color:#999; }
    .rr-picked-title{ font-weight:700; margin-bottom:8px; color:#0f5c9c; }
    #rr-results{ flex:1; min-height:0; overflow:auto; border:1px solid #eee; border-radius:6px; }
    .rr-result{ padding:8px 12px; cursor:pointer; border-bottom:1px solid #f2f2f2; font-size:13px; }
    .rr-result:hover{ background:#eef5fc; }
    .rr-result small{ display:block; color:#888; }
    #rr-right{ display:flex; flex-direction:column; min-height:520px; max-height:78vh; }
    table.rr-cart{ width:100%; border-collapse:collapse; margin-bottom:10px; font-size:13px; }
    table.rr-cart th{ text-align:left; color:#0f5c9c; font-size:11px; text-transform:uppercase; padding:4px 6px; border-bottom:2px solid #eee; }
    table.rr-cart td{ padding:5px 6px; border-bottom:1px solid #f2f2f2; }
    .rr-actions{ display:flex; justify-content:flex-end; gap:10px; margin-top:18px; grid-column:1 / -1; }
    .rr-btn{ padding:9px 16px; border-radius:6px; border:none; font-weight:600; cursor:pointer; }
    .rr-btn.primary{ background:#1a8f3c; color:#fff; }
    .rr-btn.ghost{ background:#eee; color:#333; }
    .rr-btn.small{ padding:4px 8px; font-size:12px; }
    #rr-status{ font-size:13px; margin-top:10px; white-space:pre-wrap; grid-column:1 / -1; }
  `;
  document.head.appendChild(style);

  const fab = document.createElement('button');
  fab.id = 'rr-fab';
  fab.textContent = '🔍 Requisição rápida';
  fab.addEventListener('click', openPanel);
  function mount() { document.body.appendChild(fab); }
  if (document.body) mount(); else document.addEventListener('DOMContentLoaded', mount);

  let cart = []; // { productId, name, description, unit, complemento, quantidade }
  let activeProduct = null;

  async function openPanel() {
    const overlay = document.createElement('div');
    overlay.id = 'rr-overlay';
    overlay.innerHTML = `
      <div id="rr-panel">
        <h2>Requisição rápida</h2>

        <div id="rr-left">
          <h3>Dados da requisição</h3>
          <label>Obra</label>
          <select id="rr-obra"><option value="">Carregando...</option></select>
          <label>Centro de custo</label>
          <select id="rr-cc"><option value="">Selecione a obra primeiro</option></select>
          <label>Categoria</label>
          <select id="rr-cat"><option value="">Carregando...</option></select>
          <label>Observação / Utilização</label>
          <textarea id="rr-obs" rows="2" placeholder="Opcional"></textarea>

          <h3>Itens (<span id="rr-count">0</span>)</h3>
          <table class="rr-cart">
            <thead><tr><th>Produto</th><th>Compl.</th><th>Qtd</th><th></th></tr></thead>
            <tbody id="rr-cart-body"><tr><td colspan="4" style="color:#888">Nenhum item ainda.</td></tr></tbody>
          </table>

          <div id="rr-status"></div>
          <div class="rr-actions" style="grid-column:auto; justify-content:flex-start; margin-top:10px">
            <button class="rr-btn ghost" id="rr-cancel">Fechar</button>
            <button class="rr-btn primary" id="rr-launch" disabled>Lançar rascunho</button>
          </div>
        </div>

        <div id="rr-right">
          <div id="rr-picked">
            <div class="rr-picked-title" id="rr-picked-title">Nenhum produto selecionado — busque abaixo</div>
            <div class="rr-row">
              <div><label>Complemento</label><input type="text" id="rr-complemento" placeholder="Opcional" disabled></div>
              <div><label>Quantidade</label><input type="text" id="rr-quantidade" placeholder="0" disabled></div>
            </div>
            <button class="rr-btn primary" id="rr-addBtn" type="button" disabled>+ Adicionar à requisição</button>
          </div>
          <h3>Buscar material</h3>
          <input type="text" id="rr-search" placeholder="Digite parte do nome ou descrição (ex: cabo flexível, tinta, cimento)...">
          <div id="rr-results"></div>
        </div>
      </div>`;
    document.body.appendChild(overlay);
    overlay.addEventListener('click', (e) => { if (e.target === overlay) overlay.remove(); });
    overlay.querySelector('#rr-cancel').onclick = () => overlay.remove();

    const status = overlay.querySelector('#rr-status');
    try {
      await ensureCatalogs();
    } catch (e) {
      status.textContent = 'Erro ao carregar catálogos: ' + e.message;
      return;
    }

    const obraSel = overlay.querySelector('#rr-obra');
    obraSel.innerHTML = '<option value="">Selecione obra</option>' +
      buildingsCache.map((b) => `<option value="${b.id}">${b.name.trim()}</option>`).join('');
    obraSel.onchange = () => loadCostCenters(overlay, Number(obraSel.value));

    const catSel = overlay.querySelector('#rr-cat');
    catSel.innerHTML = '<option value="">Selecione categoria</option>' +
      categoriesCache.map((c) => `<option value="${c.id}">${c.name.trim()}</option>`).join('');

    renderCart(overlay);
    wireSearch(overlay);
    overlay.querySelector('#rr-launch').onclick = () => launch(overlay);
  }

  async function loadCostCenters(overlay, buildingId) {
    const ccSel = overlay.querySelector('#rr-cc');
    if (!buildingId) { ccSel.innerHTML = '<option value="">Selecione a obra primeiro</option>'; return; }
    ccSel.innerHTML = '<option value="">Carregando...</option>';
    const raw = await api(`/costcenters?buildingId=${buildingId}`);
    const list = raw.results || raw;
    ccSel.innerHTML = '<option value="">Selecione centro de custo</option>' +
      list.map((c) => `<option value="${c.id}">${(c.item ? c.item + ' - ' : '') + c.name.trim()}</option>`).join('');
  }

  function wireSearch(overlay) {
    const input = overlay.querySelector('#rr-search');
    const results = overlay.querySelector('#rr-results');
    input.addEventListener('input', () => {
      const q = normalize(input.value.trim());
      if (q.length < 2) { results.innerHTML = ''; return; }
      const matches = productsCache.filter((p) => p.__search.includes(q)).slice(0, 60);
      results.innerHTML = matches.map((p) => `
        <div class="rr-result" data-id="${p.id}">
          ${p.name.trim()}${p.description ? ` <small>${p.description}</small>` : ''}
        </div>`).join('') || '<div class="rr-result" style="color:#888;cursor:default">Nenhum material encontrado</div>';
      results.querySelectorAll('.rr-result[data-id]').forEach((el) => {
        el.onclick = () => pickProduct(overlay, Number(el.dataset.id));
      });
    });
  }

  function setPickedEnabled(overlay, enabled) {
    overlay.querySelector('#rr-complemento').disabled = !enabled;
    overlay.querySelector('#rr-quantidade').disabled = !enabled;
    overlay.querySelector('#rr-addBtn').disabled = !enabled;
  }

  function resetPicked(overlay) {
    activeProduct = null;
    overlay.querySelector('#rr-picked-title').textContent = 'Nenhum produto selecionado — busque abaixo';
    overlay.querySelector('#rr-complemento').value = '';
    overlay.querySelector('#rr-quantidade').value = '';
    setPickedEnabled(overlay, false);
  }

  function pickProduct(overlay, productId) {
    activeProduct = productsCache.find((p) => p.id === productId);
    if (!activeProduct) return;
    overlay.querySelector('#rr-picked-title').textContent =
      `${activeProduct.name.trim()}${activeProduct.description ? ' — ' + activeProduct.description : ''} (${activeProduct.unit || 'un'})`;
    overlay.querySelector('#rr-complemento').value = '';
    overlay.querySelector('#rr-quantidade').value = '';
    setPickedEnabled(overlay, true);
    overlay.querySelector('#rr-quantidade').focus();
  }

  document.addEventListener('click', (e) => {
    if (e.target && e.target.id === 'rr-addBtn') {
      const overlay = e.target.closest('#rr-overlay');
      if (!overlay || !activeProduct) return;
      const complemento = overlay.querySelector('#rr-complemento').value.trim();
      const quantidade = overlay.querySelector('#rr-quantidade').value.trim();
      if (!quantidade || Number(quantidade) <= 0) {
        overlay.querySelector('#rr-status').textContent = 'Informe uma quantidade válida antes de adicionar.';
        return;
      }
      cart.push({
        productId: activeProduct.id,
        name: activeProduct.name.trim(),
        description: activeProduct.description || '',
        unit: activeProduct.unit || '',
        complemento,
        quantidade,
      });
      resetPicked(overlay);
      overlay.querySelector('#rr-search').value = '';
      overlay.querySelector('#rr-results').innerHTML = '';
      overlay.querySelector('#rr-status').textContent = '';
      renderCart(overlay);
    }
  });

  function renderCart(overlay) {
    const body = overlay.querySelector('#rr-cart-body');
    overlay.querySelector('#rr-count').textContent = cart.length;
    overlay.querySelector('#rr-launch').disabled = cart.length === 0;
    body.innerHTML = cart.length ? cart.map((it, i) => `
      <tr>
        <td>${it.name}</td>
        <td>${it.complemento || '—'}</td>
        <td>${it.quantidade} ${it.unit}</td>
        <td><button class="rr-btn ghost small" data-i="${i}" type="button">🗑</button></td>
      </tr>`).join('') : '<tr><td colspan="4" style="color:#888">Nenhum item ainda.</td></tr>';
    body.querySelectorAll('button[data-i]').forEach((btn) => {
      btn.onclick = () => { cart.splice(Number(btn.dataset.i), 1); renderCart(overlay); };
    });
  }

  async function launch(overlay) {
    const costCenterId = overlay.querySelector('#rr-cc').value;
    const referenceCategoryId = overlay.querySelector('#rr-cat').value;
    const observation = overlay.querySelector('#rr-obs').value.trim();

    if (!costCenterId || !referenceCategoryId) {
      overlay.querySelector('#rr-status').textContent = 'Selecione obra, centro de custo e categoria antes de lançar.';
      return;
    }

    // A API espera texto ou o campo ausente pra observação/complemento — nunca "null".
    const payload = {
      baseStatus: 'created',
      costCenterId: Number(costCenterId),
      referenceCategoryId: Number(referenceCategoryId),
      ...(observation ? { observation } : {}),
      items: cart.map((it) => {
        const item = { productId: it.productId, quantity: Number(it.quantidade) };
        if (it.complemento) item.complement = it.complemento;
        return item;
      }),
    };

    const summary = `Itens: ${cart.length}\n` + cart.map((it) => `- ${it.name} x${it.quantidade}${it.complemento ? ' (' + it.complemento + ')' : ''}`).join('\n') +
      `\n\nConfirma o lançamento desta requisição como rascunho?`;
    if (!confirm(summary)) return;

    const status = overlay.querySelector('#rr-status');
    status.textContent = 'Enviando...';
    try {
      const result = await api('/purchaserequests', { method: 'POST', body: JSON.stringify(payload) });
      status.textContent = `Requisição #${result.id} criada como rascunho. Fechando em 3s...`;
      cart = [];
      setTimeout(() => overlay.remove(), 3000);
    } catch (e) {
      status.textContent = 'Erro ao lançar: ' + e.message;
    }
  }
})();
