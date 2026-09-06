# Rename Manager v1.0.1 Configurable Open — Implementation Plan

**Date:** 2026-09-05  
**Baseline:** Rename Manager v1.0.0  
**Protected runtime baseline:** `Rename Manager_v1.0.0.zip`, SHA-256 `94ad32e3e19a3553d5b744a452b3951bb20505ae70b95b931003b929d5fbb2bb`  
**Branch:** `chatgpt-v1.0.1-configurable-controls`

## Goal

Resolve the reported `Ctrl+Alt+R` compatibility problem by migrating Rename Manager's main Open action from the old fixed shortcut row to the already-proven Anno 117 Patch 2 native configurable shortcut architecture.

This first bounded candidate intentionally changes **only the main Open control layer**. Rename/search/navigation/runtime behavior remains the v1.0.0 logic.

## Why the first candidate is opener-only

The shared `Ctrl+Alt+1..9` / `Ctrl+Alt+0` production architecture is already designed and proven, but its permanent shared core uses immutable shortcut identifiers and exact command strings. The exact validated core artifact is not currently materialized in this repository. Reconstructing a look-alike core under the same permanent ModID would create an unnecessary saved-remap/load-order compatibility risk.

Therefore:

1. fix the user's reported Open problem now with the proven single-shortcut design;
2. validate it in Rename Manager itself;
3. integrate the exact shared parchment core separately once the validated core files are recovered verbatim.

## Candidate behavior

The build candidate must expose one native Settings -> Controls row:

- Label: `Rename Manager - Open`
- Permanent Identifier: `SirLocksleyRenameManagerOpen`
- Permanent Command: `RenameManager.Open(RenameManager)`
- Default Modern: `Control;Alt;R`
- Default Legacy: `Control;Alt;R`
- Active: `Session`
- Configurable: `1`
- Visible in options: `HideInOptionMenu=0`
- Multiple shortcuts allowed: `AllowMultipleShortcuts=1`

The old `RenameManagerOpen` / `RenameManager:Open()` fixed opener must not remain in the candidate.

The existing local parchment controls `RenameManagerSlot1..9` and `RenameManagerBack` remain unchanged in this first candidate.

## Test-first build sequence

### RED

Run a static validator against untouched v1.0.0 source. It must fail because the baseline does not yet contain:

- `SirLocksleyRenameManagerOpen`
- `RenameManager.Open(RenameManager)`
- `Configurable=1`
- valid localized `Rename Manager - Open` labels

If the untouched baseline unexpectedly passes, stop.

### GREEN

Build a throwaway candidate copy and make only these bounded transformations:

1. Replace the first old opener shortcut item with the proven configurable opener item.
2. Add one Controls localization line to English, German, and French.
3. Set package version to `1.0.1-test1` for the test candidate.
4. Update package descriptions to say the Open shortcut is configurable in Settings -> Controls while keeping the navigation-key statement unchanged.
5. Do not edit `renamemanager/rename-manager.lua` in this candidate.

Then run the same validator against the candidate copy; it must pass.

## Static verification

The candidate build must additionally pass:

- parse all XML files;
- parse `modinfo.json`;
- exactly one `SirLocksleyRenameManagerOpen` shortcut row;
- no legacy `RenameManagerOpen` opener identifier;
- no legacy `RenameManager:Open()` opener command;
- all ten existing local parchment rows still present and unchanged;
- package contains exactly one `modinfo.json`;
- ZIP integrity test.

## Runtime test matrix

Do not promote to release until these are proven in game:

1. `Rename Manager - Open` is visible in Settings -> Controls.
2. Default shows `Ctrl+Alt+R`.
3. Default opens Rename Manager from normal gameplay.
4. Remap Open to a non-`Ctrl+Alt` combination and verify it opens.
5. After remap, old `Ctrl+Alt+R` no longer opens Rename Manager.
6. Full Anno restart preserves the remap.
7. Reset to Default restores `Ctrl+Alt+R`.
8. Basic Rename Manager regression: open main menu, enter Ships or Trade Routes, select one numbered item, Back, and perform one normal rename flow.

## Promotion rule

If all runtime tests pass, create the real v1.0.1 release source/build. Do not merge or publish a permanent identifier/command pair with different spelling, spacing, or command representation after validation.

## Follow-up

After the opener fix is proven, recover the exact validated `sirlocksley-parchment-controls-core@1.0.1` files and migrate Rename Manager to reserved consumer `SirLocksleyPC02`, removing its local numbered shortcut rows. That is a separate compatibility update and must not delay the immediate opener fix.