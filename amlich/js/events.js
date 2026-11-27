/**
 * Event Management & Recurrence Engine
 * Handles CRUD operations, category filters, and annual lunar resolution.
 */

import { convertLunar2Solar, convertSolar2Lunar, getDaysInLunarMonth, jdFromDate, jdToDate } from '../engine/vietnam-lunar.js';
import { encryptPrivateData, decryptPrivateData, StorageManager } from './storage.js';

export const CATEGORIES = {
  national_holiday: { label: 'Lễ Quốc Gia', color: '#dc2626' },
  traditional_festival: { label: 'Lễ Hội Dân Gian', color: '#d97706' },
  family_anniversary: { label: 'Giỗ / Gia Đình', color: '#7c3aed' },
  birthday: { label: 'Sinh Nhật', color: '#2563eb' },
  personal: { label: 'Cá Nhân', color: '#059669' },
  community: { label: 'Cộng Đồng', color: '#0284c7' },
  observance: { label: 'Kỷ Niệm', color: '#4b5563' }
};

export class EventManager {
  constructor(githubApi) {
    this.api = githubApi;
    this.holidays = [];
    this.publicEvents = [];
    this.privateEvents = [];
    this.privateFileSha = null;
    this.publicFileSha = null;
    this.passphrase = null;
    this.isPrivateUnlocked = false;
  }

  async loadInitialData() {
    // 1. Load public holidays from static file or GitHub API
    try {
      const resp = await fetch('data/public/holidays.json');
      if (resp.ok) {
        this.holidays = await resp.json();
      }
    } catch (e) {
      console.warn('Could not load local holidays.json, fallback to empty', e);
    }

    // 2. Load public events
    const basePath = this.api.auth.config.basePath || 'amlich/';
    try {
      if (this.api.auth.isAuthenticated()) {
        const ghPub = await this.api.getFile(`${basePath}data/public/events.json`);
        if (ghPub) {
          this.publicEvents = JSON.parse(ghPub.content);
          this.publicFileSha = ghPub.sha;
        }
      } else {
        const resp = await fetch('data/public/events.json');
        if (resp.ok) {
          this.publicEvents = await resp.json();
        }
      }
    } catch (e) {
      console.warn('Could not load public events', e);
    }

    // 3. Check for cached private data in local storage
    const cachedPrivate = StorageManager.get('amlich_cached_private_envelope');
    if (cachedPrivate) {
      this.cachedPrivateEnvelope = cachedPrivate;
    }
  }

  async unlockPrivate(passphrase) {
    this.passphrase = passphrase;
    let envelope = null;

    if (this.api.auth.isAuthenticated()) {
      const basePath = this.api.auth.config.basePath || 'amlich/';
      const remote = await this.api.getFile(`${basePath}data/private/events.enc.json`);
      if (remote) {
        envelope = JSON.parse(remote.content);
        this.privateFileSha = remote.sha;
      }
    }

    if (!envelope) {
      envelope = StorageManager.get('amlich_cached_private_envelope');
    }

    if (!envelope) {
      // First time initialization
      this.privateEvents = [];
      this.isPrivateUnlocked = true;
      return true;
    }

    const decrypted = await decryptPrivateData(envelope, passphrase);
    this.privateEvents = Array.isArray(decrypted) ? decrypted : [];
    this.isPrivateUnlocked = true;
    return true;
  }

  lockPrivate() {
    this.passphrase = null;
    this.privateEvents = [];
    this.isPrivateUnlocked = false;
  }

  getAllEvents() {
    return [
      ...this.holidays.map(h => ({ ...h, isHoliday: true, scope: 'public' })),
      ...this.publicEvents.map(e => ({ ...e, isHoliday: false, scope: 'public' })),
      ...(this.isPrivateUnlocked ? this.privateEvents.map(p => ({ ...p, isHoliday: false, scope: 'private' })) : [])
    ];
  }

