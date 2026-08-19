// ==UserScript==
// @name         Diário de Obra Rápido - L7 Build Manager
// @namespace    obra-check-luiz
// @version      1.0.0
// @description  Painel rápido para lançar o Diário de Obra direto na API, com sugestão automática de atividades a partir do efetivo lançado.
// @match        https://build-manager-api-snriv.ondigitalocean.app/*
// @run-at       document-start
// @grant        none
// ==/UserScript==

(function () {
  'use strict';

  const API = 'https://build-manager-api-snriv.ondigitalocean.app/api/v1';

  // Função (efetivo) -> atividade única, sempre marcada quando a contagem > 0.
  const FIXED_MAPPING = {
    'Eletricista': ['Instalação elétrica'],
    'Encanador': ['Instalação hidráulica'],
    'Armador': ['Execução de armadura'],
    'Carpinteiro': ['Execução de formas'],
    'Pintor': ['Execução de pintura'],
  };

  // Função -> possíveis atividades, sugeridas (desmarcadas) quando a contagem > 0.
  // Você decide na hora quais realmente aconteceram naquele dia.
  const SUGGESTED_MAPPING = {
    'Gesseiro': ['Execução de gesso acartonado', 'Execução de gesso corrido'],
    'Pedreiro': ['Execução de piso cerâmico', 'Execução de revestimento parede', 'Execução de rejunte', 'Execução de alvenaria', 'Assentamento de bancada'],
    'Azulejista': ['Execução de piso cerâmico', 'Execução de revestimento parede', 'Execução de rejunte'],
    'Instalador': ['Execução de infra do ar condicionado'],
  };

  // Funções que nunca geram atividade automática (apoio/gestão).
  const NO_AUTO_ACTIVITY = new Set([
    'Servente', 'Ajudante', 'Mestre de Obra', 'Encarregado de Obras', 'Engenheiro',
    'Almoxarife', 'Operador de Betoneira', 'Operador de Elevador', 'Auxiliar de Engenharia', 'Estagiário',
  ]);

  const DEFAULT_BUILDING_NAME = 'Arsen Sabiá';

  // ---- Persistência local (efetivo direto, equipamentos, ferramentas e atividades ensinadas) ----
  const LS_PREFIX = 'ddo_';
  function lsGet(key, fallback) {
    try { const v = localStorage.getItem(LS_PREFIX + key); return v ? JSON.parse(v) : fallback; }
    catch (e) { return fallback; }
  }
  function lsSet(key, value) {
    try { localStorage.setItem(LS_PREFIX + key, JSON.stringify(value)); } catch (e) {}
  }
  function learnedMapping() { return lsGet('learnedMapping', {}); }
  function learnMapping(role, activity) {
    const map = learnedMapping();
    map[role] = map[role] || [];
    if (!map[role].includes(activity)) map[role].push(activity);
    lsSet('learnedMapping', map);
  }

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
    if (!authToken) {
      throw new Error('Token ainda não capturado. Navegue pela tela do Diário de Obra uma vez antes de abrir o painel.');
    }
    const isFormData = opts.body instanceof FormData;
    return origFetch(API + path, {
      ...opts,
      headers: {
        'Accept': 'application/json',
        ...(isFormData ? {} : { 'Content-Type': 'application/json' }),
        'Authorization': authToken,
        ...(opts.headers || {}),
      },
    }).then(async (r) => {
      const text = await r.text();
      const data = text ? JSON.parse(text) : null;
      if (!r.ok) throw new Error((data && data.message) || `Erro HTTP ${r.status}`);
      return data;
    });
  }

  // ---- UI ----
  const style = document.createElement('style');
  style.textContent = `
    #ddo-fab { position: fixed; right: 20px; bottom: 100px; z-index: 999999; background: #1a56c4; color: #fff;
      border: none; border-radius: 999px; padding: 14px 18px; font: 600 14px/1 system-ui, sans-serif;
      box-shadow: 0 4px 14px rgba(0,0,0,.3); cursor: pointer; }
    #ddo-photo-fab { position: fixed; right: 20px; bottom: 40px; z-index: 999999; background: #b3261e; color: #fff;
      border: none; border-radius: 999px; padding: 10px 16px; font: 600 13px/1 system-ui, sans-serif;
      box-shadow: 0 4px 14px rgba(0,0,0,.3); cursor: pointer; }
    #ddo-overlay { position: fixed; inset: 0; background: rgba(0,0,0,.5); z-index: 1000000;
      display: flex; align-items: flex-start; justify-content: center; padding: 30px 16px; overflow: auto; }
    #ddo-panel { background: #fff; width: 640px; max-width: 100%; border-radius: 10px; padding: 20px;
      font: 14px/1.4 system-ui, sans-serif; color: #1a1a1a; }
    #ddo-panel h2 { margin: 0 0 14px; font-size: 18px; }
    #ddo-panel h3 { margin: 18px 0 8px; font-size: 14px; color: #1a56c4; border-top: 1px solid #eee; padding-top: 12px; }
    #ddo-panel label { display: block; font-weight: 600; margin-bottom: 4px; font-size: 12px; color: #444; }
    #ddo-panel select, #ddo-panel input[type=date] { width: 100%; padding: 6px 8px; border: 1px solid #ccc; border-radius: 6px; margin-bottom: 10px; }
    .ddo-row { display: flex; gap: 10px; }
    .ddo-row > div { flex: 1; }
    .ddo-grid { display: grid; grid-template-columns: 1fr 70px; gap: 6px 10px; align-items: center; }
    .ddo-grid input[type=number] { width: 100%; padding: 4px 6px; border: 1px solid #ccc; border-radius: 6px; }
    .ddo-shift { border: 1px solid #eee; border-radius: 8px; padding: 10px; margin-bottom: 8px; }
    .ddo-shift-title { font-weight: 700; margin-bottom: 6px; }
    .ddo-act { display: flex; align-items: center; gap: 8px; padding: 3px 0; font-size: 13px; }
    .ddo-act small { color: #888; margin-left: auto; }
    .ddo-actions { display: flex; justify-content: flex-end; gap: 10px; margin-top: 18px; }
    .ddo-btn { padding: 9px 16px; border-radius: 6px; border: none; font-weight: 600; cursor: pointer; }
    .ddo-btn.primary { background: #1a8f3c; color: #fff; }
    .ddo-btn.ghost { background: #eee; color: #333; }
    #ddo-status { font-size: 13px; margin-top: 10px; white-space: pre-wrap; }
    #ddo-addAct { padding: 5px 8px; border: 1px solid #ccc; border-radius: 6px; flex: 1; }
    #ddo-addActRole { padding: 5px 8px; border: 1px solid #ccc; border-radius: 6px; flex: 0 0 160px; margin: 0; width: auto; }
  `;
  document.head.appendChild(style);

  const fab = document.createElement('button');
  fab.id = 'ddo-fab';
  fab.textContent = '📋 Diário rápido';
  fab.onclick = openPanel;
  document.addEventListener('DOMContentLoaded', () => document.body.appendChild(fab));
  if (document.body) document.body.appendChild(fab);

  // Botão à parte pra adicionar fotos num diário JÁ EXISTENTE. Existe porque o "Salvar"
  // nativo tem um bug: ao editar um diário já criado e anexar fotos ali, elas aparecem
  // na tela mas nunca chegam a ser gravadas no servidor (o array de fotos volta vazio).
  // Isso usa o endpoint dedicado POST /diaries/{id}/photos, que não passa por esse bug.
  const photoFab = document.createElement('button');
  photoFab.id = 'ddo-photo-fab';
  photoFab.textContent = '📷 Adicionar fotos (via API)';
  photoFab.onclick = addPhotosToExistingDiary;
  function mountPhotoFab() { document.body.appendChild(photoFab); }
  if (document.body) mountPhotoFab(); else document.addEventListener('DOMContentLoaded', mountPhotoFab);

  function currentDiaryIdFromUrl() {
    const m = location.pathname.match(/\/obra\/diario\/(\d+)/);
    return m ? Number(m[1]) : null;
  }

  function addPhotosToExistingDiary() {
    const diaryId = currentDiaryIdFromUrl();
    if (!diaryId) {
      alert('Abra um diário já existente primeiro (não a tela de "Novo Diário de Obra") — este botão adiciona fotos a um diário que já foi criado.');
      return;
    }
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = 'image/*';
    input.multiple = true;
    input.style.display = 'none';
    document.body.appendChild(input);
    input.addEventListener('change', async () => {
      const files = [...input.files];
      input.remove();
      if (!files.length) return;
      if (!confirm(`Enviar ${files.length} foto(s) pro diário #${diaryId}?`)) return;
      try {
        const form = new FormData();
        files.forEach((f) => form.append('photos', f));
        await api(`/diaries/${diaryId}/photos`, { method: 'POST', body: form });
        alert(`${files.length} foto(s) enviada(s) com sucesso. Recarregando a página pra atualizar a lista...`);
        location.reload();
      } catch (e) {
        alert('Erro ao enviar fotos: ' + e.message);
      }
    });
    input.click();
  }

  let state = null;

  async function openPanel() {
    const overlay = document.createElement('div');
    overlay.id = 'ddo-overlay';
    overlay.innerHTML = `
      <div id="ddo-panel">
        <h2>Diário de obra rápido</h2>
        <div class="ddo-row">
          <div>
            <label>Obra</label>
            <select id="ddo-obra"><option value="">Carregando...</option></select>
          </div>
          <div>
            <label>Data</label>
            <input type="date" id="ddo-date" value="${new Date().toISOString().slice(0, 10)}">
          </div>
        </div>
        <div id="ddo-body"><p>Selecione a obra para carregar os campos.</p></div>
        <div id="ddo-status"></div>
        <div class="ddo-actions">
          <button class="ddo-btn ghost" id="ddo-cancel">Fechar</button>
          <button class="ddo-btn primary" id="ddo-save" disabled>Salvar diário</button>
        </div>
      </div>`;
    document.body.appendChild(overlay);
    overlay.addEventListener('click', (e) => { if (e.target === overlay) overlay.remove(); });
    overlay.querySelector('#ddo-cancel').onclick = () => overlay.remove();
    overlay.querySelector('#ddo-save').onclick = () => submit(overlay);

    try {
      const buildings = await api('/buildings');
      const sel = overlay.querySelector('#ddo-obra');
      sel.innerHTML = '<option value="">Selecione obra</option>' +
        buildings.results.map(b => `<option value="${b.id}">${b.name.trim()}</option>`).join('');
      sel.onchange = () => loadBuildingSettings(overlay, Number(sel.value));

      const defaultBuilding = buildings.results.find(b => b.name.trim() === DEFAULT_BUILDING_NAME);
      if (defaultBuilding) {
        sel.value = String(defaultBuilding.id);
        await loadBuildingSettings(overlay, defaultBuilding.id);
      }
    } catch (e) {
      overlay.querySelector('#ddo-status').textContent = 'Erro ao carregar obras: ' + e.message;
    }
  }

  async function loadBuildingSettings(overlay, buildingId) {
    const body = overlay.querySelector('#ddo-body');
    const saveBtn = overlay.querySelector('#ddo-save');
    saveBtn.disabled = true;
    if (!buildingId) { body.innerHTML = '<p>Selecione a obra para carregar os campos.</p>'; return; }
    body.innerHTML = '<p>Carregando configuração da obra...</p>';
    const settings = await api(`/diaries/settings/${buildingId}`);
    state = { buildingId, settings, activities: new Map() };

    const shiftsHtml = settings.shifts.map(shift => `
      <div class="ddo-shift" data-shift="${shift}">
        <div class="ddo-shift-title">${shift}</div>
        <div class="ddo-row">
          <div>
            <label>Clima</label>
            <select class="ddo-weather">${settings.weatherConditions.map(w => `<option>${w}</option>`).join('')}</select>
          </div>
          <div>
            <label>Operação</label>
            <select class="ddo-work">${settings.workConditions.map(w => `<option>${w}</option>`).join('')}</select>
          </div>
        </div>
      </div>`).join('');

    const workforceGrid = (list, cls) => `
      <div class="ddo-grid ${cls}">
        ${list.map(type => `<div>${type}</div><input type="number" min="0" value="0" data-type="${type}">`).join('')}
      </div>`;

    const resourceGrid = (list, cls) => `
      <div class="ddo-grid ${cls}">
        ${list.map(type => `<div>${type}</div><input type="number" min="0" value="0" data-type="${type}">`).join('')}
      </div>`;

    body.innerHTML = `
      <h3>Clima e operação</h3>
      ${shiftsHtml}
      <h3>Efetivo direto</h3>
      ${workforceGrid(settings.directWorkforce, 'ddo-direct')}
      <h3>Efetivo indireto</h3>
      ${workforceGrid(settings.indirectWorkforce, 'ddo-indirect')}
      ${settings.enableEquipmentsList ? `<h3>Equipamentos</h3>${resourceGrid(settings.equipments, 'ddo-equip')}` : ''}
      ${settings.enableToolsList ? `<h3>Ferramentas</h3>${resourceGrid(settings.tools, 'ddo-tools')}` : ''}
      <h3>Atividades do dia</h3>
      <div id="ddo-activities"></div>
      <div class="ddo-row" style="margin-top:6px">
        <input id="ddo-addAct" placeholder="Adicionar outra atividade...">
        <select id="ddo-addActRole">
          <option value="">via (nenhuma função)</option>
          ${settings.indirectWorkforce.map(r => `<option value="${r}">via ${r}</option>`).join('')}
        </select>
        <button class="ddo-btn ghost" id="ddo-addActBtn" type="button">+ Adicionar</button>
      </div>
      <h3>Ocorrências</h3>
      <div id="ddo-occ-buttons">
        ${settings.occurrences.map(o => `<button class="ddo-btn ghost ddo-occ-btn" type="button" data-occ="${o}" style="margin:2px">${o}</button>`).join('')}
      </div>
      <div id="ddo-occ-list"></div>
      <h3>Fotos</h3>
      <input type="file" id="ddo-photos" accept="image/*" multiple>
      <div id="ddo-photo-preview" style="margin-top:6px; font-size:12px; color:#666"></div>
    `;

    body.querySelector('#ddo-photos').addEventListener('change', (e) => {
      const preview = body.querySelector('#ddo-photo-preview');
      const files = [...e.target.files];
      preview.textContent = files.length
        ? `${files.length} foto(s) selecionada(s): ${files.map(f => f.name).join(', ')}`
        : '';
    });

    // Restaura o último efetivo direto, equipamentos e ferramentas lançados nesta obra.
    // Efetivo indireto fica sempre zerado, pois varia dia a dia (mão de obra terceirizada).
    const savedResources = lsGet('lastResources_' + buildingId, {});
    ['ddo-direct', 'ddo-equip', 'ddo-tools'].forEach(cls => {
      const saved = savedResources[cls] || {};
      body.querySelectorAll(`.${cls} input`).forEach(inp => {
        if (inp.dataset.type in saved) inp.value = saved[inp.dataset.type];
      });
    });

    body.querySelectorAll('.ddo-direct input, .ddo-indirect input').forEach(inp => {
      inp.addEventListener('input', () => recomputeActivities(body));
    });
    body.querySelector('#ddo-addActBtn').onclick = () => {
      const input = body.querySelector('#ddo-addAct');
      const roleSel = body.querySelector('#ddo-addActRole');
      const text = input.value.trim();
      if (!text) return;
      const role = roleSel.value || undefined;
      state.activities.set(text, { checked: true, manual: true, role });
      if (role) learnMapping(role, text);
      input.value = '';
      roleSel.value = '';
      renderActivities(body);
    };
    body.querySelectorAll('.ddo-occ-btn').forEach(btn => {
      btn.onclick = () => {
        const list = body.querySelector('#ddo-occ-list');
        const row = document.createElement('div');
        row.className = 'ddo-row';
        row.style.marginTop = '6px';
        row.innerHTML = `
          <div style="flex:0 0 160px"><input value="${btn.dataset.occ}" class="ddo-occ-type" readonly></div>
          <div><input placeholder="Relato / descrição" class="ddo-occ-desc"></div>
          <button class="ddo-btn ghost" type="button" style="flex:0 0 auto">x</button>`;
        row.querySelector('button').onclick = () => row.remove();
        list.appendChild(row);
      };
    });

    recomputeActivities(body);
    saveBtn.disabled = false;
  }

  function recomputeActivities(body) {
    const counts = {};
    body.querySelectorAll('.ddo-direct input, .ddo-indirect input').forEach(inp => {
      counts[inp.dataset.type] = Number(inp.value) || 0;
    });
    const learned = learnedMapping();

    for (const [role, count] of Object.entries(counts)) {
      const fixed = FIXED_MAPPING[role];
      const suggested = SUGGESTED_MAPPING[role];
      const taught = learned[role];
      if (fixed) {
        fixed.forEach(act => {
          if (count > 0 && !state.activities.has(act)) state.activities.set(act, { checked: true, auto: true, role });
          if (count === 0 && state.activities.get(act)?.auto) state.activities.delete(act);
        });
      }
      if (suggested) {
        suggested.forEach(act => {
          if (count > 0 && !state.activities.has(act)) state.activities.set(act, { checked: false, auto: true, role });
          if (count === 0 && state.activities.get(act)?.auto) state.activities.delete(act);
        });
      }
      if (taught) {
        taught.forEach(act => {
          if (count > 0 && !state.activities.has(act)) state.activities.set(act, { checked: false, auto: true, learned: true, role });
          if (count === 0 && state.activities.get(act)?.auto) state.activities.delete(act);
        });
      }
    }
    renderActivities(body);
  }

  function renderActivities(body) {
    const container = body.querySelector('#ddo-activities');
    container.innerHTML = [...state.activities.entries()].map(([text, meta]) => `
      <label class="ddo-act">
        <input type="checkbox" data-act="${text}" ${meta.checked ? 'checked' : ''}>
        ${text}
        ${meta.role ? `<small>via ${meta.role}</small>` : ''}
      </label>`).join('') || '<p style="color:#888">Nenhuma atividade sugerida ainda — informe o efetivo acima.</p>';
    container.querySelectorAll('input[type=checkbox]').forEach(cb => {
      cb.onchange = () => { state.activities.get(cb.dataset.act).checked = cb.checked; };
    });
  }

  function collectGrid(body, cls) {
    return [...body.querySelectorAll(`.${cls} input`)]
      .map(inp => ({ type: inp.dataset.type, count: Number(inp.value) || 0 }))
      .filter(x => x.count > 0);
  }

  function collectGridFull(body, cls) {
    const map = {};
    body.querySelectorAll(`.${cls} input`).forEach(inp => { map[inp.dataset.type] = Number(inp.value) || 0; });
    return map;
  }

  function saveResourceSnapshot(body, buildingId) {
    lsSet('lastResources_' + buildingId, {
      'ddo-direct': collectGridFull(body, 'ddo-direct'),
      'ddo-equip': collectGridFull(body, 'ddo-equip'),
      'ddo-tools': collectGridFull(body, 'ddo-tools'),
    });
  }

  function buildPayload(overlay) {
    const body = overlay.querySelector('#ddo-body');
    const buildingId = state.buildingId;
    const date = overlay.querySelector('#ddo-date').value;

    const conditions = [...body.querySelectorAll('.ddo-shift')].map(el => ({
      shift: el.dataset.shift,
      weatherCondition: el.querySelector('.ddo-weather').value,
      workCondition: el.querySelector('.ddo-work').value,
    }));

    const activities = [...state.activities.entries()]
      .filter(([, meta]) => meta.checked)
      .map(([description]) => ({ description, status: 'Em andamento', progress: 0 }));

    const occurrences = [...body.querySelectorAll('#ddo-occ-list .ddo-row')].map(row => ({
      type: row.querySelector('.ddo-occ-type').value,
      description: row.querySelector('.ddo-occ-desc').value,
    }));

    return {
      buildingId,
      date: `${date}T00:00:00.000Z`,
      conditions,
      directWorkforce: collectGrid(body, 'ddo-direct'),
      indirectWorkforce: collectGrid(body, 'ddo-indirect'),
      equipments: collectGrid(body, 'ddo-equip'),
      tools: collectGrid(body, 'ddo-tools'),
      activities,
      occurrences,
    };
  }

  async function submit(overlay) {
    const body = overlay.querySelector('#ddo-body');
    const payload = buildPayload(overlay);
    const photoFiles = [...body.querySelector('#ddo-photos').files];
    const summary = `Obra: ${state.buildingId}\nData: ${payload.date.slice(0, 10)}\n` +
      `Efetivo direto: ${payload.directWorkforce.length} funções\n` +
      `Efetivo indireto: ${payload.indirectWorkforce.length} funções\n` +
      `Atividades: ${payload.activities.map(a => a.description).join(', ') || '(nenhuma)'}\n` +
      `Fotos: ${photoFiles.length}\n\n` +
      `Confirma o lançamento deste diário de obra?`;
    if (!confirm(summary)) return;

    const status = overlay.querySelector('#ddo-status');
    status.textContent = 'Enviando...';
    try {
      const form = new FormData();
      form.append('diary', JSON.stringify(payload));
      photoFiles.forEach(f => form.append('photos', f));
      const result = await api('/diaries', { method: 'POST', body: form });
      saveResourceSnapshot(body, state.buildingId);
      status.textContent = `Diário criado com sucesso (#${result.id}). Fechando em 3s...`;
      setTimeout(() => overlay.remove(), 3000);
    } catch (e) {
      status.textContent = 'Erro ao salvar: ' + e.message + '\n\nPayload enviado:\n' + JSON.stringify(payload, null, 1);
    }
  }
})();
