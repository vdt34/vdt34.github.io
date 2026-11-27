/**
 * UI Renderer and Modal Controllers
 */

import { CATEGORIES } from './events.js';
import { getYearCanChi } from '../engine/can-chi.js';
import { convertSolar2Lunar, convertLunar2Solar } from '../engine/vietnam-lunar.js';

export class UIRenderer {
  constructor(calendarState, eventManager, authManager, githubApi) {
    this.cal = calendarState;
    this.events = eventManager;
    this.auth = authManager;
    this.api = githubApi;
    this.initTheme();
  }

  initTheme() {
    const saved = localStorage.getItem('amlich_theme') || (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
    document.documentElement.setAttribute('data-theme', saved);
  }

  toggleTheme() {
    const cur = document.documentElement.getAttribute('data-theme');
    const next = cur === 'dark' ? 'light' : 'dark';
    document.documentElement.setAttribute('data-theme', next);
    localStorage.setItem('amlich_theme', next);
  }

  showToast(message, type = 'info') {
    const container = document.getElementById('toast-container');
    if (!container) return;
    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;
    toast.textContent = message;
    container.appendChild(toast);
    setTimeout(() => {
      toast.remove();
    }, 3500);
  }

  render() {
    this.renderHeaderStatus();
    this.renderToolbarTitle();

    const container = document.getElementById('calendar-container');
    if (!container) return;

    if (this.cal.viewMode === 'month') {
      this.renderMonthView(container);
    } else if (this.cal.viewMode === 'week') {
      this.renderWeekView(container);
    } else if (this.cal.viewMode === 'list') {
      this.renderListView(container);
    }
  }

  renderHeaderStatus() {
    const authPill = document.getElementById('github-status-pill');
    if (authPill) {
      if (this.auth.isAuthenticated()) {
        const u = this.auth.getUser();
        authPill.innerHTML = `
          <span class="status-dot active"></span>
          <span>${u.login} (${this.auth.config.repo})</span>
        `;
      } else {
        authPill.innerHTML = `
          <span class="status-dot"></span>
          <span>Chưa kết nối GitHub</span>
        `;
      }
    }

    const privPill = document.getElementById('private-status-pill');
    if (privPill) {
      if (this.events.isPrivateUnlocked) {
        privPill.innerHTML = `
          <span class="status-dot active"></span>
          <span>Riêng tư: Đã mở</span>
        `;
      } else {
        privPill.innerHTML = `
          <span class="status-dot locked"></span>
          <span>Riêng tư: Đang khóa</span>
        `;
      }
    }
  }

  renderToolbarTitle() {
    const titleEl = document.getElementById('calendar-main-title');
    const subTitleEl = document.getElementById('calendar-sub-title');
    const date = this.cal.currentDate;

    const lunar = convertSolar2Lunar(date.getDate(), date.getMonth() + 1, date.getFullYear());
    const yearCanChi = getYearCanChi(lunar.year);

    if (titleEl) {
      titleEl.textContent = `Tháng ${date.getMonth() + 1}, ${date.getFullYear()}`;
    }
    if (subTitleEl) {
      subTitleEl.textContent = `Năm ${yearCanChi.name} (${yearCanChi.animal})`;
    }
  }

  renderMonthView(container) {
    const days = this.cal.getMonthGrid();
    let html = `
      <div class="weekday-header">
        <div>Thứ 2</div>
        <div>Thứ 3</div>
        <div>Thứ 4</div>
        <div>Thứ 5</div>
        <div>Thứ 6</div>
        <div>Thứ 7</div>
        <div>Chủ Nhật</div>
      </div>
      <div class="month-grid">
    `;

    for (const d of days) {
      const isOtherMonthClass = d.isCurrentMonth ? '' : 'other-month';
      const isTodayClass = d.isToday ? 'today' : '';

      let badgeHtml = '';
      if (d.special) {
        badgeHtml = `<span class="lunar-badge ${d.special.type}">${d.special.label}</span>`;
      }

      let eventsHtml = '';
      for (const ev of d.events.slice(0, 3)) {
        const privClass = ev.scope === 'private' ? 'private' : '';
        const color = ev.color || (CATEGORIES[ev.category]?.color || '#2563eb');
        eventsHtml += `
          <div class="event-pill ${privClass}" style="background-color: ${color}" title="${ev.title}" data-event-id="${ev.id}">
            ${ev.title}
          </div>
        `;
      }
      if (d.events.length > 3) {
        eventsHtml += `<div class="event-more text-xs text-muted">+${d.events.length - 3} sự kiện</div>`;
      }

      html += `
        <div class="calendar-cell ${isOtherMonthClass} ${isTodayClass}" data-date="${d.solar.year}-${d.solar.month}-${d.solar.day}">
          <div class="cell-header">
            <span class="solar-number">${d.solar.day}</span>
            <div class="lunar-info">
              ${badgeHtml}
              <span class="lunar-number">${d.lunar.formatted}</span>
            </div>
          </div>
          <div class="canchi-tag">${d.canChi.day}</div>
          <div class="cell-events">${eventsHtml}</div>
        </div>
      `;
    }

    html += `</div>`;
    container.innerHTML = html;

    // Attach click handlers on cells
    container.querySelectorAll('.calendar-cell').forEach(cell => {
      cell.addEventListener('click', (e) => {
        const evPill = e.target.closest('.event-pill');
        if (evPill) {
          const evId = evPill.getAttribute('data-event-id');
          this.openEventDetails(evId);
          return;
        }
        const [y, m, d] = cell.getAttribute('data-date').split('-').map(Number);
        this.openAddEventModal(d, m, y);
      });
    });
  }

  renderWeekView(container) {
    const days = this.cal.getWeekGrid();
    let html = `
      <div class="weekday-header">
        <div>Thứ 2</div>
        <div>Thứ 3</div>
        <div>Thứ 4</div>
        <div>Thứ 5</div>
        <div>Thứ 6</div>
        <div>Thứ 7</div>
        <div>Chủ Nhật</div>
      </div>
      <div class="month-grid" style="grid-auto-rows: minmax(280px, 1fr);">
    `;

    for (const d of days) {
      const isTodayClass = d.isToday ? 'today' : '';
      let badgeHtml = d.special ? `<span class="lunar-badge ${d.special.type}">${d.special.label}</span>` : '';

      let eventsHtml = '';
      for (const ev of d.events) {
        const color = ev.color || (CATEGORIES[ev.category]?.color || '#2563eb');
        eventsHtml += `
          <div class="event-pill" style="background-color: ${color}; margin-bottom: 4px;" data-event-id="${ev.id}">
            ${ev.title}
          </div>
        `;
      }

      html += `
        <div class="calendar-cell ${isTodayClass}" data-date="${d.solar.year}-${d.solar.month}-${d.solar.day}">
          <div class="cell-header">
            <span class="solar-number">${d.solar.day}</span>
            <div class="lunar-info">
              ${badgeHtml}
              <span class="lunar-number">${d.lunar.formatted}</span>
            </div>
          </div>
          <div class="canchi-tag" style="margin-bottom: 0.5rem;">${d.canChi.day}</div>
          <div class="cell-events" style="max-height: 200px;">${eventsHtml}</div>
        </div>
      `;
    }

    html += `</div>`;
    container.innerHTML = html;
  }

  renderListView(container) {
    const items = this.cal.getListViewItems(45);
    if (items.length === 0) {
      container.innerHTML = `<div style="padding: 2rem; text-align: center; color: var(--text-secondary);">Không có sự kiện hoặc ngày đặc biệt nào trong khoảng thời gian này.</div>`;
      return;
    }

    let html = `<div style="padding: 1rem; display: flex; flex-direction: column; gap: 0.75rem;">`;
    for (const item of items) {
      const lunarStr = `Âm lịch: ${item.lunar.day}/${item.lunar.month} (${item.canChi.day})`;
      let eventsHtml = '';
      for (const ev of item.events) {
        const color = ev.color || (CATEGORIES[ev.category]?.color || '#2563eb');
        eventsHtml += `
          <div style="display: flex; align-items: center; justify-content: space-between; padding: 0.5rem 0.75rem; background: var(--bg-surface-hover); border-left: 4px solid ${color}; border-radius: 4px; margin-top: 4px;">
            <div>
              <strong>${ev.title}</strong>
              <div style="font-size: 0.8rem; color: var(--text-secondary);">${ev.description || ''}</div>
            </div>
            <span style="font-size: 0.75rem; padding: 2px 6px; border-radius: 4px; background: var(--bg-surface);">${CATEGORIES[ev.category]?.label || 'Sự kiện'}</span>
          </div>
        `;
      }

      html += `
        <div style="border: 1px solid var(--border-color); border-radius: 6px; padding: 0.75rem; background: var(--bg-surface);">
          <div style="display: flex; justify-content: space-between; align-items: center;">
            <div>
              <span style="font-size: 1.1rem; font-weight: 700;">Ngày ${item.solar.day}/${item.solar.month}/${item.solar.year}</span>
              <span style="margin-left: 0.75rem; font-size: 0.85rem; color: var(--lunar-gold); font-weight: 500;">${lunarStr}</span>
            </div>
            ${item.special ? `<span class="lunar-badge ${item.special.type}">${item.special.label}</span>` : ''}
          </div>
          <div style="margin-top: 0.5rem;">${eventsHtml}</div>
        </div>
      `;
    }
    html += `</div>`;
    container.innerHTML = html;
  }

  openAddEventModal(day, month, year) {
    const modal = document.getElementById('event-modal');
    if (!modal) return;
    const form = document.getElementById('event-form');
    form.reset();

    document.getElementById('event-id').value = '';
    document.getElementById('solar-day').value = day;
    document.getElementById('solar-month').value = month;
    document.getElementById('solar-year').value = year;

    const lunar = convertSolar2Lunar(day, month, year);
    document.getElementById('lunar-day').value = lunar.day;
    document.getElementById('lunar-month').value = lunar.month;
    document.getElementById('lunar-leap').checked = lunar.leap;

    modal.style.display = 'flex';
  }

  openEventDetails(id) {
    const all = this.events.getAllEvents();
    const ev = all.find(e => e.id === id);
    if (!ev) return;

    const modal = document.getElementById('event-modal');
    if (!modal) return;

    document.getElementById('event-id').value = ev.id;
    document.getElementById('event-title').value = ev.title;
    document.getElementById('event-description').value = ev.description || '';
    document.getElementById('event-category').value = ev.category || 'personal';
    document.getElementById('event-calendar-type').value = ev.calendar_type || 'solar';
    document.getElementById('event-scope').value = ev.scope || 'public';
    document.getElementById('event-recurrence').value = ev.recurrence || 'none';
    document.getElementById('event-color').value = ev.color || '#2563eb';

    if (ev.calendar_type === 'lunar') {
      document.getElementById('lunar-day').value = ev.lunar_day || 1;
      document.getElementById('lunar-month').value = ev.lunar_month || 1;
      document.getElementById('lunar-leap').checked = Boolean(ev.is_leap);
      document.getElementById('lunar-fallback').checked = Boolean(ev.fallback_to_last_day !== false);
    } else {
      document.getElementById('solar-day').value = ev.solar_day || 1;
      document.getElementById('solar-month').value = ev.solar_month || 1;
      document.getElementById('solar-year').value = ev.solar_year || new Date().getFullYear();
    }

    modal.style.display = 'flex';
  }
}