  /**
   * Resolve events occurring on a specific solar date (day, month, year)
   */
  getEventsForDate(day, month, year) {
    const all = this.getAllEvents();
    const results = [];
    const lunar = convertSolar2Lunar(day, month, year);

    for (const ev of all) {
      const calType = ev.calendar_type || 'solar';
      const recurrence = ev.recurrence || 'none';

      if (calType === 'solar') {
        if (recurrence === 'annual_solar') {
          if (ev.solar_day === day && ev.solar_month === month) {
            results.push(ev);
          }
        } else if (recurrence === 'none') {
          if (ev.solar_day === day && ev.solar_month === month && ev.solar_year === year) {
            results.push(ev);
          }
        }
      } else if (calType === 'lunar') {
        if (recurrence === 'annual_lunar') {
          // Check matching lunar date
          if (ev.lunar_month === lunar.month) {
            // Check day 30 fallback
            if (ev.lunar_day === lunar.day) {
              results.push(ev);
            } else if (ev.lunar_day === 30 && ev.fallback_to_last_day) {
              const daysInMonth = getDaysInLunarMonth(lunar.month, lunar.year, lunar.leap);
              if (daysInMonth === 29 && lunar.day === 29) {
                results.push({ ...ev, fallbackApplied: true });
              }
            }
          }
        } else if (recurrence === 'none') {
          if (ev.lunar_day === lunar.day && ev.lunar_month === lunar.month && ev.lunar_year === lunar.year && Boolean(ev.is_leap) === lunar.leap) {
            results.push(ev);
          }
        }
      }
    }
    return results;
  }

  async addEvent(eventData) {
    const id = eventData.id || `evt-${Date.now()}-${Math.random().toString(36).substr(2, 6)}`;
    const newEvent = { ...eventData, id, updated_at: new Date().toISOString() };

    if (newEvent.scope === 'private') {
      if (!this.isPrivateUnlocked || !this.passphrase) {
        throw new Error('Vui lòng mở khóa dữ liệu riêng tư bằng mật khẩu trước khi thêm sự kiện riêng tư.');
      }
      this.privateEvents.push(newEvent);
      await this.savePrivateEvents();
    } else {
      this.publicEvents.push(newEvent);
      await this.savePublicEvents();
    }
    return newEvent;
  }

  async updateEvent(id, updatedFields) {
    const isPriv = this.privateEvents.some(e => e.id === id);
    if (isPriv) {
      if (!this.isPrivateUnlocked) throw new Error('Dữ liệu riêng tư đang khóa.');
      const idx = this.privateEvents.findIndex(e => e.id === id);
      this.privateEvents[idx] = { ...this.privateEvents[idx], ...updatedFields, updated_at: new Date().toISOString() };
      await this.savePrivateEvents();
      return this.privateEvents[idx];
    }

    const pubIdx = this.publicEvents.findIndex(e => e.id === id);
    if (pubIdx >= 0) {
      this.publicEvents[pubIdx] = { ...this.publicEvents[pubIdx], ...updatedFields, updated_at: new Date().toISOString() };
      await this.savePublicEvents();
      return this.publicEvents[pubIdx];
    }
    throw new Error('Không tìm thấy sự kiện để cập nhật.');
  }

  async deleteEvent(id) {
    const privIdx = this.privateEvents.findIndex(e => e.id === id);
    if (privIdx >= 0) {
      if (!this.isPrivateUnlocked) throw new Error('Dữ liệu riêng tư đang khóa.');
      this.privateEvents.splice(privIdx, 1);
      await this.savePrivateEvents();
      return true;
    }

    const pubIdx = this.publicEvents.findIndex(e => e.id === id);
    if (pubIdx >= 0) {
      this.publicEvents.splice(pubIdx, 1);
      await this.savePublicEvents();
      return true;
    }
    throw new Error('Không tìm thấy sự kiện để xóa.');
  }

  async savePublicEvents() {
    if (!this.api.auth.isAuthenticated()) {
      StorageManager.set('amlich_local_public_events', this.publicEvents);
      return;
    }
    const basePath = this.api.auth.config.basePath || 'amlich/';
    const jsonStr = JSON.stringify(this.publicEvents, null, 2);
    const res = await this.api.saveFile(
      `${basePath}data/public/events.json`,
      jsonStr,
      `chore(calendar): update public events [${new Date().toISOString()}]`,
      this.publicFileSha
    );
    this.publicFileSha = res.sha;
  }

  async savePrivateEvents() {
    if (!this.passphrase) {
      throw new Error('Thiếu mật khẩu mã hóa dữ liệu riêng tư.');
    }
    const envelope = await encryptPrivateData(this.privateEvents, this.passphrase);
    StorageManager.set('amlich_cached_private_envelope', envelope);

    if (this.api.auth.isAuthenticated()) {
      const basePath = this.api.auth.config.basePath || 'amlich/';
      const jsonStr = JSON.stringify(envelope, null, 2);
      const res = await this.api.saveFile(
        `${basePath}data/private/events.enc.json`,
        jsonStr,
        `chore(calendar): update encrypted private events [${new Date().toISOString()}]`,
        this.privateFileSha
      );
      this.privateFileSha = res.sha;
    }
  }
}
