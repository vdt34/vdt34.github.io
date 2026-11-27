#!/usr/bin/env python3
"""
RFC 5545 iCalendar Generator for Vietnam Lunar Calendar
Generates standard .ics subscription feeds for iPhone, macOS, Google Calendar, Outlook.
Complies strictly with RFC 5545:
- UTF-8 encoding
- CRLF line endings (\r\n)
- 75 octets line folding (UTF-8 aware)
- Correct escaping of special characters (\, ;, ,, \n)
- Stable UIDs and DTSTAMP
- All-day VALUE=DATE format with non-inclusive DTEND
"""

import os
import sys
import json
import datetime
from typing import List, Dict, Any, Tuple

# Ensure scripts dir is in sys.path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vietnam_lunar import (
    convert_solar_to_lunar,
    convert_lunar_to_solar,
    resolve_annual_lunar_event,
    get_can_chi_year,
    get_can_chi_day,
    get_days_in_lunar_month,
    jd_from_date,
    jd_to_date
)

CURRENT_YEAR = datetime.date.today().year
YEAR_RANGE = range(CURRENT_YEAR - 1, CURRENT_YEAR + 6)  # 7-year subscription window


def escape_ics_text(text: str) -> str:
    """Escape text according to RFC 5545 section 3.3.11."""
    if not text:
        return ""
    text = text.replace('\\', '\\\\')
    text = text.replace(';', '\\;')
    text = text.replace(',', '\\,')
    text = text.replace('\r\n', '\\n').replace('\n', '\\n').replace('\r', '\\n')
    return text


def fold_line(line: str) -> str:
    """
    Fold long lines at 75 octets (UTF-8 bytes) according to RFC 5545 section 3.1.
    Subsequent lines start with a single space.
    """
    line_bytes = line.encode('utf-8')
    if len(line_bytes) <= 75:
        return line

    parts = []
    # First line up to 75 octets
    limit = 75
    start = 0
    first = True
    while start < len(line):
        cur_limit = 75 if first else 74  # Account for leading space on continuation lines
        # Binary search or scan for safe cut point without splitting UTF-8 multibyte character
        end = min(start + cur_limit, len(line))
        while end > start and len(line[start:end].encode('utf-8')) > cur_limit:
            end -= 1

        chunk = line[start:end]
        if first:
            parts.append(chunk)
            first = False
        else:
            parts.append(' ' + chunk)
        start = end

    return '\r\n'.join(parts)


def format_date_next_day(year: int, month: int, day: int) -> str:
    """Return YYYYMMDD for next day (non-inclusive DTEND for all-day event)."""
    d = datetime.date(year, month, day) + datetime.timedelta(days=1)
    return d.strftime('%Y%m%d')


class ICSCalendar:
    def __init__(self, cal_name: str, cal_desc: str, prodid: str = "-//Vietnam Lunar Calendar//RFC 5545//VI"):
        self.cal_name = cal_name
        self.cal_desc = cal_desc
        self.prodid = prodid
        self.events: List[str] = []

    def add_event(
        self,
        uid: str,
        summary: str,
        description: str,
        dtstart_date: Tuple[int, int, int],  # (day, month, year)
        categories: str = "LUNAR",
        created_dt: datetime.datetime = None,
        color: str = None
    ):
        s_day, s_month, s_year = dtstart_date
        dtstart_str = f"{s_year:04d}{s_month:02d}{s_day:02d}"
        dtend_str = format_date_next_day(s_year, s_month, s_day)

        if not created_dt:
            # Deterministic DTSTAMP for feed stability
            dtstamp_str = f"{s_year:04d}0101T000000Z"
        else:
            dtstamp_str = created_dt.strftime('%Y%m%dT%H%M%SZ')

        lines = [
            "BEGIN:VEVENT",
            f"UID:{uid}",
            f"DTSTAMP:{dtstamp_str}",
            f"DTSTART;VALUE=DATE:{dtstart_str}",
            f"DTEND;VALUE=DATE:{dtend_str}",
            f"SUMMARY:{escape_ics_text(summary)}",
            f"DESCRIPTION:{escape_ics_text(description)}",
            f"CATEGORIES:{escape_ics_text(categories)}",
            "CLASS:PUBLIC",
            "STATUS:CONFIRMED",
            "TRANSP:TRANSPARENT"
        ]
        if color:
            lines.append(f"COLOR:{color}")

        lines.append("END:VEVENT")

        folded_event = "\r\n".join(fold_line(ln) for ln in lines)
        self.events.append(folded_event)

    def to_ics(self) -> str:
        headers = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            f"PRODID:{self.prodid}",
            "CALSCALE:GREGORIAN",
            "METHOD:PUBLISH",
            f"X-WR-CALNAME:{escape_ics_text(self.cal_name)}",
            f"X-WR-CALDESC:{escape_ics_text(self.cal_desc)}",
            "X-WR-TIMEZONE:Asia/Ho_Chi_Minh"
        ]
        folded_headers = "\r\n".join(fold_line(h) for h in headers)
        body = "\r\n".join(self.events)
        footer = "END:VCALENDAR\r\n"
        if body:
            return f"{folded_headers}\r\n{body}\r\n{footer}"
        return f"{folded_headers}\r\n{footer}"


