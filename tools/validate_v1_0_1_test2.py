#!/usr/bin/env python3
"""Validate Rename Manager v1.0.1-test2 shared configurable controls contract."""

from __future__ import annotations

import argparse
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

OPEN_IDENTIFIER = "SirLocksleyRenameManagerOpen"
OPEN_COMMAND = "RenameManager.Open(RenameManager)"
CORE_DIR = "SirLocksley Parchment Controls Core [SubMod]"
CORE_MODID = "sirlocksley-parchment-controls-core"
CORE_VERSION = "1.0.1"
CONSUMER_GLOBAL = "SirLocksleyPC02"
CONSUMER_MODULE = "renamemanager/parchment-consumer.lua"

LOCAL_IDENTIFIERS = {*(f"RenameManagerSlot{i}" for i in range(1, 10)), "RenameManagerBack"}
SHARED_IDENTIFIERS = {*(f"SirLocksleyParchmentSelect{i}" for i in range(1, 10)), "SirLocksleyParchmentBack"}


def canonical_command(slot: int) -> str:
    return "; ".join(
        f"if SirLocksleyPC{i:02d} ~= nil and SirLocksleyPC{i:02d}.Handle ~= nil then "
        f"SirLocksleyPC{i:02d}.Handle(SirLocksleyPC{i:02d},{slot}) end"
        for i in range(1, 13)
    )


def child_text(item: ET.Element, name: str) -> str | None:
    child = item.find(name)
    return child.text if child is not None else None


def binding_items(xml_root: ET.Element) -> list[ET.Element]:
    return [item for item in xml_root.findall(".//Item") if item.find("Identifier") is not None]


