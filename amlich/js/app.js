/**
 * Application Entrypoint
 * Wire up modules, bind user events, and bootstrap dashboard.
 */

import { AuthManager } from './auth.js';
import { GitHubAPI } from './github-api.js';
import { EventManager } from './events.js';
import { CalendarState } from './calendar.js';
import { UIRenderer } from './ui.js';
import { generateICSForEvents, downloadICSFile } from './ics-exporter.js';

document.addEventListener('DOMContentLoaded', async () => {
  const auth = new AuthManager();
  const api = new GitHubAPI(auth);
  const events = new EventManager(api);
  const cal = new CalendarState(events);
  const ui = new UIRenderer(cal, events, auth, api);

  // Initial load
  await events.loadInitialData();
  ui.render();

  // Navigation
  document.getElementById('btn-prev')?.addEventListener('click', () => {
    cal.prev();
    ui.render();
  });

  document.getElementById('btn-next')?.addEventListener('click', () => {
    cal.next();
    ui.render();
  });

  document.getElementById('btn-today')?.addEventListener('click', () => {
    cal.today();
    ui.render();
  });

  // View switchers
  document.querySelectorAll('.view-btn').forEach(btn => {
    btn.addEventListener('click', (e) => {
      document.querySelectorAll('.view-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      cal.viewMode = btn.getAttribute('data-view');
      ui.render();
    });
  });

  // Search & Filters
  document.getElementById('search-input')?.addEventListener('input', (e) => {
    cal.searchQuery = e.target.value.trim();
    ui.render();
  });

  document.getElementById('category-filter')?.addEventListener('change', (e) => {
    cal.categoryFilter = e.target.value;
    ui.render();
  });

  document.getElementById('scope-filter')?.addEventListener('change', (e) => {
    cal.scopeFilter = e.target.value;
    ui.render();
  });

  // Theme toggle
  document.getElementById('btn-theme-toggle')?.addEventListener('click', () => {
    ui.toggleTheme();
  });

  // Modals Open / Close
  const setupModal = (btnId, modalId, closeBtnSelector = '.btn-modal-close') => {
    const btn = document.getElementById(btnId);
    const modal = document.getElementById(modalId);
    if (!modal) return;
    btn?.addEventListener('click', () => {
      modal.style.display = 'flex';
    });
    modal.querySelectorAll(closeBtnSelector).forEach(c => {
      c.addEventListener('click', () => {
        modal.style.display = 'none';
      });
    });
    modal.addEventListener('click', (e) => {
      if (e.target === modal) modal.style.display = 'none';
    });
  };

  setupModal('btn-add-event', 'event-modal');
  setupModal('github-status-pill', 'github-modal');
  setupModal('private-status-pill', 'private-modal');
  setupModal('btn-feeds-modal', 'feeds-modal');

  // Event Form Calendar Type Toggle (Show/hide lunar or solar inputs)
  const calTypeSelect = document.getElementById('event-calendar-type');
  const solarFields = document.getElementById('solar-date-fields');
  const lunarFields = document.getElementById('lunar-date-fields');

  const updateCalTypeVisibility = () => {
    if (calTypeSelect.value === 'lunar') {
      solarFields.style.display = 'none';
      lunarFields.style.display = 'grid';
    } else {
      solarFields.style.display = 'grid';
      lunarFields.style.display = 'none';
    }
  };
  calTypeSelect?.addEventListener('change', updateCalTypeVisibility);
  updateCalTypeVisibility();

  // Save Event
  document.getElementById('event-form')?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const id = document.getElementById('event-id').value;
    const title = document.getElementById('event-title').value.trim();
    const description = document.getElementById('event-description').value.trim();
    const category = document.getElementById('event-category').value;
    const scope = document.getElementById('event-scope').value;
    const recurrence = document.getElementById('event-recurrence').value;
    const color = document.getElementById('event-color').value;
    const calType = calTypeSelect.value;

    const eventPayload = {
      title,
      description,
      category,
      scope,
      recurrence,
      color,
      calendar_type: calType
    };

    if (calType === 'solar') {
      eventPayload.solar_day = parseInt(document.getElementById('solar-day').value, 10);
      eventPayload.solar_month = parseInt(document.getElementById('solar-month').value, 10);
      eventPayload.solar_year = parseInt(document.getElementById('solar-year').value, 10);
    } else {
      eventPayload.lunar_day = parseInt(document.getElementById('lunar-day').value, 10);
      eventPayload.lunar_month = parseInt(document.getElementById('lunar-month').value, 10);
      eventPayload.is_leap = document.getElementById('lunar-leap').checked;
      eventPayload.fallback_to_last_day = document.getElementById('lunar-fallback').checked;
    }

    try {
      if (id) {
        await events.updateEvent(id, eventPayload);
        ui.showToast('Cập nhật sự kiện thành công!', 'success');
      } else {
        await events.addEvent(eventPayload);
        ui.showToast('Thêm sự kiện mới thành công!', 'success');
      }
      document.getElementById('event-modal').style.display = 'none';
      ui.render();
    } catch (err) {
      ui.showToast(`Lỗi: ${err.message}`, 'error');
    }
  });

  // Delete Event
  document.getElementById('btn-delete-event')?.addEventListener('click', async () => {
    const id = document.getElementById('event-id').value;
    if (!id) return;
    if (!confirm('Bạn có chắc chắn muốn xóa sự kiện này?')) return;

    try {
      await events.deleteEvent(id);
      ui.showToast('Đã xóa sự kiện.', 'info');
      document.getElementById('event-modal').style.display = 'none';
      ui.render();
    } catch (err) {
      ui.showToast(`Lỗi xóa sự kiện: ${err.message}`, 'error');
    }
  });

  // GitHub Auth Form
  const ghModal = document.getElementById('github-modal');
  const tokenInput = document.getElementById('gh-token-input');
  const ownerInput = document.getElementById('gh-owner-input');
  const repoInput = document.getElementById('gh-repo-input');
  const branchInput = document.getElementById('gh-branch-input');

  if (ownerInput) ownerInput.value = auth.config.owner;
  if (repoInput) repoInput.value = auth.config.repo;
  if (branchInput) branchInput.value = auth.config.branch;

  document.getElementById('github-auth-form')?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const token = tokenInput.value;
    const owner = ownerInput.value;
    const repo = repoInput.value;
    const branch = branchInput.value;

    const btnSubmit = e.target.querySelector('button[type="submit"]');
    btnSubmit.disabled = true;
    btnSubmit.textContent = 'Đang kiểm tra...';

    try {
      await auth.login(token, owner, repo, branch);
      ui.showToast('Kết nối GitHub thành công!', 'success');
      tokenInput.value = '';
      ghModal.style.display = 'none';
      await events.loadInitialData();
      ui.render();
    } catch (err) {
      ui.showToast(err.message, 'error');
    } finally {
      btnSubmit.disabled = false;
      btnSubmit.textContent = 'Kết nối & Lưu';
    }
  });

  document.getElementById('btn-github-logout')?.addEventListener('click', () => {
    auth.logout();
    ui.showToast('Đã đăng xuất GitHub.', 'info');
    ghModal.style.display = 'none';
    ui.render();
  });

  // Private Data Passphrase Form
  const privModal = document.getElementById('private-modal');
  const passInput = document.getElementById('private-passphrase-input');

  document.getElementById('private-auth-form')?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const pass = passInput.value;
    try {
      await events.unlockPrivate(pass);
      ui.showToast('Đã mở khóa dữ liệu riêng tư thành công!', 'success');
      passInput.value = '';
      privModal.style.display = 'none';
      ui.render();
    } catch (err) {
      ui.showToast(err.message, 'error');
    }
  });

  document.getElementById('btn-lock-private')?.addEventListener('click', () => {
    events.lockPrivate();
    ui.showToast('Đã khóa dữ liệu riêng tư.', 'info');
    privModal.style.display = 'none';
    ui.render();
  });

  // Feeds URLs & Copy buttons
  const updateFeedLinks = () => {
    const origin = window.location.origin;
    const pathname = window.location.pathname.replace(/\/index\.html$/, '').replace(/\/$/, '');
    const baseUrl = `${origin}${pathname}`;
    const webcalBase = baseUrl.replace(/^https?:\/\//, 'webcal://');

    const setLink = (id, path) => {
      const el = document.getElementById(id);
      if (el) el.value = `${baseUrl}/${path}`;
      const webcalEl = document.getElementById(`${id}-webcal`);
      if (webcalEl) webcalEl.value = `${webcalBase}/${path}`;
    };

    setLink('feed-url-holidays', 'feeds/holidays.ics');
    setLink('feed-url-lunar', 'feeds/lunar.ics');
    setLink('feed-url-events', 'feeds/public-events.ics');
  };

  updateFeedLinks();

  document.querySelectorAll('.btn-copy-url').forEach(btn => {
    btn.addEventListener('click', () => {
      const targetId = btn.getAttribute('data-target');
      const input = document.getElementById(targetId);
      if (input) {
        navigator.clipboard.writeText(input.value);
        ui.showToast('Đã sao chép link đăng ký vào bộ nhớ tạm!', 'success');
      }
    });
  });

  // Export Anniversaries (Ngày Giỗ) button
  document.getElementById('btn-export-anniversaries-ics')?.addEventListener('click', () => {
    const all = events.getAllEvents();
    // Filter family anniversaries or recurring lunar events
    const anniversaries = all.filter(e => 
      e.category === 'family_anniversary' || 
      e.recurrence === 'annual_lunar' || 
      e.scope === 'private'
    );

    if (anniversaries.length === 0) {
      ui.showToast('Chưa có ngày giỗ hoặc sự kiện âm lịch nào. Hãy thêm sự kiện trước khi xuất!', 'info');
      return;
    }

    try {
      const ics = generateICSForEvents(anniversaries, 'Ngày Giỗ & Gia Đình', 10);
      downloadICSFile('ngay-gio-gia-dinh.ics', ics);
      ui.showToast(`Đã xuất thành công ${anniversaries.length} ngày giỗ (tính sẵn 10 năm tới)!`, 'success');
    } catch (err) {
      ui.showToast(`Lỗi xuất file ICS: ${err.message}`, 'error');
    }
  });
});