def generate_holidays_feed(holidays_data: List[Dict[str, Any]]) -> str:
    cal = ICSCalendar(
        cal_name="Ngày Lễ Việt Nam (Vietnam Holidays)",
        cal_desc="Lịch ngày lễ truyền thống, lễ tết và sự kiện quốc gia Việt Nam (UTC+7)"
    )

    for year in YEAR_RANGE:
        for item in holidays_data:
            item_id = item['id']
            title = item['title']
            desc = item.get('description', '')
            cal_type = item.get('calendar_type', 'solar')
            recurrence = item.get('recurrence', 'annual_solar')

            if cal_type == 'solar' and recurrence == 'annual_solar':
                s_day = item['solar_day']
                s_month = item['solar_month']
                try:
                    datetime.date(year, s_month, s_day)
                except ValueError:
                    continue
                # Add lunar info to description
                ld, lm, ly, lleap = convert_solar_to_lunar(s_day, s_month, year)
                can_chi_yr = get_can_chi_year(ly)
                can_chi_d = get_can_chi_day(s_day, s_month, year)
                full_desc = f"{desc}\nÂm lịch: {ld}/{lm} Năm {can_chi_yr} (Ngày {can_chi_d})"
                uid = f"holiday-{item_id}-{year}@amlich.vn"
                cal.add_event(uid, title, full_desc, (s_day, s_month, year), categories="HOLIDAY,NATIONAL")

            elif cal_type == 'lunar' and recurrence == 'annual_lunar':
                l_day = item['lunar_day']
                l_month = item['lunar_month']
                fallback = item.get('fallback_to_last_day', True)
                solar_date = resolve_annual_lunar_event(
                    lunar_day=l_day,
                    lunar_month=l_month,
                    target_solar_year=year,
                    fallback_to_last_day=fallback
                )
                if solar_date:
                    s_day, s_month, s_year = solar_date
                    can_chi_yr = get_can_chi_year(year)
                    can_chi_d = get_can_chi_day(s_day, s_month, s_year)
                    full_desc = f"{desc}\nÂm lịch: {l_day}/{l_month} Năm {can_chi_yr} (Ngày {can_chi_d})"
                    uid = f"holiday-{item_id}-{year}@amlich.vn"
                    cal.add_event(uid, title, full_desc, solar_date, categories="HOLIDAY,TRADITIONAL")

    return cal.to_ics()


def generate_lunar_phases_feed() -> str:
    """Generate Mùng 1 (New Moon) and Ngày Rằm (Full Moon) for all months in range."""
    cal = ICSCalendar(
        cal_name="Lịch Âm Mùng 1 & Ngày Rằm",
        cal_desc="Đánh dấu ngày Mùng 1 (Sóc) và Ngày Rằm 15 (Vọng) âm lịch hàng tháng (UTC+7)"
    )

    for year in YEAR_RANGE:
        # Loop through lunar months 1 to 12
        for l_month in range(1, 13):
            # Check regular month
            for is_leap in [False, True]:
                solar_m1 = convert_lunar_to_solar(1, l_month, year, is_leap)
                if solar_m1:
                    s_day, s_month, s_year = solar_m1
                    can_chi_yr = get_can_chi_year(year)
                    can_chi_d = get_can_chi_day(s_day, s_month, s_year)
                    leap_str = " (Nhuận)" if is_leap else ""
                    title = f"Mùng 1 Tháng {l_month}{leap_str} Âm Lịch"
                    desc = f"Ngày Mùng 1 đầu tháng {l_month} âm lịch năm {can_chi_yr}.\nNgày {can_chi_d}."
                    uid = f"lunar-mung1-{year}-{l_month}-{'leap' if is_leap else 'reg'}@amlich.vn"
                    cal.add_event(uid, title, desc, solar_m1, categories="LUNAR_PHASE")

                solar_r15 = convert_lunar_to_solar(15, l_month, year, is_leap)
                if solar_r15:
                    s_day, s_month, s_year = solar_r15
                    can_chi_yr = get_can_chi_year(year)
                    can_chi_d = get_can_chi_day(s_day, s_month, s_year)
                    leap_str = " (Nhuận)" if is_leap else ""
                    title = f"Ngày Rằm Tháng {l_month}{leap_str} Âm Lịch"
                    desc = f"Ngày Rằm (15) trăng tròn tháng {l_month} âm lịch năm {can_chi_yr}.\nNgày {can_chi_d}."
                    uid = f"lunar-ram-{year}-{l_month}-{'leap' if is_leap else 'reg'}@amlich.vn"
                    cal.add_event(uid, title, desc, solar_r15, categories="LUNAR_PHASE")

    return cal.to_ics()


