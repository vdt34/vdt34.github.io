/**
 * Vietnam Lunar Calendar Engine (Âm Lịch Việt Nam)
 * Based on the astronomical algorithm for UTC+7 (105°E) by Dr. Hồ Ngọc Đức (adapted from Jean Meeus)
 * Reference: Jean Meeus, Astronomical Algorithms (1998)
 */

export const VN_TIMEZONE = 7.0;
const JULIAN_EPOCH_1900 = 2415021.076998695;
const SYNODIC_MONTH = 29.530588853;

/**
 * Compute the Julian day number of day dd/mm/yyyy (Gregorian/Julian)
 */
export function jdFromDate(dd, mm, yy) {
  let a = Math.floor((14 - mm) / 12);
  let y = yy + 4800 - a;
  let m = mm + 12 * a - 3;
  let jd = dd + Math.floor((153 * m + 2) / 5) + 365 * y + Math.floor(y / 4) - Math.floor(y / 100) + Math.floor(y / 400) - 32045;
  if (jd < 2299161) {
    jd = dd + Math.floor((153 * m + 2) / 5) + 365 * y + Math.floor(y / 4) - 32083;
  }
  return jd;
}

/**
 * Convert Julian day number to [day, month, year]
 */
export function jdToDate(jd) {
  let a, b, c;
  if (jd > 2299160) {
    a = jd + 32044;
    b = Math.floor((4 * a + 3) / 146097);
    c = a - Math.floor((b * 146097) / 4);
  } else {
    b = 0;
    c = jd + 32082;
  }
  let d = Math.floor((4 * c + 3) / 1461);
  let e = c - Math.floor((1461 * d) / 4);
  let m = Math.floor((5 * e + 2) / 153);
  let day = e - Math.floor((153 * m + 2) / 5) + 1;
  let month = m + 3 - 12 * Math.floor(m / 10);
  let year = b * 100 + d - 4800 + Math.floor(m / 10);
  return [day, month, year];
}

/**
 * Compute the k-th new moon since 1900-01-01 13:52 UTC
 */
function newMoon(k) {
  let T = k / 1236.85;
  let t2 = T * T;
  let t3 = t2 * T;
  let dr = Math.PI / 180.0;
  let jd1 = 2415020.75933 + 29.53058868 * k + 0.0001178 * t2 - 0.000000155 * t3;
  jd1 += 0.00033 * Math.sin((166.56 + 132.87 * T - 0.009173 * t2) * dr);
  let M = 359.2242 + 29.10535608 * k - 0.0000333 * t2 - 0.00000347 * t3;
  let mpr = 306.0253 + 385.81691806 * k + 0.0107306 * t2 + 0.00001236 * t3;
  let F = 21.2964 + 390.67050646 * k - 0.0016528 * t2 - 0.00000239 * t3;

  let c1 = (0.1734 - 0.000393 * T) * Math.sin(M * dr) + 0.0021 * Math.sin(2 * dr * M);
  c1 -= 0.4068 * Math.sin(mpr * dr) - 0.0161 * Math.sin(dr * 2 * mpr);
  c1 -= 0.0004 * Math.sin(dr * 3 * mpr);
  c1 += 0.0104 * Math.sin(dr * 2 * F) - 0.0051 * Math.sin(dr * (M + mpr));
  c1 -= 0.0074 * Math.sin(dr * (M - mpr)) + 0.0004 * Math.sin(dr * (2 * F + M));
  c1 -= 0.0004 * Math.sin(dr * (2 * F - M)) - 0.0006 * Math.sin(dr * (2 * F + mpr));
  c1 += 0.0010 * Math.sin(dr * (2 * F - mpr)) + 0.0005 * Math.sin(dr * (2 * mpr + M));

  let delta;
  if (T < -11) {
    delta = 0.001 + 0.000839 * T + 0.0002261 * t2 - 0.00000845 * t3 - 0.000000081 * T * t3;
  } else {
    delta = -0.000278 + 0.000265 * T + 0.000262 * t2;
  }
  return jd1 + c1 - delta;
}

/**
 * Sun longitude in radians
 */
function sunLongitude(jdn) {
  let T = (jdn - 2451545.0) / 36525.0;
  let t2 = T * T;
  let dr = Math.PI / 180.0;
  let M = 357.52910 + 35999.05030 * T - 0.0001559 * t2 - 0.00000048 * T * t2;
  let l0 = 280.46645 + 36000.76983 * T + 0.0003032 * t2;
  let dl = (1.914600 - 0.004817 * T - 0.000014 * t2) * Math.sin(dr * M);
  dl += (0.019993 - 0.000101 * T) * Math.sin(dr * 2 * M) + 0.000290 * Math.sin(dr * 3 * M);
  let L = (l0 + dl) * dr;
  L = L - 2 * Math.PI * Math.floor(L / (2 * Math.PI));
  return L;
}

export function getSunLongitude(dayNumber, timeZone = VN_TIMEZONE) {
  return Math.floor(sunLongitude(dayNumber - 0.5 - timeZone / 24.0) / Math.PI * 6.0);
}

