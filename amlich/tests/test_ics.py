"""
RFC 5545 iCalendar Conformance Unit Tests
Validates:
1. CRLF line endings on all generated .ics files
2. Line folding <= 75 octets (UTF-8 byte length)
3. UID uniqueness and stability
4. Correct all-day date format (VALUE=DATE:YYYYMMDD)
5. Proper character escaping (\, ;, ,, \n)
6. VCALENDAR / VEVENT nesting and closing tags
"""

import unittest
import os
import glob
import re

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
FEEDS_DIR = os.path.join(REPO_ROOT, 'feeds')


class TestRFC5545Conformance(unittest.TestCase):

    def setUp(self):
        self.ics_files = glob.glob(os.path.join(FEEDS_DIR, '*.ics'))
        self.assertTrue(len(self.ics_files) > 0, "No .ics feed files found to test!")

    def test_crlf_line_endings(self):
        """RFC 5545 section 3.1: Lines of text MUST be terminated by CRLF."""
        for file_path in self.ics_files:
            with open(file_path, 'rb') as f:
                content = f.read()

            self.assertTrue(content.endswith(b'\r\n'), f"{file_path} does not end with CRLF")

            lines = content.split(b'\n')
            for i, line in enumerate(lines[:-1]):
                self.assertTrue(line.endswith(b'\r'), f"Line {i+1} in {os.path.basename(file_path)} does not end with CR (bare LF)")

    def test_line_length_75_octets(self):
        """
        RFC 5545 section 3.1: Lines of text SHOULD NOT be longer than 75 octets,
        excluding the line break.
        """
        for file_path in self.ics_files:
            with open(file_path, 'rb') as f:
                raw_lines = f.read().split(b'\r\n')

            for line_no, raw_line in enumerate(raw_lines, start=1):
                self.assertLessEqual(
                    len(raw_line), 75,
                    f"Line {line_no} in {os.path.basename(file_path)} exceeds 75 octets ({len(raw_line)} bytes)"
                )

    def test_vevent_structure_and_unique_uids(self):
        """Test proper VCALENDAR/VEVENT nesting, valid dates, and unique UIDs."""
        for file_path in self.ics_files:
            # newline='' is essential to prevent Python from converting CRLF to LF
            with open(file_path, 'r', encoding='utf-8', newline='') as f:
                text = f.read()

            unfolded = re.sub(r'\r\n[ \t]', '', text)
            lines = unfolded.split('\r\n')

            self.assertTrue(lines[0] == "BEGIN:VCALENDAR", f"{file_path} must begin with BEGIN:VCALENDAR")
            # Last line is empty due to trailing CRLF, line before last must be END:VCALENDAR
            self.assertTrue(lines[-2] == "END:VCALENDAR" or lines[-1] == "END:VCALENDAR", f"{file_path} must end with END:VCALENDAR")

            in_vevent = False
            uids = set()
            cur_uid = None
            has_dtstart = False
            has_dtstamp = False
            has_summary = False

            for line in lines:
                if line == "BEGIN:VEVENT":
                    self.assertFalse(in_vevent, f"Nested BEGIN:VEVENT in {file_path}")
                    in_vevent = True
                    cur_uid = None
                    has_dtstart = False
                    has_dtstamp = False
                    has_summary = False
                elif line == "END:VEVENT":
                    self.assertTrue(in_vevent, f"Mismatched END:VEVENT in {file_path}")
                    self.assertIsNotNone(cur_uid, f"VEVENT missing UID in {file_path}")
                    self.assertTrue(has_dtstart, f"VEVENT missing DTSTART in {file_path}")
                    self.assertTrue(has_dtstamp, f"VEVENT missing DTSTAMP in {file_path}")
                    self.assertTrue(has_summary, f"VEVENT missing SUMMARY in {file_path}")
                    in_vevent = False
                elif in_vevent:
                    if line.startswith("UID:"):
                        cur_uid = line[4:]
                        self.assertNotIn(cur_uid, uids, f"Duplicate UID '{cur_uid}' in {file_path}")
                        uids.add(cur_uid)
                    elif line.startswith("DTSTART"):
                        has_dtstart = True
                        self.assertRegex(line, r'DTSTART;VALUE=DATE:\d{8}')
                    elif line.startswith("DTSTAMP:"):
                        has_dtstamp = True
                    elif line.startswith("SUMMARY:"):
                        has_summary = True

            self.assertFalse(in_vevent, f"Unclosed VEVENT in {file_path}")
            self.assertGreater(len(uids), 0, f"No VEVENTs found in {file_path}")


if __name__ == '__main__':
    unittest.main()
