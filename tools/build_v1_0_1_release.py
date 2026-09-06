#!/usr/bin/env python3
"""Build the runtime-proven Rename Manager v1.0.1 release from the test2 source."""

from __future__ import annotations

import hashlib
import json
import shutil
import xml.etree.ElementTree as ET
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

import build_v1_0_1_test2 as base

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build-release"
STAGE = BUILD / "Rename Manager"
ZIP_PATH = BUILD / "Rename_Manager_v1.0.1.zip"

CONSUMER = '''local Consumer = {
    target = nil
}

function Consumer:SetTarget(target)
    self.target = target
    return self.target ~= nil
end

function Consumer:Handle(slot)
    local target = self.target
    if target == nil then
        return false
    end

    if target.IsReportOpen == nil or not target:IsReportOpen() then
        return false
    end

    slot = tonumber(slot)

    if slot == 0 then
        return target:BackToMenu()
    end

    if slot == nil or slot < 1 or slot > 9 then
        return false
    end

    return target:ParchmentShortcut(slot)
end

return Consumer
'''

CHANGELOG_ENTRY = '''# Rename Manager Changelog

## v1.0.1

### Configurable controls
- Added **Rename Manager - Open** to Anno's **Settings -> Controls**
- Default Open shortcut remains **Ctrl+Alt+R**
- Open can be remapped through the native Controls menu
- Migrated numbered parchment navigation to the shared **Parchment Controls**
- **Entry 1-9** default to **Ctrl+Alt+1-9**
- **Back** defaults to **Ctrl+Alt+0**
- Entry 1-9 and Back can be remapped through the native Controls menu
- Removed Rename Manager's old private fixed Entry 1-9 / Back shortcut registrations

### Integration and compatibility
- Rename Manager uses reserved shared parchment consumer **SirLocksleyPC02**
- Fixed the Rename Manager consumer integration so it receives the actual Rename Manager module object explicitly
- Existing rename, search, route, island, goods, caching, and navigation logic is unchanged
- Bundles the shared parchment controls core; no other mod is required

'''


def build() -> None:
    # Reuse the already CI-validated test2 transformation, then apply the
    # runtime-proven PC02 target injection and final release metadata.
    base.copy_source()
    base.remove_local_parchment_rows()
    base.add_consumer()
    base.update_parent_modinfo()
    base.update_readme()
    base.add_shared_core()

    if BUILD.exists():
        shutil.rmtree(BUILD)
    shutil.copytree(base.STAGE, STAGE)

    runtime = STAGE / "renamemanager/rename-manager.lua"
    runtime_hash = hashlib.sha256(runtime.read_bytes()).hexdigest()

    (STAGE / "renamemanager/parchment-consumer.lua").write_text(CONSUMER, encoding="utf-8")

    modinfo_path = STAGE / "modinfo.json"
    info = json.loads(modinfo_path.read_text(encoding="utf-8"))
    info["Version"] = "1.0.1"
    info["Scripts"]["Init"] = (
        'RenameManager = require("rename-manager"); '
        'SirLocksleyPC02 = require("parchment-consumer"); '
        'SirLocksleyPC02:SetTarget(RenameManager)'
    )
    modinfo_path.write_text(json.dumps(info, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    readme_path = STAGE / "README.md"
    readme = readme_path.read_text(encoding="utf-8").replace(
        "# Rename Manager v1.0.1-test2", "# Rename Manager v1.0.1", 1
    )
    readme_path.write_text(readme, encoding="utf-8")

    changelog_path = STAGE / "CHANGELOG.md"
    old = changelog_path.read_text(encoding="utf-8")
    if old.startswith("# Rename Manager Changelog\n"):
        old = old[len("# Rename Manager Changelog\n"):]
    changelog_path.write_text(CHANGELOG_ENTRY + old, encoding="utf-8")

    # Fresh structural verification before packaging/materialization.
    assert hashlib.sha256(runtime.read_bytes()).hexdigest() == runtime_hash
    assert info["Version"] == "1.0.1"
    assert "SirLocksleyPC02:SetTarget(RenameManager)" in info["Scripts"]["Init"]
    assert "target:IsReportOpen()" in CONSUMER
    assert "target:ParchmentShortcut(slot)" in CONSUMER
    assert "target:BackToMenu()" in CONSUMER

    for path in STAGE.rglob("*.xml"):
        ET.parse(path)
    for path in STAGE.rglob("*.json"):
        json.loads(path.read_text(encoding="utf-8"))

    if ZIP_PATH.exists():
        ZIP_PATH.unlink()
    with ZipFile(ZIP_PATH, "w", ZIP_DEFLATED) as zf:
        for path in sorted(STAGE.rglob("*")):
            if path.is_file():
                zf.write(path, (Path("Rename Manager") / path.relative_to(STAGE)).as_posix())
    with ZipFile(ZIP_PATH) as zf:
        assert zf.testzip() is None

    print(f"Built {ZIP_PATH}")
    print(f"Protected rename-manager.lua SHA-256: {runtime_hash}")


if __name__ == "__main__":
    build()