export function getNewMoonDay(k, timeZone = VN_TIMEZONE) {
  return Math.floor(newMoon(k) + 0.5 + timeZone / 24.0);
}

export function getLunarMonth11(yy, timeZone = VN_TIMEZONE) {
  let off = jdFromDate(31, 12, yy) - 2415021;
  let k = Math.floor(off / SYNODIC_MONTH);
  let nm = getNewMoonDay(k, timeZone);
  let sunLong = getSunLongitude(nm, timeZone);
  if (sunLong >= 9) {
    nm = getNewMoonDay(k - 1, timeZone);
  }
  return nm;
}

export function getLeapMonthOffset(a11, timeZone = VN_TIMEZONE) {
  let k = Math.floor((a11 - JULIAN_EPOCH_1900) / SYNODIC_MONTH + 0.5);
  let last = 0;
  let i = 1;
  let arc = getSunLongitude(getNewMoonDay(k + i, timeZone), timeZone);
  do {
    last = arc;
    i++;
    arc = getSunLongitude(getNewMoonDay(k + i, timeZone), timeZone);
  } while (arc !== last && i < 14);
  return i - 1;
}

/**
 * Convert Solar date (day, month, year) to Lunar date
 * Returns { day, month, year, leap: boolean, jd: number }
 */
export function convertSolar2Lunar(dd, mm, yy, timeZone = VN_TIMEZONE) {
  let dayNumber = jdFromDate(dd, mm, yy);
  let k = Math.floor((dayNumber - JULIAN_EPOCH_1900) / SYNODIC_MONTH);
  let monthStart = getNewMoonDay(k + 1, timeZone);
  if (monthStart > dayNumber) {
    monthStart = getNewMoonDay(k, timeZone);
  }
  let a11 = getLunarMonth11(yy, timeZone);
  let b11 = a11;
  let lunarYear;
  if (a11 >= monthStart) {
    lunarYear = yy;
    a11 = getLunarMonth11(yy - 1, timeZone);
  } else {
    lunarYear = yy + 1;
    b11 = getLunarMonth11(yy + 1, timeZone);
  }
  let lunarDay = dayNumber - monthStart + 1;
  let diff = Math.floor((monthStart - a11) / 29);
  let lunarLeap = 0;
  let lunarMonth = diff + 11;
  if (b11 - a11 > 365) {
    let leapMonthDiff = getLeapMonthOffset(a11, timeZone);
    if (diff >= leapMonthDiff) {
      lunarMonth = diff + 10;
      if (diff === leapMonthDiff) {
        lunarLeap = 1;
      }
    }
  }
  if (lunarMonth > 12) {
    lunarMonth -= 12;
  }
  if (lunarMonth >= 11 && diff < 4) {
    lunarYear -= 1;
  }
  return {
    day: lunarDay,
    month: lunarMonth,
    year: lunarYear,
    leap: lunarLeap === 1,
    jd: dayNumber
  };
}

/**
 * Convert Lunar date to Solar date
 * Returns { day, month, year } or null if invalid
 */
export function convertLunar2Solar(lunarDay, lunarMonth, lunarYear, lunarLeap = false, timeZone = VN_TIMEZONE) {
  let a11, b11;
  if (lunarMonth < 11) {
    a11 = getLunarMonth11(lunarYear - 1, timeZone);
    b11 = getLunarMonth11(lunarYear, timeZone);
  } else {
    a11 = getLunarMonth11(lunarYear, timeZone);
    b11 = getLunarMonth11(lunarYear + 1, timeZone);
  }
  let k = Math.floor(0.5 + (a11 - JULIAN_EPOCH_1900) / SYNODIC_MONTH);
  let off = lunarMonth - 11;
  if (off < 0) {
    off += 12;
  }
  if (b11 - a11 > 365) {
    let leapOff = getLeapMonthOffset(a11, timeZone);
    let leapMonth = leapOff - 2;
    if (leapMonth < 0) {
      leapMonth += 12;
    }
    if (lunarLeap && (lunarMonth !== leapMonth)) {
      return null;
    } else if (lunarLeap || (off >= leapOff)) {
      off += 1;
    }
  }
  let monthStart = getNewMoonDay(k + off, timeZone);
  let [day, month, year] = jdToDate(monthStart + lunarDay - 1);
  return { day, month, year };
}

/**
 * Get total days in a specific lunar month (29 or 30 days)
 */
export function getDaysInLunarMonth(lunarMonth, lunarYear, lunarLeap = false, timeZone = VN_TIMEZONE) {
  let start = convertLunar2Solar(1, lunarMonth, lunarYear, lunarLeap, timeZone);
  if (!start) return 0;
  let jd1 = jdFromDate(start.day, start.month, start.year);

  // Try day 30
  let solar30 = convertLunar2Solar(30, lunarMonth, lunarYear, lunarLeap, timeZone);
  if (!solar30) return 29;
  let checkBack = convertSolar2Lunar(solar30.day, solar30.month, solar30.year, timeZone);
  if (checkBack.day === 30 && checkBack.month === lunarMonth && checkBack.leap === Boolean(lunarLeap)) {
    return 30;
  }
  return 29;
}
