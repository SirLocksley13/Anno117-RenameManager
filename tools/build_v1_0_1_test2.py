#!/usr/bin/env python3
"""Build Rename Manager v1.0.1-test2 from the verified test1 source tree.

The protected rename/search/navigation Lua file is copied byte-for-byte. This
builder changes only shortcut registration, adds the thin shared consumer, and
bundles the already-proven XML-only shared parchment controls contract.
"""

from __future__ import annotations

import json
import re
import shutil
import xml.etree.ElementTree as ET
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build-test2"
STAGE = BUILD / "Rename Manager"
ZIP_PATH = BUILD / "Rename_Manager_v1.0.1-test2_Shared_Configurable_Controls.zip"
CORE_DIR = "SirLocksley Parchment Controls Core [SubMod]"
CORE_VERSION = "1.0.1"
TEXT_BASE = 2088800000

LOCAL_BLOCK = re.compile(
    r"\n  <ModOp Type=\"add\" GUID=\"2001271\" Path=\"/Values/ShortcutConfig/InputBindings\">\s*"
    r"<Item>\s*<Command>RenameManager:ParchmentShortcut\(1\)</Command>.*?"
    r"</ModOp>",
    re.DOTALL,
)


def canonical_command(slot: int) -> str:
    return "; ".join(
        f"if SirLocksleyPC{i:02d} ~= nil and SirLocksleyPC{i:02d}.Handle ~= nil then "
        f"SirLocksleyPC{i:02d}.Handle(SirLocksleyPC{i:02d},{slot}) end"
        for i in range(1, 13)
    )


def copy_source() -> None:
    if BUILD.exists():
        shutil.rmtree(BUILD)
    STAGE.mkdir(parents=True)

    excluded_top = {".git", ".github", "tools", "build", "build-test2", "test-builds"}
    for source in ROOT.iterdir():
        if source.name in excluded_top:
            continue
        target = STAGE / source.name
        if source.is_dir():
            shutil.copytree(source, target)
        else:
            shutil.copy2(source, target)


def remove_local_parchment_rows() -> None:
    path = STAGE / "data/base/config/export/assets.xml"
    text = path.read_text(encoding="utf-8")
    updated, count = LOCAL_BLOCK.subn("", text, count=1)
    if count != 1:
        raise RuntimeError(f"expected one legacy Rename Manager parchment ModOp, removed {count}")
    if "RenameManagerSlot1" in updated or "RenameManagerBack" in updated:
        raise RuntimeError("legacy Rename Manager parchment identifiers remain after removal")
    path.write_text(updated, encoding="utf-8")


def add_consumer() -> None:
    path = STAGE / "renamemanager/parchment-consumer.lua"
    consumer = (
        "local Consumer = {}\n\n"
        "function Consumer:Handle(slot)\n"
        "    slot = tonumber(slot)\n"
        "    if slot == 0 then\n"
        "        return RenameManager:BackToMenu()\n"
        "    end\n"
        "    if slot == nil or slot < 1 or slot > 9 then\n"
        "        return false\n"
        "    end\n"
        "    return RenameManager:ParchmentShortcut(slot)\n"
        "end\n\n"
        "return Consumer\n"
    )
    path.write_text(consumer, encoding="utf-8")


