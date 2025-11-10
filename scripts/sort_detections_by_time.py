#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Sort detection lists in JSON files by their 'timestamp' field,
without changing the rest of the JSON structure.

Usage examples:
  python sort_detections_by_time.py path/to/file.json
  python sort_detections_by_time.py path/to/file.json --output path/to/sorted.json
  python sort_detections_by_time.py path/to/file.json --dry
"""

import argparse
import json
from datetime import datetime
from pathlib import Path
from typing import Any, List, Tuple
import os


def parse_timestamp(ts: Any) -> Tuple[int, Any]:
    """
    Return a sort key for a timestamp-like value.

    We try to parse ISO 8601; if that fails, we fall back to string
    comparison; if there's no timestamp, these items go to the end
    but keep their relative order (stable sort).
    """
    if isinstance(ts, str):
        # Normalize 'Z' to '+00:00' for fromisoformat
        normalized = ts.replace("Z", "+00:00")
        try:
            dt = datetime.fromisoformat(normalized)
            return (0, dt)  # parsed datetime
        except Exception:
            return (1, ts)  # unparsed string, still deterministic
    return (2, None)  # missing / non-string timestamp


def sort_records(records: List[dict], label: str) -> Tuple[List[dict], dict]:
    """
    Sort a list of detection-like records in-place by their 'timestamp' field.

    Returns (sorted_records, stats_dict).
    """
    if not records:
        return records, {
            "label": label,
            "count": 0,
            "changed": False,
            "first_before": None,
            "first_after": None,
            "last_before": None,
            "last_after": None,
            "out_of_order": 0,
            "count_before": 0,
            "count_after": 0,
        }

    # Extract timestamps for reporting
    def get_ts(obj: dict) -> Any:
        return obj.get("timestamp")

    before_first = get_ts(records[0])
    before_last = get_ts(records[-1])

    num_out_of_order = sum(
        1
        for i in range(1, len(records))
        if parse_timestamp(records[i].get("timestamp")) < parse_timestamp(records[i - 1].get("timestamp"))
    )

    # Stable sort by timestamp
    sorted_records = sorted(records, key=lambda obj: parse_timestamp(obj.get("timestamp")))

    after_first = get_ts(sorted_records[0])
    after_last = get_ts(sorted_records[-1])

    changed = any(a is not b for a, b in zip(records, sorted_records))

    stats = {
        "label": label,
        "count": len(records),
        "changed": changed,
        "first_before": before_first,
        "first_after": after_first,
        "last_before": before_last,
        "last_after": after_last,
        "out_of_order": num_out_of_order,
        "count_before": len(records),
        "count_after": len(sorted_records),
    }
    return sorted_records, stats


def process_file(path: Path, dry: bool = False, output: Path | None = None) -> None:
    """
    Load JSON, sort detection lists, and write back (or just report in --dry mode).
    """
    original_size = os.path.getsize(path)

    with path.open("r", encoding="utf-8") as f:
        data = json.load(f)

    stats_list = []

    # Case 1: Top-level list -> treat as detections list
    if isinstance(data, list):
        sorted_records, stats = sort_records(data, label="top-level-list")
        stats_list.append(stats)
        if not dry and stats["changed"]:
            data = sorted_records

    # Case 2: Top-level dict with 'detections' 
    elif isinstance(data, dict):
        # Always handle 'detections'
        if isinstance(data.get("detections"), list):
            sorted_records, stats = sort_records(data["detections"], label="detections")
            stats_list.append(stats)
            if not dry and stats["changed"]:
                data["detections"] = sorted_records

    # Anything else: just report and do nothing
    else:
        print(f"[WARN] {path}: unsupported JSON structure (type={type(data).__name__})")
        return

    # Report
    print(f"\n[INFO] {path}")
    if not stats_list:
        print("  No detection-like lists found.")
    else:
        for st in stats_list:
            if st["count"] == 0:
                print(f"  {st['label']}: empty list, nothing to sort.")
                continue
            print(f"  {st['label']}: {st['count']} records")
            print(f"    Count before    : {st['count_before']}")
            print(f"    Count after     : {st['count_after']}")
            print(f"    Requires sorting: {st['changed']}")
            print(f"    Out of order    : {st['out_of_order']}")
            print(f"    First before    : {st['first_before']}")
            print(f"    First after     : {st['first_after']}")
            print(f"    Last  before    : {st['last_before']}")
            print(f"    Last  after     : {st['last_after']}")
            print(f"    Original size   : {original_size / (1024*1024):.2f} MB")

    if dry:
        print("  [DRY] No changes written.")
        return

    # Determine output path
    if output is None:
        # In-place: write back to the same file
        out_path = path
    else:
        out_path = output

    # Write JSON back. We don't preserve original whitespace, but structure is identical.
    with out_path.open("w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    new_size = os.path.getsize(out_path)

    print(f"  [OK] Written to {out_path}")
    print(f"  New file size     : {new_size / (1024*1024):.2f} MB")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Sort detection lists in JSON files by 'timestamp', "
                    "leaving all other JSON structure untouched."
    )
    parser.add_argument("input", type=Path, help="Path to input JSON file")
    parser.add_argument(
        "-o", "--output", type=Path, default=None,
        help="Optional output file. If omitted, the input file is modified in-place."
    )
    parser.add_argument(
        "--dry", action="store_true",
        help="Dry run: analyze and report, but do NOT write any changes."
    )

    args = parser.parse_args()

    process_file(
        path=args.input,
        dry=args.dry,
        output=args.output,
    )


if __name__ == "__main__":
    main()