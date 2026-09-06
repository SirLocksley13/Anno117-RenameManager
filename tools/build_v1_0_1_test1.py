#!/usr/bin/env python3
"""Build the bounded Rename Manager v1.0.1-test1 configurable-open candidate.

The repository source stays at the protected v1.0.0 runtime baseline. This builder
copies only runtime files into a staging folder and applies the opener-only test
transformation there. That lets us prove the change before promoting source files.
"""

from __future__ import annotations

import json
import shutil
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILD_ROOT = ROOT / "build"
STAGE = BUILD_ROOT / "Rename Manager"
ZIP_PATH = BUILD_ROOT / "Rename_Manager_v1.0.1-test1_Configurable_Open.zip"

OLD_OPEN_BLOCK = """  <ModOp Type=\"add\" GUID=\"2001271\" Path=\"/Values/ShortcutConfig/InputBindings\">\n    <Item>\n      <Command>RenameManager:Open()</Command>\n      <Active>Session</Active>\n      <Identifier>RenameManagerOpen</Identifier>\n      <AvailableOnPlatforms>PC</AvailableOnPlatforms>\n      <InputTypes>\n        <Modern>\n          <KeyType>Control;Alt;R</KeyType>\n        </Modern>\n        <Legacy>\n          <KeyType>Control;Alt;R</KeyType>\n        </Legacy>\n      </InputTypes>\n    </Item>\n  </ModOp>\n"""

NEW_OPEN_BLOCK = """  <ModOp Type=\"add\" GUID=\"2001271\" Path=\"/Values/ShortcutConfig/InputBindings\">\n    <Item>\n      <Command>RenameManager.Open(RenameManager)</Command>\n      <Text>2019720021</Text>\n      <Active>Session</Active>\n      <Configurable>1</Configurable>\n      <Identifier>SirLocksleyRenameManagerOpen</Identifier>\n      <AvailableOnPlatforms>PC</AvailableOnPlatforms>\n      <HideInOptionMenu>0</HideInOptionMenu>\n      <AllowMultipleShortcuts>1</AllowMultipleShortcuts>\n      <InputTypes>\n        <Modern>\n          <KeyType>Control;Alt;R</KeyType>\n        </Modern>\n        <Legacy>\n          <KeyType>Control;Alt;R</KeyType>\n        </Legacy>\n      </InputTypes>\n    </Item>\n  </ModOp>\n"""

CONTROL_LABEL_LINE_ID = "2019720021"
CONTROL_LABELS = {
    "texts_english.xml": "Rename Manager - Open",
    "texts_german.xml": "Rename Manager - Oeffnen",
    "texts_french.xml": "Rename Manager - Ouvrir",
}


def die(message: str) -> None:
    print(f"BUILD ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def replace_exact_once(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        die(f"{path}: expected exact source block once, found {count}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


def add_control_label(path: Path, label: str) -> None:
    text = path.read_text(encoding="utf-8")
    if CONTROL_LABEL_LINE_ID in text:
        die(f"{path}: control label line {CONTROL_LABEL_LINE_ID} already exists")

    marker = "  </ModOp>\n</ModOps>"
    if text.count(marker) != 1:
        die(f"{path}: expected one final localization ModOp marker")

    block = (
        "    <Text>\n"
        f"      <Text>{label}</Text>\n"
        f"      <LineId>{CONTROL_LABEL_LINE_ID}</LineId>\n"
        "    </Text>\n"
    )
    path.write_text(text.replace(marker, block + marker, 1), encoding="utf-8")


def update_modinfo(path: Path) -> None:
    data = json.loads(path.read_text(encoding="utf-8"))
    if data.get("Version") != "1.0.0":
        die(f"{path}: protected source version is not 1.0.0")

    data["Version"] = "1.0.1-test1"
    data["Description"]["English"] = (
        "Find and rename ships and trade routes directly in Anno 117. Rename Manager "
        "provides native in-game menus for All Ships, Ships by Trade Route, Independent "
        "Ships, Warships, All Trade Routes, routes by Group / Region, By Islands and By "
        "Goods. Island and goods views use cached scans with a combined manual rescan. "
        "The Open command is configurable in Settings -> Controls (default Ctrl+Alt+R). "
        "Ctrl+Alt+1-9 selects numbered entries and Ctrl+Alt+0 goes back. English, German "
        "and French. No new game required."
    )
    data["Description"]["German"] = (
        "Finde und benenne Schiffe und Handelsrouten direkt in Anno 117 um. Rename Manager "
        "bietet native In-Game-Menues fuer Alle Schiffe, Schiffe nach Handelsroute, "
        "Unabhaengige Schiffe, Kriegsschiffe, Alle Handelsrouten, Routen nach Gruppe / "
        "Region, Nach Inseln und Nach Waren. Insel- und Warenansichten nutzen Caches mit "
        "einem kombinierten manuellen Rescan. Der Befehl zum Oeffnen ist unter Einstellungen "
        "-> Steuerung konfigurierbar (Standard Ctrl+Alt+R). Ctrl+Alt+1-9 waehlt nummerierte "
        "Eintraege und Ctrl+Alt+0 geht zurueck. Englisch, Deutsch und Franzoesisch. Kein "
        "neues Spiel erforderlich."
    )
    data["Description"]["French"] = (
        "Trouvez et renommez rapidement les navires et les routes commerciales directement "
        "dans Anno 117. Rename Manager propose des menus integres pour Tous les navires, "
        "Navires par route commerciale, Navires independants, Navires de guerre, Toutes les "
        "routes commerciales, Par groupe / region, Par iles et Par marchandises. La commande "
        "d'ouverture est configurable dans Parametres -> Commandes (par defaut Ctrl+Alt+R). "
        "Ctrl+Alt+1-9 selectionne les entrees numerotees et Ctrl+Alt+0 permet de revenir en "
        "arriere. Anglais, allemand et francais. Aucune nouvelle partie n'est necessaire."
    )

    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def update_readme(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    text = text.replace("# Rename Manager v1.0.0", "# Rename Manager v1.0.1-test1", 1)
    text = text.replace(
        "## Open Rename Manager\n\nPress **Ctrl+Alt+R**.",
        "## Open Rename Manager\n\nOpen **Settings -> Controls** and look for **Rename Manager - Open**. "
        "The default is **Ctrl+Alt+R**, and you can remap it to another key combination.",
        1,
    )
    path.write_text(text, encoding="utf-8")


def stage_runtime() -> None:
    if BUILD_ROOT.exists():
        shutil.rmtree(BUILD_ROOT)
    STAGE.mkdir(parents=True)

    for directory in ("data", "renamemanager"):
        shutil.copytree(ROOT / directory, STAGE / directory)
    for filename in ("modinfo.json", "README.md"):
        shutil.copy2(ROOT / filename, STAGE / filename)


def zip_stage() -> None:
    with zipfile.ZipFile(ZIP_PATH, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(STAGE.rglob("*")):
            if path.is_file():
                archive.write(path, Path("Rename Manager") / path.relative_to(STAGE))


def main() -> int:
    stage_runtime()

    replace_exact_once(
        STAGE / "data/base/config/export/assets.xml",
        OLD_OPEN_BLOCK,
        NEW_OPEN_BLOCK,
    )

    gui = STAGE / "data/base/config/gui"
    for filename, label in CONTROL_LABELS.items():
        add_control_label(gui / filename, label)

    update_modinfo(STAGE / "modinfo.json")
    update_readme(STAGE / "README.md")
    zip_stage()

    print(f"BUILT: {ZIP_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
