# Rename Manager v1.0.0

Rename Manager helps you **find and rename ships and trade routes directly in Anno 117: Pax Romana** without searching through the game manually.

## Open Rename Manager

Press **Ctrl+Alt+R**.

Numbered entries in supported parchments use:

- **Ctrl+Alt+1-9** — select the numbered ship or trade route
- **Ctrl+Alt+0** — back

Rename Manager then opens Anno's native rename field. Type the new name and press **Enter**. The mod returns you to the relevant Rename Manager view.

## Ships

The Ships submenu includes:

- **All Ships**
- **Ships by Trade Route**
- **Independent Ships**
- **Warships**

Ships are shown with their current names. Trade-route views keep route context visible so you can decide what a ship should be called before renaming it.

## Trade Routes

The Trade Routes submenu includes:

- **All Trade Routes**
- **By Group / Region**
- **By Islands**
- **By Goods**
- **Rescan Islands + Goods**

All trade-route views remain rename-capable.

### By Islands

By Islands first shows an alphabetical parchment of islands.

Choose an island to see all trade routes serving it. Routes are grouped and sorted by the **other island or combination of other islands** connected to that route.

The island topology is cached. The slower topology work is performed only when needed.

### By Goods

By Goods first shows an alphabetical list of goods with the number of routes carrying each good.

Choose a good to see its trade routes, grouped by their native route group / region.

Goods are read from the native Trade Route overview and cached. No deep route-by-route goods scan is required.

### Rescan Islands + Goods

Use **Rescan Islands + Goods** after changing:

- route stops / islands
- goods assigned to a route
- creating or deleting trade routes

The rescan shares one normal route harvest for both systems. The slower island topology remains lazy and is rebuilt only when an island is opened again.

## Rename behavior

Rename Manager deliberately uses Anno's **native rename interfaces**.

It does not directly overwrite ship or trade-route names. Exact native object IDs / RouteIDs are retained so duplicate display names are supported safely.

## Languages

- English
- German
- French

The mod name remains **Rename Manager** in both languages.

## Compatibility

- Anno 117: Pax Romana
- Tested with Patch 2.0
- No new game required
- Safe to remove
- No other mod required

## Installation

### mod.io

Subscribe to Rename Manager on mod.io and let the game/mod system install it.

### Manual installation

Extract the **Rename Manager** folder into your Anno 117 `mods` folder.

The folder should contain:

```text
Rename Manager/
├── data/
├── renamemanager/
└── modinfo.json
```

## Author

Dr. Enrico Handrick  
GitHub: **SirLocksley13**

## Disclaimer

This is an unofficial community mod and is not affiliated with or endorsed by Ubisoft.
Anno is a trademark of Ubisoft Entertainment.
