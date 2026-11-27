#!/usr/bin/env python3
"""
Validation Script for Vietnam Lunar Calendar Data
Validates data/public/*.json and ensures data/private adheres to zero-plaintext security.
"""

import json
import os
import sys
import re

REQUIRED_FIELDS = ['id', 'title', 'calendar_type', 'scope']
VALID_CALENDAR_TYPES = ['solar', 'lunar']
VALID_SCOPES = ['public', 'private']
VALID_RECURRENCES = ['none', 'annual_solar', 'annual_lunar']


def validate_event(event: dict, file_name: str, seen_ids: set) -> list:
    errors = []
    event_id = event.get('id')

    if not event_id or not isinstance(event_id, str):
        errors.append(f"Missing or invalid 'id' in {file_name}: {event}")
        return errors

    if event_id in seen_ids:
        errors.append(f"Duplicate event ID '{event_id}' in {file_name}")
    seen_ids.add(event_id)

    if not re.match(r'^[a-z0-9_-]+$', event_id):
        errors.append(f"ID '{event_id}' in {file_name} should contain only lowercase letters, numbers, dashes, and underscores.")

    for field in REQUIRED_FIELDS:
        if field not in event:
            errors.append(f"Event '{event_id}' in {file_name} missing required field '{field}'")

    cal_type = event.get('calendar_type')
    if cal_type not in VALID_CALENDAR_TYPES:
        errors.append(f"Event '{event_id}' has invalid calendar_type: {cal_type}")

    if cal_type == 'solar':
        day = event.get('solar_day')
        month = event.get('solar_month')
        if not (isinstance(day, int) and 1 <= day <= 31):
            errors.append(f"Event '{event_id}' has invalid solar_day: {day}")
        if not (isinstance(month, int) and 1 <= month <= 12):
            errors.append(f"Event '{event_id}' has invalid solar_month: {month}")

    elif cal_type == 'lunar':
        day = event.get('lunar_day')
        month = event.get('lunar_month')
        if not (isinstance(day, int) and 1 <= day <= 30):
            errors.append(f"Event '{event_id}' has invalid lunar_day: {day}")
        if not (isinstance(month, int) and 1 <= month <= 12):
            errors.append(f"Event '{event_id}' has invalid lunar_month: {month}")

    recurrence = event.get('recurrence', 'none')
    if recurrence not in VALID_RECURRENCES:
        errors.append(f"Event '{event_id}' has invalid recurrence: {recurrence}")

    if 'public' in file_name and event.get('scope') != 'public':
        errors.append(f"Event '{event_id}' in public file {file_name} has non-public scope '{event.get('scope')}'")

    return errors


def validate_public_file(file_path: str, seen_ids: set) -> list:
    errors = []
    if not os.path.exists(file_path):
        return [f"File not found: {file_path}"]

    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception as e:
        return [f"JSON syntax error in {file_path}: {e}"]

    if not isinstance(data, list):
        return [f"Root of {file_path} must be a JSON array"]

    for item in data:
        if not isinstance(item, dict):
            errors.append(f"Invalid item (not an object) in {file_path}")
            continue
        errors.extend(validate_event(item, os.path.basename(file_path), seen_ids))

    return errors


def validate_private_folder(folder_path: str) -> list:
    """Ensure no unencrypted sensitive data is committed in plaintext."""
    errors = []
    if not os.path.exists(folder_path):
        return errors

    for root, _, files in os.walk(folder_path):
        for f in files:
            if f.endswith('.md') or f.startswith('.'):
                continue
            if f.endswith('.json'):
                full_path = os.path.join(root, f)
                try:
                    with open(full_path, 'r', encoding='utf-8') as jf:
                        content = json.load(jf)
                        if isinstance(content, dict):
                            if not content.get('encrypted', False):
                                errors.append(f"SECURITY ALERT: Unencrypted private JSON file detected at {full_path}!")
                        elif isinstance(content, list):
                            errors.append(f"SECURITY ALERT: Plaintext JSON array detected in private directory at {full_path}!")
                except Exception as e:
                    errors.append(f"Error reading private file {full_path}: {e}")
    return errors


def main():
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
    data_dir = os.path.join(repo_root, 'data')
    public_dir = os.path.join(data_dir, 'public')
    private_dir = os.path.join(data_dir, 'private')

    all_errors = []
    seen_ids = set()

    for pub_file in ['holidays.json', 'events.json']:
        fp = os.path.join(public_dir, pub_file)
        if os.path.exists(fp):
            all_errors.extend(validate_public_file(fp, seen_ids))
        else:
            all_errors.append(f"Missing required public file: {fp}")

    all_errors.extend(validate_private_folder(private_dir))

    if all_errors:
        print(f"Validation FAILED with {len(all_errors)} errors:")
        for err in all_errors:
            print(f" - {err}")
        sys.exit(1)
    else:
        print(f"Validation PASSED: {len(seen_ids)} valid public events verified. Private security check passed.")
        sys.exit(0)


if __name__ == '__main__':
    main()
