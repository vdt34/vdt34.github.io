/**
 * Client-Side RFC 5545 iCalendar Exporter
 * Generates and downloads .ics files for Family Anniversaries (Ngày Giỗ) and Personal Events.
 * Automatically resolves lunar recurring dates into exact solar dates for the next 10 years.
 */

import { convertLunar2Solar, convertSolar2Lunar, getDaysInLunarMonth } from '../engine/vietnam-lunar.js';
import { getDayCanChi, getYearCanChi } from '../engine/can-chi.js';

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
  if (enc.encode(line).length <= 75) {
    return line;
  }
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

export function generateICSForEvents(eventsList, calendarName = 'Ngày Giỗ & Sự Kiện Gia Đình', yearsAhead = 10) {
  const currentYear = new Date().getFullYear();
  const yearRange = [];
  for (let y = currentYear - 1; y <= currentYear + yearsAhead; y++) {
    yearRange.push(y);
  }

  const vevents = [];

  for (const year of yearRange) {
    for (const ev of eventsList) {
      const calType = ev.calendar_type || 'solar';
      const recurrence = ev.recurrence || 'none';

      let solarDate = null;
      let annotation = '';

      if (calType === 'lunar') {
        const lDay = ev.lunar_day || 1;
        const lMonth = ev.lunar_month || 1;
        const isLeap = Boolean(ev.is_leap);
        const fallback = ev.fallback_to_last_day !== false;

        if (recurrence === 'annual_lunar') {
          // Resolve for target solar year
          let effectiveDay = lDay;
          const daysInMonth = getDaysInLunarMonth(lMonth, year, isLeap);
          if (lDay > daysInMonth) {
            if (fallback) {
              effectiveDay = daysInMonth;
            } else {
              continue; // Skip if strict
            }
          }
          const res = convertLunar2Solar(effectiveDay, lMonth, year, isLeap);
          if (res) {
            solarDate = res;
            const canChiYr = getYearCanChi(year);
            const canChiD = getDayCanChi(res.day, res.month, res.year);
            annotation = `Âm lịch: ${effectiveDay}/${lMonth} Năm ${canChiYr.name} (Ngày ${canChiD.name})`;
            if (effectiveDay !== lDay) {
              annotation += ` [Đã tự động lùi từ ngày 30 về 29 vì tháng thiếu]`;
            }
          }
        } else if (recurrence === 'none') {
          if (ev.solar_year === year) {
            const res = convertLunar2Solar(lDay, lMonth, year, isLeap);
            if (res) solarDate = res;
          }
        }
      } else if (calType === 'solar') {
        const sDay = ev.solar_day || 1;
        const sMonth = ev.solar_month || 1;
        if (recurrence === 'annual_solar') {
          solarDate = { day: sDay, month: sMonth, year: year };
          const lunar = convertSolar2Lunar(sDay, sMonth, year);
          annotation = `Âm lịch tương ứng: ${lunar.day}/${lunar.month}/${lunar.year}`;
        } else if (recurrence === 'none' && ev.solar_year === year) {
          solarDate = { day: sDay, month: sMonth, year: year };
        }
      }

      if (!solarDate) continue;

      const sYear = solarDate.year;
      const sMonth = String(solarDate.month).padStart(2, '0');
      const sDay = String(solarDate.day).padStart(2, '0');
      const dtstart = `${sYear}${sMonth}${sDay}`;
      const dtend = formatNextDay(solarDate.year, solarDate.month, solarDate.day);
      const uid = `event-${ev.id}-${year}@amlich.vn`;
      const dtstamp = `${currentYear}0101T000000Z`;

      const titlePrefix = ev.category === 'family_anniversary' ? '[Ngày Giỗ] ' : '';
      const summary = `${titlePrefix}${ev.title}`;
      const description = `${ev.description ? ev.description + '\n' : ''}${annotation}`;

      const lines = [
        'BEGIN:VEVENT',
        `UID:${uid}`,
        `DTSTAMP:${dtstamp}`,
        `DTSTART;VALUE=DATE:${dtstart}`,
        `DTEND;VALUE=DATE:${dtend}`,
        `SUMMARY:${escapeICSText(summary)}`,
        `DESCRIPTION:${escapeICSText(description)}`,
        `CATEGORIES:${escapeICSText(ev.category || 'EVENT')}`,
        'CLASS:PUBLIC',
        'STATUS:CONFIRMED',
        'TRANSP:TRANSPARENT',
        // Reminder alarm before 1 day (at 08:00 AM)
        'BEGIN:VALARM',
        'ACTION:DISPLAY',
        `DESCRIPTION:${escapeICSText('Nhắc nhở ngày giỗ: ' + ev.title)}`,
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
    'PRODID:-//Vietnam Lunar Calendar//RFC 5545 Export//VI',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    `X-WR-CALNAME:${escapeICSText(calendarName)}`,
    `X-WR-CALDESC:${escapeICSText('Lịch Ngày Giỗ và Sự kiện Âm Lịch Việt Nam')}`,
    'X-WR-TIMEZONE:Asia/Ho_Chi_Minh'
  ].map(foldLine).join('\r\n');

  const footer = 'END:VCALENDAR\r\n';
  return `${header}\r\n${vevents.join('\r\n')}\r\n${footer}`;
}

export function downloadICSFile(filename, icsContent) {
  const blob = new Blob([icsContent], { type: 'text/calendar;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  setTimeout(() => URL.revokeObjectURL(url), 2000);
}
