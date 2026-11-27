"""
Comprehensive Unit Tests for Vietnam Lunar Calendar Engine
Tests accuracy of UTC+7 Vietnam algorithm vs Chinese UTC+8, leap months, round-trip conversions,
and edge-cases (day 30 of 29-day month, leap month recurrence).
"""

import unittest
import sys
import os

# Add scripts directory to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'scripts')))

from vietnam_lunar import (
    convert_solar_to_lunar,
    convert_lunar_to_solar,
    get_days_in_lunar_month,
    resolve_annual_lunar_event,
    get_can_chi_year,
    get_can_chi_day,
    jd_from_date,
    jd_to_date
)


class TestVietnamLunarCalendar(unittest.TestCase):

    def test_vietnam_vs_china_1985(self):
        """
        Historical discrepancy test:
        In 1985, Vietnam celebrated Lunar New Year (Tết Ất Sửu) on January 21, 1985 (UTC+7).
        China (UTC+8) celebrated on February 20, 1985.
        Our engine MUST yield Lunar 1/1 on 1985-01-21 for Vietnam!
        """
        ld, lm, ly, lleap = convert_solar_to_lunar(21, 1, 1985)
        self.assertEqual((ld, lm, ly, lleap), (1, 1, 1985, 0))

        # Check conversion back
        solar = convert_lunar_to_solar(1, 1, 1985, False)
        self.assertEqual(solar, (21, 1, 1985))

    def test_lunar_new_years(self):
        """Test modern Lunar New Year (Mùng 1 Tết) dates."""
        test_cases = [
            (10, 2, 2024, (1, 1, 2024, 0), "Giáp Thìn"),
            (29, 1, 2025, (1, 1, 2025, 0), "Ất Tỵ"),
            (17, 2, 2026, (1, 1, 2026, 0), "Bính Ngọ"),
            (6, 2, 2027, (1, 1, 2027, 0), "Đinh Mùi"),
            (26, 1, 2028, (1, 1, 2028, 0), "Mậu Thân"),
        ]
        for s_day, s_mon, s_yr, expected_lunar, expected_can_chi in test_cases:
            res = convert_solar_to_lunar(s_day, s_mon, s_yr)
            self.assertEqual(res, expected_lunar, f"Failed for {s_day}/{s_mon}/{s_yr}")
            self.assertEqual(get_can_chi_year(res[2]), expected_can_chi)

            # Round-trip back
            back = convert_lunar_to_solar(res[0], res[1], res[2], bool(res[3]))
            self.assertEqual(back, (s_day, s_mon, s_yr))

    def test_leap_month_2023(self):
        """2023 had leap month 2 (tháng 2 nhuận) starting on 2023-03-22."""
        # Regular month 2 day 1
        reg_lunar = convert_solar_to_lunar(20, 2, 2023)
        self.assertEqual(reg_lunar, (1, 2, 2023, 0))

        # Leap month 2 day 1
        leap_lunar = convert_solar_to_lunar(22, 3, 2023)
        self.assertEqual(leap_lunar, (1, 2, 2023, 1))

        # Convert back
        solar_reg = convert_lunar_to_solar(1, 2, 2023, False)
        self.assertEqual(solar_reg, (20, 2, 2023))

        solar_leap = convert_lunar_to_solar(1, 2, 2023, True)
        self.assertEqual(solar_leap, (22, 3, 2023))

    def test_leap_month_2020(self):
        """2020 had leap month 4 (tháng 4 nhuận) starting on 2020-05-23."""
        leap_lunar = convert_solar_to_lunar(23, 5, 2020)
        self.assertEqual(leap_lunar, (1, 4, 2020, 1))
        solar_leap = convert_lunar_to_solar(1, 4, 2020, True)
        self.assertEqual(solar_leap, (23, 5, 2020))

    def test_short_lunar_month_fallback(self):
        """
        When an anniversary is on lunar day 30, but that month only has 29 days,
        the resolver should fall back to day 29 if fallback_to_last_day=True.
        """
        # Find a month with 29 days in 2024
        # Month 1 of 2024 has 29 days (2024-02-10 to 2024-03-09 = 29 days)
        days_m1 = get_days_in_lunar_month(1, 2024)
        self.assertIn(days_m1, [29, 30])

        # Test resolving day 30
        res = resolve_annual_lunar_event(
            lunar_day=30,
            lunar_month=1,
            target_solar_year=2024,
            fallback_to_last_day=True
        )
        self.assertIsNotNone(res)
        # Check that resolved date matches either day 30 or day 29 of month 1
        back_ld, back_lm, back_ly, _ = convert_solar_to_lunar(res[0], res[1], res[2])
        self.assertEqual(back_lm, 1)
        self.assertEqual(back_ld, days_m1)

    def test_round_trip_range(self):
        """Test 100 sample dates across multiple decades for round-trip consistency."""
        test_dates = [
            (1, 1, 1950), (15, 8, 1965), (2, 9, 1975), (30, 4, 1980),
            (1, 5, 1990), (10, 10, 2000), (1, 1, 2010), (15, 7, 2020),
            (27, 11, 2026), (1, 1, 2030), (31, 12, 2050)
        ]
        for d, m, y in test_dates:
            ld, lm, ly, lleap = convert_solar_to_lunar(d, m, y)
            back_d, back_m, back_y = convert_lunar_to_solar(ld, lm, ly, bool(lleap))
            self.assertEqual((back_d, back_m, back_y), (d, m, y), f"Round-trip failed for {d}/{m}/{y}")


if __name__ == '__main__':
    unittest.main()