def generate_public_events_feed(events_data: List[Dict[str, Any]]) -> str:
    cal = ICSCalendar(
        cal_name="Sự Kiện Cộng Đồng (Public Events)",
        cal_desc="Các sự kiện văn hóa, lễ hội cộng đồng theo lịch âm dương Việt Nam"
    )

    for year in YEAR_RANGE:
        for item in events_data:
            item_id = item['id']
            title = item['title']
            desc = item.get('description', '')
            cal_type = item.get('calendar_type', 'solar')
            recurrence = item.get('recurrence', 'annual_solar')

            if cal_type == 'lunar' and recurrence == 'annual_lunar':
                l_day = item['lunar_day']
                l_month = item['lunar_month']
                solar_date = resolve_annual_lunar_event(
                    lunar_day=l_day,
                    lunar_month=l_month,
                    target_solar_year=year,
                    fallback_to_last_day=item.get('fallback_to_last_day', True)
                )
                if solar_date:
                    s_day, s_month, s_year = solar_date
                    can_chi_yr = get_can_chi_year(year)
                    can_chi_d = get_can_chi_day(s_day, s_month, s_year)
                    full_desc = f"{desc}\nÂm lịch: {l_day}/{l_month} Năm {can_chi_yr} (Ngày {can_chi_d})"
                    uid = f"pub-event-{item_id}-{year}@amlich.vn"
                    cal.add_event(uid, title, full_desc, solar_date, categories="EVENT,COMMUNITY")

            elif cal_type == 'solar' and recurrence == 'annual_solar':
                s_day = item.get('solar_day')
                s_month = item.get('solar_month')
                if s_day and s_month:
                    try:
                        datetime.date(year, s_month, s_day)
                        uid = f"pub-event-{item_id}-{year}@amlich.vn"
                        cal.add_event(uid, title, desc, (s_day, s_month, year), categories="EVENT,COMMUNITY")
                    except ValueError:
                        continue

    return cal.to_ics()


def main():
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
    data_dir = os.path.join(repo_root, 'data', 'public')
    feeds_dir = os.path.join(repo_root, 'feeds')
    os.makedirs(feeds_dir, exist_ok=True)

    # 1. Holidays feed
    holidays_path = os.path.join(data_dir, 'holidays.json')
    if os.path.exists(holidays_path):
        with open(holidays_path, 'r', encoding='utf-8') as f:
            holidays_data = json.load(f)
        holidays_ics = generate_holidays_feed(holidays_data)
        out_path = os.path.join(feeds_dir, 'holidays.ics')
        with open(out_path, 'wb') as f:
            f.write(holidays_ics.encode('utf-8'))
        print(f"Generated {out_path} ({len(holidays_ics)} chars)")

    # 2. Lunar phases feed
    lunar_ics = generate_lunar_phases_feed()
    out_path = os.path.join(feeds_dir, 'lunar.ics')
    with open(out_path, 'wb') as f:
        f.write(lunar_ics.encode('utf-8'))
    print(f"Generated {out_path} ({len(lunar_ics)} chars)")

    # 3. Public events feed
    events_path = os.path.join(data_dir, 'events.json')
    if os.path.exists(events_path):
        with open(events_path, 'r', encoding='utf-8') as f:
            events_data = json.load(f)
        events_ics = generate_public_events_feed(events_data)
        out_path = os.path.join(feeds_dir, 'public-events.ics')
        with open(out_path, 'wb') as f:
            f.write(events_ics.encode('utf-8'))
        print(f"Generated {out_path} ({len(events_ics)} chars)")


if __name__ == '__main__':
    main()
