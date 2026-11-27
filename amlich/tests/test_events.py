"""
Unit Tests for Calendar Event Logic and Recurring Lunar Calculations
"""

import unittest
import sys
import os

# Ensure scripts dir is in sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'scripts')))

from vietnam_lunar import (
    resolve_annual_lunar_event,
    get_days_in_lunar_month,
    convert_solar_to_lunar,
    convert_lunar_to_solar
)


class TestEventRecurrence(unittest.TestCase):

    def test_annual_lunar_anniversary(self):
        """
        Test recurring annual lunar event (e.g. Giỗ ngày 15 tháng 7 Âm lịch).
        Must correctly compute the solar date for consecutive years.
        """
        # 15/7 Lunar Vu Lan
        # 2024: 15/7 lunar was 2024-08-18
        # 2025: 15/7 lunar is 2025-09-06
        # 2026: 15/7 lunar is 2026-08-27
        d2024 = resolve_annual_lunar_event(15, 7, 2024)
        self.assertEqual(d2024, (18, 8, 2024))

        d2025 = resolve_annual_lunar_event(15, 7, 2025)
        self.assertEqual(d2025, (6, 9, 2025))

        d2026 = resolve_annual_lunar_event(15, 7, 2026)
        self.assertEqual(d2026, (27, 8, 2026))

    def test_day_30_missing_fallback_policy(self):
        """
        Test day 30 falling back to day 29 when the lunar month only has 29 days.
        """
        # In 2025, let's find a lunar month with 29 days
        short_month = None
        for m in range(1, 13):
            if get_days_in_lunar_month(m, 2025) == 29:
                short_month = m
                break
        self.assertIsNotNone(short_month, "Expected at least one 29-day month in 2025")

        # Fallback enabled
        resolved = resolve_annual_lunar_event(30, short_month, 2025, fallback_to_last_day=True)
        self.assertIsNotNone(resolved)
        back_ld, back_lm, back_ly, _ = convert_solar_to_lunar(resolved[0], resolved[1], resolved[2])
        self.assertEqual(back_ld, 29)
        self.assertEqual(back_lm, short_month)

        # Fallback disabled -> should return None
        strict = resolve_annual_lunar_event(30, short_month, 2025, fallback_to_last_day=False)
        self.assertIsNone(strict)

    def test_giao_thua_resolution(self):
        """
        Giao Thừa (Đêm 30 Tết):
        In years where month 12 only has 29 days (tháng chạp thiếu),
        Tất Niên must resolve to day 29, the last day of the year.
        """
        for yr in [2024, 2025, 2026, 2027]:
            resolved = resolve_annual_lunar_event(30, 12, yr, fallback_to_last_day=True)
            self.assertIsNotNone(resolved)
            # The next day must be Mùng 1 Tết of next lunar year
            ld, lm, ly, _ = convert_solar_to_lunar(resolved[0], resolved[1], resolved[2])
            days_in_m12 = get_days_in_lunar_month(12, yr)
            self.assertEqual(ld, days_in_m12)
            self.assertEqual(lm, 12)


if __name__ == '__main__':
    unittest.main()