def update_parent_modinfo() -> None:
    path = STAGE / "modinfo.json"
    info = json.loads(path.read_text(encoding="utf-8"))
    if info.get("Version") != "1.0.1-test1":
        raise RuntimeError(f"expected test1 source version, got {info.get('Version')!r}")
    info["Version"] = "1.0.1-test2"

    descriptions = info.get("Description", {})
    descriptions["English"] = (
        "Find and rename ships and trade routes directly in Anno 117. Rename Manager provides native in-game menus for ships and trade routes. "
        "Open Rename Manager and the shared Parchment Controls (Entry 1-9 and Back) are configurable in Settings -> Controls. "
        "Defaults remain Ctrl+Alt+R, Ctrl+Alt+1-9 and Ctrl+Alt+0. English, German and French. No new game required."
    )
    descriptions["German"] = (
        "Finde und benenne Schiffe und Handelsrouten direkt in Anno 117 um. Rename Manager bietet native In-Game-Menues fuer Schiffe und Handelsrouten. "
        "Rename Manager oeffnen sowie die gemeinsamen Parchment Controls (Eintrag 1-9 und Zurueck) sind unter Einstellungen -> Steuerung konfigurierbar. "
        "Die Standards bleiben Ctrl+Alt+R, Ctrl+Alt+1-9 und Ctrl+Alt+0. Englisch, Deutsch und Franzoesisch. Kein neues Spiel erforderlich."
    )
    descriptions["French"] = (
        "Trouvez et renommez les navires et les routes commerciales directement dans Anno 117. Rename Manager utilise les menus natifs du jeu. "
        "L'ouverture de Rename Manager et les commandes partagees Parchment Controls (Entrees 1-9 et Retour) sont configurables dans Parametres -> Commandes. "
        "Les valeurs par defaut restent Ctrl+Alt+R, Ctrl+Alt+1-9 et Ctrl+Alt+0. Anglais, allemand et francais. Aucune nouvelle partie n'est necessaire."
    )

    scripts = info["Scripts"]
    modules = list(scripts.get("Modules", []))
    consumer = "renamemanager/parchment-consumer.lua"
    if consumer not in modules:
        modules.append(consumer)
    scripts["Modules"] = modules
    scripts["Init"] = (
        'RenameManager = require("rename-manager"); '
        'SirLocksleyPC02 = require("parchment-consumer")'
    )

    path.write_text(json.dumps(info, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def update_readme() -> None:
    path = STAGE / "README.md"
    text = path.read_text(encoding="utf-8")
    text = text.replace("# Rename Manager v1.0.1-test1", "# Rename Manager v1.0.1-test2", 1)
    old = (
        "Numbered entries in supported parchments use:\n\n"
        "- **Ctrl+Alt+1-9** — select the numbered ship or trade route\n"
        "- **Ctrl+Alt+0** — back\n"
    )
    new = (
        "Numbered parchment navigation now uses the shared **Parchment Controls** entries in "
        "**Settings -> Controls**. Defaults remain Ctrl+Alt+1-9 for Entry 1-9 and Ctrl+Alt+0 for Back, "
        "but each can be remapped.\n"
    )
    if old not in text:
        raise RuntimeError("README test1 parchment paragraph not found")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


def write_core_assets(core: Path) -> None:
    export = core / "data/base/config/export"
    export.mkdir(parents=True, exist_ok=True)

    lines = [
        "<?xml version='1.0' encoding='utf-8'?>",
        "<ModOps>",
        '  <ModOp Type="add" GUID="2001271" Path="/Values/ShortcutConfig/InputBindings">',
    ]

    for slot in range(1, 10):
        line_id = TEXT_BASE + slot
        lines.extend([
            "    <Item>",
            f"      <Command>{canonical_command(slot)}</Command>",
            f"      <Text>{line_id}</Text>",
            "      <Active>Session</Active>",
            "      <Configurable>1</Configurable>",
            f"      <Identifier>SirLocksleyParchmentSelect{slot}</Identifier>",
            "      <AvailableOnPlatforms>PC</AvailableOnPlatforms>",
            "      <HideInOptionMenu>0</HideInOptionMenu>",
            "      <AllowMultipleShortcuts>1</AllowMultipleShortcuts>",
            "      <InputTypes>",
            f"        <Modern><KeyType>Control;Alt;Digit{slot}</KeyType></Modern>",
            f"        <Legacy><KeyType>Control;Alt;Digit{slot}</KeyType></Legacy>",
            "      </InputTypes>",
            "    </Item>",
        ])

    lines.extend([
        "    <Item>",
        f"      <Command>{canonical_command(0)}</Command>",
        f"      <Text>{TEXT_BASE + 10}</Text>",
        "      <Active>Session</Active>",
        "      <Configurable>1</Configurable>",
        "      <Identifier>SirLocksleyParchmentBack</Identifier>",
        "      <AvailableOnPlatforms>PC</AvailableOnPlatforms>",
        "      <HideInOptionMenu>0</HideInOptionMenu>",
        "      <AllowMultipleShortcuts>1</AllowMultipleShortcuts>",
        "      <InputTypes>",
        "        <Modern><KeyType>Control;Alt;Digit0</KeyType></Modern>",
        "        <Legacy><KeyType>Control;Alt;Digit0</KeyType></Legacy>",
        "      </InputTypes>",
        "    </Item>",
        "  </ModOp>",
        "</ModOps>",
        "",
    ])
    (export / "assets.xml").write_text("\n".join(lines), encoding="utf-8")


def write_core_texts(core: Path) -> None:
    gui = core / "data/base/config/gui"
    gui.mkdir(parents=True, exist_ok=True)
    labels = [(TEXT_BASE + slot, f"Parchment Controls - Entry {slot}") for slot in range(1, 10)]
    labels.append((TEXT_BASE + 10, "Parchment Controls - Back"))

    for language in ("english", "german", "french"):
        lines = [
            "<?xml version='1.0' encoding='utf-8'?>",
            "<ModOps>",
            '  <ModOp Add="/TextExport/Texts[1]">',
        ]
        for line_id, label in labels:
            lines.extend([
                "    <Text>",
                f"      <Text>{label}</Text>",
                f"      <LineId>{line_id}</LineId>",
                "    </Text>",
            ])
        lines.extend(["  </ModOp>", "</ModOps>", ""])
        (gui / f"texts_{language}.xml").write_text("\n".join(lines), encoding="utf-8")


def add_shared_core() -> None:
    core = STAGE / CORE_DIR
    core.mkdir(parents=True, exist_ok=True)
    info = {
        "ModID": "sirlocksley-parchment-controls-core",
        "Version": CORE_VERSION,
        "Anno": 8,
        "Difficulty": "cheat",
        "RequiresNewGame": False,
        "SafeToRemove": True,
        "ModName": {
            "English": "SirLocksley Parchment Controls Core",
            "German": "SirLocksley Parchment Controls Core",
            "French": "SirLocksley Parchment Controls Core",
        },
        "Category": {"English": "Mod", "German": "Mod", "French": "Mod"},
        "Description": {
            "English": "Shared configurable Entry 1-9 and Back controls for SirLocksley parchment utilities.",
            "German": "Gemeinsame konfigurierbare Eintrag-1-9- und Zurueck-Steuerung fuer SirLocksley-Parchment-Utilities.",
            "French": "Commandes partagees et configurables Entrees 1-9 et Retour pour les utilitaires SirLocksley.",
        },
        "CreatorName": "Dr. Enrico Handrick",
    }
    (core / "modinfo.json").write_text(json.dumps(info, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    write_core_assets(core)
    write_core_texts(core)


def validate_basic_parse() -> None:
    for path in STAGE.rglob("*.xml"):
        ET.parse(path)
    for path in STAGE.rglob("modinfo.json"):
        json.loads(path.read_text(encoding="utf-8"))


def package() -> None:
    if ZIP_PATH.exists():
        ZIP_PATH.unlink()
    with ZipFile(ZIP_PATH, "w", ZIP_DEFLATED) as zf:
        for path in sorted(STAGE.rglob("*")):
            if path.is_file():
                arc = Path("Rename Manager") / path.relative_to(STAGE)
                zf.write(path, arc.as_posix())


def main() -> None:
    copy_source()
    remove_local_parchment_rows()
    add_consumer()
    update_parent_modinfo()
    update_readme()
    add_shared_core()
    validate_basic_parse()
    package()
    print(f"Built {ZIP_PATH}")


if __name__ == "__main__":
    main()
