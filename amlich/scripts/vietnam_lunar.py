"""
Vietnam Lunar Calendar Astronomical Engine (Hồ Ngọc Đức algorithm)
Timezone: Asia/Ho_Chi_Minh (UTC+7, 105°E)
Reference: Jean Meeus, Astronomical Algorithms (1998)
"""

import math
from typing import Tuple, Optional, Dict, Any

VN_TIMEZONE = 7.0
JULIAN_EPOCH_1900 = 2415021.076998695
SYNODIC_MONTH = 29.530588853

CAN = ['Giáp', 'Ất', 'Bính', 'Đinh', 'Mậu', 'Kỷ', 'Canh', 'Tân', 'Nhâm', 'Quý']
CHI = ['Tý', 'Sửu', 'Dần', 'Mão', 'Thìn', 'Tỵ', 'Ngọ', 'Mùi', 'Thân', 'Dậu', 'Tuất', 'Hợi']
ANIMALS = ['Chuột', 'Trâu', 'Hổ', 'Mèo', 'Rồng', 'Rắn', 'Ngựa', 'Dê', 'Khỉ', 'Gà', 'Chó', 'Lợn']


def jd_from_date(dd: int, mm: int, yy: int) -> int:
    """Compute the Julian day number of day dd/mm/yyyy."""
    a = (14 - mm) // 12
    y = yy + 4800 - a
    m = mm + 12 * a - 3
    jd = dd + ((153 * m + 2) // 5) + 365 * y + (y // 4) - (y // 100) + (y // 400) - 32045
    if jd < 2299161:
        jd = dd + ((153 * m + 2) // 5) + 365 * y + (y // 4) - 32083
    return jd


def jd_to_date(jd: int) -> Tuple[int, int, int]:
    """Convert Julian day number to (day, month, year)."""
    if jd > 2299160:
        a = jd + 32044
        b = (4 * a + 3) // 146097
        c = a - (b * 146097) // 4
    else:
        b = 0
        c = jd + 32082
    d = (4 * c + 3) // 1461
    e = c - (1461 * d) // 4
    m = (5 * e + 2) // 153
    day = e - ((153 * m + 2) // 5) + 1
    month = m + 3 - 12 * (m // 10)
    year = b * 100 + d - 4800 + (m // 10)
    return day, month, year


def new_moon(k: int) -> float:
    """Compute the k-th new moon since 1900-01-01."""
    t = k / 1236.85
    t2 = t * t
    t3 = t2 * t
    dr = math.pi / 180.0
    jd1 = 2415020.75933 + 29.53058868 * k + 0.0001178 * t2 - 0.000000155 * t3
    jd1 += 0.00033 * math.sin((166.56 + 132.87 * t - 0.009173 * t2) * dr)
    m = 359.2242 + 29.10535608 * k - 0.0000333 * t2 - 0.00000347 * t3
    mpr = 306.0253 + 385.81691806 * k + 0.0107306 * t2 + 0.00001236 * t3
    f = 21.2964 + 390.67050646 * k - 0.0016528 * t2 - 0.00000239 * t3

    c1 = (0.1734 - 0.000393 * t) * math.sin(m * dr) + 0.0021 * math.sin(2 * dr * m)
    c1 -= 0.4068 * math.sin(mpr * dr) - 0.0161 * math.sin(dr * 2 * mpr)
    c1 -= 0.0004 * math.sin(dr * 3 * mpr)
    c1 += 0.0104 * math.sin(dr * 2 * f) - 0.0051 * math.sin(dr * (m + mpr))
    c1 -= 0.0074 * math.sin(dr * (m - mpr)) + 0.0004 * math.sin(dr * (2 * f + m))
    c1 -= 0.0004 * math.sin(dr * (2 * f - m)) - 0.0006 * math.sin(dr * (2 * f + mpr))
    c1 += 0.0010 * math.sin(dr * (2 * f - mpr)) + 0.0005 * math.sin(dr * (2 * mpr + m))

    if t < -11:
        delta = 0.001 + 0.000839 * t + 0.0002261 * t2 - 0.00000845 * t3 - 0.000000081 * t * t3
    else:
        delta = -0.000278 + 0.000265 * t + 0.000262 * t2
    return jd1 + c1 - delta


def sun_longitude(jdn: float) -> float:
    """True solar longitude in radians."""
    t = (jdn - 2451545.0) / 36525.0
    t2 = t * t
    dr = math.pi / 180.0
    m = 357.52910 + 35999.05030 * t - 0.0001559 * t2 - 0.00000048 * t * t2
    l0 = 280.46645 + 36000.76983 * t + 0.0003032 * t2
    dl = (1.914600 - 0.004817 * t - 0.000014 * t2) * math.sin(dr * m)
    dl += (0.019993 - 0.000101 * t) * math.sin(dr * 2 * m) + 0.000290 * math.sin(dr * 3 * m)
    l = (l0 + dl) * dr
    l = l - 2 * math.pi * math.floor(l / (2 * math.pi))
    return l


def get_sun_longitude(day_number: int, time_zone: float = VN_TIMEZONE) -> int:
    """Return solar term index (0..11) at midnight."""
    return math.floor(sun_longitude(day_number - 0.5 - time_zone / 24.0) / math.pi * 6.0)


def get_new_moon_day(k: int, time_zone: float = VN_TIMEZONE) -> int:
    return math.floor(new_moon(k) + 0.5 + time_zone / 24.0)


def get_lunar_month_11(yy: int, time_zone: float = VN_TIMEZONE) -> int:
    """Find start of lunar month 11 (containing Winter Solstice)."""
    off = jd_from_date(31, 12, yy) - 2415021
    k = int(off / SYNODIC_MONTH)
    nm = get_new_moon_day(k, time_zone)
    sun_long = get_sun_longitude(nm, time_zone)
    if sun_long >= 9:
        nm = get_new_moon_day(k - 1, time_zone)
    return nm


def get_leap_month_offset(a11: int, time_zone: float = VN_TIMEZONE) -> int:
    k = math.floor((a11 - JULIAN_EPOCH_1900) / SYNODIC_MONTH + 0.5)
    last = 0
    i = 1
    arc = get_sun_longitude(get_new_moon_day(k + i, time_zone), time_zone)
    while True:
        last = arc
        i += 1
        arc = get_sun_longitude(get_new_moon_day(k + i, time_zone), time_zone)
        if arc == last or i >= 14:
            break
    return i - 1


def convert_solar_to_lunar(dd: int, mm: int, yy: int, time_zone: float = VN_TIMEZONE) -> Tuple[int, int, int, int]:
    """
    Convert solar date dd/mm/yyyy to lunar date.
    Returns: (lunar_day, lunar_month, lunar_year, is_leap: 0 or 1)
    """
    day_number = jd_from_date(dd, mm, yy)
    k = int((day_number - JULIAN_EPOCH_1900) / SYNODIC_MONTH)
    month_start = get_new_moon_day(k + 1, time_zone)
    if month_start > day_number:
        month_start = get_new_moon_day(k, time_zone)
    a11 = get_lunar_month_11(yy, time_zone)
    b11 = a11
    if a11 >= month_start:
        lunar_year = yy
        a11 = get_lunar_month_11(yy - 1, time_zone)
    else:
        lunar_year = yy + 1
        b11 = get_lunar_month_11(yy + 1, time_zone)
    lunar_day = day_number - month_start + 1
    diff = (month_start - a11) // 29
    lunar_leap = 0
    lunar_month = diff + 11
    if b11 - a11 > 365:
        leap_month_diff = get_leap_month_offset(a11, time_zone)
        if diff >= leap_month_diff:
            lunar_month = diff + 10
            if diff == leap_month_diff:
                lunar_leap = 1
    if lunar_month > 12:
        lunar_month -= 12
    if lunar_month >= 11 and diff < 4:
        lunar_year -= 1
    return lunar_day, lunar_month, lunar_year, lunar_leap


def convert_lunar_to_solar(lunar_day: int, lunar_month: int, lunar_year: int, lunar_leap: bool = False, time_zone: float = VN_TIMEZONE) -> Optional[Tuple[int, int, int]]:
    """
    Convert lunar date to solar date.
    Returns: (day, month, year) or None if invalid.
    """
    if lunar_month < 11:
        a11 = get_lunar_month_11(lunar_year - 1, time_zone)
        b11 = get_lunar_month_11(lunar_year, time_zone)
    else:
        a11 = get_lunar_month_11(lunar_year, time_zone)
        b11 = get_lunar_month_11(lunar_year + 1, time_zone)
    k = math.floor(0.5 + (a11 - JULIAN_EPOCH_1900) / SYNODIC_MONTH)
    off = lunar_month - 11
    if off < 0:
        off += 12
    if b11 - a11 > 365:
        leap_off = get_leap_month_offset(a11, time_zone)
        leap_month = leap_off - 2
        if leap_month < 0:
            leap_month += 12
        if lunar_leap and (lunar_month != leap_month):
            return None
        elif lunar_leap or (off >= leap_off):
            off += 1
    month_start = get_new_moon_day(k + off, time_zone)
    return jd_to_date(month_start + lunar_day - 1)


def get_days_in_lunar_month(lunar_month: int, lunar_year: int, lunar_leap: bool = False, time_zone: float = VN_TIMEZONE) -> int:
    """Return 29 or 30 days in the given lunar month."""
    solar30 = convert_lunar_to_solar(30, lunar_month, lunar_year, lunar_leap, time_zone)
    if not solar30:
        return 29
    ld, lm, ly, lleap = convert_solar_to_lunar(solar30[0], solar30[1], solar30[2], time_zone)
    if ld == 30 and lm == lunar_month and bool(lleap) == bool(lunar_leap):
        return 30
    return 29


def resolve_annual_lunar_event(
    lunar_day: int,
    lunar_month: int,
    target_solar_year: int,
    is_leap: bool = False,
    fallback_to_last_day: bool = True,
    time_zone: float = VN_TIMEZONE
) -> Optional[Tuple[int, int, int]]:
    """
    Resolve the solar date of an annual recurring lunar event in target_solar_year.
    Handles short months (e.g. day 30 falling back to day 29 if month has only 29 days).
    """
    # In target_solar_year, the lunar year usually matches target_solar_year
    lunar_year = target_solar_year
    days_in_month = get_days_in_lunar_month(lunar_month, lunar_year, is_leap, time_zone)

    effective_day = lunar_day
    if lunar_day > days_in_month:
        if fallback_to_last_day:
            effective_day = days_in_month
        else:
            return None

    solar = convert_lunar_to_solar(effective_day, lunar_month, lunar_year, is_leap, time_zone)
    # If it falls into previous year or next year, re-check
    if solar:
        return solar

    # Fallback to non-leap if requested leap month does not exist this year
    if is_leap:
        days_in_month_reg = get_days_in_lunar_month(lunar_month, lunar_year, False, time_zone)
        effective_day = min(lunar_day, days_in_month_reg)
        return convert_lunar_to_solar(effective_day, lunar_month, lunar_year, False, time_zone)

    return None


def get_can_chi_year(lunar_year: int) -> str:
    can_idx = (lunar_year + 6) % 10
    chi_idx = (lunar_year + 8) % 12
    return f"{CAN[can_idx]} {CHI[chi_idx]}"


def get_can_chi_day(dd: int, mm: int, yy: int) -> str:
    jd = jd_from_date(dd, mm, yy)
    can_idx = (jd + 9) % 10
    chi_idx = (jd + 1) % 12
    return f"{CAN[can_idx]} {CHI[chi_idx]}"
