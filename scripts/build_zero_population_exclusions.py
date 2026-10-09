#!/usr/bin/env python3
"""Build the 1395 census zero-population settlement exclusion data.

Uses only Python's standard library. It leaves the original Excel workbooks
and the human-maintained geography Markdown files untouched.
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
import xml.etree.ElementTree as ET
from collections import defaultdict
from pathlib import Path
from zipfile import ZipFile

NS = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}


def normalize(value: str) -> str:
    value = (value or "").strip().replace("ي", "ی").replace("ى", "ی").replace("ك", "ک")
    value = value.replace("\u200c", " ").replace("\u200f", "")
    return re.sub(r"\s+", " ", value).strip()


def read_census(workbook: Path) -> list[tuple[str, str, str, str, int]]:
    rows: list[tuple[str, str, str, str, int]] = []
    with ZipFile(workbook) as archive:
        shared_root = ET.fromstring(archive.read("xl/sharedStrings.xml"))
        shared = [
            "".join(text.text or "" for text in item.findall(".//m:t", NS))
            for item in shared_root.findall("m:si", NS)
        ]
        sheet_root = ET.fromstring(archive.read("xl/worksheets/sheet1.xml"))
        for row in sheet_root.findall(".//m:sheetData/m:row", NS)[2:]:
            values: dict[str, str] = {}
            for cell in row.findall("m:c", NS):
                column = re.match(r"[A-Z]+", cell.attrib["r"]).group()
                node = cell.find("m:v", NS)
                value = node.text if node is not None else ""
                if cell.attrib.get("t") == "s" and value:
                    value = shared[int(value)]
                values[column] = value.strip()

            code, settlement, population = values.get("J", ""), values.get("K", ""), values.get("P", "")
            if not code or not settlement or not population:
                continue
            try:
                population_value = int(population.replace(",", ""))
            except ValueError:
                continue
            rows.append(
                (
                    normalize(values.get("B", "")),
                    normalize(values.get("D", "")),
                    normalize(settlement),
                    code.strip(),
                    population_value,
                )
            )
    return rows


def read_markdown(path: Path) -> list[dict[str, str]]:
    province = county = None
    rows: list[dict[str, str]] = []
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if line.startswith("## "):
            province, county = line[3:].strip(), None
        elif line.startswith("### "):
            county = line[4:].strip()
        elif line.startswith("- ") and not line.startswith("- تعداد") and province and county:
            rows.append(
                {
                    "province": province,
                    "county": county,
                    "settlement": line[2:].strip(),
                }
            )
    return rows


def key(row: dict[str, str] | tuple[str, str, str]) -> tuple[str, str, str]:
    if isinstance(row, dict):
        values = (row["province"], row["county"], row["settlement"])
    else:
        values = row
    return tuple(normalize(value) for value in values)


def write_tsv(path: Path, header: list[str], rows: list[list[object]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.writer(stream, delimiter="\t", lineterminator="\n")
        writer.writerow(header)
        writer.writerows(rows)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--workbooks",
        type=Path,
        default=Path("/home/sadeq/personalinformation/SD/VetoApp Documents/روستاهای ایران"),
    )
    parser.add_argument(
        "--project",
        type=Path,
        default=Path(__file__).resolve().parents[1],
    )
    args = parser.parse_args()
    seed_dir = args.project / "app/database/seed_data"
    workbook_paths = sorted(args.workbooks.glob("*.xlsx"))
    if len(workbook_paths) != 31:
        raise SystemExit(f"Expected 31 provincial workbooks, found {len(workbook_paths)}")

    census_rows = [row for path in workbook_paths for row in read_census(path)]
    census_by_key: dict[tuple[str, str, str], list[tuple[str, str, str, str, int]]] = defaultdict(list)
    for row in census_rows:
        census_by_key[key(row[:3])].append(row)
    zero_only = {
        item_key
        for item_key, rows in census_by_key.items()
        if rows and all(row[4] == 0 for row in rows)
    }
    mixed = {
        item_key: rows
        for item_key, rows in census_by_key.items()
        if any(row[4] == 0 for row in rows) and any(row[4] > 0 for row in rows)
    }
    census_by_province_name: dict[
        tuple[str, str], list[tuple[str, str, str, str, int]]
    ] = defaultdict(list)
    for row in census_rows:
        census_by_province_name[(row[0], row[2])].append(row)
    zero_only_province_names = {
        item_key
        for item_key, rows in census_by_province_name.items()
        if rows and all(row[4] == 0 for row in rows)
    }
    mixed_province_names = {
        item_key: rows
        for item_key, rows in census_by_province_name.items()
        if any(row[4] == 0 for row in rows) and any(row[4] > 0 for row in rows)
    }

    write_tsv(
        seed_dir / "zero_population_settlements_1395.tsv",
        ["province", "county", "settlement"],
        [list(item) for item in sorted(zero_only)],
    )
    write_tsv(
        seed_dir / "zero_population_name_collisions_1395.tsv",
        ["province", "county", "settlement", "zero_codes", "positive_code_population"],
        [
            [
                *item,
                ",".join(row[3] for row in rows if row[4] == 0),
                ",".join(f"{row[3]}:{row[4]}" for row in rows if row[4] > 0),
            ]
            for item, rows in sorted(mixed.items())
        ],
    )

    cities = read_markdown(seed_dir / "فهرست-شهرهای-ایران.md")
    villages = read_markdown(seed_dir / "فهرست-روستاهای-ایران.md")
    city_keys = {key(row) for row in cities}
    city_name_collisions = zero_only & city_keys
    safe_database_keys = zero_only - city_name_collisions
    city_province_names = {
        (normalize(row["province"]), normalize(row["settlement"])) for row in cities
    }
    city_province_name_collisions = zero_only_province_names & city_province_names
    safe_province_names = zero_only_province_names - city_province_names
    write_tsv(
        seed_dir / "zero_population_database_targets_1395.tsv",
        ["province", "county", "settlement"],
        [list(item) for item in sorted(safe_database_keys)],
    )
    write_tsv(
        seed_dir / "zero_population_city_name_collisions_1395.tsv",
        ["province", "county", "settlement"],
        [list(item) for item in sorted(city_name_collisions)],
    )
    write_tsv(
        seed_dir / "zero_population_province_targets_1395.tsv",
        ["province", "settlement"],
        [list(item) for item in sorted(safe_province_names)],
    )
    write_tsv(
        seed_dir / "zero_population_province_mixed_names_1395.tsv",
        ["province", "settlement", "zero_counties", "positive_counties"],
        [
            [
                *item,
                ",".join(sorted({row[1] for row in rows if row[4] == 0})),
                ",".join(sorted({row[1] for row in rows if row[4] > 0})),
            ]
            for item, rows in sorted(mixed_province_names.items())
        ],
    )
    write_tsv(
        seed_dir / "zero_population_province_city_collisions_1395.tsv",
        ["province", "settlement"],
        [list(item) for item in sorted(city_province_name_collisions)],
    )

    exclusions: set[tuple[str, str, str]] = set()
    province_counts: dict[str, int] = defaultdict(int)
    for row in villages:
        item_key = key(row)
        if item_key not in safe_database_keys:
            continue
        exclusions.add(item_key)
        province_counts[item_key[0]] += 1

    village_keys = {key(row) for row in villages}
    report = [
        "# Census 1395 zero-population settlement data",
        "",
        f"- Provincial workbooks read: {len(workbook_paths)}",
        f"- Census settlement-code records read: {len(census_rows):,}",
        f"- Census records with population 0: {sum(row[4] == 0 for row in census_rows):,}",
        f"- Distinct province/county/name groups that are all-zero: {len(zero_only):,}",
        f"- Distinct same-name groups with both zero and positive census records: {len(mixed):,}",
        f"- Distinct province/name groups with only zero-population records: {len(zero_only_province_names):,}",
        f"- Province/name groups with zero and positive population records (excluded): {len(mixed_province_names):,}",
        f"- Safe province/name targets after excluding same-named cities: {len(safe_province_names):,}",
        f"- Province/name targets excluded because they also name a city: {len(city_province_name_collisions):,}",
        f"- Current village seed entries matching a safe target: {sum(province_counts.values()):,}",
        f"- Distinct safe province/county/name database targets: {len(safe_database_keys):,}",
        f"- All-zero names also used by a city record (excluded from name-based migration): {len(city_name_collisions):,}",
        f"- All-zero groups not present in the current village seed list: {len(zero_only - village_keys):,}",
        "",
        "The corrected server migration uses province/name because county boundaries changed since the 1395 census. It only considers province/name pairs whose every census record is zero, excludes names used by cities, and requires a unique matching settlement in the live database. Province/name pairs with any positive census record are in `zero_population_province_mixed_names_1395.tsv` and are excluded.",
        "",
        "## Matched seed entries by province",
        "",
        "| Province | Entries |",
        "|---|---:|",
    ]
    report.extend(f"| {province} | {count:,} |" for province, count in sorted(province_counts.items()))
    (seed_dir / "zero_population_report_1395.md").write_text("\n".join(report) + "\n", encoding="utf-8")
    print("\n".join(report[:13]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
