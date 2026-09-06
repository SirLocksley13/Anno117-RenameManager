#!/usr/bin/env python3
"""Static regression checks for the Rename Manager configurable Open shortcut."""

from __future__ import annotations

import argparse
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

EXPECTED_IDENTIFIER = "SirLocksleyRenameManagerOpen"
EXPECTED_COMMAND = "RenameManager.Open(RenameManager)"
LEGACY_IDENTIFIER = "RenameManagerOpen"
LEGACY_COMMAND = "RenameManager:Open()"
CONTROL_LABEL_LINE_ID = "2019720021"

EXPECTED_LABELS = {
    "texts_english.xml": "Rename Manager - Open",
    "texts_german.xml": "Rename Manager - Oeffnen",
    "texts_french.xml": "Rename Manager - Ouvrir",
}

EXPECTED_PARCHMENT_IDENTIFIERS = {
    *(f"RenameManagerSlot{i}" for i in range(1, 10)),
    "RenameManagerBack",
}


def text_of(item: ET.Element, name: str) -> str | None:
    node = item.find(name)
    return node.text if node is not None else None


def fail(errors: list[str], message: str) -> None:
    errors.append(message)


def validate(root: Path) -> list[str]:
    errors: list[str] = []

    assets_path = root / "data/base/config/export/assets.xml"
    modinfo_path = root / "modinfo.json"
    gui_path = root / "data/base/config/gui"

    try:
        assets_root = ET.parse(assets_path).getroot()
    except Exception as exc:  # pragma: no cover - diagnostic path
        return [f"assets.xml parse failed: {exc}"]

    items = assets_root.findall(".//Item")
    target_items = [
        item for item in items if text_of(item, "Identifier") == EXPECTED_IDENTIFIER
    ]

    if len(target_items) != 1:
        fail(
            errors,
            f"expected exactly one {EXPECTED_IDENTIFIER} item, found {len(target_items)}",
        )
    else:
        item = target_items[0]
        expected_fields = {
            "Command": EXPECTED_COMMAND,
            "Text": CONTROL_LABEL_LINE_ID,
            "Active": "Session",
            "Configurable": "1",
            "Identifier": EXPECTED_IDENTIFIER,
            "AvailableOnPlatforms": "PC",
            "HideInOptionMenu": "0",
            "AllowMultipleShortcuts": "1",
        }
        for field, expected in expected_fields.items():
            actual = text_of(item, field)
            if actual != expected:
                fail(errors, f"{EXPECTED_IDENTIFIER}: {field}={actual!r}, expected {expected!r}")

        modern = item.find("./InputTypes/Modern/KeyType")
        legacy = item.find("./InputTypes/Legacy/KeyType")
        if modern is None or modern.text != "Control;Alt;R":
            fail(errors, "Modern default is not Control;Alt;R")
        if legacy is None or legacy.text != "Control;Alt;R":
            fail(errors, "Legacy default is not Control;Alt;R")

    if any(text_of(item, "Identifier") == LEGACY_IDENTIFIER for item in items):
        fail(errors, f"legacy opener identifier {LEGACY_IDENTIFIER} is still registered")
    if any(text_of(item, "Command") == LEGACY_COMMAND for item in items):
        fail(errors, f"legacy opener command {LEGACY_COMMAND} is still registered")

    found_parchment = {
        text_of(item, "Identifier")
        for item in items
        if text_of(item, "Identifier") in EXPECTED_PARCHMENT_IDENTIFIERS
    }
    missing_parchment = sorted(EXPECTED_PARCHMENT_IDENTIFIERS - found_parchment)
    if missing_parchment:
        fail(errors, f"existing local parchment controls disappeared: {missing_parchment}")

    try:
        modinfo = json.loads(modinfo_path.read_text(encoding="utf-8"))
    except Exception as exc:  # pragma: no cover - diagnostic path
        fail(errors, f"modinfo.json parse failed: {exc}")
        modinfo = {}

    version = str(modinfo.get("Version", ""))
    if not version.startswith("1.0.1"):
        fail(errors, f"candidate version is {version!r}, expected 1.0.1* test/release version")

    for filename, expected_label in EXPECTED_LABELS.items():
        path = gui_path / filename
        try:
            xml_root = ET.parse(path).getroot()
        except Exception as exc:  # pragma: no cover - diagnostic path
            fail(errors, f"{filename} parse failed: {exc}")
            continue

        matches = []
        for text_node in xml_root.findall(".//Text"):
            line_id = text_node.find("LineId")
            value = text_node.find("Text")
            if line_id is not None and line_id.text == CONTROL_LABEL_LINE_ID:
                matches.append(value.text if value is not None else None)

        if matches != [expected_label]:
            fail(
                errors,
                f"{filename}: line {CONTROL_LABEL_LINE_ID}={matches!r}, expected [{expected_label!r}]",
            )

    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path("."))
    args = parser.parse_args()

    errors = validate(args.root.resolve())
    if errors:
        print("CONFIGURABLE OPEN VALIDATION: FAIL")
        for error in errors:
            print(f" - {error}")
        return 1

    print("CONFIGURABLE OPEN VALIDATION: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
