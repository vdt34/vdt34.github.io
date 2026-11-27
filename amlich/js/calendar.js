/**
 * Calendar Core State & Grid Calculation
 * Supports Month, Week, and List Views with Solar/Lunar mapping.
 */

import { convertSolar2Lunar, jdFromDate, jdToDate } from '../engine/vietnam-lunar.js';
import { getDayCanChi, getYearCanChi, isSpecialLunarDay } from '../engine/can-chi.js';

export class CalendarState {
  constructor(eventManager) {
    this.events = eventManager;
    const now = new Date();
    this.currentDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    this.viewMode = 'month'; // 'month' | 'week' | 'list'
    this.searchQuery = '';
    this.categoryFilter = 'all';
    this.scopeFilter = 'all';
  }

  setDate(year, month, day = 1) {
    this.currentDate = new Date(year, month, day);
  }

  prev() {
    if (this.viewMode === 'month') {
      this.currentDate.setMonth(this.currentDate.getMonth() - 1);
    } else if (this.viewMode === 'week') {
      this.currentDate.setDate(this.currentDate.getDate() - 7);
    } else {
      this.currentDate.setMonth(this.currentDate.getMonth() - 1);
    }
  }

  next() {
    if (this.viewMode === 'month') {
      this.currentDate.setMonth(this.currentDate.getMonth() + 1);
    } else if (this.viewMode === 'week') {
      this.currentDate.setDate(this.currentDate.getDate() + 7);
    } else {
      this.currentDate.setMonth(this.currentDate.getMonth() + 1);
    }
  }

  today() {
    const now = new Date();
    this.currentDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  }

  getMonthGrid() {
    const year = this.currentDate.getFullYear();
    const month = this.currentDate.getMonth(); // 0-11

    const firstDayOfMonth = new Date(year, month, 1);
    const lastDayOfMonth = new Date(year, month + 1, 0);

    // Monday as start of week: 0=Mon, 1=Tue... 6=Sun
    let startDayOfWeek = firstDayOfMonth.getDay() - 1;
    if (startDayOfWeek === -1) startDayOfWeek = 6;

    const days = [];
    const today = new Date();

    // Days from previous month
    const prevMonthLastDate = new Date(year, month, 0).getDate();
    for (let i = startDayOfWeek - 1; i >= 0; i--) {
      const pDay = prevMonthLastDate - i;
      const pDate = new Date(year, month - 1, pDay);
      days.push(this.createDayModel(pDate, false, today));
    }

    // Days in current month
    for (let d = 1; d <= lastDayOfMonth.getDate(); d++) {
      const cDate = new Date(year, month, d);
      days.push(this.createDayModel(cDate, true, today));
    }

    // Trailing days from next month to fill grid (multiple of 7, up to 42 cells)
    const remaining = (7 - (days.length % 7)) % 7;
    for (let n = 1; n <= remaining; n++) {
      const nDate = new Date(year, month + 1, n);
      days.push(this.createDayModel(nDate, false, today));
    }

    return days;
  }

  getWeekGrid() {
    const curr = new Date(this.currentDate);
    let dayOfWeek = curr.getDay() - 1;
    if (dayOfWeek === -1) dayOfWeek = 6;

    // Start on Monday
    const monday = new Date(curr);
    monday.setDate(curr.getDate() - dayOfWeek);

    const days = [];
    const today = new Date();
    for (let i = 0; i < 7; i++) {
      const d = new Date(monday);
      d.setDate(monday.getDate() + i);
      days.push(this.createDayModel(d, true, today));
    }
    return days;
  }

  createDayModel(date, isCurrentMonth, today) {
    const sDay = date.getDate();
    const sMonth = date.getMonth() + 1;
    const sYear = date.getFullYear();

    const lunar = convertSolar2Lunar(sDay, sMonth, sYear);
    const canChiDay = getDayCanChi(sDay, sMonth, sYear);
    const canChiYear = getYearCanChi(lunar.year);
    const special = isSpecialLunarDay(lunar.day);

    let events = this.events.getEventsForDate(sDay, sMonth, sYear);

    // Apply active filters
    if (this.categoryFilter !== 'all') {
      events = events.filter(e => e.category === this.categoryFilter);
    }
    if (this.scopeFilter !== 'all') {
      events = events.filter(e => e.scope === this.scopeFilter);
    }
    if (this.searchQuery) {
      const q = this.searchQuery.toLowerCase();
      events = events.filter(e => e.title.toLowerCase().includes(q) || (e.description && e.description.toLowerCase().includes(q)));
    }

    const isToday = (
      date.getDate() === today.getDate() &&
      date.getMonth() === today.getMonth() &&
      date.getFullYear() === today.getFullYear()
    );

    return {
      date,
      solar: { day: sDay, month: sMonth, year: sYear },
      lunar: {
        day: lunar.day,
        month: lunar.month,
        year: lunar.year,
        leap: lunar.leap,
        formatted: lunar.day === 1 ? `${lunar.day}/${lunar.month}` : `${lunar.day}`
      },
      canChi: {
        day: canChiDay.name,
        year: canChiYear.name
      },
      special,
      isCurrentMonth,
      isToday,
      events
    };
  }

  getListViewItems(limit = 60) {
    const list = [];
    const start = new Date(this.currentDate);
    start.setDate(1);

    const today = new Date();
    for (let i = 0; i < limit; i++) {
      const d = new Date(start);
      d.setDate(start.getDate() + i);
      const dayModel = this.createDayModel(d, true, today);
      if (dayModel.events.length > 0 || dayModel.special) {
        list.push(dayModel);
      }
    }
    return list;
  }
}
