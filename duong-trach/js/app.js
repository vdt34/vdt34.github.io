/**
 * Tổng Hợp Dương Trạch Web App (UTC+7 · 2014–2099)
 * Fully synchronized across all 8 tabs with localStorage persistence.
 */
(function () {
  'use strict';

  const STORAGE_KEY = 'duong_trach_utc7_state_v1';

  const GOOD_KW = [
    'sinh khí', 'thiên y', 'diên niên', 'phục vị', 'không phạm', 'tốt',
    'chính kim', 'thiên lộc', 'quý nhân', 'thiên mã', 'điền trạch',
    'diên thọ', 'dịch mã', 'song tinh', 'n.long', 't.hổ'
  ];
  const BAD_KW = [
    'tuyệt mệnh', 'ngũ quỷ', 'lục sát', 'họa hại', 'phạm ', 'xấu',
    'cô hư', 'kiêng bếp', 'đại sát', 'thiên hình', 'độc hỏa', 'kiếp tài', 'bại'
  ];

  function sentiment(txt) {
    const t = (txt || '').trim().toLowerCase();
    if (!t) return 'neutral';
    if (t.includes('không phạm')) return 'good';
    for (const kw of BAD_KW) if (t.includes(kw)) return 'bad';
    for (const kw of GOOD_KW) if (t.includes(kw)) return 'good';
    return 'neutral';
  }

  function esc(s) {
    return String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }

  function badgeHTML(text, force) {
    const clean = (text || '').trim();
    if (!clean) return '<span class="badge neutral">—</span>';
    const cls = force || sentiment(clean);
    return `<span class="badge ${cls}">${esc(clean)}</span>`;
  }

  function daysInSolarMonth(y, m) {
    return new Date(y, m, 0).getDate();
  }

  let eng = null;
  let leapMapLC = {};
  let tietRawList = [];
  let hoaGiapList = [];
  let calState = null;

  const $ = (id) => document.getElementById(id);

  // ============================================================================
  // State Persistence & Global Sync
  // ============================================================================
  function defaultState() {
    const now = new Date();
    const yr = Math.min(2099, Math.max(2014, now.getFullYear()));
    return {
      sync: true,
      bt: { gender: 'Nam', owner: 1950, digger: 1970, year: yr, houseDeg: 156, doorDeg: 137 },
      tst: { year: yr, month: 1 },
      pt: { year: yr, month: 4, day: 'Ất Hợi', tietIdx: 1, birth: 1950, gender: 'Nam' },
      lc: { year: yr, month: 5, leap: false, birth: 1950, gender: 'nam' },
    };
  }

  function loadState() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (raw) {
        const parsed = JSON.parse(raw);
        const def = defaultState();
        return {
          sync: parsed.sync !== undefined ? parsed.sync : def.sync,
          bt: { ...def.bt, ...(parsed.bt || {}) },
          tst: { ...def.tst, ...(parsed.tst || {}) },
          pt: { ...def.pt, ...(parsed.pt || {}) },
          lc: { ...def.lc, ...(parsed.lc || {}) },
        };
      }
    } catch (_) {}
    return defaultState();
  }

  function saveState() {
    try {
      const st = {
        sync: $('chk-global-sync').checked,
        bt: {
          gender: $('bt-gender').value,
          owner: parseInt($('bt-owner').value, 10) || 1950,
          digger: parseInt($('bt-digger').value, 10) || 1970,
          year: parseInt($('bt-year').value, 10) || 2026,
          houseDeg: parseFloat($('bt-house-deg').value) || 0,
          doorDeg: parseFloat($('bt-door-deg').value) || 0,
        },
        tst: {
          year: parseInt($('tst-year').value, 10) || 2026,
          month: parseInt($('tst-month').value, 10) || 1,
        },
        pt: {
          year: parseInt($('pt-year').value, 10) || 2026,
          month: parseInt($('pt-month').value, 10) || 4,
          day: $('pt-day').value,
          tietIdx: $('pt-tiet').selectedIndex,
          birth: parseInt($('pt-birth').value, 10) || 1950,
          gender: $('pt-gender').value,
        },
        lc: {
          year: parseInt($('lc-year').value, 10) || 2026,
          month: parseInt($('lc-month').value, 10) || 5,
          leap: $('lc-leap').checked,
          birth: parseInt($('lc-birth').value, 10) || 1950,
          gender: $('lc-gender').value,
        },
      };
      localStorage.setItem(STORAGE_KEY, JSON.stringify(st));
    } catch (_) {}
  }

  // ============================================================================
  // Navigation (Desktop Sidebar + Mobile Drawer & Pill Tabs)
  // ============================================================================
  function switchTab(tabId) {
    document.querySelectorAll('.tab-panel').forEach(p => p.classList.toggle('active', p.id === 'tab-' + tabId));
    document.querySelectorAll('.nav-btn').forEach(b => b.classList.toggle('active', b.dataset.tab === tabId));
    document.querySelectorAll('.pill-tab').forEach(b => b.classList.toggle('active', b.dataset.tab === tabId));
    closeDrawer();
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  function closeDrawer() {
    $('sidebar').classList.remove('open');
    $('sidebar-backdrop').classList.remove('open');
  }

  // ============================================================================
  // TAB 1: BÁT TRẠCH (+ auto-sync to Tab 2, 3, and optionally 4, 5, 6)
  // ============================================================================
  function updateBatTrach(propagateSync = true) {
    const gender = $('bt-gender').value;
    const owner = Math.min(2099, Math.max(1924, parseInt($('bt-owner').value, 10) || 1950));
    const digger = Math.min(2099, Math.max(1924, parseInt($('bt-digger').value, 10) || 1970));
    const year = Math.min(2099, Math.max(1924, parseInt($('bt-year').value, 10) || 2026));
    const houseDeg = ((parseFloat($('bt-house-deg').value) || 0) % 360 + 360) % 360;
    const doorDeg = ((parseFloat($('bt-door-deg').value) || 0) % 360 + 360) % 360;

    eng.setInputs([
      ['Bát trạch', 'D2', gender],
      ['Bát trạch', 'E2', owner],
      ['Bát trạch', 'E3', digger],
      ['Bát trạch', 'E4', year],
      ['Bát trạch', 'E5', houseDeg],
      ['Bát trạch', 'E6', doorDeg],
    ]);

    renderBatTrach();
    renderHuyenKhong();
    renderTinhThanSat();

    if (propagateSync && $('chk-global-sync').checked) {
      $('tst-year').value = year;
      $('pt-year').value = year;
      $('pt-birth').value = owner;
      $('pt-gender').value = gender;
      if (year >= 2014 && year <= 2099) $('lc-year').value = year;
      $('lc-birth').value = owner;
      $('lc-gender').value = gender.toLowerCase();
      updateThanSatThang(false);
      updatePhiTinh(false);
      updateLeCung(false);
    }
    saveState();
  }

  function renderBatTrach() {
    const s = 'Bát trạch';
    $('bt-owner-cc').textContent = `${eng.getStr(s, 'F2')} · ${eng.getStr(s, 'I2')} tuổi`;
    $('bt-digger-cc').textContent = `${eng.getStr(s, 'F3')} · ${eng.getStr(s, 'I3')} tuổi`;
    $('bt-year-cc').textContent = `Năm ${eng.getStr(s, 'F4')}`;
    $('bt-toa-deg').textContent = `Tọa nhà: ${eng.getStr(s, 'H5')}°`;

    // 3 Direction cards
    const dirs = [
      ['HƯỚNG NHÀ', 'D'],
      ['TỌA NHÀ', 'G'],
      ['HƯỚNG CỬA', 'J'],
    ];
    $('bt-dir-cards').innerHTML = dirs.map(([title, col]) => {
      const deg = eng.getStr(s, col + '10').trim();
      const pv = eng.getStr(s, col + '11').trim();
      const que = eng.getStr(s, col + '12').trim();
      const son = eng.getStr(s, col + '13').trim();
      const pk = eng.getStr(s, col + '14').trim();
      const pkt = eng.getStr(s, col + '15').trim();
      const phoi = eng.getStr(s, col + '16').trim();
      const th = (col === 'D' || col === 'J') ? eng.getStr(s, col + '17').trim() : '';
      return `
        <div class="card">
          <div class="card-title">${title}</div>
          <div class="kv-list compact">
            <div class="kv-row"><span class="kv-key">Độ / Phương vị</span><span class="kv-val">${deg ? esc(deg + '° · ' + pv) : 'Trùng hướng nhà'}</span></div>
            <div class="kv-row"><span class="kv-key">Quẻ / Sơn</span><span class="kv-val">${que ? esc(que + ' — Sơn ' + son) : '—'}</span></div>
            <div class="kv-row"><span class="kv-key">Phân kim</span><span class="kv-val">${esc(pk || '—')}</span></div>
            <div class="kv-row"><span class="kv-key">Tính chất</span><span class="kv-val">${badgeHTML(pkt)}</span></div>
            <div class="kv-row"><span class="kv-key">Phối mệnh chủ</span><span class="kv-val">${badgeHTML(phoi)}</span></div>
            <div class="kv-row"><span class="kv-key">Tam hợp ngũ hành</span><span class="kv-val">${badgeHTML(th)}</span></div>
          </div>
        </div>`;
    }).join('');

    // Tuổi làm nhà
    const ageRows = [
      ['1. Kim Lâu', eng.getStr(s, 'C20')],
      ['2. Hoang Ốc', eng.getStr(s, 'C23')],
      ['3. Tam Tai', eng.getStr(s, 'C24')],
      ['4. Trạch Tuổi', eng.getStr(s, 'C25')],
    ];
    $('bt-age-list').innerHTML = ageRows.map(([k, v]) =>
      `<div class="kv-row"><span class="kv-key">${k}</span><span class="kv-val">${badgeHTML(v)}</span></div>`
    ).join('');

    // Năm làm nhà
    const yrRows = [
      ['1. Thái Tuế', eng.getStr(s, 'C28'), null],
      ['2. Ngũ Hoàng Sát', eng.getStr(s, 'A29').replace('2. Ngũ hoàng sát: ', ''), null],
      ['3. Mậu Kỷ Đô Thiên', eng.getStr(s, 'A30').replace('3. Mậu kỷ đô thiên sát: ', ''), null],
      ['Kị động thổ', eng.getStr(s, 'A31').replace('* Chú ý: ', ''), 'bad'],
      ['4. Tam Sát', eng.getStr(s, 'C32'), null],
      ['5. Bát Sát', eng.getStr(s, 'C33'), null],
    ];
    $('bt-year-list').innerHTML = yrRows.map(([k, v, f]) =>
      `<div class="kv-row"><span class="kv-key">${k}</span><span class="kv-val">${badgeHTML(v, f)}</span></div>`
    ).join('');

    // Bếp Lục Diệu
    const cols = ['D', 'E', 'F', 'G', 'H', 'I', 'J', 'K'];
    const ths = ['Nhất Long 1', 'Nhất Long 2', 'Nhất Long 3', 'Nhất Long 4', 'Tứ Hổ 1', 'Tứ Hổ 2', 'Tứ Hổ 3', 'Tứ Hổ 4'];
    const rowSon = cols.map(c => `<td><strong>${esc(eng.getStr(s, c + '37'))}</strong></td>`).join('');
    const rowKhi = cols.map(c => `<td>${badgeHTML(eng.getStr(s, c + '38'))}</td>`).join('');
    $('bt-bep-table').innerHTML = `
      <thead><tr><th>Mục</th>${ths.map(h => `<th>${h}</th>`).join('')}</tr></thead>
      <tbody>
        <tr><th>Sơn</th>${rowSon}</tr>
        <tr><th>Phối mệnh</th>${rowKhi}</tr>
      </tbody>`;
    $('bt-bep-notes').innerHTML = badgeHTML(eng.getStr(s, 'B40'), 'bad') + badgeHTML(eng.getStr(s, 'B41'), 'bad');
  }

  // ============================================================================
  // TAB 2: HUYỀN KHÔNG - BÁT TRẠCH
  // ============================================================================
  function renderHuyenKhong() {
    const s = 'huyen khong-bat trach';
    const items = [
      ['Hướng nhà', `${eng.getStr(s, 'I1')}° (Sơn ${eng.getStr(s, 'I2')})`],
      ['Tọa nhà', `Sơn ${eng.getStr(s, 'M2')}`],
      ['Kiêm hướng', eng.getStr(s, 'M1').toUpperCase()],
      ['Vận', eng.getStr(s, 'M3')],
      ['Chủ nhà', `${eng.getStr(s, 'I4')} ${eng.getStr(s, 'J4')} (${eng.getStr(s, 'I5')} · Mệnh ${eng.getStr(s, 'K5')})`],
      ['Hướng cửa', `${eng.getStr(s, 'I6')} (${eng.getStr(s, 'M6')})`],
      ['Kiêng bếp', `${eng.getStr(s, 'P2')}, ${eng.getStr(s, 'P4')}, ${eng.getStr(s, 'P5')}`],
    ];
    $('hk-summary').innerHTML = items.map(([k, v]) => `<div class="summary-item"><strong>${k}:</strong> ${esc(v)}</div>`).join('');

    const cungs = [
      ['Đông Nam (Tốn)', 'BE21', 'F13', 'H13', 'F15', 'H15', 'G14', 'G16', false],
      ['Nam (Ly)', 'BE22', 'I13', 'K13', 'I15', 'K15', 'J14', 'J16', false],
      ['Tây Nam (Khôn)', 'BE23', 'L13', 'N13', 'L15', 'N15', 'M14', 'M16', false],
      ['Đông (Chấn)', 'BE20', 'F17', 'H17', 'F19', 'H19', 'G18', 'G20', false],
      ['Trung Cung', null, 'I17', 'K17', 'I19', 'K19', 'J18', 'J20', true],
      ['Tây (Đoài)', 'BE24', 'L17', 'N17', 'L19', 'N19', 'M18', 'M20', false],
      ['Đông Bắc (Cấn)', 'BE19', 'F21', 'H21', 'F23', 'H23', 'G22', 'G24', false],
      ['Bắc (Khảm)', 'BE18', 'I21', 'K21', 'I23', 'K23', 'J22', 'J24', false],
      ['Tây Bắc (Càn)', 'BE25', 'L21', 'N21', 'L23', 'N23', 'M22', 'M24', false],
    ];
    $('hk-board').innerHTML = cungs.map(([name, bt, sc, hc, sk, hk, vc, cc, isCenter]) => {
      const sonV = eng.getStr(s, sc).trim() || eng.getStr(s, sk).trim() || '—';
      const huongV = eng.getStr(s, hc).trim() || eng.getStr(s, hk).trim() || '—';
      const vanV = eng.getStr(s, vc).trim() || '—';
      const btBadge = bt ? badgeHTML(eng.getStr(s, bt)) : badgeHTML('Vận ' + eng.getStr(s, 'M3'), 'gold');
      return `
        <div class="cung-box ${isCenter ? 'center' : ''}">
          <div class="cung-head"><span class="cung-name">${name}</span>${btBadge}</div>
          <div class="hk-stars">
            <span class="hk-son">${esc(sonV)}</span>
            <span class="hk-van">${esc(vanV)}</span>
            <span class="hk-huong">${esc(huongV)}</span>
          </div>
          <div style="text-align:center">${badgeHTML(eng.getStr(s, cc))}</div>
        </div>`;
    }).join('');

    const sonRefs = [
      ['F11','F9','F10','F8'],['G11','G9','G10','G8'],['H11','H9','H10','H8'],
      ['I11','I9','I10','I8'],['J11','J9','J10','J8'],['K11','K9','K10','K8'],
      ['L11','L9','L10','L8'],['M11','M9','M10','M8'],['N11','N9','N10','N8'],
      ['P18','R18','Q18','S18'],['P19','R19','Q19','S19'],['P20','R20','Q20','S20'],
      ['N26','N28','N27','N29'],['M26','M28','M27','M29'],['L26','L28','L27','L29'],
      ['K26','K28','K27','K29'],['J26','J28','J27','J29'],['I26','I28','I27','I29'],
      ['H26','H28','H27','H29'],['G26','G28','G27','G29'],['F26','F28','F27','F29'],
      ['D20','B20','C20','A20'],['D19','B19','C19','A19'],['D18','B18','C18','A18'],
    ];
    $('hk-24son').innerHTML = sonRefs.map(([rS, rL, rQ, rK]) => {
      const son = eng.getStr(s, rS).trim();
      const ld = eng.getStr(s, rL).trim();
      const que = eng.getStr(s, rQ).trim();
      const kb = eng.getStr(s, rK).trim();
      return `
        <div class="son-cell">
          <div class="son-title">${esc(son)}</div>
          ${ld ? `<div class="son-ld">${esc(ld)} (${esc(que)})</div>` : ''}
          ${kb ? `<div class="son-kb">⚠ Kiêng bếp</div>` : ''}
        </div>`;
    }).join('');
  }

  // ============================================================================
  // TAB 3: TÍNH THẦN SÁT
  // ============================================================================
  function renderTinhThanSat() {
    const s = 'tính thần sát';
    $('ts-summary').innerHTML = `
      <div class="summary-item"><strong>Phân kim Hướng:</strong> ${esc(eng.getStr(s, 'B1'))}</div>
      <div class="summary-item"><strong>Phân kim Tọa:</strong> ${esc(eng.getStr(s, 'B2'))}</div>`;

    const cungs = [
      ['Đông Nam (Tốn)', 57, 64, false], ['Nam (Ly)', 1, 8, false], ['Tây Nam (Khôn)', 9, 16, false],
      ['Đông (Chấn)', 49, 56, false], ['Trung Cung', 65, 72, true], ['Tây (Đoài)', 17, 24, false],
      ['Đông Bắc (Cấn)', 41, 48, false], ['Bắc (Khảm)', 33, 40, false], ['Tây Bắc (Càn)', 25, 32, false],
    ];
    $('ts-board').innerHTML = cungs.map(([title, r1, r2, isCenter]) => {
      const tags = [];
      for (let r = r1; r <= r2; r++) {
        const v = eng.getStr(s, 'BA' + r).trim();
        if (v) tags.push(badgeHTML(v));
      }
      return `
        <div class="cung-box ${isCenter ? 'center' : ''}">
          <div class="cung-name">${title}</div>
          <div class="cung-tags">${tags.length ? tags.join('') : '<span class="muted-inline">—</span>'}</div>
        </div>`;
    }).join('');
  }

  // ============================================================================
  // TAB 4: THẦN SÁT THÁNG
  // ============================================================================
  function updateThanSatThang(persist = true) {
    const yr = Math.min(2099, Math.max(1900, parseInt($('tst-year').value, 10) || 2026));
    const m = Math.min(12, Math.max(1, parseInt($('tst-month').value, 10) || 1));
    eng.setInputs([['thần sát tháng', 'B3', yr], ['thần sát tháng', 'B4', m]]);
    const s = 'thần sát tháng';
    $('tst-year-cc').textContent = eng.getStr(s, 'C3');
    $('tst-month-cc').textContent = eng.getStr(s, 'C4');
    const rows = [
      ['Lộc tại', 'B7', 'C7', null],
      ['Mã tại', 'B8', 'C8', null],
      ['+ Quý tại (Dương Quý)', 'B9', 'C9', 'D9'],
      ['- Quý tại (Âm Quý)', 'B10', 'C10', 'D10'],
    ];
    $('tst-table').innerHTML = `
      <thead><tr><th>Thần sát</th><th>Can Chi</th><th>Đáo cung</th><th>Âm / Dương</th></tr></thead>
      <tbody>${rows.map(([lbl, cc, cg, ad]) => `
        <tr>
          <td class="left"><strong>${lbl}</strong></td>
          <td>${esc(eng.getStr(s, cc))}</td>
          <td>${badgeHTML(eng.getStr(s, cg), 'gold')}</td>
          <td>${ad ? esc(eng.getStr(s, ad).trim() || '—') : '—'}</td>
        </tr>`).join('')}</tbody>`;
    if (persist) saveState();
  }

  // ============================================================================
  // TAB 5: TRA PHI TINH
  // ============================================================================
  function updatePhiTinh(persist = true) {
    const yr = Math.min(2099, Math.max(1900, parseInt($('pt-year').value, 10) || 2026));
    const m = Math.min(12, Math.max(1, parseInt($('pt-month').value, 10) || 4));
    const day = $('pt-day').value;
    const tiet = tietRawList[$('pt-tiet').selectedIndex] || tietRawList[0];
    const birth = Math.min(2099, Math.max(1924, parseInt($('pt-birth').value, 10) || 1950));
    const gender = $('pt-gender').value;

    eng.setInputs([
      ['tra phi tinh', 'B2', yr],
      ['tra phi tinh', 'B3', m],
      ['tra phi tinh', 'B4', day],
      ['tra phi tinh', 'B5', tiet],
      ['tra phi tinh', 'B6', birth],
      ['tra phi tinh', 'B7', gender],
    ]);

    const s = 'tra phi tinh';
    $('pt-year-info').textContent = `${eng.getStr(s, 'C2')} · Sao ${eng.getStr(s, 'D2')}`;
    $('pt-month-info').textContent = `Sao ${eng.getStr(s, 'D3')}`;
    $('pt-day-info').textContent = `Sao ${eng.getStr(s, 'D4')}`;
    $('pt-menh').textContent = `${eng.getStr(s, 'C6')} · ${eng.getStr(s, 'C7')}`;

    const specs = [
      ['PHI TINH NĂM', 13, ['A13','C12','E13','A14',null,'E14','A15','C16','E15']],
      ['PHI TINH THÁNG', 20, ['A20','C19','E20','A21',null,'E21','A22','C23','E22']],
      ['PHI TINH NGÀY', 27, ['A27','C26','E27','A28',null,'E28','A29','C30','E29']],
    ];
    const titles = ['ĐN (Tốn)','Nam (Ly)','TN (Khôn)','Đông (Chấn)','Trung','Tây (Đoài)','ĐB (Cấn)','Bắc (Khảm)','TB (Càn)'];
    const cols = ['B', 'C', 'D'];
    $('pt-boards').innerHTML = specs.map(([title, baseR, khiCells]) => {
      const cellsHTML = titles.map((ct, idx) => {
        const rr = Math.floor(idx / 3), cc = idx % 3;
        const star = eng.getStr(s, cols[cc] + (baseR + rr));
        const kc = khiCells[idx];
        const kb = kc ? badgeHTML(eng.getStr(s, kc)) : badgeHTML('Trung cung', 'gold');
        return `<div class="pt-cell ${idx === 4 ? 'center' : ''}">
          <span class="pt-cung">${ct}</span>
          <span class="pt-star">${esc(star)}</span>
          <span>${kb}</span>
        </div>`;
      }).join('');
      return `<div class="card"><div class="card-title">${title}</div><div class="pt-mini-grid">${cellsHTML}</div></div>`;
    }).join('');
    if (persist) saveState();
  }

  // ============================================================================
  // TAB 6: LỆ CUNG NIÊN VẬN ĐỒ (2014–2099)
  // ============================================================================
  function syncLeCungLeapUI() {
    const yr = Math.min(2099, Math.max(2014, parseInt($('lc-year').value, 10) || 2026));
    const m = Math.min(12, Math.max(1, parseInt($('lc-month').value, 10) || 1));
    const lm = leapMapLC[yr];
    if (lm !== undefined) {
      $('lc-leap-hint').textContent = `Năm ${yr} nhuận tháng ${lm}`;
      const can = (m === lm);
      $('lc-leap').disabled = !can;
      if (!can) $('lc-leap').checked = false;
    } else {
      $('lc-leap-hint').textContent = `Năm ${yr} không nhuận`;
      $('lc-leap').disabled = true;
      $('lc-leap').checked = false;
    }
  }

  function updateLeCung(persist = true) {
    syncLeCungLeapUI();
    const yr = Math.min(2099, Math.max(2014, parseInt($('lc-year').value, 10) || 2026));
    const m = Math.min(12, Math.max(1, parseInt($('lc-month').value, 10) || 1));
    const mVal = $('lc-leap').checked ? `${m}N` : m;
    const birth = Math.min(2099, Math.max(1924, parseInt($('lc-birth').value, 10) || 2000));
    const gender = $('lc-gender').value;

    eng.setInputs([
      ['lệ cung niên vận đồ', 'C5', yr],
      ['lệ cung niên vận đồ', 'C6', mVal],
      ['lệ cung niên vận đồ', 'C9', birth],
      ['lệ cung niên vận đồ', 'C10', gender],
    ]);

    const s = 'lệ cung niên vận đồ';
    $('lc-year-cc').textContent = eng.getStr(s, 'D5');
    const nh = eng.getStr(s, 'E6').trim();
    $('lc-month-cc').textContent = (eng.getStr(s, 'D6') + ' ' + nh).trim();
    $('lc-day1').textContent = 'Mùng 1: ' + eng.getStr(s, 'C7');
    $('lc-birth-cc').textContent = eng.getStr(s, 'D9');
    $('lc-menh').textContent = 'Mệnh: ' + eng.getStr(s, 'C11');

    const cungs = [
      ['Tốn (Đông Nam)', 'B15', ['B16','B17','B18','B19'], false],
      ['Ly (Nam)', 'D15', ['D16','D17','D18','D19'], false],
      ['Khôn (Tây Nam)', 'F15', ['F16','F17','F18','F19'], false],
      ['Chấn (Đông)', 'B20', ['B21','B22','B23','B24'], false],
      ['Trung Cung', 'D20', ['D21','D22','D23','D24'], true],
      ['Đoài (Tây)', 'F20', ['F21','F22','F23','F24'], false],
      ['Cấn (Đông Bắc)', 'B25', ['B26','B27','B28','B29'], false],
      ['Khảm (Bắc)', 'D25', ['D26','D27','D28','D29'], false],
      ['Càn (Tây Bắc)', 'F25', ['F26','F27','F28','F29'], false],
    ];
    $('lc-board').innerHTML = cungs.map(([title, kc, dcs, isCenter]) => {
      const days = dcs.map(c => eng.getStr(s, c).trim()).filter(Boolean);
      return `
        <div class="cung-box ${isCenter ? 'center' : ''}">
          <div class="cung-head">
            <span class="cung-name">${title}</span>
            ${badgeHTML(eng.getStr(s, kc))}
          </div>
          <div class="cung-days">${days.map(d => `<div>${esc(d)}</div>`).join('')}</div>
        </div>`;
    }).join('');
    if (persist) saveState();
  }

  // ============================================================================
  // TAB 7: CHỌN GIỜ (Static tables from workbook)
  // ============================================================================
  function renderChonGio() {
    const s = 'chọn giờ';
    const h1 = ['A2', 'E2', 'I2'].map(c => `<th>${esc(eng.getStr(s, c))}</th>`).join('');
    let b1 = '';
    for (let r = 3; r <= 10; r++) {
      b1 += '<tr>' + ['A', 'E', 'I'].map(col => {
        const v = eng.getStr(s, col + r);
        return r >= 7 ? `<td><strong style="color:var(--good-fg)">${esc(v)}</strong></td>` : `<td>${esc(v)}</td>`;
      }).join('') + '</tr>';
    }
    $('cg-tudaicat').innerHTML = `<thead><tr>${h1}</tr></thead><tbody>${b1}</tbody>`;

    const cols13 = ['A','B','C','D','E','F','G','H','I','J','K','L','M'];
    const h2 = ['Can ngày'].concat(cols13.slice(1).map(c => eng.getStr(s, c + '13').replace(/\n/g, ' ').trim()));
    let b2 = '';
    for (let r = 14; r <= 33; r++) {
      b2 += '<tr>' + cols13.map((col, idx) => {
        const v = eng.getStr(s, col + r).trim();
        return idx === 0 && v ? `<td><strong>${esc(v)}</strong></td>` : `<td>${esc(v)}</td>`;
      }).join('') + '</tr>';
    }
    $('cg-quynhan').innerHTML = `<thead><tr>${h2.map(h => `<th>${esc(h)}</th>`).join('')}</tr></thead><tbody>${b2}</tbody>`;

    let vongHTML = '';
    for (let r = 35; r <= 46; r++) {
      const txt = eng.getStr(s, 'A' + r);
      const cls = txt.toLowerCase().includes('không tốt') ? 'bad' : 'good';
      vongHTML += `<div class="vong-item ${cls}">${esc(txt)}</div>`;
    }
    $('cg-vong').innerHTML = vongHTML;
  }

  // ============================================================================
  // TAB 8: LỊCH ÂM – ĐỔI NGÀY (UTC+7, 1900–2100)
  // ============================================================================
  function initLichAm() {
    const now = new Date();
    const today = [now.getDate(), now.getMonth() + 1, now.getFullYear()];
    calState = { today, sel: today, viewM: today[1], viewY: today[2] };

    $('cal-month').innerHTML = Array.from({ length: 12 }, (_, i) => `<option value="${i + 1}">Tháng ${i + 1}</option>`).join('');
    $('cal-month').value = String(calState.viewM);
    $('cal-year').value = calState.viewY;

    $('cal-prev').addEventListener('click', () => {
      calState.viewM--;
      if (calState.viewM < 1) { calState.viewM = 12; calState.viewY = Math.max(1900, calState.viewY - 1); }
      syncCalNav();
    });
    $('cal-next').addEventListener('click', () => {
      calState.viewM++;
      if (calState.viewM > 12) { calState.viewM = 1; calState.viewY = Math.min(2100, calState.viewY + 1); }
      syncCalNav();
    });
    $('cal-today').addEventListener('click', () => selectSolarDate(...calState.today, true));
    $('cal-month').addEventListener('change', () => { calState.viewM = parseInt($('cal-month').value, 10); renderCalendar(); });
    $('cal-year').addEventListener('input', () => {
      const y = parseInt($('cal-year').value, 10);
      if (y >= 1900 && y <= 2100) { calState.viewY = y; renderCalendar(); }
    });

    ['s2l-d', 's2l-m', 's2l-y'].forEach(id => $(id).addEventListener('input', updateS2L));
    ['l2s-d', 'l2s-m', 'l2s-y', 'l2s-leap'].forEach(id => $(id).addEventListener('input', updateL2S));
    $('l2s-leap').addEventListener('change', updateL2S);

    $('btn-s2l-pick').addEventListener('click', () => {
      const d = parseInt($('s2l-d').value, 10), m = parseInt($('s2l-m').value, 10), y = parseInt($('s2l-y').value, 10);
      if (y >= 1900 && y <= 2100 && m >= 1 && m <= 12) selectSolarDate(Math.min(daysInSolarMonth(y, m), Math.max(1, d)), m, y, true);
    });
    $('btn-l2s-pick').addEventListener('click', () => {
      const d = parseInt($('l2s-d').value, 10), m = parseInt($('l2s-m').value, 10), y = parseInt($('l2s-y').value, 10);
      const ll = $('l2s-leap').checked ? 1 : 0;
      const sol = LunarVN.lunarToSolar(d, m, y, ll);
      if (sol) selectSolarDate(...sol, true);
    });

    $('btn-jump-lecung').addEventListener('click', () => {
      const [, lm, ly, ll] = LunarVN.solarToLunar(...calState.sel);
      if (ly >= 2014 && ly <= 2099) {
        $('lc-year').value = ly;
        $('lc-month').value = lm;
        syncLeCungLeapUI();
        $('lc-leap').checked = Boolean(ll) && !$('lc-leap').disabled;
        updateLeCung();
        switchTab('lecung');
      }
    });
    $('btn-jump-phitinh').addEventListener('click', () => {
      const info = LunarVN.getDayInfo(...calState.sel);
      const [, lm, ly] = info.lunar;
      if (ly >= 1900 && ly <= 2099) {
        $('pt-year').value = ly;
        $('pt-month').value = lm;
        const idx = hoaGiapList.findIndex(hg => hg.toLowerCase() === info.canchiDay.toLowerCase());
        if (idx >= 0) $('pt-day').selectedIndex = idx;
        updatePhiTinh();
        switchTab('phitinh');
      }
    });
    $('btn-jump-tst').addEventListener('click', () => {
      const [, lm, ly] = LunarVN.solarToLunar(...calState.sel);
      if (ly >= 1900 && ly <= 2099) {
        $('tst-year').value = ly;
        $('tst-month').value = lm;
        updateThanSatThang();
        switchTab('thansatthang');
      }
    });

    selectSolarDate(...calState.sel, true);
  }

  function syncCalNav() {
    $('cal-month').value = String(calState.viewM);
    $('cal-year').value = calState.viewY;
    renderCalendar();
  }

  function selectSolarDate(dd, mm, yy, syncConv = false) {
    calState.sel = [dd, mm, yy];
    if (mm !== calState.viewM || yy !== calState.viewY) {
      calState.viewM = mm;
      calState.viewY = yy;
      syncCalNav();
    } else {
      renderCalendar();
    }
    renderDayDetail();
    if (syncConv) {
      $('s2l-y').value = yy;
      $('s2l-m').value = mm;
      $('s2l-d').max = daysInSolarMonth(yy, mm);
      $('s2l-d').value = dd;

      const [ld, lm, ly, ll] = LunarVN.solarToLunar(dd, mm, yy);
      $('l2s-y').value = ly;
      $('l2s-m').value = lm;
      $('l2s-leap').checked = Boolean(ll);
      $('l2s-d').value = ld;
      updateS2L();
      updateL2S();
    }
  }

  function renderCalendar() {
    const firstJD = LunarVN.jdFromDate(1, calState.viewM, calState.viewY);
    const firstWD = ((firstJD % 7) + 7) % 7; // 0=Mon .. 6=Sun
    const startJD = firstJD - firstWD;

    let html = '';
    for (let i = 0; i < 42; i++) {
      const jd = startJD + i;
      const [dd, mm, yy] = LunarVN.jdToDate(jd);
      const [ld, lm, , ll] = LunarVN.solarToLunar(dd, mm, yy);
      const hd = LunarVN.getNgayHoangDao(lm, jd);
      const leapTag = ll ? 'N' : '';
      const dot = hd.isHD ? ' ●' : '';
      const lunStr = ld === 1 ? `${ld}/${lm}${leapTag}${dot}` : `${ld}${dot}`;

      const cls = ['cal-day'];
      if (dd === calState.sel[0] && mm === calState.sel[1] && yy === calState.sel[2]) cls.push('selected');
      else if (dd === calState.today[0] && mm === calState.today[1] && yy === calState.today[2]) cls.push('today');
      else if (mm !== calState.viewM) cls.push('other');
      else if (ld === 1) cls.push('lunar1');
      else if (i % 7 === 6) cls.push('sunday');

      html += `<button class="${cls.join(' ')}" data-d="${dd}" data-m="${mm}" data-y="${yy}">
        <span class="d-sol">${dd}</span>
        <span class="d-lun">${lunStr}</span>
      </button>`;
    }
    const grid = $('cal-grid');
    grid.innerHTML = html;
    grid.querySelectorAll('.cal-day').forEach(btn => {
      btn.addEventListener('click', () => {
        selectSolarDate(parseInt(btn.dataset.d, 10), parseInt(btn.dataset.m, 10), parseInt(btn.dataset.y, 10), true);
      });
    });
  }

  function renderDayDetail() {
    const [dd, mm, yy] = calState.sel;
    const info = LunarVN.getDayInfo(dd, mm, yy);
    const [ld, lm, ly, ll] = info.lunar;
    const leapTxt = ll ? ' (nhuận)' : '';
    const mlenTxt = info.lunarMonthLen === 30 ? 'đủ 30 ngày' : 'thiếu 29 ngày';

    $('det-solar').textContent = `${info.weekday}, ${String(dd).padStart(2, '0')}/${String(mm).padStart(2, '0')}/${yy}`;
    const hdEl = $('det-hd');
    hdEl.textContent = info.hd.label;
    hdEl.className = 'badge ' + (info.hd.isHD ? 'good' : 'bad');
    $('det-lunar').textContent = `Âm lịch: ${String(ld).padStart(2, '0')}/${String(lm).padStart(2, '0')}/${ly}${leapTxt} (tháng ${mlenTxt}) · Năm ${info.canchiYear}`;

    const trucTag = info.truc.rate === 'good' ? 'Tốt' : (info.truc.rate === 'bad' ? 'Xấu' : 'Trung bình');
    const saoTag = info.sao.good ? 'Cát tú' : 'Hung tú';
    $('det-kv').innerHTML = `
      <div class="kv-row"><span class="kv-key">Can Chi</span><span class="kv-val">Ngày ${esc(info.canchiDay)} · Tháng ${esc(info.canchiMonth)}${leapTxt}</span></div>
      <div class="kv-row"><span class="kv-key">Nạp âm</span><span class="kv-val">${esc(info.napAm)}</span></div>
      <div class="kv-row"><span class="kv-key">Tiết khí</span><span class="kv-val">${badgeHTML(info.tietKhi, 'good')}</span></div>
      <div class="kv-row"><span class="kv-key">Trực</span><span class="kv-val">${badgeHTML(`Trực ${info.truc.name} (${trucTag})`, info.truc.rate)}<div class="det-desc">${esc(info.truc.desc)}</div></span></div>
      <div class="kv-row"><span class="kv-key">28 Sao</span><span class="kv-val">${badgeHTML(`Sao ${info.sao.shortName} · ${info.sao.fullName} (${saoTag})`, info.sao.good ? 'good' : 'bad')}<div class="det-desc">${esc(info.sao.desc)}</div></span></div>
      <div class="kv-row"><span class="kv-key">Xung / Xuất hành</span><span class="kv-val">${esc(info.xungKhac)}<div class="det-desc">Hỷ Thần: ${esc(info.hyThan)} · Tài Thần: ${esc(info.taiThan)}</div></span></div>`;

    $('det-ghd').textContent = 'Giờ Hoàng Đạo: ' + info.gioHoangDao.join(' · ');
    $('btn-jump-lecung').disabled = !(ly >= 2014 && ly <= 2099);
    $('btn-jump-phitinh').disabled = !(ly >= 1900 && ly <= 2099);
    $('btn-jump-tst').disabled = !(ly >= 1900 && ly <= 2099);
  }

  function updateS2L() {
    const yy = parseInt($('s2l-y').value, 10), mm = parseInt($('s2l-m').value, 10);
    if (!yy || yy < 1900 || yy > 2100 || !mm || mm < 1 || mm > 12) return;
    const maxD = daysInSolarMonth(yy, mm);
    $('s2l-d').max = maxD;
    let dd = parseInt($('s2l-d').value, 10) || 1;
    if (dd > maxD) { dd = maxD; $('s2l-d').value = dd; }
    const info = LunarVN.getDayInfo(dd, mm, yy);
    const [ld, lm, ly, ll] = info.lunar;
    $('s2l-res').innerHTML = `Âm lịch: <strong>${String(ld).padStart(2, '0')}/${String(lm).padStart(2, '0')}/${ly}${ll ? ' (Nhuận)' : ''}</strong> (${info.weekday}) · ${esc(info.hd.label)}<br/>Ngày ${esc(info.canchiDay)} · Trực ${esc(info.truc.name)} · Sao ${esc(info.sao.fullName)}`;
  }

  function updateL2S() {
    const ly = parseInt($('l2s-y').value, 10), lm = parseInt($('l2s-m').value, 10);
    if (!ly || ly < 1900 || ly > 2100 || !lm || lm < 1 || lm > 12) return;
    const leapM = LunarVN.getYearLeapMonth(ly);
    const canLeap = (leapM !== null && lm === leapM);
    $('l2s-leap').disabled = !canLeap;
    $('l2s-leap').title = leapM ? `Năm ${ly} có tháng ${leapM} nhuận` : `Năm ${ly} không nhuận`;
    if (!canLeap) $('l2s-leap').checked = false;

    const ll = $('l2s-leap').checked ? 1 : 0;
    const mlen = LunarVN.getLunarMonthLength(lm, ly, ll);
    if (mlen === 29 || mlen === 30) $('l2s-d').max = mlen;
    let ld = parseInt($('l2s-d').value, 10) || 1;
    if (mlen && ld > mlen) { ld = mlen; $('l2s-d').value = ld; }

    const sol = LunarVN.lunarToSolar(ld, lm, ly, ll);
    if (!sol) { $('l2s-res').textContent = 'Ngày âm lịch không hợp lệ.'; return; }
    const info = LunarVN.getDayInfo(...sol);
    $('l2s-res').innerHTML = `Dương lịch: <strong>${info.weekday}, ${String(sol[0]).padStart(2, '0')}/${String(sol[1]).padStart(2, '0')}/${sol[2]}</strong> · ${esc(info.hd.label)}<br/>Ngày ${esc(info.canchiDay)} · Trực ${esc(info.truc.name)} · Sao ${esc(info.sao.fullName)}`;
  }

  // ============================================================================
  // Bootstrap
  // ============================================================================
  async function init() {
    try {
      const resp = await fetch('data/workbook.json');
      if (!resp.ok) throw new Error('HTTP ' + resp.status);
      const data = await resp.json();
      eng = new WorkbookEngine(data);

      // Build leap map for Lệ Cung 2014..2099
      for (let yr = 2014; yr <= 2099; yr++) {
        const v = eng.get('lệ cung niên vận đồ', 'AZ' + (110 + (yr - 2014)));
        if (v !== null && v !== '' && Number(v) > 0) leapMapLC[yr] = Number(v);
      }

      // Populate Tra Phi Tinh dropdowns
      hoaGiapList = [];
      for (let r = 3; r <= 62; r++) hoaGiapList.push(eng.getStr('tra phi tinh', 'I' + r));
      $('pt-day').innerHTML = hoaGiapList.map(h => `<option value="${esc(h)}">${esc(h)}</option>`).join('');

      tietRawList = ['J', 'K', 'L', 'M', 'N', 'O'].map(c => eng.getStr('tra phi tinh', c + '2'));
      $('pt-tiet').innerHTML = tietRawList.map(raw => {
        const clean = raw.replace(/\n/g, ' ').replace(/\s+/g, ' ').trim();
        return `<option>${esc(clean)}</option>`;
      }).join('');

      // Restore saved state
      const st = loadState();
      $('chk-global-sync').checked = st.sync;
      $('bt-gender').value = st.bt.gender;
      $('bt-owner').value = st.bt.owner;
      $('bt-digger').value = st.bt.digger;
      $('bt-year').value = st.bt.year;
      $('bt-house-deg').value = st.bt.houseDeg;
      $('bt-door-deg').value = st.bt.doorDeg;

      $('tst-year').value = st.tst.year;
      $('tst-month').value = st.tst.month;

      $('pt-year').value = st.pt.year;
      $('pt-month').value = st.pt.month;
      $('pt-day').value = st.pt.day;
      $('pt-tiet').selectedIndex = Math.max(0, Math.min(5, st.pt.tietIdx || 0));
      $('pt-birth').value = st.pt.birth;
      $('pt-gender').value = st.pt.gender;

      $('lc-year').value = st.lc.year;
      $('lc-month').value = st.lc.month;
      $('lc-birth').value = st.lc.birth;
      $('lc-gender').value = st.lc.gender;

      // Wire events
      document.querySelectorAll('.nav-btn, .pill-tab').forEach(btn => {
        btn.addEventListener('click', () => switchTab(btn.dataset.tab));
      });
      $('btn-menu').addEventListener('click', () => {
        $('sidebar').classList.toggle('open');
        $('sidebar-backdrop').classList.toggle('open');
      });
      $('sidebar-backdrop').addEventListener('click', closeDrawer);

      const doReset = () => {
        localStorage.removeItem(STORAGE_KEY);
        location.reload();
      };
      $('btn-reset').addEventListener('click', doReset);
      $('btn-reset-mobile').addEventListener('click', doReset);
      $('chk-global-sync').addEventListener('change', saveState);

      ['bt-gender', 'bt-owner', 'bt-digger', 'bt-year', 'bt-house-deg', 'bt-door-deg'].forEach(id => {
        $(id).addEventListener('input', () => updateBatTrach(true));
        $(id).addEventListener('change', () => updateBatTrach(true));
      });
      ['tst-year', 'tst-month'].forEach(id => $(id).addEventListener('input', () => updateThanSatThang(true)));
      ['pt-year', 'pt-month', 'pt-day', 'pt-tiet', 'pt-birth', 'pt-gender'].forEach(id => {
        $(id).addEventListener('input', () => updatePhiTinh(true));
        $(id).addEventListener('change', () => updatePhiTinh(true));
      });
      ['lc-year', 'lc-month', 'lc-birth', 'lc-gender'].forEach(id => {
        $(id).addEventListener('input', () => updateLeCung(true));
        $(id).addEventListener('change', () => updateLeCung(true));
      });
      $('lc-leap').addEventListener('change', () => updateLeCung(true));

      // Initial renders
      updateBatTrach(false);
      updateThanSatThang(false);
      updatePhiTinh(false);
      syncLeCungLeapUI();
      $('lc-leap').checked = st.lc.leap && !$('lc-leap').disabled;
      updateLeCung(false);
      renderChonGio();
      initLichAm();

      $('loading-overlay').classList.add('hidden');
    } catch (err) {
      $('loading-overlay').innerHTML = `<div class="loading-box"><strong style="color:#b91c1c">Lỗi tải dữ liệu:</strong><br/>${esc(err.message)}</div>`;
      console.error(err);
    }
  }

  document.addEventListener('DOMContentLoaded', init);
})();
