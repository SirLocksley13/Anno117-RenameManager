# Rename Manager Changelog

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


## v1.0.0 — 2026-08-22

### First public release

#### Ships
- All Ships
- Ships by Trade Route
- Independent Ships
- Warships
- Native ship rename input
- Automatic return to the originating Rename Manager view

#### Trade Routes
- All Trade Routes
- By Group / Region
- By Islands
- By Goods
- Combined Rescan Islands + Goods
- Exact RouteID targeting
- Native Trade Route rename command
- Automatic return to the originating view after rename

#### By Islands
- Alphabetical starting parchment with islands
- Drill-down to routes serving the selected island
- Routes sorted by the other island or combination of other islands
- Cached island index and route/island topology
- Lazy topology rebuild for better performance

#### By Goods
- Alphabetical goods starting parchment
- Route count per good
- Drill-down to all routes carrying the selected good
- Routes grouped by Group / Region
- Goods cache derived from native Trade Route overview data

#### User interface
- Ctrl+Alt+R opens Rename Manager
- Ctrl+Alt+1-9 selects numbered entries
- Ctrl+Alt+0 goes back
- Larger, visually separated Close option
- English, German and French localization

#### Compatibility
- Tested with Anno 117 Patch 2.0
- No new game required
- Safe to remove
- No dependencies
