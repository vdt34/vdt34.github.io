/**
 * Clan Death Anniversaries (Lịch Giỗ Dòng Họ) & iCalendar RFC 5545 Exporter
 * Computes exact solar dates for lunar death anniversaries for 10 years ahead.
 */

import { convertLunar2Solar, convertSolar2Lunar, getDaysInLunarMonth } from '../../amlich/engine/vietnam-lunar.js';
import { getDayCanChi, getYearCanChi } from '../../amlich/engine/can-chi.js';

function escapeICSText(text) {
  if (!text) return '';
  return text
    .replace(/\\/g, '\\\\')
    .replace(/;/g, '\\;')
    .replace(/,/g, '\\,')
    .replace(/\r\n/g, '\\n')
    .replace(/\n/g, '\\n')
    .replace(/\r/g, '\\n');
}

function foldLine(line) {
  const enc = new TextEncoder();
  if (enc.encode(line).length <= 75) return line;

  const parts = [];
  let start = 0;
  let first = true;
  while (start < line.length) {
    const limit = first ? 75 : 74;
    let end = Math.min(start + limit, line.length);
    while (end > start && enc.encode(line.substring(start, end)).length > limit) {
      end--;
    }
    const chunk = line.substring(start, end);
    if (first) {
      parts.push(chunk);
      first = false;
    } else {
      parts.push(' ' + chunk);
    }
    start = end;
  }
  return parts.join('\r\n');
}

function formatNextDay(year, month, day) {
  const d = new Date(year, month - 1, day);
  d.setDate(d.getDate() + 1);
  const nextY = d.getFullYear();
  const nextM = String(d.getMonth() + 1).padStart(2, '0');
  const nextD = String(d.getDate()).padStart(2, '0');
  return `${nextY}${nextM}${nextD}`;
}

export class DeathAnniversaryManager {
  constructor(membersList) {
    this.members = membersList.filter(m => !m.is_alive && m.death && m.death.lunar_month && m.death.lunar_day);
  }

  /**
   * Get sorted list of death anniversaries in the current year
   */
  getAnniversariesForYear(year = new Date().getFullYear()) {
    const list = [];
    for (const m of this.members) {
      const lDay = m.death.lunar_day;
      const lMonth = m.death.lunar_month;
      const daysInMonth = getDaysInLunarMonth(lMonth, year, false);
      const effectiveDay = (lDay > daysInMonth) ? daysInMonth : lDay;

      const solar = convertLunar2Solar(effectiveDay, lMonth, year, false);
      if (solar) {
        const canChiDay = getDayCanChi(solar.day, solar.month, solar.year);
        const canChiYear = getYearCanChi(year);
        list.push({
          member: m,
          solarDate: solar,
          lunarDate: { day: lDay, month: lMonth, effectiveDay },
          canChiDay: canChiDay.name,
          canChiYear: canChiYear.name,
          note: m.death.note || ''
        });
      }
    }

    // Sort by solar date
    list.sort((a, b) => {
      const da = new Date(a.solarDate.year, a.solarDate.month - 1, a.solarDate.day);
      const db = new Date(b.solarDate.year, b.solarDate.month - 1, b.solarDate.day);
      return da - db;
    });

    return list;
  }

  /**
   * Generate RFC 5545 iCalendar stream for iPhone subscription
   */
  generateICS(yearsAhead = 10, clanName = 'Gia Phả Họ Vũ') {
    const curYear = new Date().getFullYear();
    const vevents = [];

    for (let y = curYear - 1; y <= curYear + yearsAhead; y++) {
      const items = this.getAnniversariesForYear(y);
      for (const item of items) {
        const m = item.member;
        const s = item.solarDate;
        const sMonth = String(s.month).padStart(2, '0');
        const sDay = String(s.day).padStart(2, '0');
        const dtstart = `${s.year}${sMonth}${sDay}`;
        const dtend = formatNextDay(s.year, s.month, s.day);

        const summary = `[Ngày Giỗ] ${m.name} (${m.title || 'Đời ' + m.generation})`;
        let desc = `Ngày Giỗ: ${item.lunarDate.day}/${item.lunarDate.month} Âm lịch (Năm ${item.canChiYear})\nNgày: ${item.canChiDay}\n`;
        if (m.grave?.location) {
          desc += `Mộ phần: ${m.grave.location}\n`;
        }
        if (item.note) {
          desc += `Ghi chú: ${item.note}\n`;
        }

        const uid = `gio-${m.id}-${y}@giapha.vdt34`;
        const dtstamp = `${curYear}0101T000000Z`;

        const lines = [
          'BEGIN:VEVENT',
          `UID:${uid}`,
          `DTSTAMP:${dtstamp}`,
          `DTSTART;VALUE=DATE:${dtstart}`,
          `DTEND;VALUE=DATE:${dtend}`,
          `SUMMARY:${escapeICSText(summary)}`,
          `DESCRIPTION:${escapeICSText(desc)}`,
          'CATEGORIES:NGAY_GIO,GIA_PHA',
          'CLASS:PUBLIC',
          'STATUS:CONFIRMED',
          'TRANSP:TRANSPARENT',
          // Alarm 1 day prior
          'BEGIN:VALARM',
          'ACTION:DISPLAY',
          `DESCRIPTION:${escapeICSText('Ngày mai là Ngày Giỗ: ' + m.name)}`,
          'TRIGGER:-P1D',
          'END:VALARM',
          'END:VEVENT'
        ];

        vevents.push(lines.map(foldLine).join('\r\n'));
      }
    }

    const header = [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//Vietnam Lunar Clan Genealogy//RFC 5545//VI',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
      `X-WR-CALNAME:${escapeICSText('Lịch Giỗ — ' + clanName)}`,
      `X-WR-CALDESC:${escapeICSText('Lịch Ngày Giỗ Tổ Tiên Dòng Họ theo Âm Lịch')}`,
      'X-WR-TIMEZONE:Asia/Ho_Chi_Minh'
    ].map(foldLine).join('\r\n');

    return `${header}\r\n${vevents.join('\r\n')}\r\nEND:VCALENDAR\r\n`;
  }

  downloadICS(clanName = 'Gia Phả Họ Vũ') {
    const ics = this.generateICS(10, clanName);
    const blob = new Blob([ics], { type: 'text/calendar;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `lich-gio-${clanName.toLowerCase().replace(/\s+/g, '-')}.ics`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    setTimeout(() => URL.revokeObjectURL(url), 2000);
  }
}
