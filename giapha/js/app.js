/**
 * Gia Pha Viet Nam — Main Application Controller
 */

import { KinshipResolver } from './kinship.js';
import { TreeVisualizer } from './tree-view.js';
import { MemberModalController } from './member-modal.js';
import { BookViewRenderer } from './book-view.js';
import { GraveMapRenderer } from './grave-map.js';
import { DeathAnniversaryManager } from './death-anniversaries.js';

class GiaPhaApp {
  constructor() {
    this.clanData = null;
    this.currentTab = 'tree';
    this.selfId = localStorage.getItem('giapha_self_id') || 'p016'; // Default to Vũ Đình Nam (Đời 4)
    this.searchQuery = '';

    this.treeVisualizer = null;
    this.memberModal = null;
    this.bookRenderer = null;
    this.graveRenderer = null;
    this.anniversaryManager = null;
  }

  async init() {
    this.initTheme();
    await this.loadData();
    this.initControllers();
    this.bindEvents();
    this.renderCurrentView();
  }

  initTheme() {
    const saved = localStorage.getItem('giapha_theme') || (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
    document.documentElement.setAttribute('data-theme', saved);
  }

  toggleTheme() {
    const cur = document.documentElement.getAttribute('data-theme');
    const next = cur === 'dark' ? 'light' : 'dark';
    document.documentElement.setAttribute('data-theme', next);
    localStorage.setItem('giapha_theme', next);
  }

  showToast(msg, type = 'info') {
    const container = document.getElementById('toast-container');
    if (!container) return;
    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;
    toast.textContent = msg;
    container.appendChild(toast);
    setTimeout(() => toast.remove(), 3500);
  }

  async loadData() {
    try {
      const cached = localStorage.getItem('giapha_clan_data');
      if (cached) {
        this.clanData = JSON.parse(cached);
      } else {
        const resp = await fetch('data/clan.json');
        if (resp.ok) {
          this.clanData = await resp.json();
        }
      }
    } catch (e) {
      console.warn('Error loading clan data', e);
    }

    if (!this.clanData) {
      this.clanData = {
        clan_info: { name: 'Gia Phả Dòng Họ' },
        members: []
      };
    }
  }

  saveDataLocally() {
    localStorage.setItem('giapha_clan_data', JSON.stringify(this.clanData));
  }

  initControllers() {
    this.kinship = new KinshipResolver(this.clanData.members);

    this.treeVisualizer = new TreeVisualizer(
      'tree-container',
      (id) => this.memberModal.open(id),
      (id) => this.setSelf(id)
    );

    this.memberModal = new MemberModalController(
      this.clanData,
      this.kinship,
      (updated) => {
        this.saveDataLocally();
        this.treeVisualizer.setData(this.clanData.members, this.selfId);
        this.populateSelfSelector();
        this.showToast(`Đã lưu thành viên: ${updated.name}`, 'success');
      },
      (selfId) => this.setSelf(selfId),
      (deletedId) => {
        this.clanData.members = this.clanData.members.filter(x => x.id !== deletedId);
        for (const m of this.clanData.members) {
          if (m.father_id === deletedId) m.father_id = null;
          if (m.mother_id === deletedId) m.mother_id = null;
          if (m.spouses) m.spouses = m.spouses.filter(sid => sid !== deletedId);
          if (m.children) m.children = m.children.filter(cid => cid !== deletedId);
        }
        this.saveDataLocally();
        this.treeVisualizer.setData(this.clanData.members, this.selfId);
        this.populateSelfSelector();
        this.showToast('Đã xóa thành viên khỏi gia phả.', 'info');
      }
    );

    this.bookRenderer = new BookViewRenderer(
      this.clanData,
      (id) => this.memberModal.open(id)
    );

    this.graveRenderer = new GraveMapRenderer(
      this.clanData,
      (id) => this.memberModal.open(id)
    );

    this.anniversaryManager = new DeathAnniversaryManager(this.clanData.members);

    this.populateSelfSelector();
    this.memberModal.setSelf(this.selfId);
  }

  setSelf(id) {
    this.selfId = id;
    localStorage.setItem('giapha_self_id', id);
    const sel = document.getElementById('self-selector');
    if (sel) sel.value = id;
    this.memberModal.setSelf(id);
    this.treeVisualizer.setSelf(id);
    const selfMem = this.clanData.members.find(x => x.id === id);
    if (selfMem) {
      this.showToast(`Đã đặt mốc "Tôi" là: ${selfMem.name} (Đời ${selfMem.generation})`, 'info');
    }
  }

  populateSelfSelector() {
    const sel = document.getElementById('self-selector');
    if (!sel) return;
    let html = '<option value="">-- Chọn mốc Tôi để tính danh xưng --</option>';
    for (const m of this.clanData.members) {
      html += `<option value="${m.id}">Đời ${m.generation || 1}: ${m.name} (${m.title || ''})</option>`;
    }
    sel.innerHTML = html;
    if (this.selfId) sel.value = this.selfId;
  }

  bindEvents() {
    // Tab switching (sync desktop tabs & mobile bottom bar)
    const switchTab = (tabName) => {
      this.currentTab = tabName;
      document.querySelectorAll('.tab-btn, .mobile-tab-btn').forEach(b => {
        b.classList.toggle('active', b.getAttribute('data-tab') === tabName);
      });
      this.renderCurrentView();
    };

    document.querySelectorAll('.tab-btn, .mobile-tab-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        switchTab(btn.getAttribute('data-tab'));
      });
    });

    // Theme toggle
    document.getElementById('btn-theme-toggle')?.addEventListener('click', () => {
      this.toggleTheme();
    });

    // Mobile Actions Menu Sheet
    const mobileMenuModal = document.getElementById('mobile-actions-modal');
    document.getElementById('btn-mobile-menu')?.addEventListener('click', () => {
      if (mobileMenuModal) mobileMenuModal.style.display = 'flex';
    });
    document.querySelectorAll('.btn-close-mobile-menu').forEach(b => {
      b.addEventListener('click', () => {
        if (mobileMenuModal) mobileMenuModal.style.display = 'none';
      });
    });
    mobileMenuModal?.addEventListener('click', (e) => {
      if (e.target === mobileMenuModal) mobileMenuModal.style.display = 'none';
    });

    document.getElementById('btn-mobile-export-ics')?.addEventListener('click', () => {
      if (mobileMenuModal) mobileMenuModal.style.display = 'none';
      document.getElementById('btn-export-clan-ics')?.click();
    });

    document.getElementById('btn-mobile-backup')?.addEventListener('click', () => {
      if (mobileMenuModal) mobileMenuModal.style.display = 'none';
      document.getElementById('btn-backup-data')?.click();
    });

    document.getElementById('btn-mobile-theme')?.addEventListener('click', () => {
      this.toggleTheme();
    });

    // Self selector change
    document.getElementById('self-selector')?.addEventListener('change', (e) => {
      if (e.target.value) {
        this.setSelf(e.target.value);
      }
    });

    // Quick Add on Header
    document.getElementById('btn-header-add')?.addEventListener('click', () => {
      this.memberModal.openCreateModal();
    });

    // Tree Zoom buttons
    document.getElementById('btn-zoom-in')?.addEventListener('click', () => {
      this.treeVisualizer.zoom(1.2);
    });
    document.getElementById('btn-zoom-out')?.addEventListener('click', () => {
      this.treeVisualizer.zoom(0.8);
    });
    document.getElementById('btn-zoom-reset')?.addEventListener('click', () => {
      this.treeVisualizer.resetZoom();
    });

    // Search bar
    document.getElementById('search-member-input')?.addEventListener('input', (e) => {
      this.searchQuery = e.target.value.toLowerCase().trim();
      this.handleSearch();
    });

    // Export Clan Anniversaries ICS
    document.getElementById('btn-export-clan-ics')?.addEventListener('click', () => {
      try {
        const clanName = this.clanData.clan_info?.name || 'Gia Phả';
        this.anniversaryManager.downloadICS(clanName);
        this.showToast('Đã tải xuống file .ics Lịch Giỗ Tổ Tiên (10 năm)!', 'success');
      } catch (err) {
        this.showToast(`Lỗi xuất ICS: ${err.message}`, 'error');
      }
    });

    // Backup & Restore Modal
    const backupModal = document.getElementById('backup-modal');
    document.getElementById('btn-backup-data')?.addEventListener('click', () => {
      backupModal.style.display = 'flex';
    });
    document.getElementById('btn-close-backup-modal')?.addEventListener('click', () => {
      backupModal.style.display = 'none';
    });
    backupModal?.addEventListener('click', (e) => {
      if (e.target === backupModal) backupModal.style.display = 'none';
    });

    // Download JSON
    document.getElementById('btn-download-json')?.addEventListener('click', () => {
      const dataStr = JSON.stringify(this.clanData, null, 2);
      const blob = new Blob([dataStr], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `clan-${Date.now()}.json`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      setTimeout(() => URL.revokeObjectURL(url), 2000);
      this.showToast('Đã tải file clan.json về máy!', 'success');
    });

    // Reset Data
    document.getElementById('btn-reset-data')?.addEventListener('click', () => {
      if (confirm('Khôi phục lại dữ liệu mẫu gốc? Mọi chỉnh sửa cục bộ sẽ bị xóa.')) {
        localStorage.removeItem('giapha_clan_data');
        location.reload();
      }
    });

    // Import JSON File
    document.getElementById('input-import-json')?.addEventListener('change', (e) => {
      const file = e.target.files[0];
      if (!file) return;
      const reader = new FileReader();
      reader.onload = (event) => {
        try {
          const parsed = JSON.parse(event.target.result);
          if (!parsed.members || !Array.isArray(parsed.members)) {
            throw new Error('File JSON không đúng cấu trúc (thiếu danh sách members).');
          }
          this.clanData = parsed;
          this.saveDataLocally();
          backupModal.style.display = 'none';
          this.initControllers();
          this.renderCurrentView();
          this.showToast(`Đã nạp thành công ${parsed.members.length} thành viên từ file!`, 'success');
        } catch (err) {
          alert(`Lỗi nạp file: ${err.message}`);
        }
      };
      reader.readAsText(file);
    });

    // Print Book View
    document.getElementById('btn-print-book')?.addEventListener('click', () => {
      window.print();
    });
  }

  handleSearch() {
    if (!this.searchQuery) {
      this.treeVisualizer.setData(this.clanData.members, this.selfId);
      return;
    }
    const filtered = this.clanData.members.filter(m =>
      m.name.toLowerCase().includes(this.searchQuery) ||
      (m.title && m.title.toLowerCase().includes(this.searchQuery)) ||
      (m.bio && m.bio.toLowerCase().includes(this.searchQuery))
    );
    this.treeVisualizer.setData(filtered, this.selfId);
  }

  renderCurrentView() {
    const treeContainer = document.getElementById('tree-view-wrapper');
    const bookContainer = document.getElementById('book-view-wrapper');
    const gravesContainer = document.getElementById('graves-view-wrapper');
    const anniversariesContainer = document.getElementById('anniversaries-view-wrapper');
    const btnPrint = document.getElementById('btn-print-book');

    // Hide all
    treeContainer.style.display = 'none';
    bookContainer.style.display = 'none';
    gravesContainer.style.display = 'none';
    anniversariesContainer.style.display = 'none';
    if (btnPrint) btnPrint.style.display = 'none';

    if (this.currentTab === 'tree') {
      treeContainer.style.display = 'block';
      this.treeVisualizer.setData(this.clanData.members, this.selfId);
    } else if (this.currentTab === 'book') {
      bookContainer.style.display = 'block';
      if (btnPrint) btnPrint.style.display = 'inline-flex';
      this.bookRenderer.render(bookContainer);
    } else if (this.currentTab === 'graves') {
      gravesContainer.style.display = 'block';
      this.graveRenderer.render(gravesContainer);
    } else if (this.currentTab === 'anniversaries') {
      anniversariesContainer.style.display = 'block';
      this.renderAnniversariesView(anniversariesContainer);
    }
  }

  renderAnniversariesView(container) {
    const curYear = new Date().getFullYear();
    const list = this.anniversaryManager.getAnniversariesForYear(curYear);

    let rowsHtml = '';
    for (const item of list) {
      const m = item.member;
      const s = item.solarDate;
      const dateStr = `Ngày ${s.day}/${s.month}/${s.year}`;
      const lunarStr = `Ngày ${item.lunarDate.day}/${item.lunarDate.month} Âm lịch`;

      rowsHtml += `
        <div style="background: var(--bg-surface); border: 1px solid var(--border-color); border-radius: 8px; padding: 1rem; display: flex; justify-content: space-between; align-items: center; gap: 1rem; flex-wrap: wrap;">
          <div>
            <div style="display: flex; align-items: center; gap: 0.5rem;">
              <span style="font-size: 1.15rem; font-weight: 700;">${m.name}</span>
              <span style="font-size: 0.75rem; color: var(--gold); background: #fef3c7; padding: 2px 6px; border-radius: 4px; font-weight: 600;">Đời ${m.generation} • ${m.title || ''}</span>
            </div>
            <div style="font-size: 0.85rem; color: var(--gold); font-weight: 600; margin-top: 4px;">
              🕯️ ${lunarStr} (Năm ${item.canChiYear})
            </div>
            <div style="font-size: 0.8125rem; color: var(--text-secondary); margin-top: 2px;">
              Dương lịch năm nay: <strong>${dateStr}</strong> (${item.canChiDay})
            </div>
            ${item.note ? `<div style="font-size: 0.8rem; color: var(--text-muted); margin-top: 2px;"><em>${item.note}</em></div>` : ''}
          </div>

          <button type="button" class="btn btn-outline btn-sm btn-view-profile-from-gio" data-id="${m.id}">
            Xem hồ sơ
          </button>
        </div>
      `;
    }

    container.innerHTML = `
      <div style="max-width: 900px; margin: 1.5rem auto; padding: 0 1.25rem;">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1.25rem; flex-wrap: wrap; gap: 1rem;">
          <div>
            <h2 style="font-size: 1.35rem; font-weight: 700;">Lịch Giỗ Tổ Tiên Trong Năm (${curYear})</h2>
            <p style="font-size: 0.85rem; color: var(--text-secondary);">Tự động tính toán ngày dương lịch theo chu kỳ âm lịch Việt Nam chuẩn UTC+7.</p>
          </div>
          <button type="button" id="btn-export-clan-ics-2" class="btn btn-gold">
            📥 Tải file .ics Lịch Giỗ (10 năm)
          </button>
        </div>

        <div style="display: flex; flex-direction: column; gap: 0.75rem;">
          ${rowsHtml}
        </div>
      </div>
    `;

    container.querySelectorAll('.btn-view-profile-from-gio').forEach(btn => {
      btn.addEventListener('click', () => {
        const id = btn.getAttribute('data-id');
        this.memberModal.open(id);
      });
    });

    document.getElementById('btn-export-clan-ics-2')?.addEventListener('click', () => {
      this.anniversaryManager.downloadICS(this.clanData.clan_info?.name || 'Gia Phả');
      this.showToast('Đã tải xuống file .ics Lịch Giỗ Tổ Tiên!', 'success');
    });
  }
}

document.addEventListener('DOMContentLoaded', () => {
  const app = new GiaPhaApp();
  app.init();
});