def expect(errors: list[str], condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


def validate(root: Path) -> list[str]:
    errors: list[str] = []

    parent_assets = root / "data/base/config/export/assets.xml"
    parent_modinfo = root / "modinfo.json"
    consumer_path = root / CONSUMER_MODULE
    core_root = root / CORE_DIR
    core_assets = core_root / "data/base/config/export/assets.xml"
    core_modinfo = core_root / "modinfo.json"

    try:
        parent_xml = ET.parse(parent_assets).getroot()
    except Exception as exc:
        return [f"parent assets.xml parse failed: {exc}"]

    parent_items = binding_items(parent_xml)
    parent_identifiers = [child_text(item, "Identifier") for item in parent_items]
    expect(errors, parent_identifiers.count(OPEN_IDENTIFIER) == 1,
           f"expected exactly one parent {OPEN_IDENTIFIER} row")

    open_rows = [item for item in parent_items if child_text(item, "Identifier") == OPEN_IDENTIFIER]
    if len(open_rows) == 1:
        row = open_rows[0]
        expected = {
            "Command": OPEN_COMMAND,
            "Text": "2019720021",
            "Active": "Session",
            "Configurable": "1",
            "AvailableOnPlatforms": "PC",
            "HideInOptionMenu": "0",
            "AllowMultipleShortcuts": "1",
        }
        for field, value in expected.items():
            expect(errors, child_text(row, field) == value,
                   f"Open row {field}={child_text(row, field)!r}, expected {value!r}")
        for preset in ("Modern", "Legacy"):
            key = row.find(f"./InputTypes/{preset}/KeyType")
            expect(errors, key is not None and key.text == "Control;Alt;R",
                   f"Open {preset} default is not Control;Alt;R")

    leaked_local = sorted(set(parent_identifiers) & LOCAL_IDENTIFIERS)
    expect(errors, not leaked_local, f"legacy local parchment rows still registered: {leaked_local}")
    for item in parent_items:
        command = child_text(item, "Command") or ""
        if command.startswith("RenameManager:ParchmentShortcut(") or command == "RenameManager:BackToMenu()":
            errors.append(f"legacy local parchment command still registered: {command}")

    try:
        parent_info = json.loads(parent_modinfo.read_text(encoding="utf-8"))
    except Exception as exc:
        errors.append(f"parent modinfo.json parse failed: {exc}")
        parent_info = {}

    expect(errors, parent_info.get("Version") == "1.0.1-test2",
           f"parent version={parent_info.get('Version')!r}, expected '1.0.1-test2'")
    scripts = parent_info.get("Scripts") or {}
    modules = scripts.get("Modules") or []
    expect(errors, CONSUMER_MODULE in modules,
           f"{CONSUMER_MODULE} missing from Scripts.Modules")
    init = scripts.get("Init") or ""
    expect(errors, f'{CONSUMER_GLOBAL} = require("parchment-consumer")' in init,
           f"Init does not expose {CONSUMER_GLOBAL}")

    if not consumer_path.exists():
        errors.append(f"missing {CONSUMER_MODULE}")
    else:
        consumer = consumer_path.read_text(encoding="utf-8")
        expect(errors, "function Consumer:Handle(slot)" in consumer,
               "consumer does not expose Handle(slot)")
        expect(errors, "RenameManager:BackToMenu()" in consumer,
               "consumer does not delegate Back")
        expect(errors, "RenameManager:ParchmentShortcut(slot)" in consumer,
               "consumer does not delegate Entry 1..9")
        expect(errors, "slot < 1 or slot > 9" in consumer,
               "consumer does not bound entry slots to 1..9")

    if not core_modinfo.exists():
        errors.append(f"missing nested core modinfo: {core_modinfo.relative_to(root)}")
        core_info = {}
    else:
        try:
            core_info = json.loads(core_modinfo.read_text(encoding="utf-8"))
        except Exception as exc:
            errors.append(f"nested core modinfo parse failed: {exc}")
            core_info = {}
    expect(errors, core_info.get("ModID") == CORE_MODID,
           f"core ModID={core_info.get('ModID')!r}, expected {CORE_MODID!r}")
    expect(errors, core_info.get("Version") == CORE_VERSION,
           f"core Version={core_info.get('Version')!r}, expected {CORE_VERSION!r}")
    expect(errors, not core_info.get("Scripts"), "shared core must remain XML-only")

    if not core_assets.exists():
        errors.append(f"missing nested core assets: {core_assets.relative_to(root)}")
        return errors

    try:
        core_xml = ET.parse(core_assets).getroot()
    except Exception as exc:
        errors.append(f"nested core assets.xml parse failed: {exc}")
        return errors

    core_items = binding_items(core_xml)
    identifiers = [child_text(item, "Identifier") for item in core_items]
    found_shared = {i for i in identifiers if i in SHARED_IDENTIFIERS}
    expect(errors, found_shared == SHARED_IDENTIFIERS,
           f"shared identifiers mismatch; missing={sorted(SHARED_IDENTIFIERS - found_shared)}")
    expect(errors, len([i for i in identifiers if i in SHARED_IDENTIFIERS]) == 10,
           "shared core must register exactly ten production parchment rows")

    for slot in range(1, 10):
        identifier = f"SirLocksleyParchmentSelect{slot}"
        rows = [item for item in core_items if child_text(item, "Identifier") == identifier]
        if len(rows) != 1:
            errors.append(f"{identifier}: expected one row, found {len(rows)}")
            continue
        row = rows[0]
        expected_key = f"Control;Alt;Digit{slot}"
        expected_fields = {
            "Command": canonical_command(slot),
            "Active": "Session",
            "Configurable": "1",
            "AvailableOnPlatforms": "PC",
            "HideInOptionMenu": "0",
            "AllowMultipleShortcuts": "1",
        }
        for field, value in expected_fields.items():
            expect(errors, child_text(row, field) == value,
                   f"{identifier}: {field} mismatch")
        expect(errors, child_text(row, "Text") not in (None, ""),
               f"{identifier}: missing localized Text id")
        for preset in ("Modern", "Legacy"):
            key = row.find(f"./InputTypes/{preset}/KeyType")
            expect(errors, key is not None and key.text == expected_key,
                   f"{identifier}: {preset} default mismatch")

    back_rows = [item for item in core_items if child_text(item, "Identifier") == "SirLocksleyParchmentBack"]
    if len(back_rows) != 1:
        errors.append(f"SirLocksleyParchmentBack: expected one row, found {len(back_rows)}")
    else:
        row = back_rows[0]
        expected_fields = {
            "Command": canonical_command(0),
            "Active": "Session",
            "Configurable": "1",
            "AvailableOnPlatforms": "PC",
            "HideInOptionMenu": "0",
            "AllowMultipleShortcuts": "1",
        }
        for field, value in expected_fields.items():
            expect(errors, child_text(row, field) == value,
                   f"SirLocksleyParchmentBack: {field} mismatch")
        expect(errors, child_text(row, "Text") not in (None, ""),
               "SirLocksleyParchmentBack: missing localized Text id")
        for preset in ("Modern", "Legacy"):
            key = row.find(f"./InputTypes/{preset}/KeyType")
            expect(errors, key is not None and key.text == "Control;Alt;Digit0",
                   f"SirLocksleyParchmentBack: {preset} default mismatch")

    gui_dir = core_root / "data/base/config/gui"
    for language in ("english", "german", "french"):
        path = gui_dir / f"texts_{language}.xml"
        try:
            text_root = ET.parse(path).getroot()
        except Exception as exc:
            errors.append(f"core texts_{language}.xml parse failed: {exc}")
            continue
        values = {
            (node.findtext("LineId") or ""): (node.findtext("Text") or "")
            for node in text_root.findall(".//Text")
            if node.find("LineId") is not None
        }
        expect(errors, len(values) >= 10,
               f"core texts_{language}.xml has fewer than ten labels")
        expect(errors, "Parchment Controls - Back" in values.values(),
               f"core texts_{language}.xml lacks Back label")
        for slot in range(1, 10):
            expect(errors, f"Parchment Controls - Entry {slot}" in values.values(),
                   f"core texts_{language}.xml lacks Entry {slot} label")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path("."))
    args = parser.parse_args()
    errors = validate(args.root.resolve())
    if errors:
        print("RENAME MANAGER TEST2 VALIDATION: FAIL")
        for error in errors:
            print(f" - {error}")
        return 1
    print("RENAME MANAGER TEST2 VALIDATION: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
