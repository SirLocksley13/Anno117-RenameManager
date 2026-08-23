local RenameManager = {
    language = "en",

    directOpenPending = false,
    directOpenAttempt = 0,

    observedSignal = nil,

    report = {
        active = false,
        opening = false,
        mode = nil,
        page = 0,
        visible = {},
        islandName = "",
        islandKey = "",
        goodName = "",
        goodKey = "",
    },

    returnMainPending = false,
    returnMainTicks = 0,
    returnMenuTarget = "main",

    renamePending = false,
    renameTargetID = nil,
    renameTargetIDText = "",
    renameTargetName = "",
    omReadyTicks = 0,
    renameAttempts = 0,
    ticksSinceRenameAttempt = 0,

    renameMonitoring = false,
    renameMonitorTicks = 0,
    resumeMode = nil,
    resumePage = 0,
    resumePending = false,
    resumeTicks = 0,
    resumeIslandName = "",
    resumeIslandKey = "",
    resumeGoodName = "",
    resumeGoodKey = "",

    -- Exact same-page return is remembered correctly, but Anno's TextPopup
    -- currently reopens on native page 1.  v0.6.3 probes the native Panel
    -- read-only after a return from page > 1 so the real page-navigation
    -- control can be identified without touching the proven rename flow.
    pageRestoreProbePending = false,
    pageRestoreProbeLogged = false,

    tradeOverviewPending = false,
    tradeOverviewTicks = 0,
    tradeOverviewStableTicks = 0,
    tradeRouteAutoEditAttempted = false,

    tradeRouteEditMonitoring = false,
    tradeRouteEditMonitorTicks = 0,
    tradeRouteEditNameData = nil,
    tradeRouteEditTargetID = nil,
    tradeRouteEditTargetName = "",

    tradeRouteProbeTicks = 0,
    tradeRouteProbeLastSignature = "",

    tradeRouteManualObserver = false,
    tradeRouteManualObserverTicks = 0,
    tradeRouteManualLastRows = {},

    tradeRouteNativePending = false,
    tradeRouteNativePhase = "",
    tradeRouteNativeTicks = 0,
    tradeRouteNativeRow = nil,
    tradeRouteNativeNameData = nil,
    tradeRouteNativeRouteID = nil,
    tradeRouteNativeInitialName = "",
    tradeRouteNativeSawEnabled = false,

    routeCache = {},
    routeGroupCache = {},

    -- By Goods cache, derived from native TradeRouteItems during the normal
    -- overview harvest. No individual route editor needs to be opened.
    routeGoodsIndexValid = false,
    routeGoodsNames = {},
    routeGoodsRoutes = {},
    routeGoodsTopologySignature = "",
    routeGoodsSessionGUID = nil,
    routeGoodsRoutesWithGoods = 0,

    routeHarvestPending = false,
    routeHarvestPhase = "",
    routeHarvestTicks = 0,
    routeHarvestExpandRounds = 0,
    routeHarvestReturnMode = "trade_routes",

    -- Fast lazy island cache. The index (native island buttons) is built once;
    -- each island's route membership is scanned only when that island is opened.
    routeIslandIndexValid = false,
    routeIslandNames = {},
    routeIslandRoutes = {},
    routeIslandTopologySignature = "",
    routeIslandSessionGUID = nil,
    routeIslandLastRefreshPlayTime = nil,

    routeIslandEnumPending = false,
    routeIslandEnumTicks = 0,
    routeIslandEnumPopupOpened = false,

    routeIslandFilterPending = false,
    routeIslandFilterPhase = "",
    routeIslandFilterTicks = 0,
    routeIslandFilterExpandRounds = 0,
    routeIslandTargetName = "",
    routeIslandTargetKey = "",
    routeIslandTargetArrayIndex = nil,
    routeIslandFilterPopupOpened = false,
    routeIslandFilterButton = nil,

    -- Full route<->island membership cache. This is built lazily only when
    -- an island is actually opened. It scans native island filters (normally
    -- far fewer than the number of trade routes), never every route editor.
    routeIslandMembershipComplete = false,
    routeIslandMembershipPending = false,
    routeIslandMembershipPhase = "",
    routeIslandMembershipTicks = 0,
    routeIslandMembershipExpandRounds = 0,
    routeIslandMembershipQueue = {},
    routeIslandMembershipIndex = 0,
    routeIslandMembershipPopupOpened = false,
    routeIslandMembershipButton = nil,
    routeIslandMembershipFailures = 0,

    routeTargetFromParchment = false,
    routeTargetID = nil,
    routeTargetName = "",
    routeTargetExpandRounds = 0,
    routeTargetSearchApplied = false,
    routeTargetSearchTicks = 0,
    routeTargetSearchAttempt = 0,
    routeTargetSearchQuery = "",
    routeTargetSourceMode = "trade_routes",
    routeTargetSourceIslandName = "",
    routeTargetSourceIslandKey = "",
    routeTargetSourceGoodName = "",
    routeTargetSourceGoodKey = "",
}

local PREFIX = "[Rename Manager 1.0.0] "
local MAIN_STORYLINE = 2197200
local SHIPS_STORYLINE = 2197240
local TRADE_ROUTES_STORYLINE = 2197250
local PAGE_STORY_BASE = 2197300
local DIRECT_OPEN_MAX_ATTEMPTS = 30

local OM_STABLE_TICKS = 4
local RENAME_RETRY_INTERVAL_TICKS = 2
local RENAME_MAX_ATTEMPTS = 4

local function log(message)
    system.log(PREFIX .. tostring(message))
end

local function getTextPopupContent()
    local content = nil
    pcall(function()
        content = ui
            and ui.Scenes
            and ui.Scenes.TextPopup
            and ui.Scenes.TextPopup.SceneData
            and ui.Scenes.TextPopup.SceneData.Content
            or nil
    end)
    return content
end


local function probeTextPopupPanel(reason)
    local panel = nil
    pcall(function()
        panel =
            ui
            and ui.Scenes
            and ui.Scenes.TextPopup
            and ui.Scenes.TextPopup.SceneData
            and ui.Scenes.TextPopup.SceneData.Panel
            or nil
    end)

    if panel == nil then
        log(
            "PAGE RESTORE PANEL PROBE"
            .. " | reason=" .. tostring(reason or "")
            .. " | panelPresent=false"
        )
        return
    end

    local helpOK, helpValue =
        pcall(function()
            return help(panel)
        end)

    local typeOK, typeValue =
        pcall(function()
            return getTypeInfo(panel)
        end)

    local deprecatedOK, deprecatedValue =
        pcall(function()
            return getTypeInfoDeprecated(panel)
        end)

    log(
        "PAGE RESTORE PANEL PROBE"
        .. " | reason=" .. tostring(reason or "")
        .. " | panelPresent=true"
        .. " | helpSuccess=" .. tostring(helpOK)
        .. " | help=" .. tostring(helpValue or "")
        .. " | typeInfoSuccess=" .. tostring(typeOK)
        .. " | typeInfo=" .. tostring(typeValue or "")
        .. " | deprecatedSuccess=" .. tostring(deprecatedOK)
        .. " | deprecated=" .. tostring(deprecatedValue or "")
    )

    -- Read-only named-member scan.  Do not invoke any candidate.
    local candidates = {
        "CurrentPage",
        "Page",
        "PageIndex",
        "SelectedPage",
        "Previous",
        "Next",
        "Left",
        "Right",
        "PreviousButton",
        "NextButton",
        "PreviousPageButton",
        "NextPageButton",
        "PreviousButtonData",
        "NextButtonData",
        "PreviousPageButtonData",
        "NextPageButtonData",
        "PageBack",
        "PageForward",
        "Navigation",
        "Paging",
        "Buttons",
    }

    local found = {}
    for _, name in ipairs(candidates) do
        local ok, value =
            pcall(function()
                return panel[name]
            end)

        if ok and value ~= nil then
            found[#found + 1] =
                tostring(name)
                .. "="
                .. tostring(value)
                .. ":"
                .. type(value)
        end
    end

    log(
        "PAGE RESTORE PANEL MEMBERS"
        .. " | reason=" .. tostring(reason or "")
        .. " | found=" .. tostring(#found)
        .. " | values=" .. table.concat(found, " ; ")
        .. " | policy=read-only-no-events"
    )
end

local function signalValue()
    local ok, value = pcall(function()
        return Variables:GetVariable("RMF")
    end)
    if not ok or value == nil then return 0 end
    return tonumber(value) or 0
end

local function normalizeMarker(text)
    local raw = tostring(text or "")
    local base = string.match(raw, "^(RM_.+)_DE$")
    if base ~= nil then
        RenameManager.language = "de"
        return base
    end

    base = string.match(raw, "^(RM_.+)_FR$")
    if base ~= nil then
        RenameManager.language = "fr"
        return base
    end

    base = string.match(raw, "^(RM_.+)_EN$")
    if base ~= nil then
        RenameManager.language = "en"
        return base
    end

    return raw
end

local function isOwned(object)
    local owned = false
    pcall(function()
        owned = object.Owner == 41 or tostring(object.Owner) == "41"
    end)
    return owned
end

local function readName(object)
    local value = nil
    pcall(function() value = object.Nameable.Name end)
    if value == nil then return "" end
    return tostring(value)
end

local function recordKey(mode, name, routeName, id, military, assigned)
    if mode == "routes" then
        return string.lower(routeName)
            .. "|" .. string.lower(name)
            .. "|" .. tostring(id)
    end

    return string.lower(name)
        .. "|" .. string.lower(routeName or "")
        .. "|" .. tostring(id)
end

function RenameManager:Records(mode)
    local records = {}

    for _, object in pairs(
        Scripts:GetObjectGroupByProperty(Properties.ShipModuleOwner) or {}
    ) do
        if isOwned(object) then
            local name = readName(object)
            local objectID = nil
            pcall(function() objectID = object.ID end)

            if name ~= "" and objectID ~= nil then
                local route = nil
                pcall(function() route = object.TradeRouteVehicle end)

                local assigned = false
                local routeName = ""
                if route ~= nil then
                    pcall(function()
                        assigned = route.IsAssignedOnTradeRoute == true
                    end)
                    pcall(function()
                        if route.RouteName ~= nil then
                            routeName = tostring(route.RouteName)
                        end
                    end)
                end

                local military = false
                pcall(function()
                    military = object.Unit
                        and object.Unit.IsMilitaryUnit == true
                end)

                local include = false
                if mode == "all" then
                    include = true
                elseif mode == "routes" then
                    include = assigned and routeName ~= ""
                elseif mode == "independent" then
                    include = not military and not assigned
                elseif mode == "warships" then
                    include = military
                end

                if include then
                    records[#records + 1] = {
                        id = tostring(objectID),
                        name = name,
                        routeName = routeName,
                        military = military,
                        assigned = assigned,
                        key = recordKey(
                            mode,
                            name,
                            routeName,
                            objectID,
                            military,
                            assigned
                        ),
                    }
                end
            end
        end
    end

    table.sort(records, function(a, b)
        return a.key < b.key
    end)

    return records
end

local function routeNameCounts(routeCache)
    local counts = {}
    for _, rec in pairs(routeCache or {}) do
        local name = tostring(rec and rec.name or "")
        if name ~= "" then
            counts[name] = (counts[name] or 0) + 1
        end
    end
    return counts
end

local function liveShipsByRouteName()
    local result = {}

    for _, object in pairs(
        Scripts:GetObjectGroupByProperty(Properties.ShipModuleOwner) or {}
    ) do
        if isOwned(object) then
            local shipName = readName(object)
            local route = nil
            pcall(function()
                route = object.TradeRouteVehicle
            end)

            local assigned = false
            local routeName = ""

            if route ~= nil then
                pcall(function()
                    assigned =
                        route.IsAssignedOnTradeRoute == true
                end)
                pcall(function()
                    routeName =
                        tostring(route.RouteName or "")
                end)
            end

            if assigned
                and routeName ~= ""
                and shipName ~= ""
            then
                result[routeName] =
                    result[routeName] or {}
                result[routeName][#result[routeName] + 1] =
                    shipName
            end
        end
    end

    for _, ships in pairs(result) do
        table.sort(ships, function(a, b)
            return string.lower(a) < string.lower(b)
        end)
    end

    return result
end

local function routeShipDetail(record, de, fr)
    local shipNames = record.shipNames or {}
    local count = #shipNames

    if count > 0 then
        local parts = {}
        for _, shipName in ipairs(shipNames) do
            parts[#parts + 1] = "★ " .. tostring(shipName)
        end
        return "   " .. table.concat(parts, "  •  ")
    end

    local nativeCount =
        tonumber(record.activeShipsAmount)

    if nativeCount ~= nil and nativeCount > 0 then
        if nativeCount == 1 then
            return de
                and "   ★ 1 Schiff (Name hier nicht verfuegbar)"
                or fr
                and "   ★ 1 navire (nom indisponible ici)"
                or "   ★ 1 ship (name unavailable here)"
        end

        return
            "   ★ " .. tostring(nativeCount)
            .. (
                de
                and " Schiffe (Namen hier nicht verfuegbar)"
                or fr
                and " navires (noms indisponibles ici)"
                or " ships (names unavailable here)"
            )
    end

    return de
        and "   — Kein Schiff zugewiesen"
        or fr
        and "   — Aucun navire assigné"
        or "   — No ship assigned"
end




function RenameManager:RouteRecords()
    local records = {}
    local counts = routeNameCounts(self.routeCache)
    local shipsByRouteName = liveShipsByRouteName()

    for _, rec in pairs(self.routeCache or {}) do
        if rec ~= nil
            and type(rec.routeID) == "number"
            and tostring(rec.name or "") ~= ""
        then
            local routeName = tostring(rec.name)
            local duplicateName =
                (counts[routeName] or 0) > 1

            local shipNames = {}
            if not duplicateName then
                shipNames =
                    shipsByRouteName[routeName] or {}
            end

            records[#records + 1] = {
                routeID = rec.routeID,
                name = routeName,
                folderID = rec.folderID,
                groupName = tostring(rec.groupName or ""),
                activeShipsAmount =
                    tostring(rec.activeShipsAmount or ""),
                pausedShipsAmount =
                    tostring(rec.pausedShipsAmount or ""),
                lostShipsAmount =
                    tostring(rec.lostShipsAmount or ""),
                duplicateName = duplicateName,
                shipNames = shipNames,
                key =
                    string.lower(routeName)
                    .. "|" .. tostring(rec.routeID),
            }
        end
    end

    table.sort(records, function(a, b)
        return a.key < b.key
    end)

    return records
end


local function currentSessionGUID()
    local value = nil
    pcall(function()
        value = GameSession and GameSession.SessionGUID or nil
    end)
    return value
end

local function routeIDTopologySignature(routeCache)
    local ids = {}
    for routeID, rec in pairs(routeCache or {}) do
        local id = routeID
        if rec and rec.routeID ~= nil then id = rec.routeID end
        if type(id) == "number" and id >= 0 then
            ids[#ids + 1] = tostring(id)
        end
    end
    table.sort(ids)
    return table.concat(ids, ",")
end


function RenameManager:InvalidateGoodsCache(reason)
    self.routeGoodsIndexValid = false
    self.routeGoodsNames = {}
    self.routeGoodsRoutes = {}
    self.routeGoodsTopologySignature = ""
    self.routeGoodsSessionGUID = nil
    self.routeGoodsRoutesWithGoods = 0

    log(
        "GOODS CACHE INVALIDATE"
        .. " | reason=" .. tostring(reason or "manual")
    )
end

function RenameManager:RefreshGoodsCacheFromRouteCache(reason)
    local byGood = {}
    local routesWithGoods = 0
    local routeTotal = 0

    for routeID, rec in pairs(self.routeCache or {}) do
        routeTotal = routeTotal + 1
        local routeHadGood = false

        for _, good in ipairs(rec.goods or {}) do
            local key = tostring(good.key or "")
            local name = tostring(good.name or "")

            if key ~= "" and name ~= "" then
                local bucket = byGood[key]

                if bucket == nil then
                    bucket = {
                        key = key,
                        name = name,
                        routeIDs = {},
                        seenRouteIDs = {},
                    }
                    byGood[key] = bucket
                end

                if not bucket.seenRouteIDs[routeID] then
                    bucket.seenRouteIDs[routeID] = true
                    bucket.routeIDs[#bucket.routeIDs + 1] =
                        routeID
                end

                routeHadGood = true
            end
        end

        if routeHadGood then
            routesWithGoods =
                routesWithGoods + 1
        end
    end

    local names = {}
    local routes = {}

    for key, bucket in pairs(byGood) do
        table.sort(bucket.routeIDs)

        names[#names + 1] = {
            key = key,
            name = bucket.name,
            routeCount = #bucket.routeIDs,
        }

        routes[key] = {
            key = key,
            name = bucket.name,
            routeIDs = bucket.routeIDs,
            routeCount = #bucket.routeIDs,
        }
    end

    table.sort(names, function(a, b)
        return string.lower(tostring(a.name or ""))
            < string.lower(tostring(b.name or ""))
    end)

    self.routeGoodsNames = names
    self.routeGoodsRoutes = routes
    self.routeGoodsTopologySignature =
        routeIDTopologySignature(self.routeCache)
    self.routeGoodsSessionGUID =
        currentSessionGUID()
    self.routeGoodsRoutesWithGoods =
        routesWithGoods
    self.routeGoodsIndexValid = true

    log(
        "GOODS CACHE REFRESH"
        .. " | reason=" .. tostring(reason or "harvest")
        .. " | goods=" .. tostring(#names)
        .. " | routesWithGoods=" .. tostring(routesWithGoods)
        .. " | routesTotal=" .. tostring(routeTotal)
        .. " | source=native-TradeRouteItems"
        .. " | deepRouteScan=false"
    )

    return #names
end

function RenameManager:GoodsCacheUsable()
    if not self.routeGoodsIndexValid then
        return false, "index-invalid"
    end

    local currentSession = currentSessionGUID()

    if self.routeGoodsSessionGUID ~= nil
        and currentSession ~= self.routeGoodsSessionGUID
    then
        return false, "session-changed"
    end

    local sig =
        routeIDTopologySignature(self.routeCache)

    if sig ~= ""
        and self.routeGoodsTopologySignature ~= ""
        and sig ~= self.routeGoodsTopologySignature
    then
        return false, "route-id-set-changed"
    end

    return true, "match"
end

function RenameManager:GoodsIndexRecords()
    local records = {}

    for _, good in ipairs(self.routeGoodsNames or {}) do
        records[#records + 1] = {
            kind = "good",
            name = tostring(good.name or ""),
            goodKey = tostring(good.key or ""),
            routeCount =
                tonumber(good.routeCount) or 0,
            key =
                string.lower(tostring(good.name or ""))
                .. "|" .. tostring(good.key or ""),
        }
    end

    table.sort(records, function(a, b)
        return tostring(a.key or "")
            < tostring(b.key or "")
    end)

    return records
end

function RenameManager:GoodRouteRecords(goodKey)
    local key = tostring(goodKey or "")
    local cache = self.routeGoodsRoutes[key]

    if cache == nil then
        return {}
    end

    local wanted = {}

    for _, routeID in ipairs(cache.routeIDs or {}) do
        wanted[routeID] = true
    end

    local records = {}

    for _, rec in ipairs(self:RouteRecords()) do
        if wanted[rec.routeID] then
            records[#records + 1] = rec
        end
    end

    -- Useful naming context: region/group first, then route name.
    table.sort(records, function(a, b)
        local ga =
            string.lower(tostring(a.groupName or ""))
        local gb =
            string.lower(tostring(b.groupName or ""))

        if ga == "" then ga = "~~~" end
        if gb == "" then gb = "~~~" end

        if ga ~= gb then
            return ga < gb
        end

        return tostring(a.key or "")
            < tostring(b.key or "")
    end)

    return records
end

function RenameManager:InvalidateIslandCache(reason)
    self.routeIslandIndexValid = false
    self.routeIslandNames = {}
    self.routeIslandRoutes = {}
    self.routeIslandTopologySignature = ""
    self.routeIslandSessionGUID = nil
    self.routeIslandLastRefreshPlayTime = nil
    self.routeIslandMembershipComplete = false
    self.routeIslandMembershipPending = false
    self.routeIslandMembershipPhase = ""
    self.routeIslandMembershipQueue = {}
    self.routeIslandMembershipIndex = 0
    self.routeIslandMembershipButton = nil
    self.routeIslandMembershipFailures = 0

    log(
        "ISLAND CACHE INVALIDATE"
        .. " | reason=" .. tostring(reason or "manual")
    )
end

function RenameManager:IslandCacheUsable()
    if not self.routeIslandIndexValid then
        return false, "index-invalid"
    end

    local currentSession = currentSessionGUID()
    if self.routeIslandSessionGUID ~= nil
        and currentSession ~= self.routeIslandSessionGUID
    then
        return false, "session-changed"
    end

    local sig = routeIDTopologySignature(self.routeCache)
    if sig ~= ""
        and self.routeIslandTopologySignature ~= ""
        and sig ~= self.routeIslandTopologySignature
    then
        return false, "route-id-set-changed"
    end

    if #(self.routeIslandNames or {}) < 1 then
        return false, "empty-island-index"
    end

    return true, "match"
end

function RenameManager:IslandIndexRecords()
    local records = {}

    for _, island in ipairs(self.routeIslandNames or {}) do
        local cache = self.routeIslandRoutes[island.key]
        records[#records + 1] = {
            kind = "island",
            name = tostring(island.name or ""),
            islandKey = tostring(island.key or ""),
            arrayIndex = island.arrayIndex,
            routeCount = cache and tonumber(cache.routeCount) or nil,
            scanned = cache ~= nil,
            key = string.lower(tostring(island.name or ""))
                .. "|" .. string.format("%04d", tonumber(island.arrayIndex) or 0),
        }
    end

    table.sort(records, function(a, b)
        return tostring(a.key or "") < tostring(b.key or "")
    end)

    return records
end


local function routeIDInIslandCache(cache, routeID)
    if cache == nil then return false end
    for _, candidate in ipairs(cache.routeIDs or {}) do
        if candidate == routeID then
            return true
        end
    end
    return false
end

function RenameManager:OtherIslandsForRoute(selectedIslandKey, routeID)
    local names = {}

    for _, island in ipairs(self.routeIslandNames or {}) do
        local key = tostring(island.key or "")
        if key ~= ""
            and key ~= tostring(selectedIslandKey or "")
        then
            local cache = self.routeIslandRoutes[key]
            if routeIDInIslandCache(cache, routeID) then
                names[#names + 1] = tostring(island.name or "")
            end
        end
    end

    table.sort(names, function(a, b)
        return string.lower(a) < string.lower(b)
    end)

    return names
end

function RenameManager:IslandRouteRecords(islandKey)
    local selectedKey = tostring(islandKey or "")
    local cache = self.routeIslandRoutes[selectedKey]
    if cache == nil then return {} end

    local wanted = {}
    for _, routeID in ipairs(cache.routeIDs or {}) do
        wanted[routeID] = true
    end

    local records = {}
    for _, rec in ipairs(self:RouteRecords()) do
        if wanted[rec.routeID] then
            local otherIslands =
                self:OtherIslandsForRoute(
                    selectedKey,
                    rec.routeID
                )

            rec.otherIslandNames = otherIslands
            rec.otherIslandLabel =
                table.concat(otherIslands, " • ")
            rec.otherIslandSortKey =
                string.lower(rec.otherIslandLabel)

            if rec.otherIslandSortKey == "" then
                -- Routes for which no second island could be established
                -- are still retained, but always sort last.
                rec.otherIslandSortKey = "~~~"
            end

            records[#records + 1] = rec
        end
    end

    table.sort(records, function(a, b)
        local aa = tostring(a.otherIslandSortKey or "~~~")
        local bb = tostring(b.otherIslandSortKey or "~~~")
        if aa ~= bb then return aa < bb end
        return tostring(a.key or "") < tostring(b.key or "")
    end)

    return records
end

function RenameManager:ReportRecords(mode)
    if mode == "island_index" then
        return self:IslandIndexRecords()
    elseif mode == "trade_routes_for_island" then
        return self:IslandRouteRecords(self.report.islandKey)
    elseif mode == "goods_index" then
        return self:GoodsIndexRecords()
    elseif mode == "trade_routes_for_good" then
        return self:GoodRouteRecords(self.report.goodKey)
    end

    if mode == "trade_routes"
        or mode == "trade_routes_by_group"
    then
        local records = self:RouteRecords()

        if mode == "trade_routes_by_group" then
            table.sort(records, function(a, b)
                local ga = string.lower(
                    tostring(a.groupName or "")
                )
                local gb = string.lower(
                    tostring(b.groupName or "")
                )

                if ga == "" then ga = "~~~" end
                if gb == "" then gb = "~~~" end

                if ga ~= gb then return ga < gb end
                return tostring(a.key or "") < tostring(b.key or "")
            end)
        end

        return records
    end
    return self:Records(mode)
end

function RenameManager:ModeTitle(mode)
    local de = self.language == "de"
    local fr = self.language == "fr"

    if mode == "all" then
        return de and "RENAME MANAGER — ALLE SCHIFFE"
            or fr and "RENAME MANAGER — TOUS LES NAVIRES"
            or "RENAME MANAGER — ALL SHIPS"
    elseif mode == "routes" then
        return de and "RENAME MANAGER — SCHIFFE NACH HANDELSROUTE"
            or fr and "RENAME MANAGER — NAVIRES PAR ROUTE COMMERCIALE"
            or "RENAME MANAGER — SHIPS BY TRADE ROUTE"
    elseif mode == "independent" then
        return de and "RENAME MANAGER — UNABHÄNGIGE SCHIFFE"
            or fr and "RENAME MANAGER — NAVIRES INDÉPENDANTS"
            or "RENAME MANAGER — INDEPENDENT SHIPS"
    elseif mode == "warships" then
        return de and "RENAME MANAGER — KRIEGSSCHIFFE"
            or fr and "RENAME MANAGER — NAVIRES DE GUERRE"
            or "RENAME MANAGER — WARSHIPS"
    elseif mode == "trade_routes" then
        return de and "RENAME MANAGER — ALLE HANDELSROUTEN"
            or fr and "RENAME MANAGER — TOUTES LES ROUTES COMMERCIALES"
            or "RENAME MANAGER — ALL TRADE ROUTES"
    elseif mode == "trade_routes_by_group" then
        return de and "RENAME MANAGER — HANDELSROUTEN NACH GRUPPE / REGION"
            or fr and "RENAME MANAGER — ROUTES COMMERCIALES PAR GROUPE / RÉGION"
            or "RENAME MANAGER — TRADE ROUTES BY GROUP / REGION"
    elseif mode == "island_index" then
        return de and "RENAME MANAGER — INSELN"
            or fr and "RENAME MANAGER — ÎLES"
            or "RENAME MANAGER — ISLANDS"
    elseif mode == "trade_routes_for_island" then
        return "RENAME MANAGER — " .. tostring(self.report.islandName or "")
    elseif mode == "goods_index" then
        return de and "RENAME MANAGER — WAREN"
            or fr and "RENAME MANAGER — MARCHANDISES"
            or "RENAME MANAGER — GOODS"
    elseif mode == "trade_routes_for_good" then
        return "RENAME MANAGER — " .. tostring(self.report.goodName or "")
    end

    return "RENAME MANAGER"
end


function RenameManager:IslandIndexPageText(pageIndex)
    local records = self:IslandIndexRecords()
    local pages = math.max(1, math.ceil(#records / 9))
    if pages > 12 then pages = 12 end

    local page = math.max(0, tonumber(pageIndex) or 0)
    if page >= pages then page = pages - 1 end

    self.report.page = page
    self.report.visible = {}
    self.report.islandName = ""
    self.report.islandKey = ""

    local de = self.language == "de"
    local fr = self.language == "fr"
    local first = page * 9 + 1
    local last = math.min(first + 8, math.min(#records, 108))

    local lines = {
        self:ModeTitle("island_index"),
        "",
        tostring(#records)
            .. (
                de and " Inseln • Strg+Alt+1-9 zum Oeffnen"
                or fr and " îles • Ctrl+Alt+1-9 pour ouvrir"
                or " islands • Ctrl+Alt+1-9 to open"
            ),
        de
            and "Beim ersten Oeffnen einer Insel wird einmalig die Inselverbindungstopologie geladen und zwischengespeichert."
            or fr
            and "À la première ouverture d'une île, la topologie des connexions entre îles est chargée une fois puis mise en cache."
            or "Opening the first island builds the island-connection topology once, then caches it.",
        de and "Strg+Alt+0: Zurueck zu Handelsrouten"
            or fr and "Ctrl+Alt+0 : Retour aux routes commerciales"
            or "Ctrl+Alt+0: Back to Trade Routes",
    }

    if pages > 1 then
        lines[#lines + 1] =
            (
                de and "Seite "
                or fr and "Page "
                or "Page "
            )
            .. tostring(page + 1) .. "/" .. tostring(pages)
    end

    lines[#lines + 1] = ""

    if #records == 0 then
        lines[#lines + 1] =
            de and "Keine Inseln aus dem nativen Handelsroutenfilter gefunden."
            or fr and "Aucune île trouvée dans le filtre natif des routes commerciales."
            or "No islands found in the native Trade Route filter."
        return table.concat(lines, "\n")
    end

    for index = first, last do
        local record = records[index]
        local slot = index - first + 1

        self.report.visible[slot] = {
            kind = "island",
            name = record.name,
            islandKey = record.islandKey,
            arrayIndex = record.arrayIndex,
        }

        local suffix = ""

        if record.scanned then
            suffix =
                de and (" — " .. tostring(record.routeCount or 0) .. " Routen im Cache")
                or fr and (" — " .. tostring(record.routeCount or 0) .. " routes en cache")
                or (" — " .. tostring(record.routeCount or 0) .. " routes cached")
        else
            suffix =
                de and " — Routen beim Oeffnen laden"
                or fr and " — charger les routes à l'ouverture"
                or " — load routes when opened"
        end

        lines[#lines + 1] =
            tostring(slot) .. ". ▶ " .. tostring(record.name) .. suffix
    end

    return table.concat(lines, "\n")
end


function RenameManager:IslandRoutesPageText(pageIndex)
    local records = self:IslandRouteRecords(self.report.islandKey)
    local pages = math.max(1, math.ceil(#records / 9))
    if pages > 12 then pages = 12 end

    local page = math.max(0, tonumber(pageIndex) or 0)
    if page >= pages then page = pages - 1 end

    self.report.page = page
    self.report.visible = {}

    local de = self.language == "de"
    local fr = self.language == "fr"
    local islandName = tostring(self.report.islandName or "")
    local first = page * 9 + 1
    local last = math.min(first + 8, math.min(#records, 108))

    local lines = {
        self:ModeTitle("trade_routes_for_island"),
        "",
        tostring(#records)
            .. (
                de and " Handelsrouten • Strg+Alt+1-9 zum Umbenennen"
                or fr and " routes commerciales • Ctrl+Alt+1-9 pour renommer"
                or " trade routes • Ctrl+Alt+1-9 to rename"
            ),
        de
            and ("Sortiert nach der anderen Insel bzw. den anderen Inseln der Route von/zu " .. islandName .. ".")
            or fr
            and ("Triées selon l'autre île ou les autres îles reliées à " .. islandName .. ".")
            or ("Sorted by the other island or islands connected with " .. islandName .. "."),
        de and "Strg+Alt+0: Zurueck zur Inselliste"
            or fr and "Ctrl+Alt+0 : Retour à la liste des îles"
            or "Ctrl+Alt+0: Back to Islands",
    }

    if pages > 1 then
        lines[#lines + 1] =
            (
                de and "Seite "
                or fr and "Page "
                or "Page "
            )
            .. tostring(page + 1) .. "/" .. tostring(pages)
    end

    lines[#lines + 1] = ""

    if #records == 0 then
        lines[#lines + 1] =
            de and "Keine Handelsrouten bedienen diese Insel."
            or fr and "Aucune route commerciale ne dessert cette île."
            or "No trade routes serve this island."
        return table.concat(lines, "\n")
    end

    local lastOtherGroup = nil

    for index = first, last do
        local record = records[index]
        local slot = index - first + 1

        local otherLabel = tostring(record.otherIslandLabel or "")

        if otherLabel == "" then
            otherLabel =
                de and "Keine weitere Insel ermittelt"
                or fr and "Aucune autre île identifiée"
                or "No other island identified"
        end

        if otherLabel ~= lastOtherGroup then
            if lastOtherGroup ~= nil then
                lines[#lines + 1] = ""
            end
            lines[#lines + 1] = "◆ " .. otherLabel
            lastOtherGroup = otherLabel
        end

        self.report.visible[slot] = {
            routeID = record.routeID,
            name = record.name,
            folderID = record.folderID,
            kind = "trade_route",
            sourceMode = "trade_routes_for_island",
            islandName = islandName,
            islandKey = tostring(self.report.islandKey or ""),
        }

        local groupName = tostring(record.groupName or "")

        if groupName == "" then
            groupName =
                de and "Ohne Gruppe"
                or fr and "Sans groupe"
                or "Ungrouped"
        end

        lines[#lines + 1] =
            tostring(slot)
            .. ". ▶ " .. tostring(record.name)
            .. (
                de and (" (Gruppe: " .. groupName .. ")")
                or fr and (" (Groupe : " .. groupName .. ")")
                or (" (Group: " .. groupName .. ")")
            )

        lines[#lines + 1] =
            routeShipDetail(record, de, fr)

        if index < last then
            lines[#lines + 1] = "────────────────────────"
        end
    end

    return table.concat(lines, "\n")
end


function RenameManager:GoodsIndexPageText(pageIndex)
    local records = self:GoodsIndexRecords()
    local pages = math.max(1, math.ceil(#records / 9))
    if pages > 12 then pages = 12 end

    local page = math.max(0, tonumber(pageIndex) or 0)
    if page >= pages then page = pages - 1 end

    self.report.page = page
    self.report.visible = {}
    self.report.goodName = ""
    self.report.goodKey = ""

    local de = self.language == "de"
    local fr = self.language == "fr"
    local first = page * 9 + 1
    local last =
        math.min(first + 8, math.min(#records, 108))

    local lines = {
        self:ModeTitle("goods_index"),
        "",
        tostring(#records)
            .. (
                de and " Waren • Strg+Alt+1-9 zum Oeffnen"
                or fr and " marchandises • Ctrl+Alt+1-9 pour ouvrir"
                or " goods • Ctrl+Alt+1-9 to open"
            ),
        de
            and "Aus den Waren-Icons der nativen Handelsrouten-Uebersicht zwischengespeichert."
            or fr
            and "Mises en cache à partir des icônes de marchandises de l'aperçu natif des routes commerciales."
            or "Cached from the native Trade Route overview goods icons.",
        de and "Strg+Alt+0: Zurueck zu Handelsrouten"
            or fr and "Ctrl+Alt+0 : Retour aux routes commerciales"
            or "Ctrl+Alt+0: Back to Trade Routes",
    }

    if pages > 1 then
        lines[#lines + 1] =
            (
                de and "Seite "
                or fr and "Page "
                or "Page "
            )
            .. tostring(page + 1)
            .. "/" .. tostring(pages)
    end

    lines[#lines + 1] = ""

    if #records == 0 then
        lines[#lines + 1] =
            de and "Keine Waren aus den Handelsrouten-Icons gefunden."
            or fr and "Aucune marchandise trouvée dans les icônes des routes commerciales."
            or "No goods found in the Trade Route overview icons."
        return table.concat(lines, "\n")
    end

    for index = first, last do
        local record = records[index]
        local slot = index - first + 1

        self.report.visible[slot] = {
            kind = "good",
            name = record.name,
            goodKey = record.goodKey,
        }

        lines[#lines + 1] =
            tostring(slot)
            .. ". ▶ " .. tostring(record.name)
            .. (
                de and (" — " .. tostring(record.routeCount) .. " Routen")
                or fr and (" — " .. tostring(record.routeCount) .. " routes")
                or (" — " .. tostring(record.routeCount) .. " routes")
            )
    end

    return table.concat(lines, "\n")
end


function RenameManager:GoodRoutesPageText(pageIndex)
    local records =
        self:GoodRouteRecords(self.report.goodKey)
    local pages = math.max(1, math.ceil(#records / 9))
    if pages > 12 then pages = 12 end

    local page = math.max(0, tonumber(pageIndex) or 0)
    if page >= pages then page = pages - 1 end

    self.report.page = page
    self.report.visible = {}

    local de = self.language == "de"
    local fr = self.language == "fr"
    local goodName =
        tostring(self.report.goodName or "")
    local first = page * 9 + 1
    local last =
        math.min(first + 8, math.min(#records, 108))

    local lines = {
        self:ModeTitle("trade_routes_for_good"),
        "",
        tostring(#records)
            .. (
                de and " Handelsrouten • Strg+Alt+1-9 zum Umbenennen"
                or fr and " routes commerciales • Ctrl+Alt+1-9 pour renommer"
                or " trade routes • Ctrl+Alt+1-9 to rename"
            ),
        de
            and ("Routen fuer " .. goodName .. " • sortiert nach Gruppe / Region.")
            or fr
            and ("Routes transportant " .. goodName .. " • triées par groupe / région.")
            or ("Routes carrying " .. goodName .. " • sorted by group / region."),
        de and "Strg+Alt+0: Zurueck zur Warenliste"
            or fr and "Ctrl+Alt+0 : Retour à la liste des marchandises"
            or "Ctrl+Alt+0: Back to Goods",
    }

    if pages > 1 then
        lines[#lines + 1] =
            (
                de and "Seite "
                or fr and "Page "
                or "Page "
            )
            .. tostring(page + 1)
            .. "/" .. tostring(pages)
    end

    lines[#lines + 1] = ""

    if #records == 0 then
        lines[#lines + 1] =
            de and "Keine Handelsrouten fuer diese Ware gefunden."
            or fr and "Aucune route commerciale trouvée pour cette marchandise."
            or "No trade routes found for this good."
        return table.concat(lines, "\n")
    end

    local lastGroup = nil

    for index = first, last do
        local record = records[index]
        local slot = index - first + 1

        local groupName =
            tostring(record.groupName or "")

        if groupName == "" then
            groupName =
                de and "Ohne Gruppe"
                or fr and "Sans groupe"
                or "Ungrouped"
        end

        if groupName ~= lastGroup then
            if lastGroup ~= nil then
                lines[#lines + 1] = ""
            end

            lines[#lines + 1] =
                "◆ " .. groupName
            lastGroup = groupName
        end

        self.report.visible[slot] = {
            routeID = record.routeID,
            name = record.name,
            folderID = record.folderID,
            kind = "trade_route",
            sourceMode = "trade_routes_for_good",
            goodName = goodName,
            goodKey = tostring(self.report.goodKey or ""),
        }

        lines[#lines + 1] =
            tostring(slot)
            .. ". ▶ " .. tostring(record.name)

        lines[#lines + 1] =
            routeShipDetail(record, de, fr)

        if self.routeIslandMembershipComplete then
            local served = {}

            for _, island in ipairs(
                self.routeIslandNames or {}
            ) do
                local cache =
                    self.routeIslandRoutes[
                        tostring(island.key or "")
                    ]

                if routeIDInIslandCache(
                    cache,
                    record.routeID
                ) then
                    served[#served + 1] =
                        tostring(island.name or "")
                end
            end

            table.sort(served, function(a, b)
                return string.lower(a)
                    < string.lower(b)
            end)

            if #served > 0 then
                lines[#lines + 1] =
                    (
                        de and "   Inseln: "
                        or fr and "   Îles : "
                        or "   Islands: "
                    )
                    .. table.concat(served, " • ")
            end
        end

        if index < last then
            lines[#lines + 1] =
                "────────────────────────"
        end
    end

    return table.concat(lines, "\n")
end


function RenameManager:PageText(pageIndex)
    local mode = self.report.mode or "all"

    if mode == "island_index" then
        return self:IslandIndexPageText(pageIndex)
    elseif mode == "trade_routes_for_island" then
        return self:IslandRoutesPageText(pageIndex)
    elseif mode == "goods_index" then
        return self:GoodsIndexPageText(pageIndex)
    elseif mode == "trade_routes_for_good" then
        return self:GoodRoutesPageText(pageIndex)
    end

    local records = self:ReportRecords(mode)
    local pages = math.max(1, math.ceil(#records / 9))
    if pages > 12 then pages = 12 end

    local page = math.max(0, tonumber(pageIndex) or 0)
    if page >= pages then page = pages - 1 end

    self.report.page = page
    self.report.visible = {}

    local de = self.language == "de"
    local fr = self.language == "fr"
    local first = page * 9 + 1
    local last = math.min(first + 8, math.min(#records, 108))
    local routeMode =
        mode == "trade_routes"
        or mode == "trade_routes_by_group"

    local lines = {
        self:ModeTitle(mode),
        "",
        tostring(#records)
            .. (
                routeMode
                and (
                    de and " Handelsrouten • Strg+Alt+1-9 zum Umbenennen"
                    or fr and " routes commerciales • Ctrl+Alt+1-9 pour renommer"
                    or " trade routes • Ctrl+Alt+1-9 to rename"
                )
                or (
                    de and " Schiffe • Aktuelle Provinz/Sitzung"
                    or fr and " navires • Province/session actuelle"
                    or " ships • Current province/session"
                )
            ),
        routeMode
            and (
                mode == "trade_routes_by_group"
                and (
                    de and "Namensansicht: Gruppe / Region • Route • Schiffe"
                    or fr and "Vue de nommage : groupe / région • route • navires"
                    or "Naming view: group / region • route • ships"
                )
                or (
                    de and "Namensansicht: Route • Gruppe • Schiffe"
                    or fr and "Vue de nommage : route • groupe • navires"
                    or "Naming view: route • group • ships"
                )
            )
            or (
                de and "Strg+Alt+1-9: Nummeriertes Schiff umbenennen"
                or fr and "Ctrl+Alt+1-9 : Renommer le navire numéroté"
                or "Ctrl+Alt+1-9: Rename numbered ship"
            ),
        de and "Strg+Alt+0: Zurueck zum Rename-Manager-Menue"
            or fr and "Ctrl+Alt+0 : Retour au menu Rename Manager"
            or "Ctrl+Alt+0: Back to Rename Manager menu",
    }

    if pages > 1 then
        lines[#lines + 1] =
            (
                de and "Seite "
                or fr and "Page "
                or "Page "
            )
            .. tostring(page + 1)
            .. "/"
            .. tostring(pages)
    end

    lines[#lines + 1] = ""

    if #records == 0 then
        lines[#lines + 1] =
            routeMode
            and (
                de and "Keine Handelsrouten in der aktuellen Uebersicht."
                or fr and "Aucune route commerciale dans l'aperçu actuel."
                or "No trade routes in the current overview."
            )
            or (
                de and "Keine passenden Schiffe in dieser Provinz."
                or fr and "Aucun navire correspondant dans cette province."
                or "No matching ships in this province."
            )
        return table.concat(lines, "\n")
    end

    if routeMode then
        local lastGroupOnPage = nil

        for index = first, last do
            local record = records[index]
            local slot = index - first + 1

            self.report.visible[slot] = {
                routeID = record.routeID,
                name = record.name,
                folderID = record.folderID,
                kind = "trade_route",
                sourceMode = mode,
            }

            local groupName = tostring(record.groupName or "")

            if groupName == "" then
                groupName =
                    de and "Ohne Gruppe"
                    or fr and "Sans groupe"
                    or "Ungrouped"
            end

            if mode == "trade_routes_by_group"
                and groupName ~= lastGroupOnPage
            then
                if lastGroupOnPage ~= nil then
                    lines[#lines + 1] = ""
                end
                lines[#lines + 1] = "◆ " .. groupName
                lastGroupOnPage = groupName
            end

            if mode == "trade_routes_by_group" then
                lines[#lines + 1] =
                    tostring(slot) .. ". ▶ " .. tostring(record.name)
            else
                lines[#lines + 1] =
                    tostring(slot)
                    .. ". ▶ "
                    .. tostring(record.name)
                    .. (
                        de and (" (Gruppe: " .. groupName .. ")")
                        or fr and (" (Groupe : " .. groupName .. ")")
                        or (" (Group: " .. groupName .. ")")
                    )
            end

            lines[#lines + 1] =
                routeShipDetail(record, de, fr)

            if index < last then
                lines[#lines + 1] = "────────────────────────"
            end
        end
    else
        local lastRoute = nil

        for index = first, last do
            local record = records[index]
            local slot = index - first + 1

            if mode == "routes" and record.routeName ~= lastRoute then
                if lastRoute ~= nil then
                    lines[#lines + 1] = ""
                end
                lines[#lines + 1] = "▶ " .. record.routeName
                lastRoute = record.routeName
            end

            self.report.visible[slot] = {
                id = record.id,
                name = record.name,
                routeName = record.routeName,
                kind = "ship",
            }

            local routeSuffix = ""

            if mode ~= "routes" then
                if record.assigned and record.routeName ~= "" then
                    routeSuffix = " — ▶ " .. record.routeName
                else
                    routeSuffix =
                        de and " — Keine Handelsroute"
                        or fr and " — Aucune route commerciale"
                        or " — No trade route"
                end
            end

            lines[#lines + 1] =
                tostring(slot) .. ". ★ " .. record.name .. routeSuffix
        end
    end

    if #records > 108 and page == 11 then
        lines[#lines + 1] = ""

        lines[#lines + 1] =
            routeMode
            and (
                de and "Testlimit: Die ersten 108 Handelsrouten werden angezeigt."
                or fr and "Limite de test : les 108 premières routes commerciales sont affichées."
                or "Test limit: showing the first 108 trade routes."
            )
            or (
                de and "Testlimit: Die ersten 108 Schiffe werden angezeigt."
                or fr and "Limite de test : les 108 premiers navires sont affichés."
                or "Test limit: showing the first 108 ships."
            )
    end

    return table.concat(lines, "\n")
end

function RenameManager:IsReportOpen()
    if self.report.active ~= true then return false end
    local content = getTextPopupContent()
    if content == nil then return false end

    local text = ""
    pcall(function() text = tostring(content.Text or "") end)

    return text:find("RENAME MANAGER", 1, true) == 1
end

function RenameManager:TryDirectOpen(phase)
    self.directOpenAttempt = self.directOpenAttempt + 1

    local states = nil
    local okState, stateError = pcall(function()
        states =
            ui.Scenes.GovernorRequests
            .SceneData.Notification[0]
            .ButtonData.States
    end)

    if not okState or states == nil then
        log(
            "MENU OPEN RETRY"
            .. " | phase=" .. tostring(phase)
            .. " | attempt=" .. tostring(self.directOpenAttempt)
            .. " | statesPresent=false"
            .. " | error=" .. tostring(stateError or "")
        )
        return false
    end

    local focusOK, focusResult = pcall(function()
        return states:RequestFocus()
    end)
    local primaryOK, primaryResult = pcall(function()
        return states:EventPrimary()
    end)

    log(
        "MENU OPEN"
        .. " | phase=" .. tostring(phase)
        .. " | attempt=" .. tostring(self.directOpenAttempt)
        .. " | requestFocusSuccess=" .. tostring(focusOK)
        .. " | requestFocusResult=" .. tostring(focusResult)
        .. " | eventPrimarySuccess=" .. tostring(primaryOK)
        .. " | eventPrimaryResult=" .. tostring(primaryResult)
    )

    return focusOK and primaryOK
end

function RenameManager:Open()
    self.observedSignal = signalValue()
    self.report.active = false
    self.report.opening = false
    self.report.mode = nil
    self.report.visible = {}
    self.report.islandName = ""
    self.report.islandKey = ""

    self.directOpenPending = false
    self.directOpenAttempt = 0

    local ok, err = pcall(function()
        GovernorDecision:CheatStartGovernorDecisionForCurrentPlayerNet(
            MAIN_STORYLINE
        )
    end)

    log(
        "OPEN REQUEST"
        .. " | storyline=" .. tostring(MAIN_STORYLINE)
        .. " | signal=" .. tostring(self.observedSignal)
        .. " | success=" .. tostring(ok)
        .. " | error=" .. tostring(err or "")
    )

    if not ok then return false end

    if not self:TryDirectOpen("IMMEDIATE") then
        self.directOpenPending = true
    end

    return true
end


function RenameManager:OpenShipsMenu()
    self.observedSignal = signalValue()
    self.report.active = false
    self.report.opening = false
    self.report.mode = nil
    self.report.visible = {}
    self.report.islandName = ""
    self.report.islandKey = ""

    self.directOpenPending = false
    self.directOpenAttempt = 0

    local ok, err = pcall(function()
        GovernorDecision:CheatStartGovernorDecisionForCurrentPlayerNet(
            SHIPS_STORYLINE
        )
    end)

    log(
        "SHIPS MENU OPEN REQUEST"
        .. " | storyline=" .. tostring(SHIPS_STORYLINE)
        .. " | signal=" .. tostring(self.observedSignal)
        .. " | success=" .. tostring(ok)
        .. " | error=" .. tostring(err or "")
    )

    if not ok then return false end

    if not self:TryDirectOpen("SHIPS_IMMEDIATE") then
        self.directOpenPending = true
    end

    return true
end


function RenameManager:OpenTradeRoutesMenu()
    self.observedSignal = signalValue()
    self.report.active = false
    self.report.opening = false
    self.report.mode = nil
    self.report.visible = {}
    self.report.islandName = ""
    self.report.islandKey = ""

    self.directOpenPending = false
    self.directOpenAttempt = 0

    local ok, err = pcall(function()
        GovernorDecision:CheatStartGovernorDecisionForCurrentPlayerNet(
            TRADE_ROUTES_STORYLINE
        )
    end)

    log(
        "TRADE ROUTES MENU OPEN REQUEST"
        .. " | storyline=" .. tostring(TRADE_ROUTES_STORYLINE)
        .. " | signal=" .. tostring(self.observedSignal)
        .. " | success=" .. tostring(ok)
        .. " | error=" .. tostring(err or "")
    )

    if not ok then return false end

    if not self:TryDirectOpen("TRADE_ROUTES_IMMEDIATE") then
        self.directOpenPending = true
    end

    return true
end

function RenameManager:TickTextPopup()
    local content = getTextPopupContent()
    if content == nil then
        if self.report.active then
            self.report.active = false
            self.report.opening = false
            self.report.visible = {}
            log("PARCHMENT CLOSED | state-cleared")
        end
        return false
    end

    local text = nil
    pcall(function() text = content.Text end)
    local marker = normalizeMarker(text)

    if marker == "RM_CLOSE" then
        local okClose, closeErr = pcall(function()
            Scripts:PopUI()
        end)
        log(
            "SAFE CLOSE COMPLETE"
            .. " | success=" .. tostring(okClose)
            .. " | error=" .. tostring(closeErr or "")
        )
        return true
    end

    local pageNumber = string.match(marker, "^RM_SHIP_REPORT_P(%d+)$")
    if pageNumber ~= nil then
        local nativePage = tonumber(pageNumber) - 1
        self.report.opening = false
        self.report.active = true

        local report = self:PageText(nativePage)
        local okWrite, writeErr = pcall(function()
            content.Text = report
        end)

        log(
            "PARCHMENT WRITE"
            .. " | mode=" .. tostring(self.report.mode or "")
            .. " | nativePage=" .. tostring(nativePage + 1)
            .. " | effectivePage=" .. tostring((self.report.page or 0) + 1)
            .. " | success=" .. tostring(okWrite)
            .. " | chars=" .. tostring(#tostring(report or ""))
            .. " | error=" .. tostring(writeErr or "")
        )

        if self.pageRestoreProbePending
            and not self.pageRestoreProbeLogged
        then
            self.pageRestoreProbeLogged = true
            self.pageRestoreProbePending = false
            probeTextPopupPanel(
                "post-rename-remembered-page-"
                .. tostring((self.resumePage or 0) + 1)
            )
        end

        return true
    end

    return false
end


local function tradeOverviewState()
    local scene = nil
    local overview = nil
    local array = nil
    local panelOpen = nil
    local rows = 0

    pcall(function()
        scene = ui and ui.Scenes and ui.Scenes.TradeRoute or nil
        overview = scene and scene.TradeOverview or nil
        panelOpen = overview and overview.IsPanelOpen
        array = overview
            and overview.OverviewListData
            and overview.OverviewListData.ArrayData
            or nil
    end)

    if array ~= nil then
        local seen = false
        local emptyTail = 0
        for i = 0, 511 do
            local ok, item = pcall(function() return array[i] end)
            if ok and item ~= nil
                and string.find(tostring(item), "weak null", 1, true) == nil
            then
                rows = rows + 1
                seen = true
                emptyTail = 0
            elseif seen then
                emptyTail = emptyTail + 1
            end

            if seen and emptyTail >= 16 then
                break
            end
        end
    end

    return scene, overview, array, panelOpen, rows
end

function RenameManager:ResetTradeRouteNativeState()
    self.tradeOverviewPending = false
    self.tradeOverviewTicks = 0
    self.tradeOverviewStableTicks = 0
    self.tradeRouteAutoEditAttempted = false

    self.tradeRouteEditMonitoring = false
    self.tradeRouteEditMonitorTicks = 0
    self.tradeRouteEditNameData = nil
    self.tradeRouteEditTargetID = nil
    self.tradeRouteEditTargetName = ""

    self.tradeRouteNativePending = false
    self.tradeRouteNativePhase = ""
    self.tradeRouteNativeTicks = 0
    self.tradeRouteNativeRow = nil
    self.tradeRouteNativeNameData = nil
    self.tradeRouteNativeRouteID = nil
    self.tradeRouteNativeInitialName = ""
    self.tradeRouteNativeSawEnabled = false

    self.routeIslandEnumPending = false
    self.routeIslandEnumTicks = 0
    self.routeIslandEnumPopupOpened = false

    self.routeIslandFilterPending = false
    self.routeIslandFilterPhase = ""
    self.routeIslandFilterTicks = 0
    self.routeIslandFilterExpandRounds = 0
    self.routeIslandFilterPopupOpened = false
    self.routeIslandFilterButton = nil

    self.routeIslandMembershipPending = false
    self.routeIslandMembershipPhase = ""
    self.routeIslandMembershipTicks = 0
    self.routeIslandMembershipExpandRounds = 0
    self.routeIslandMembershipQueue = {}
    self.routeIslandMembershipIndex = 0
    self.routeIslandMembershipPopupOpened = false
    self.routeIslandMembershipButton = nil
    self.routeIslandMembershipFailures = 0
end

function RenameManager:OpenNativeTradeRouteOverview(purpose)
    self:ResetTradeRouteNativeState()

    self.tradeOverviewPending = true
    self.tradeOverviewTicks = 0

    if purpose == "harvest" then
        self.routeHarvestPending = true
        self.routeHarvestPhase = "open"
        self.routeHarvestTicks = 0
        self.routeHarvestExpandRounds = 0
        self.routeTargetFromParchment = false
    elseif purpose == "target" then
        self.routeHarvestPending = false
        self.routeTargetFromParchment = true
        self.routeTargetExpandRounds = 0
        self.routeTargetSearchApplied = false
        self.routeTargetSearchTicks = 0
        self.routeTargetSearchAttempt = 0
        self.routeTargetSearchQuery = ""
    elseif purpose == "island_filter" then
        self.routeHarvestPending = false
        self.routeTargetFromParchment = false
        self.routeIslandFilterPending = true
        self.routeIslandFilterPhase = "prepare"
        self.routeIslandFilterTicks = 0
        self.routeIslandFilterExpandRounds = 0
        self.routeIslandFilterPopupOpened = false
        self.routeIslandFilterButton = nil
    elseif purpose == "island_membership" then
        self.routeHarvestPending = false
        self.routeTargetFromParchment = false
        self.routeIslandMembershipPending = true
        self.routeIslandMembershipPhase = "prepare"
        self.routeIslandMembershipTicks = 0
        self.routeIslandMembershipExpandRounds = 0
        self.routeIslandMembershipQueue = {}
        self.routeIslandMembershipIndex = 0
        self.routeIslandMembershipPopupOpened = false
        self.routeIslandMembershipButton = nil
        self.routeIslandMembershipFailures = 0
    else
        self.routeHarvestPending = false
        self.routeTargetFromParchment = false
    end

    local ok, result = pcall(function()
        return Scripts:ToggleTraderouteMenu()
    end)

    log(
        "TRADE ROUTE OVERVIEW OPEN"
        .. " | purpose=" .. tostring(purpose or "direct")
        .. " | method=Scripts:ToggleTraderouteMenu()"
        .. " | success=" .. tostring(ok)
        .. " | result=" .. tostring(result)
    )

    if not ok then
        self.tradeOverviewPending = false
        self.routeHarvestPending = false
        self.routeTargetFromParchment = false
    end

    return ok
end


local function firstNativeTradeRouteNameInput(array)
    if array == nil then
        return nil, nil, nil, "array-missing"
    end

    local seen = false
    local emptyTail = 0

    for i = 0, 511 do
        local okItem, item = pcall(function()
            return array[i]
        end)

        if okItem and item ~= nil
            and string.find(tostring(item), "weak null", 1, true) == nil
        then
            seen = true
            emptyTail = 0

            local routeID = nil
            local nameData = nil
            local routeName = nil

            pcall(function() routeID = item.RouteID end)
            pcall(function() nameData = item.NameData end)
            pcall(function()
                routeName = nameData and nameData.Text or nil
            end)

            if type(routeID) == "number"
                and routeID >= 0
                and nameData ~= nil
                and string.find(
                    tostring(nameData),
                    "weak null",
                    1,
                    true
                ) == nil
            then
                return nameData, routeID, tostring(routeName or ""), "ready"
            end
        else
            if seen then
                emptyTail = emptyTail + 1
                if emptyTail >= 16 then
                    break
                end
            end
        end
    end

    return nil, nil, nil, "no-route-row-with-NameData"
end


local function firstRealTradeRouteNameData(array)
    if array == nil then
        return nil, nil, nil, "array-missing"
    end

    local seen = false
    local emptyTail = 0

    for i = 0, 511 do
        local okItem, item = pcall(function()
            return array[i]
        end)

        if okItem and item ~= nil
            and string.find(tostring(item), "weak null", 1, true) == nil
        then
            seen = true
            emptyTail = 0

            local routeID = nil
            local nameData = nil
            local routeName = nil

            pcall(function() routeID = item.RouteID end)
            pcall(function() nameData = item.NameData end)
            pcall(function()
                routeName = nameData and nameData.Text or nil
            end)

            if type(routeID) == "number"
                and routeID >= 0
                and nameData ~= nil
                and string.find(tostring(nameData), "weak null", 1, true) == nil
            then
                return nameData, routeID, tostring(routeName or ""), "ready"
            end
        elseif seen then
            emptyTail = emptyTail + 1
            if emptyTail >= 16 then
                break
            end
        end
    end

    return nil, nil, nil, "no-real-route-row"
end


local function nativeTradeRouteRenameInput()
    local input = nil
    local ok, err = pcall(function()
        input =
            ui
            and ui.Scenes
            and ui.Scenes.TradeRoute
            and ui.Scenes.TradeRoute.TradeGoodSelection
            and ui.Scenes.TradeRoute.TradeGoodSelection.TradeRouteNameTextInputData
            or nil
    end)

    if not ok or input == nil then
        return nil, "missing:" .. tostring(err or "")
    end

    return input, "ready"
end



local function nativeLifecycleBackendName(routeID)
    local manager = nil

    pcall(function()
        if TradeRoute and type(TradeRoute.get) == "function" then
            manager = TradeRoute.get()
        end
    end)

    if manager == nil then
        pcall(function()
            manager = TradeRoute
        end)
    end

    if manager == nil or type(routeID) ~= "number" then
        return nil, "manager-missing"
    end

    local route = nil
    local okRoute, routeErr = pcall(function()
        route = manager:GetRoute(routeID)
    end)

    if not okRoute or route == nil
        or string.find(tostring(route), "weak null", 1, true) ~= nil
    then
        return nil, "route-missing:" .. tostring(routeErr or "")
    end

    local name = nil
    local okName, nameErr = pcall(function()
        name = route.Name
    end)

    if not okName then
        return nil, "name-unreadable:" .. tostring(nameErr or "")
    end

    return tostring(name or ""), "ready"
end

local function firstNativeLifecycleRoute(array)
    if array == nil then
        return nil, nil, nil, nil, "array-missing"
    end

    local seen = false
    local emptyTail = 0

    for i = 0, 255 do
        local ok, row = pcall(function()
            return array[i]
        end)

        if ok and row ~= nil
            and string.find(tostring(row), "weak null", 1, true) == nil
        then
            seen = true
            emptyTail = 0

            local routeID = nil
            local isGroup = nil
            local nameData = nil
            local routeName = ""

            pcall(function() routeID = row.RouteID end)
            pcall(function() isGroup = row.IsGroupBtn end)
            pcall(function() nameData = row.NameData end)
            pcall(function()
                routeName = tostring(
                    nameData and nameData.Text or ""
                )
            end)

            if type(routeID) == "number"
                and routeID >= 0
                and isGroup ~= true
                and nameData ~= nil
                and string.find(tostring(nameData), "weak null", 1, true) == nil
            then
                return row, nameData, routeID, routeName, "ready"
            end
        elseif seen then
            emptyTail = emptyTail + 1
            if emptyTail >= 16 then
                break
            end
        end
    end

    return nil, nil, nil, nil, "no-real-route-row"
end


local function routeOverviewArray()
    local overview = nil
    local array = nil
    pcall(function()
        overview =
            ui
            and ui.Scenes
            and ui.Scenes.TradeRoute
            and ui.Scenes.TradeRoute.TradeOverview
            or nil
        array =
            overview
            and overview.OverviewListData
            and overview.OverviewListData.ArrayData
            or nil
    end)
    return overview, array
end

local function expandCollapsedRouteGroups()
    local _, array = routeOverviewArray()
    if array == nil then
        return 0
    end

    local expanded = 0
    local seen = false
    local emptyTail = 0

    for i = 0, 255 do
        local ok, item = pcall(function()
            return array[i]
        end)

        if ok and item ~= nil
            and string.find(tostring(item), "weak null", 1, true) == nil
        then
            seen = true
            emptyTail = 0

            local isOpen = nil
            local buttonData = nil
            local okOpen = pcall(function()
                isOpen = item.IsGroupOpen
            end)
            local okButton = pcall(function()
                buttonData = item.ButtonData
            end)

            if okOpen and okButton
                and type(isOpen) == "boolean"
                and buttonData ~= nil
                and isOpen == false
            then
                local fn = nil
                pcall(function()
                    fn = buttonData.PrimaryButtonPressed
                end)

                if type(fn) == "function" then
                    local pressOK = pcall(function()
                        buttonData:PrimaryButtonPressed()
                    end)
                    if pressOK then
                        expanded = expanded + 1
                    end
                end
            end
        elseif seen then
            emptyTail = emptyTail + 1
            if emptyTail >= 16 then
                break
            end
        end
    end

    return expanded
end

local function harvestRouteGroups()
    local _, array = routeOverviewArray()
    local groups = {}
    if array == nil then
        return groups
    end

    local seen = false
    local emptyTail = 0

    for i = 0, 255 do
        local ok, item = pcall(function()
            return array[i]
        end)

        if ok and item ~= nil
            and string.find(
                tostring(item),
                "weak null",
                1,
                true
            ) == nil
        then
            seen = true
            emptyTail = 0

            local isGroupOpen = nil
            local buttonData = nil

            pcall(function()
                isGroupOpen = item.IsGroupOpen
            end)
            pcall(function()
                buttonData = item.ButtonData
            end)

            if type(isGroupOpen) == "boolean"
                and buttonData ~= nil
            then
                local folderID = nil
                local nameData = nil
                local groupName = ""

                pcall(function()
                    folderID = buttonData.FolderID
                end)
                pcall(function()
                    nameData = buttonData.NameData
                end)
                pcall(function()
                    groupName =
                        tostring(
                            nameData
                            and nameData.Text
                            or ""
                        )
                end)

                if type(folderID) == "number"
                    and groupName ~= ""
                then
                    groups[folderID] = groupName
                end
            end
        elseif seen then
            emptyTail = emptyTail + 1
            if emptyTail >= 16 then
                break
            end
        end
    end

    return groups
end


local function safeTradeRouteIconArraySize(array)
    if array == nil then return -1 end

    local helper =
        halo and halo["PhoenixArray<halo::CIconData>"] or nil

    if helper and type(helper.GetSize) == "function" then
        local size = -1
        pcall(function()
            size = tonumber(helper.GetSize(array)) or -1
        end)
        return size
    end

    return -1
end

local function safeTradeRouteIconArrayElement(array, index)
    if array == nil then return nil end

    local helper =
        halo and halo["PhoenixArray<halo::CIconData>"] or nil

    if helper and type(helper.GetElement) == "function" then
        local value = nil
        pcall(function()
            value = helper.GetElement(array, index)
        end)
        return value
    end

    local value = nil
    pcall(function()
        value = array[index]
    end)
    return value
end

local function titleCaseGoodsToken(token)
    local text =
        string.gsub(tostring(token or ""), "_", " ")

    return string.gsub(
        text,
        "(%a)([%w']*)",
        function(first, rest)
            return string.upper(first)
                .. string.lower(rest)
        end
    )
end

local function goodFromTradeRouteIcon(icon)
    if icon == nil then return nil end

    local imageID = ""
    local visible = nil

    pcall(function()
        imageID = tostring(icon.ImageID or "")
    end)
    pcall(function()
        visible = icon.IsVisible
    end)

    if visible == false or imageID == "" then
        return nil
    end

    local lower = string.lower(imageID)

    if not string.find(
        lower,
        "production_goods",
        1,
        true
    ) then
        return nil
    end

    local base =
        string.match(lower, "([^/\\]+)$")
        or lower

    base = string.gsub(base, "%.[^.]+$", "")
    base = string.gsub(base, "^icon_3d_", "")
    base = string.gsub(base, "_goods$", "")

    if base == "" then return nil end

    return {
        key = base,
        name = titleCaseGoodsToken(base),
        imageID = imageID,
    }
end

local function goodsFromTradeRouteItems(items)
    local result = {}
    local seen = {}
    local size = safeTradeRouteIconArraySize(items)

    if size < 0 then
        return result
    end

    for i = 0, size - 1 do
        local icon =
            safeTradeRouteIconArrayElement(items, i)
        local good = goodFromTradeRouteIcon(icon)

        if good ~= nil
            and not seen[good.key]
        then
            seen[good.key] = true
            result[#result + 1] = good
        end
    end

    table.sort(result, function(a, b)
        return string.lower(tostring(a.name or ""))
            < string.lower(tostring(b.name or ""))
    end)

    return result
end

local function harvestRouteRows()
    local _, array = routeOverviewArray()
    local result = {}
    if array == nil then
        return result
    end

    local seen = false
    local emptyTail = 0

    for i = 0, 511 do
        local ok, row = pcall(function()
            return array[i]
        end)

        if ok and row ~= nil
            and string.find(tostring(row), "weak null", 1, true) == nil
        then
            seen = true
            emptyTail = 0

            local routeID = nil
            local nameData = nil
            local folderID = nil
            local activeShipsAmount = ""
            local pausedShipsAmount = ""
            local lostShipsAmount = ""
            local tradeRouteItems = nil

            pcall(function() routeID = row.RouteID end)
            pcall(function() nameData = row.NameData end)
            pcall(function() folderID = row.FolderID end)
            pcall(function()
                activeShipsAmount =
                    tostring(row.ActiveShipsAmount or "")
            end)
            pcall(function()
                pausedShipsAmount =
                    tostring(row.PausedShipsAmount or "")
            end)
            pcall(function()
                lostShipsAmount =
                    tostring(row.LostShipsAmount or "")
            end)
            pcall(function()
                tradeRouteItems = row.TradeRouteItems
            end)

            if type(routeID) == "number"
                and routeID >= 0
                and nameData ~= nil
            then
                local name = ""
                pcall(function()
                    name = tostring(nameData.Text or "")
                end)

                if name ~= "" then
                    result[routeID] = {
                        routeID = routeID,
                        name = name,
                        folderID = folderID,
                        activeShipsAmount =
                            activeShipsAmount,
                        pausedShipsAmount =
                            pausedShipsAmount,
                        lostShipsAmount =
                            lostShipsAmount,
                        goods =
                            goodsFromTradeRouteItems(
                                tradeRouteItems
                            ),
                    }
                end
            end
        elseif seen then
            emptyTail = emptyTail + 1
            if emptyTail >= 16 then
                break
            end
        end
    end

    return result
end

local function routeSearchQuery(routeName)
    local name = tostring(routeName or "")

    -- Search is only a visibility aid. Final identity is still exact RouteID.
    --
    -- Runtime evidence:
    --   "Amphorae" successfully materialized a renamed Amphorae route.
    --   "Beer Swe" did NOT materialize RouteID 105 for
    --   "Beer Swe - Dan_Test".
    --
    -- Therefore use the first word only. This is deliberately broad; safety
    -- comes from the exact RouteID match after the native search rebuild.
    local firstSpace = string.find(name, " ", 1, true)
    if firstSpace ~= nil and firstSpace > 1 then
        return string.sub(name, 1, firstSpace - 1)
    end

    return name
end


local function setTradeRouteNativeSearch(text)
    local overview, _ = routeOverviewArray()
    if overview == nil then
        return false, "overview-missing", nil, nil
    end

    local outer = nil
    local input = nil

    local okObjects, objectsErr = pcall(function()
        outer =
            overview.FilterData
            and overview.FilterData.SearchInputData
            or nil

        input =
            outer
            and outer.SearchInput
            or nil
    end)

    if not okObjects or input == nil then
        return false,
            "search-input-missing:" .. tostring(objectsErr or ""),
            outer,
            input
    end

    local before = ""
    pcall(function()
        before = tostring(input.Text or "")
    end)

    local writeOK, writeErr = pcall(function()
        input.Text = tostring(text or "")
    end)

    local methodAvailable = false
    pcall(function()
        methodAvailable =
            type(input.TextFinished) == "function"
    end)

    local finishOK = false
    local finishErr = ""

    if writeOK and methodAvailable then
        finishOK, finishErr = pcall(function()
            return input:TextFinished()
        end)
    end

    local after = ""
    pcall(function()
        after = tostring(input.Text or "")
    end)

    return writeOK and finishOK,
        tostring(
            (not writeOK and writeErr)
            or (not methodAvailable and "TextFinished-missing")
            or (not finishOK and finishErr)
            or ""
        ),
        before,
        after
end

local function findExactRouteRow(routeID)
    local _, array = routeOverviewArray()
    if array == nil or type(routeID) ~= "number" then
        return nil, nil, nil
    end

    local seen = false
    local emptyTail = 0

    for i = 0, 511 do
        local ok, row = pcall(function()
            return array[i]
        end)

        if ok and row ~= nil
            and string.find(tostring(row), "weak null", 1, true) == nil
        then
            seen = true
            emptyTail = 0

            local id = nil
            pcall(function() id = row.RouteID end)

            if id == routeID then
                local nameData = nil
                local name = ""
                pcall(function() nameData = row.NameData end)
                pcall(function()
                    name = tostring(
                        nameData and nameData.Text or ""
                    )
                end)
                return row, nameData, name
            end
        elseif seen then
            emptyTail = emptyTail + 1
            if emptyTail >= 16 then
                break
            end
        end
    end

    return nil, nil, nil
end


-- ------------------------------------------------------------------
-- Fast cached By Islands drill-down.
-- Uses the same proven native Trade Route island filter surface used by
-- Ship Finder, but lazily: enumerate island buttons once, then scan only the
-- island the player actually opens.
-- ------------------------------------------------------------------

local function getIslandFilterParts()
    local scene = ui and ui.Scenes and ui.Scenes.TradeRoute or nil
    local overview = scene and scene.TradeOverview or nil
    local filter = overview and overview.FilterData or nil
    local islandList = filter and filter.IslandListData or nil
    local buttons = islandList and islandList.IslandListData or nil
    local rows = overview and overview.OverviewListData
        and overview.OverviewListData.ArrayData or nil
    return scene, overview, filter, islandList, buttons, rows
end

local function safeIslandButtonArraySize(array)
    if array == nil then return -1 end
    local helper = halo and halo["PhoenixArray<halo::CButtonData>"] or nil
    if helper and helper.GetSize then
        local size = -1
        pcall(function() size = helper.GetSize(array) end)
        return size
    end
    return -1
end

local function safeIslandButtonElement(array, index)
    if array == nil then return nil end
    local helper = halo and halo["PhoenixArray<halo::CButtonData>"] or nil
    if helper and helper.GetElement then
        local value = nil
        pcall(function() value = helper.GetElement(array, index) end)
        return value
    end
    local value = nil
    pcall(function() value = array[index] end)
    return value
end

local function islandButtonText(button)
    local text = nil
    pcall(function()
        text = button.Data and button.Data.TextData
            and button.Data.TextData.Text or nil
    end)
    if text == nil or tostring(text) == "" then
        pcall(function()
            text = button.Data and button.Data.Text or nil
        end)
    end
    return text and tostring(text) or ""
end

local function islandButtonSelected(button)
    local selected = false
    pcall(function()
        selected = button.States and button.States.IsSelected == true
    end)
    return selected
end

local function pressIslandButton(button)
    if button == nil then return false, "button-nil" end
    local states = nil
    pcall(function() states = button.States end)
    if states == nil then return false, "states-nil" end
    local fn = nil
    pcall(function() fn = states.EventPrimary end)
    if type(fn) ~= "function" then
        return false, "EventPrimary-unavailable"
    end
    local ok, result = pcall(function()
        return states:EventPrimary()
    end)
    return ok, result
end

local function collectNativeIslandButtons()
    local _, _, _, _, buttons = getIslandFilterParts()
    local size = safeIslandButtonArraySize(buttons)
    local records = {}

    if size < 1 then return records, size end

    for i = 0, size - 1 do
        local button = safeIslandButtonElement(buttons, i)
        if button ~= nil then
            local name = islandButtonText(button)
            if name ~= "" then
                records[#records + 1] = {
                    name = name,
                    arrayIndex = i,
                    key = tostring(i) .. "|" .. name,
                    button = button,
                }
            end
        end
    end

    return records, size
end

local function openIslandFilterPopup()
    local _, _, filter = getIslandFilterParts()
    if filter == nil then return false, "filter-missing", false end

    local visible = false
    pcall(function() visible = filter.IsPopupVisible == true end)
    if visible then return true, nil, false end

    local fn = nil
    pcall(function() fn = filter.FilterButtonEvent end)
    if type(fn) ~= "function" then
        return false, "FilterButtonEvent-unavailable", false
    end

    local ok, result = pcall(function()
        return filter:FilterButtonEvent()
    end)
    return ok, result, ok
end

local function closeIslandFilterPopup(openedByUs)
    if not openedByUs then return true, nil end
    local _, _, filter = getIslandFilterParts()
    if filter == nil then return false, "filter-missing" end

    local visible = false
    pcall(function() visible = filter.IsPopupVisible == true end)
    if not visible then return true, nil end

    local fn = nil
    pcall(function() fn = filter.CloseButtonEvent end)
    if type(fn) ~= "function" then
        return false, "CloseButtonEvent-unavailable"
    end
    return pcall(function() return filter:CloseButtonEvent() end)
end

local function clearSelectedIslandButtons(buttonRecords)
    local cleared = 0
    for _, rec in ipairs(buttonRecords or {}) do
        if islandButtonSelected(rec.button) then
            local ok = pressIslandButton(rec.button)
            if ok then cleared = cleared + 1 end
        end
    end
    return cleared
end

local function countRouteCache(routeCache)
    local n = 0
    for _ in pairs(routeCache or {}) do n = n + 1 end
    return n
end

local function closeNativeTradeRouteScene()
    return pcall(function()
        local trScene = ui and ui.Scenes and ui.Scenes.TradeRoute or nil
        if trScene and trScene.CloseTradeRouteScene then
            return trScene:CloseTradeRouteScene()
        end
        return Scripts:ToggleTraderouteMenu()
    end)
end

function RenameManager:BeginIslandEnumeration()
    self.routeIslandEnumPending = true
    self.routeIslandEnumTicks = 0
    self.routeIslandEnumPopupOpened = false
    self.tradeOverviewPending = true

    log(
        "ISLAND INDEX ENUM START"
        .. " | strategy=native-island-buttons-only"
        .. " | routeScan=none"
        .. " | cache=lazy-per-island"
    )
    return true
end

function RenameManager:TickIslandEnumeration()
    if not self.routeIslandEnumPending then return false end
    self.routeIslandEnumTicks = self.routeIslandEnumTicks + 1

    local _, overview, filter, islandList, buttons = getIslandFilterParts()
    if overview == nil or filter == nil or islandList == nil then
        if self.routeIslandEnumTicks >= 20 then
            log("ISLAND INDEX ENUM ABORT | reason=filter-surface-unavailable")
            self.routeIslandEnumPending = false
            self.tradeOverviewPending = false
            closeNativeTradeRouteScene()
            return true
        end
        return true
    end

    local visible = false
    pcall(function() visible = filter.IsPopupVisible == true end)
    if not visible then
        local ok, result, opened = openIslandFilterPopup()
        if opened then self.routeIslandEnumPopupOpened = true end
        log(
            "ISLAND INDEX FILTER OPEN"
            .. " | success=" .. tostring(ok)
            .. " | result=" .. tostring(result or "")
        )
        if not ok then
            self.routeIslandEnumPending = false
            self.tradeOverviewPending = false
            closeNativeTradeRouteScene()
            return true
        end
        return true
    end

    local records, nativeSize = collectNativeIslandButtons()
    if #records < 1 then
        if self.routeIslandEnumTicks < 8 then return true end
        log(
            "ISLAND INDEX ENUM ABORT"
            .. " | reason=no-named-buttons"
            .. " | nativeSize=" .. tostring(nativeSize)
        )
        self.routeIslandEnumPending = false
        self.tradeOverviewPending = false
        closeIslandFilterPopup(self.routeIslandEnumPopupOpened)
        closeNativeTradeRouteScene()
        return true
    end

    -- Preserve duplicate display names safely by keeping the native array index
    -- in the internal key. Sorting is display-only.
    table.sort(records, function(a, b)
        local an = string.lower(tostring(a.name or ""))
        local bn = string.lower(tostring(b.name or ""))
        if an ~= bn then return an < bn end
        return (tonumber(a.arrayIndex) or 0) < (tonumber(b.arrayIndex) or 0)
    end)

    local stored = {}
    for _, rec in ipairs(records) do
        stored[#stored + 1] = {
            name = rec.name,
            arrayIndex = rec.arrayIndex,
            key = rec.key,
        }
    end

    self.routeIslandNames = stored
    self.routeIslandIndexValid = true
    self.routeIslandTopologySignature = routeIDTopologySignature(self.routeCache)
    self.routeIslandSessionGUID = currentSessionGUID()
    pcall(function()
        self.routeIslandLastRefreshPlayTime = Game and Game.PlayTime or nil
    end)

    local selectedCount = 0
    for _, rec in ipairs(records) do
        if islandButtonSelected(rec.button) then selectedCount = selectedCount + 1 end
    end

    log(
        "ISLAND INDEX ENUM COMPLETE"
        .. " | nativeButtons=" .. tostring(nativeSize)
        .. " | namedIslands=" .. tostring(#stored)
        .. " | selectedBeforeClose=" .. tostring(selectedCount)
        .. " | routeCache=" .. tostring(countRouteCache(self.routeCache))
        .. " | topologySignatureChars="
        .. tostring(#tostring(self.routeIslandTopologySignature or ""))
        .. " | behavior=list-first-lazy-route-cache"
    )

    self.routeIslandEnumPending = false
    self.tradeOverviewPending = false
    closeIslandFilterPopup(self.routeIslandEnumPopupOpened)
    local closeOK, closeErr = closeNativeTradeRouteScene()

    if closeOK then
        self.resumeMode = "island_index"
        self.resumePage = 0
        self.resumeIslandName = ""
        self.resumeIslandKey = ""
        self.resumePending = true
        self.resumeTicks = 2
    end

    log(
        "ISLAND INDEX RETURN ARMED"
        .. " | closeSuccess=" .. tostring(closeOK)
        .. " | error=" .. tostring(closeErr or "")
    )
    return true
end

function RenameManager:TickIslandRouteFilter()
    if not self.routeIslandFilterPending then return false end
    self.routeIslandFilterTicks = self.routeIslandFilterTicks + 1

    local _, overview, filter, islandList = getIslandFilterParts()
    if overview == nil or filter == nil or islandList == nil then
        if self.routeIslandFilterTicks >= 20 then
            log(
                "ISLAND ROUTE FILTER ABORT"
                .. " | island=" .. tostring(self.routeIslandTargetName)
                .. " | reason=filter-surface-unavailable"
            )
            self.routeIslandFilterPending = false
            self.tradeOverviewPending = false
            closeNativeTradeRouteScene()
        end
        return true
    end

    if self.routeIslandFilterPhase == "prepare" then
        if self.routeIslandFilterExpandRounds == 0 then
            local clearOK, clearErr = setTradeRouteNativeSearch("")
            log(
                "ISLAND ROUTE FILTER SEARCH CLEAR"
                .. " | success=" .. tostring(clearOK)
                .. " | error=" .. tostring(clearErr or "")
            )
        end

        local expanded = expandCollapsedRouteGroups()
        self.routeIslandFilterExpandRounds = self.routeIslandFilterExpandRounds + 1
        if expanded > 0 and self.routeIslandFilterExpandRounds < 5 then
            self.tradeOverviewTicks = 0
            return true
        end

        local visible = false
        pcall(function() visible = filter.IsPopupVisible == true end)
        if not visible then
            local ok, result, opened = openIslandFilterPopup()
            if opened then self.routeIslandFilterPopupOpened = true end
            log(
                "ISLAND ROUTE FILTER OPEN"
                .. " | island=" .. tostring(self.routeIslandTargetName)
                .. " | success=" .. tostring(ok)
                .. " | result=" .. tostring(result or "")
            )
            if not ok then
                self.routeIslandFilterPending = false
                self.tradeOverviewPending = false
                closeNativeTradeRouteScene()
            end
            return true
        end

        local buttons, nativeSize = collectNativeIslandButtons()
        if #buttons < 1 then
            if self.routeIslandFilterTicks < 8 then return true end
            log(
                "ISLAND ROUTE FILTER ABORT"
                .. " | island=" .. tostring(self.routeIslandTargetName)
                .. " | reason=no-island-buttons"
                .. " | nativeSize=" .. tostring(nativeSize)
            )
            self.routeIslandFilterPending = false
            self.tradeOverviewPending = false
            closeIslandFilterPopup(self.routeIslandFilterPopupOpened)
            closeNativeTradeRouteScene()
            return true
        end

        -- Normalize any existing native island filter, then activate only the
        -- chosen island in the same event-loop turn. This costs one rebuild.
        local cleared = clearSelectedIslandButtons(buttons)
        local target = nil

        if self.routeIslandTargetArrayIndex ~= nil then
            for _, rec in ipairs(buttons) do
                if rec.arrayIndex == self.routeIslandTargetArrayIndex
                    and rec.name == self.routeIslandTargetName
                then
                    target = rec
                    break
                end
            end
        end
        if target == nil then
            for _, rec in ipairs(buttons) do
                if rec.name == self.routeIslandTargetName then
                    target = rec
                    break
                end
            end
        end

        if target == nil then
            log(
                "ISLAND ROUTE FILTER ABORT"
                .. " | island=" .. tostring(self.routeIslandTargetName)
                .. " | reason=target-button-not-found"
                .. " | cleared=" .. tostring(cleared)
            )
            self.routeIslandFilterPending = false
            self.tradeOverviewPending = false
            closeIslandFilterPopup(self.routeIslandFilterPopupOpened)
            closeNativeTradeRouteScene()
            return true
        end

        local ok, result = pressIslandButton(target.button)
        self.routeIslandFilterButton = target.button
        self.routeIslandFilterPhase = "read"
        self.routeIslandFilterTicks = 0

        log(
            "ISLAND ROUTE FILTER SELECT"
            .. " | island=" .. tostring(self.routeIslandTargetName)
            .. " | key=" .. tostring(self.routeIslandTargetKey)
            .. " | arrayIndex=" .. tostring(target.arrayIndex)
            .. " | clearedExisting=" .. tostring(cleared)
            .. " | success=" .. tostring(ok)
            .. " | result=" .. tostring(result or "")
        )

        if not ok then
            self.routeIslandFilterPending = false
            self.tradeOverviewPending = false
            closeIslandFilterPopup(self.routeIslandFilterPopupOpened)
            closeNativeTradeRouteScene()
        end
        return true
    end

    if self.routeIslandFilterPhase == "read" then
        local selected = islandButtonSelected(self.routeIslandFilterButton)
        local filtered = harvestRouteRows()
        local filteredCount = countRouteCache(filtered)
        local baselineCount = countRouteCache(self.routeCache)

        -- The native list rebuilds asynchronously. A full baseline immediately
        -- after clicking is stale; wait rather than caching the wrong island.
        local settled = selected
            and (filteredCount < baselineCount or baselineCount <= 1)

        if not settled and self.routeIslandFilterTicks < 8 then
            return true
        end

        if not settled then
            log(
                "ISLAND ROUTE FILTER ABORT"
                .. " | island=" .. tostring(self.routeIslandTargetName)
                .. " | reason=filter-did-not-narrow"
                .. " | selected=" .. tostring(selected)
                .. " | filteredRoutes=" .. tostring(filteredCount)
                .. " | baselineRoutes=" .. tostring(baselineCount)
            )
            if selected then
                pressIslandButton(self.routeIslandFilterButton)
            end
            closeIslandFilterPopup(self.routeIslandFilterPopupOpened)
            local closeOK, closeErr = closeNativeTradeRouteScene()
            self.routeIslandFilterPending = false
            self.tradeOverviewPending = false
            self.routeIslandFilterPhase = ""
            self.routeIslandFilterButton = nil
            if closeOK then
                self.resumeMode = "island_index"
                self.resumePage = 0
                self.resumeIslandName = ""
                self.resumeIslandKey = ""
                self.resumePending = true
                self.resumeTicks = 2
            end
            log(
                "ISLAND ROUTE FILTER ABORT RETURN"
                .. " | closeSuccess=" .. tostring(closeOK)
                .. " | error=" .. tostring(closeErr or "")
            )
            return true
        end

        local routeIDs = {}
        for routeID, rec in pairs(filtered or {}) do
            if type(routeID) == "number" and routeID >= 0 then
                routeIDs[#routeIDs + 1] = routeID

                -- Keep names/counts fresh without changing route identity.
                if self.routeCache[routeID] == nil then
                    rec.groupName = tostring(
                        self.routeGroupCache[rec.folderID] or ""
                    )
                    self.routeCache[routeID] = rec
                end
            end
        end
        table.sort(routeIDs)

        self.routeIslandRoutes[self.routeIslandTargetKey] = {
            islandKey = self.routeIslandTargetKey,
            islandName = self.routeIslandTargetName,
            routeIDs = routeIDs,
            routeCount = #routeIDs,
        }

        log(
            "ISLAND ROUTE FILTER READ"
            .. " | island=" .. tostring(self.routeIslandTargetName)
            .. " | key=" .. tostring(self.routeIslandTargetKey)
            .. " | selected=" .. tostring(selected)
            .. " | routes=" .. tostring(#routeIDs)
            .. " | baselineRoutes=" .. tostring(baselineCount)
            .. " | readTicks=" .. tostring(self.routeIslandFilterTicks)
            .. " | cache=commit-per-island"
        )

        if selected then
            pressIslandButton(self.routeIslandFilterButton)
        end
        self.routeIslandFilterPhase = "restore"
        self.routeIslandFilterTicks = 0
        return true
    end

    if self.routeIslandFilterPhase == "restore" then
        -- Give the native overview one turn to remove the filter before closing.
        if self.routeIslandFilterTicks < 1 then return true end

        closeIslandFilterPopup(self.routeIslandFilterPopupOpened)
        local closeOK, closeErr = closeNativeTradeRouteScene()

        self.routeIslandFilterPending = false
        self.tradeOverviewPending = false
        self.routeIslandFilterPhase = ""
        self.routeIslandFilterButton = nil

        if closeOK then
            self.resumeMode = "trade_routes_for_island"
            self.resumePage = 0
            self.resumeIslandName = self.routeIslandTargetName
            self.resumeIslandKey = self.routeIslandTargetKey
            self.resumePending = true
            self.resumeTicks = 2
        end

        log(
            "ISLAND ROUTE FILTER COMPLETE"
            .. " | island=" .. tostring(self.routeIslandTargetName)
            .. " | closeSuccess=" .. tostring(closeOK)
            .. " | error=" .. tostring(closeErr or "")
        )
        return true
    end

    return true
end

function RenameManager:FinishIslandMembershipScan()
    closeIslandFilterPopup(self.routeIslandMembershipPopupOpened)
    local closeOK, closeErr = closeNativeTradeRouteScene()

    self.routeIslandMembershipPending = false
    self.tradeOverviewPending = false
    self.routeIslandMembershipPhase = ""
    self.routeIslandMembershipButton = nil

    self.routeIslandMembershipComplete =
        self.routeIslandMembershipFailures == 0

    local cachedIslands = 0
    for _, island in ipairs(self.routeIslandNames or {}) do
        if self.routeIslandRoutes[tostring(island.key or "")] ~= nil then
            cachedIslands = cachedIslands + 1
        end
    end

    if closeOK then
        self.resumeMode = "trade_routes_for_island"
        self.resumePage = 0
        self.resumeIslandName = self.routeIslandTargetName
        self.resumeIslandKey = self.routeIslandTargetKey
        self.resumePending = true
        self.resumeTicks = 2
    end

    log(
        "ISLAND MEMBERSHIP COMPLETE"
        .. " | selectedIsland=" .. tostring(self.routeIslandTargetName)
        .. " | cachedIslands=" .. tostring(cachedIslands)
        .. "/" .. tostring(#(self.routeIslandNames or {}))
        .. " | failures=" .. tostring(self.routeIslandMembershipFailures)
        .. " | complete=" .. tostring(self.routeIslandMembershipComplete)
        .. " | closeSuccess=" .. tostring(closeOK)
        .. " | error=" .. tostring(closeErr or "")
        .. " | purpose=sort-routes-by-other-islands"
    )

    return true
end

function RenameManager:TickIslandMembershipScan()
    if not self.routeIslandMembershipPending then return false end
    self.routeIslandMembershipTicks =
        self.routeIslandMembershipTicks + 1

    local _, overview, filter, islandList =
        getIslandFilterParts()

    if overview == nil or filter == nil or islandList == nil then
        if self.routeIslandMembershipTicks >= 20 then
            self.routeIslandMembershipFailures =
                self.routeIslandMembershipFailures + 1
            log(
                "ISLAND MEMBERSHIP ABORT"
                .. " | reason=filter-surface-unavailable"
            )
            return self:FinishIslandMembershipScan()
        end
        return true
    end

    if self.routeIslandMembershipPhase == "prepare" then
        if self.routeIslandMembershipExpandRounds == 0 then
            local clearOK, clearErr = setTradeRouteNativeSearch("")
            log(
                "ISLAND MEMBERSHIP SEARCH CLEAR"
                .. " | success=" .. tostring(clearOK)
                .. " | error=" .. tostring(clearErr or "")
            )
        end

        local expanded = expandCollapsedRouteGroups()
        self.routeIslandMembershipExpandRounds =
            self.routeIslandMembershipExpandRounds + 1

        if expanded > 0
            and self.routeIslandMembershipExpandRounds < 5
        then
            self.routeIslandMembershipTicks = 0
            return true
        end

        local popupVisible = false
        pcall(function()
            popupVisible = filter.IsPopupVisible == true
        end)

        if not popupVisible then
            local ok, result, opened =
                openIslandFilterPopup()
            if opened then
                self.routeIslandMembershipPopupOpened = true
            end
            log(
                "ISLAND MEMBERSHIP FILTER OPEN"
                .. " | success=" .. tostring(ok)
                .. " | result=" .. tostring(result or "")
            )
            if not ok then
                self.routeIslandMembershipFailures =
                    self.routeIslandMembershipFailures + 1
                return self:FinishIslandMembershipScan()
            end
            return true
        end

        local buttons, nativeSize =
            collectNativeIslandButtons()
        if #buttons < 1 then
            if self.routeIslandMembershipTicks < 8 then
                return true
            end
            self.routeIslandMembershipFailures =
                self.routeIslandMembershipFailures + 1
            log(
                "ISLAND MEMBERSHIP ABORT"
                .. " | reason=no-island-buttons"
                .. " | nativeSize=" .. tostring(nativeSize)
            )
            return self:FinishIslandMembershipScan()
        end

        clearSelectedIslandButtons(buttons)

        local queue = {}
        for _, island in ipairs(self.routeIslandNames or {}) do
            local key = tostring(island.key or "")
            if key ~= ""
                and self.routeIslandRoutes[key] == nil
            then
                queue[#queue + 1] = {
                    name = tostring(island.name or ""),
                    key = key,
                    arrayIndex = island.arrayIndex,
                }
            end
        end

        self.routeIslandMembershipQueue = queue
        self.routeIslandMembershipIndex = 1
        self.routeIslandMembershipTicks = 0

        log(
            "ISLAND MEMBERSHIP START"
            .. " | missingIslands=" .. tostring(#queue)
            .. " | totalIslands=" .. tostring(#(self.routeIslandNames or {}))
            .. " | scanUnit=native-island-filter"
            .. " | routeEditorsOpened=0"
        )

        if #queue == 0 then
            return self:FinishIslandMembershipScan()
        end

        self.routeIslandMembershipPhase = "select"
        return true
    end

    if self.routeIslandMembershipPhase == "select" then
        local current =
            self.routeIslandMembershipQueue[
                self.routeIslandMembershipIndex
            ]

        if current == nil then
            return self:FinishIslandMembershipScan()
        end

        local buttons = select(1, collectNativeIslandButtons())
        clearSelectedIslandButtons(buttons)

        local target = nil
        for _, rec in ipairs(buttons or {}) do
            if rec.arrayIndex == current.arrayIndex
                and rec.name == current.name
            then
                target = rec
                break
            end
        end
        if target == nil then
            for _, rec in ipairs(buttons or {}) do
                if rec.name == current.name then
                    target = rec
                    break
                end
            end
        end

        if target == nil then
            self.routeIslandMembershipFailures =
                self.routeIslandMembershipFailures + 1
            log(
                "ISLAND MEMBERSHIP SKIP"
                .. " | island=" .. tostring(current.name)
                .. " | reason=target-button-not-found"
            )
            self.routeIslandMembershipIndex =
                self.routeIslandMembershipIndex + 1
            self.routeIslandMembershipTicks = 0
            return true
        end

        local ok, result = pressIslandButton(target.button)
        if not ok then
            self.routeIslandMembershipFailures =
                self.routeIslandMembershipFailures + 1
            log(
                "ISLAND MEMBERSHIP SKIP"
                .. " | island=" .. tostring(current.name)
                .. " | reason=button-press-failed"
                .. " | result=" .. tostring(result or "")
            )
            self.routeIslandMembershipIndex =
                self.routeIslandMembershipIndex + 1
            self.routeIslandMembershipTicks = 0
            return true
        end

        self.routeIslandMembershipButton = target.button
        self.routeIslandMembershipPhase = "read"
        self.routeIslandMembershipTicks = 0

        log(
            "ISLAND MEMBERSHIP SELECT"
            .. " | n=" .. tostring(self.routeIslandMembershipIndex)
            .. "/" .. tostring(#self.routeIslandMembershipQueue)
            .. " | island=" .. tostring(current.name)
        )
        return true
    end

    if self.routeIslandMembershipPhase == "read" then
        local current =
            self.routeIslandMembershipQueue[
                self.routeIslandMembershipIndex
            ]

        if current == nil then
            return self:FinishIslandMembershipScan()
        end

        local selected =
            islandButtonSelected(
                self.routeIslandMembershipButton
            )
        local filtered = harvestRouteRows()
        local filteredCount = countRouteCache(filtered)
        local baselineCount = countRouteCache(self.routeCache)

        local settled = selected
            and (
                filteredCount < baselineCount
                or baselineCount <= 1
            )

        if not settled
            and self.routeIslandMembershipTicks < 8
        then
            return true
        end

        if not settled then
            self.routeIslandMembershipFailures =
                self.routeIslandMembershipFailures + 1
            log(
                "ISLAND MEMBERSHIP READ FAILED"
                .. " | island=" .. tostring(current.name)
                .. " | selected=" .. tostring(selected)
                .. " | filteredRoutes=" .. tostring(filteredCount)
                .. " | baselineRoutes=" .. tostring(baselineCount)
            )

            if selected then
                pressIslandButton(
                    self.routeIslandMembershipButton
                )
            end

            self.routeIslandMembershipButton = nil
            self.routeIslandMembershipPhase = "wait-clear"
            self.routeIslandMembershipTicks = 0
            return true
        end

        local routeIDs = {}
        for routeID, rec in pairs(filtered or {}) do
            if type(routeID) == "number"
                and routeID >= 0
            then
                routeIDs[#routeIDs + 1] = routeID

                if self.routeCache[routeID] == nil then
                    rec.groupName = tostring(
                        self.routeGroupCache[rec.folderID]
                        or ""
                    )
                    self.routeCache[routeID] = rec
                end
            end
        end
        table.sort(routeIDs)

        self.routeIslandRoutes[current.key] = {
            islandKey = current.key,
            islandName = current.name,
            routeIDs = routeIDs,
            routeCount = #routeIDs,
        }

        log(
            "ISLAND MEMBERSHIP READ"
            .. " | n=" .. tostring(self.routeIslandMembershipIndex)
            .. "/" .. tostring(#self.routeIslandMembershipQueue)
            .. " | island=" .. tostring(current.name)
            .. " | routes=" .. tostring(#routeIDs)
            .. " | readTicks=" .. tostring(self.routeIslandMembershipTicks)
        )

        if selected then
            pressIslandButton(
                self.routeIslandMembershipButton
            )
        end

        self.routeIslandMembershipButton = nil
        self.routeIslandMembershipPhase = "wait-clear"
        self.routeIslandMembershipTicks = 0
        return true
    end

    if self.routeIslandMembershipPhase == "wait-clear" then
        if self.routeIslandMembershipTicks < 1 then
            return true
        end

        self.routeIslandMembershipIndex =
            self.routeIslandMembershipIndex + 1
        self.routeIslandMembershipPhase = "select"
        self.routeIslandMembershipTicks = 0

        if self.routeIslandMembershipIndex >
            #self.routeIslandMembershipQueue
        then
            return self:FinishIslandMembershipScan()
        end

        return true
    end

    return true
end


local function nativeRouteSubMenuState()
    local overview = nil
    local subMenu = nil
    local buttons = nil
    local visible = nil
    local focusedIndex = nil

    pcall(function()
        overview =
            ui
            and ui.Scenes
            and ui.Scenes.TradeRoute
            and ui.Scenes.TradeRoute.TradeOverview
            or nil
    end)

    if overview ~= nil then
        pcall(function()
            subMenu = overview.SubMenuData
        end)
    end

    if subMenu ~= nil then
        pcall(function()
            visible = subMenu.IsVisible
        end)
        pcall(function()
            focusedIndex = subMenu.FocusedIndex
        end)
        pcall(function()
            buttons = subMenu.RouteSubMenuButtonData
        end)
    end

    return subMenu, buttons, visible, focusedIndex
end

local function firstNativeRouteSubMenuButton(buttons)
    if buttons == nil then
        return nil, nil, nil, "buttons-missing"
    end

    for i = 0, 15 do
        local ok, button = pcall(function()
            return buttons[i]
        end)

        if ok and button ~= nil
            and string.find(tostring(button), "weak null", 1, true) == nil
        then
            local text = ""
            local index = nil

            pcall(function()
                text = tostring(button.Text or "")
            end)
            pcall(function()
                index = button.Index
            end)

            return button, text, index, "ready"
        end
    end

    return nil, nil, nil, "no-submenu-button"
end

function RenameManager:TickTradeRouteEditReturn()
    if not self.tradeRouteNativePending then
        return false
    end

    self.tradeRouteNativeTicks =
        self.tradeRouteNativeTicks + 1

    local row = self.tradeRouteNativeRow
    local nameData = self.tradeRouteNativeNameData

    if row == nil or nameData == nil then
        log(
            "TRADE ROUTE NATIVE COMMAND ABORT"
            .. " | reason=target-object-missing"
        )
        self.tradeRouteNativePending = false
        return true
    end

    local selected = nil
    local enabled = nil
    local liveName = ""

    pcall(function()
        selected = row.SubMenuBtnIsSelected
    end)
    pcall(function()
        enabled = nameData.IsEnabled
    end)
    pcall(function()
        liveName = tostring(nameData.Text or "")
    end)

    local backendName, backendState =
        nativeLifecycleBackendName(
            self.tradeRouteNativeRouteID
        )

    if self.tradeRouteNativePhase == "select-row" then
        if self.tradeRouteNativeTicks == 1 then
            local openOK, openErr = pcall(function()
                return row:SubMenuButtonEvent()
            end)

            log(
                "TRADE ROUTE NATIVE MENU OPEN REQUEST"
                .. " | routeID="
                .. tostring(self.tradeRouteNativeRouteID)
                .. " | success="
                .. tostring(openOK)
                .. " | selected="
                .. tostring(selected)
                .. " | enabled="
                .. tostring(enabled)
                .. " | error="
                .. tostring(openErr or "")
            )

            if not openOK then
                self.tradeRouteNativePending = false
                return true
            end

            self.tradeRouteNativePhase = "wait-menu"
            self.tradeRouteNativeTicks = 0
            return true
        end

        return false
    end

    if self.tradeRouteNativePhase == "wait-menu" then
        local subMenu, buttons, visible, focusedIndex =
            nativeRouteSubMenuState()

        if visible == true and buttons ~= nil then
            local button, text, index, buttonState =
                firstNativeRouteSubMenuButton(buttons)

            log(
                "TRADE ROUTE NATIVE MENU READY"
                .. " | routeID="
                .. tostring(self.tradeRouteNativeRouteID)
                .. " | visible="
                .. tostring(visible)
                .. " | focusedIndex="
                .. tostring(focusedIndex)
                .. " | firstText="
                .. tostring(text)
                .. " | firstIndex="
                .. tostring(index)
                .. " | buttonState="
                .. tostring(buttonState)
            )

            if button == nil then
                self.tradeRouteNativePending = false
                return true
            end

            local invokeOK, invokeErr = pcall(function()
                return button:SubMenuButtonEvent()
            end)

            log(
                "TRADE ROUTE NATIVE RENAME COMMAND"
                .. " | routeID="
                .. tostring(self.tradeRouteNativeRouteID)
                .. " | buttonText="
                .. tostring(text)
                .. " | buttonIndex="
                .. tostring(index)
                .. " | success="
                .. tostring(invokeOK)
                .. " | error="
                .. tostring(invokeErr or "")
            )

            if not invokeOK then
                self.tradeRouteNativePending = false
                return true
            end

            self.tradeRouteNativePhase = "wait-editor"
            self.tradeRouteNativeTicks = 0
            return true
        end

        if self.tradeRouteNativeTicks >= 12 then
            log(
                "TRADE ROUTE NATIVE COMMAND ABORT"
                .. " | reason=submenu-not-visible"
                .. " | routeID="
                .. tostring(self.tradeRouteNativeRouteID)
                .. " | visible="
                .. tostring(visible)
            )
            self.tradeRouteNativePending = false
            return true
        end

        return false
    end

    if self.tradeRouteNativePhase == "wait-editor" then
        if enabled == true then
            log(
                "TRADE ROUTE NATIVE EDITOR ACTIVE"
                .. " | routeID="
                .. tostring(self.tradeRouteNativeRouteID)
                .. " | routeName="
                .. tostring(self.tradeRouteNativeInitialName)
                .. " | selected="
                .. tostring(selected)
                .. " | enabled=true"
                .. " | source=native-Rename-route-command"
            )

            self.tradeRouteNativePhase = "editing"
            self.tradeRouteNativeTicks = 0
            self.tradeRouteNativeSawEnabled = true
            return true
        end

        if self.tradeRouteNativeTicks >= 12 then
            log(
                "TRADE ROUTE NATIVE COMMAND ABORT"
                .. " | reason=native-rename-command-did-not-open-editor"
                .. " | routeID="
                .. tostring(self.tradeRouteNativeRouteID)
                .. " | enabled="
                .. tostring(enabled)
            )
            self.tradeRouteNativePending = false
            return true
        end

        return false
    end

    if self.tradeRouteNativePhase == "editing" then
        local initialName =
            tostring(self.tradeRouteNativeInitialName or "")

        local backendChanged =
            backendName ~= nil
            and tostring(backendName) ~= initialName

        -- PRIMARY COMMIT SIGNAL:
        -- We are now invoking Anno's real native "Rename route" command.
        -- Therefore an exact backend RouteID name change is a true completed
        -- native commit. This remains valid even if the filtered overview
        -- rebuilds the visible row and the stored NameData object becomes stale.
        if backendChanged then
            local committedName =
                tostring(backendName or liveName or "")

            log(
                "TRADE ROUTE BACKEND COMMIT DETECTED"
                .. " | routeID="
                .. tostring(self.tradeRouteNativeRouteID)
                .. " | initialName="
                .. tostring(initialName)
                .. " | liveName="
                .. tostring(liveName)
                .. " | backendName="
                .. tostring(backendName)
                .. " | selected="
                .. tostring(selected)
                .. " | enabled="
                .. tostring(enabled)
                .. " | backendState="
                .. tostring(backendState)
                .. " | rowMayHaveRebuilt="
                .. tostring(enabled == nil)
            )

            self.tradeRouteNativePending = false

            local closeOK, closeErr = pcall(function()
                Scripts:PopUI()
            end)

            if self.routeCache[self.tradeRouteNativeRouteID] ~= nil then
                self.routeCache[self.tradeRouteNativeRouteID].name =
                    committedName
            end

            if closeOK then
                self.resumeMode =
                    self.routeTargetSourceMode or "trade_routes"
                self.resumeIslandName = tostring(
                    self.routeTargetSourceIslandName or ""
                )
                self.resumeIslandKey = tostring(
                    self.routeTargetSourceIslandKey or ""
                )
                self.resumeGoodName = tostring(
                    self.routeTargetSourceGoodName or ""
                )
                self.resumeGoodKey = tostring(
                    self.routeTargetSourceGoodKey or ""
                )
                self.resumePending = true
                self.resumeTicks = 3
            end

            log(
                "TRADE ROUTE NATIVE COMMAND FINISHED"
                .. " | routeID="
                .. tostring(self.tradeRouteNativeRouteID)
                .. " | initialName="
                .. tostring(initialName)
                .. " | liveName="
                .. tostring(liveName)
                .. " | backendName="
                .. tostring(backendName)
                .. " | backendChanged=true"
                .. " | committed=true"
                .. " | completionSignal=backend-RouteID-name-change"
                .. " | enabled="
                .. tostring(enabled)
                .. " | backendState="
                .. tostring(backendState)
            )

            log(
                "TRADE ROUTE NATIVE COMMAND RETURN PREPARE"
                .. " | closeTradeRouteSuccess="
                .. tostring(closeOK)
                .. " | resumePending="
                .. tostring(self.resumePending)
                .. " | returnTarget=" .. tostring(self.resumeMode)
                .. " | returnIsland=" .. tostring(self.resumeIslandName or "")
                .. " | returnGood=" .. tostring(self.resumeGoodName or "")
                .. " | delayTicks="
                .. tostring(self.resumeTicks)
                .. " | error="
                .. tostring(closeErr or "")
            )

            return true
        end

        -- SECONDARY SIGNAL:
        -- If Anno closes the native editor without changing the name, the
        -- original visible-row IsEnabled=false lifecycle still returns safely.
        if self.tradeRouteNativeSawEnabled and enabled == false then
            log(
                "TRADE ROUTE NATIVE COMMAND FINISHED"
                .. " | routeID="
                .. tostring(self.tradeRouteNativeRouteID)
                .. " | initialName="
                .. tostring(initialName)
                .. " | liveName="
                .. tostring(liveName)
                .. " | backendName="
                .. tostring(backendName)
                .. " | backendChanged=false"
                .. " | committed="
                .. tostring(
                    backendName ~= nil
                    and tostring(liveName) == tostring(backendName)
                )
                .. " | completionSignal=NameData-IsEnabled-false"
                .. " | selected="
                .. tostring(selected)
                .. " | enabled=false"
                .. " | backendState="
                .. tostring(backendState)
            )

            self.tradeRouteNativePending = false

            local closeOK, closeErr = pcall(function()
                Scripts:PopUI()
            end)

            if closeOK then
                self.resumeMode =
                    self.routeTargetSourceMode or "trade_routes"
                self.resumeIslandName = tostring(
                    self.routeTargetSourceIslandName or ""
                )
                self.resumeIslandKey = tostring(
                    self.routeTargetSourceIslandKey or ""
                )
                self.resumeGoodName = tostring(
                    self.routeTargetSourceGoodName or ""
                )
                self.resumeGoodKey = tostring(
                    self.routeTargetSourceGoodKey or ""
                )
                self.resumePending = true
                self.resumeTicks = 3
            end

            log(
                "TRADE ROUTE NATIVE COMMAND RETURN PREPARE"
                .. " | closeTradeRouteSuccess="
                .. tostring(closeOK)
                .. " | resumePending="
                .. tostring(self.resumePending)
                .. " | returnTarget=" .. tostring(self.resumeMode)
                .. " | returnIsland=" .. tostring(self.resumeIslandName or "")
                .. " | returnGood=" .. tostring(self.resumeGoodName or "")
                .. " | delayTicks="
                .. tostring(self.resumeTicks)
                .. " | error="
                .. tostring(closeErr or "")
            )

            return true
        end

        if enabled == true then
            if self.tradeRouteNativeTicks == 2
                or self.tradeRouteNativeTicks == 6
                or self.tradeRouteNativeTicks == 12
            then
                log(
                    "TRADE ROUTE NATIVE COMMAND EDITING"
                    .. " | routeID="
                    .. tostring(self.tradeRouteNativeRouteID)
                    .. " | liveName="
                    .. tostring(liveName)
                    .. " | backendName="
                    .. tostring(backendName)
                    .. " | selected="
                    .. tostring(selected)
                    .. " | enabled=true"
                    .. " | backendState="
                    .. tostring(backendState)
                )
            end
            return false
        end

        -- If the visible row was rebuilt, enabled can become nil. Keep watching
        -- the backend instead of getting stuck silently.
        if enabled == nil
            and (
                self.tradeRouteNativeTicks == 2
                or self.tradeRouteNativeTicks == 6
                or self.tradeRouteNativeTicks == 12
                or self.tradeRouteNativeTicks % 20 == 0
            )
        then
            log(
                "TRADE ROUTE NATIVE COMMAND ROW REBUILT WATCH"
                .. " | routeID="
                .. tostring(self.tradeRouteNativeRouteID)
                .. " | backendName="
                .. tostring(backendName)
                .. " | initialName="
                .. tostring(initialName)
                .. " | enabled=nil"
                .. " | backendState="
                .. tostring(backendState)
            )
        end

        if self.tradeRouteNativeTicks >= 240 then
            log(
                "TRADE ROUTE NATIVE COMMAND ABORT"
                .. " | reason=no-native-completion-detected"
                .. " | routeID="
                .. tostring(self.tradeRouteNativeRouteID)
                .. " | liveName="
                .. tostring(liveName)
                .. " | backendName="
                .. tostring(backendName)
                .. " | selected="
                .. tostring(selected)
                .. " | enabled="
                .. tostring(enabled)
            )
            self.tradeRouteNativePending = false
            return true
        end
    end

    return false
end

function RenameManager:TickTradeRouteOverview()
    if not self.tradeOverviewPending then
        return false
    end

    self.tradeOverviewTicks =
        self.tradeOverviewTicks + 1

    local scene, overview, array, panelOpen, rows =
        tradeOverviewState()

    if overview == nil then
        if self.tradeOverviewTicks >= 40 then
            log(
                "TRADE ROUTE OVERVIEW TIMEOUT"
                .. " | purpose="
                .. tostring(
                    self.routeHarvestPending and "harvest"
                    or self.routeTargetFromParchment and "target"
                    or "direct"
                )
                .. " | rows=" .. tostring(rows)
                .. " | IsPanelOpen=" .. tostring(panelOpen)
            )
            self.tradeOverviewPending = false
            self.routeHarvestPending = false
            self.routeTargetFromParchment = false
            return true
        end
        return false
    end

    -- Island filtering can legitimately produce zero route rows, so it must run
    -- before the generic rows<=0 guard.
    if self.routeIslandEnumPending then
        return self:TickIslandEnumeration()
    end
    if self.routeIslandFilterPending then
        return self:TickIslandRouteFilter()
    end
    if self.routeIslandMembershipPending then
        return self:TickIslandMembershipScan()
    end

    if rows <= 0 then
        if self.tradeOverviewTicks >= 40 then
            log(
                "TRADE ROUTE OVERVIEW TIMEOUT"
                .. " | purpose=rows-empty"
                .. " | rows=" .. tostring(rows)
                .. " | IsPanelOpen=" .. tostring(panelOpen)
            )
            self.tradeOverviewPending = false
            self.routeHarvestPending = false
            self.routeTargetFromParchment = false
            return true
        end
        return false
    end

    if self.tradeOverviewTicks < 2 then
        return false
    end

    -- Phase A: build parchment source from the actual native overview.
    if self.routeHarvestPending then
        if self.routeHarvestExpandRounds == 0 then
            local clearOK, clearErr =
                setTradeRouteNativeSearch("")
            log(
                "TRADE ROUTE HARVEST SEARCH CLEAR"
                .. " | success=" .. tostring(clearOK)
                .. " | error=" .. tostring(clearErr or "")
            )
        end

        local expanded = expandCollapsedRouteGroups()
        self.routeHarvestExpandRounds =
            self.routeHarvestExpandRounds + 1

        log(
            "TRADE ROUTE HARVEST EXPAND"
            .. " | round=" .. tostring(self.routeHarvestExpandRounds)
            .. " | expanded=" .. tostring(expanded)
            .. " | rows=" .. tostring(rows)
        )

        if expanded > 0
            and self.routeHarvestExpandRounds < 6
        then
            self.tradeOverviewTicks = 0
            return true
        end

        self.routeGroupCache =
            harvestRouteGroups()
        self.routeCache = harvestRouteRows()

        for _, routeRec in pairs(self.routeCache) do
            if routeRec ~= nil
                and routeRec.folderID ~= nil
            then
                routeRec.groupName =
                    tostring(
                        self.routeGroupCache[
                            routeRec.folderID
                        ]
                        or ""
                    )
            end
        end

        local count = 0
        for _ in pairs(self.routeCache) do
            count = count + 1
        end

        local groupCount = 0
        for _ in pairs(self.routeGroupCache or {}) do
            groupCount = groupCount + 1
        end

        log(
            "TRADE ROUTE HARVEST COMPLETE"
            .. " | routes=" .. tostring(count)
            .. " | groups=" .. tostring(groupCount)
            .. " | context=ship-names+native-count+group"
            .. " | expandRounds="
            .. tostring(self.routeHarvestExpandRounds)
        )

        local harvestedSignature = routeIDTopologySignature(self.routeCache)

        -- TradeRouteItems are already available on these overview rows, so
        -- every ordinary route harvest cheaply refreshes the goods cache.
        self:RefreshGoodsCacheFromRouteCache(
            "route-overview-harvest"
        )

        if self.routeIslandIndexValid
            and self.routeIslandTopologySignature ~= ""
            and harvestedSignature ~= self.routeIslandTopologySignature
        then
            self:InvalidateIslandCache("route-id-set-changed-after-harvest")
        end

        self.routeHarvestPending = false

        if self.routeHarvestReturnMode == "island_index_enum" then
            log(
                "TRADE ROUTE HARVEST HANDOFF"
                .. " | mode=island_index_enum"
                .. " | action=enumerate-native-island-buttons"
            )
            return self:BeginIslandEnumeration()
        end

        self.tradeOverviewPending = false

        local closeOK, closeErr = pcall(function()
            local trScene =
                ui and ui.Scenes and ui.Scenes.TradeRoute or nil
            if trScene and trScene.CloseTradeRouteScene then
                return trScene:CloseTradeRouteScene()
            end
            return Scripts:ToggleTraderouteMenu()
        end)

        log(
            "TRADE ROUTE HARVEST CLOSE"
            .. " | success=" .. tostring(closeOK)
            .. " | error=" .. tostring(closeErr or "")
        )

        if closeOK then
            self.resumeMode =
                self.routeHarvestReturnMode or "trade_routes"
            self.resumePage = 0
            self.resumePending = true
            self.resumeTicks = 2

            log(
                "TRADE ROUTE HARVEST RETURN ARMED"
                .. " | mode=" .. tostring(self.resumeMode)
                .. " | page=1"
            )

            self.routeHarvestReturnMode = "trade_routes"
        end

        return true
    end

    -- Phase B: parchment selected an exact RouteID. Expand native groups until
    -- that exact row exists, then hand it to the proven v0.5.3 rename command.
    if self.routeTargetFromParchment then
        -- The harvest already expanded all groups. If the reopened overview
        -- contains the full model, do not repeat an empty expansion pass.
        if self.routeTargetExpandRounds < 1 then
            local expanded = 0

            if rows < 20 then
                expanded = expandCollapsedRouteGroups()
            end

            self.routeTargetExpandRounds =
                self.routeTargetExpandRounds + 1

            log(
                "TRADE ROUTE TARGET PREPARE"
                .. " | routeID=" .. tostring(self.routeTargetID)
                .. " | routeName=" .. tostring(self.routeTargetName)
                .. " | expanded=" .. tostring(expanded)
                .. " | rows=" .. tostring(rows)
                .. " | fastSkipExpand="
                .. tostring(rows >= 20)
            )

            if expanded > 0 then
                self.tradeOverviewTicks = 0
                return true
            end
        end

        if not self.routeTargetSearchApplied then
            local query =
                routeSearchQuery(self.routeTargetName)

            local searchOK, searchErr, beforeText, afterText =
                setTradeRouteNativeSearch(query)

            self.routeTargetSearchApplied = true
            self.routeTargetSearchTicks = 0
            self.routeTargetSearchAttempt = 1
            self.routeTargetSearchQuery = query

            log(
                "TRADE ROUTE TARGET SEARCH"
                .. " | routeID=" .. tostring(self.routeTargetID)
                .. " | routeName=" .. tostring(self.routeTargetName)
                .. " | query=" .. tostring(query)
                .. " | strategy=single-first-word"
                .. " | success=" .. tostring(searchOK)
                .. " | before=" .. tostring(beforeText)
                .. " | after=" .. tostring(afterText)
                .. " | error=" .. tostring(searchErr or "")
            )

            return true
        end

        self.routeTargetSearchTicks =
            self.routeTargetSearchTicks + 1

        local row, nameData, routeName =
            findExactRouteRow(self.routeTargetID)

        if row == nil then
            -- v0.6.1's successful broad search materialized the target after
            -- one rebuild tick. Allow a few ticks for slower machines, but do
            -- not launch additional searches that surprise the player.
            if self.routeTargetSearchTicks < 4 then
                return false
            end

            log(
                "TRADE ROUTE TARGET ABORT"
                .. " | reason=exact-RouteID-not-visible-after-single-search"
                .. " | routeID=" .. tostring(self.routeTargetID)
                .. " | routeName=" .. tostring(self.routeTargetName)
                .. " | query="
                .. tostring(self.routeTargetSearchQuery)
            )
            self.tradeOverviewPending = false
            self.routeTargetFromParchment = false
            return true
        end

        self.tradeOverviewPending = false
        self.routeTargetFromParchment = false

        self.tradeRouteNativePending = true
        self.tradeRouteNativePhase = "select-row"
        self.tradeRouteNativeTicks = 0
        self.tradeRouteNativeRow = row
        self.tradeRouteNativeNameData = nameData
        self.tradeRouteNativeRouteID = self.routeTargetID
        self.tradeRouteNativeInitialName =
            routeName ~= "" and routeName or self.routeTargetName
        self.tradeRouteNativeSawEnabled = false

        log(
            "TRADE ROUTE TARGET VISIBLE"
            .. " | routeID=" .. tostring(self.routeTargetID)
            .. " | parchmentName=" .. tostring(self.routeTargetName)
            .. " | visibleName=" .. tostring(routeName)
            .. " | searchQuery="
            .. tostring(self.routeTargetSearchQuery)
            .. " | searchTicks="
            .. tostring(self.routeTargetSearchTicks)
            .. " | action=native-context-menu-rename"
        )

        return true
    end

    -- Direct fallback: retain v0.5.3 first-visible behavior.
    if self.tradeOverviewTicks < 4 then
        return false
    end

    local row, nameData, routeID, routeName, state =
        firstNativeLifecycleRoute(array)

    if row == nil or nameData == nil then
        log(
            "TRADE ROUTE NATIVE ABORT"
            .. " | reason=" .. tostring(state)
            .. " | rows=" .. tostring(rows)
        )
        self.tradeOverviewPending = false
        return true
    end

    self.tradeOverviewPending = false
    self.tradeRouteNativePending = true
    self.tradeRouteNativePhase = "select-row"
    self.tradeRouteNativeTicks = 0
    self.tradeRouteNativeRow = row
    self.tradeRouteNativeNameData = nameData
    self.tradeRouteNativeRouteID = routeID
    self.tradeRouteNativeInitialName = routeName
    self.tradeRouteNativeSawEnabled = false

    return true
end

function RenameManager:TickSignal()
    local signal = signalValue()
    if self.observedSignal == nil then
        self.observedSignal = signal
    end

    local oldSignal = tonumber(self.observedSignal) or 0
    local delta = signal - oldSignal

    if delta < 1000 then
        if signal ~= oldSignal then self.observedSignal = signal end
        return false
    end

    self.observedSignal = signal

    local reportNumber = math.floor(delta / 1000)

    if reportNumber == 8 then
        log(
            "CATEGORY SIGNAL"
            .. " | old=" .. tostring(oldSignal)
            .. " | new=" .. tostring(signal)
            .. " | delta=" .. tostring(delta)
            .. " | mode=ships_submenu"
        )
        self:OpenShipsMenu()
        return true
    elseif reportNumber == 10 then
        log(
            "CATEGORY SIGNAL"
            .. " | old=" .. tostring(oldSignal)
            .. " | new=" .. tostring(signal)
            .. " | delta=" .. tostring(delta)
            .. " | mode=trade_routes_submenu"
        )
        self:OpenTradeRoutesMenu()
        return true
    elseif reportNumber == 9 then
        log(
            "CATEGORY SIGNAL"
            .. " | old=" .. tostring(oldSignal)
            .. " | new=" .. tostring(signal)
            .. " | delta=" .. tostring(delta)
            .. " | mode=back_to_main"
        )
        self:Open()
        return true
    end

    if reportNumber == 5 then
        self.routeHarvestReturnMode = "trade_routes"
        log(
            "CATEGORY SIGNAL"
            .. " | old=" .. tostring(oldSignal)
            .. " | new=" .. tostring(signal)
            .. " | delta=" .. tostring(delta)
            .. " | mode=trade_routes"
            .. " | action=harvest-native-overview-then-parchment"
        )
        self:OpenNativeTradeRouteOverview("harvest")
        return true
    elseif reportNumber == 11 then
        self.routeHarvestReturnMode = "trade_routes_by_group"
        log(
            "CATEGORY SIGNAL"
            .. " | old=" .. tostring(oldSignal)
            .. " | new=" .. tostring(signal)
            .. " | delta=" .. tostring(delta)
            .. " | mode=trade_routes_by_group"
            .. " | action=harvest-native-overview-then-grouped-naming-view"
        )
        self:OpenNativeTradeRouteOverview("harvest")
        return true
    elseif reportNumber == 12 then
        local usable, reason = self:IslandCacheUsable()
        log(
            "CATEGORY SIGNAL"
            .. " | old=" .. tostring(oldSignal)
            .. " | new=" .. tostring(signal)
            .. " | delta=" .. tostring(delta)
            .. " | mode=island_index"
            .. " | cacheUsable=" .. tostring(usable)
            .. " | cacheReason=" .. tostring(reason)
        )

        if usable then
            self.report.islandName = ""
            self.report.islandKey = ""
            self:OpenReport("island_index", "island-cache-hit")
        else
            if reason ~= "index-invalid" then
                self:InvalidateIslandCache(reason)
            end
            self.routeHarvestReturnMode = "island_index_enum"
            self:OpenNativeTradeRouteOverview("harvest")
        end
        return true
    elseif reportNumber == 13 then
        self:InvalidateIslandCache("combined-manual-rescan")
        self:InvalidateGoodsCache("combined-manual-rescan")
        self.routeHarvestReturnMode = "island_index_enum"

        log(
            "CATEGORY SIGNAL"
            .. " | old=" .. tostring(oldSignal)
            .. " | new=" .. tostring(signal)
            .. " | delta=" .. tostring(delta)
            .. " | mode=rescan_islands_and_goods"
            .. " | action=clear-both-caches+one-route-harvest+refresh-island-index"
            .. " | goodsRefresh=piggyback-on-route-harvest"
            .. " | islandTopology=lazy-on-next-island-open"
        )

        self:OpenNativeTradeRouteOverview("harvest")
        return true
    elseif reportNumber == 14 then
        local usable, reason =
            self:GoodsCacheUsable()

        log(
            "CATEGORY SIGNAL"
            .. " | old=" .. tostring(oldSignal)
            .. " | new=" .. tostring(signal)
            .. " | delta=" .. tostring(delta)
            .. " | mode=goods_index"
            .. " | cacheUsable=" .. tostring(usable)
            .. " | cacheReason=" .. tostring(reason)
        )

        if usable then
            self.report.goodName = ""
            self.report.goodKey = ""
            self:OpenReport(
                "goods_index",
                "goods-cache-hit"
            )
        else
            if reason ~= "index-invalid" then
                self:InvalidateGoodsCache(reason)
            end

            self.routeHarvestReturnMode =
                "goods_index"

            self:OpenNativeTradeRouteOverview(
                "harvest"
            )
        end

        return true

    end

    local mode = nil
    if reportNumber == 1 then
        mode = "all"
    elseif reportNumber == 2 then
        mode = "routes"
    elseif reportNumber == 3 then
        mode = "independent"
    elseif reportNumber == 4 then
        mode = "warships"
    end

    if mode == nil then
        log(
            "CATEGORY SIGNAL ABORT"
            .. " | old=" .. tostring(oldSignal)
            .. " | new=" .. tostring(signal)
            .. " | delta=" .. tostring(delta)
        )
        return false
    end

    local records = self:Records(mode)
    local pages = math.max(1, math.ceil(#records / 9))
    if pages > 12 then pages = 12 end

    self.report.mode = mode
    self.report.page = 0
    self.report.visible = {}
    self.report.active = false
    self.report.opening = true

    local storyline = PAGE_STORY_BASE + pages
    local ok, err = pcall(function()
        GovernorDecision:CheatStartGovernorDecisionForCurrentPlayerNet(
            storyline
        )
    end)

    log(
        "CATEGORY SIGNAL"
        .. " | old=" .. tostring(oldSignal)
        .. " | new=" .. tostring(signal)
        .. " | delta=" .. tostring(delta)
        .. " | mode=" .. tostring(mode)
        .. " | records=" .. tostring(#records)
        .. " | pages=" .. tostring(pages)
        .. " | storyline=" .. tostring(storyline)
        .. " | success=" .. tostring(ok)
        .. " | error=" .. tostring(err or "")
    )

    if not ok then
        self.report.opening = false
    end

    return true
end

function RenameManager:ResolveFresh(record)
    if record == nil then return nil end

    for _, object in pairs(
        Scripts:GetObjectGroupByProperty(Properties.ShipModuleOwner) or {}
    ) do
        if isOwned(object) then
            local objectID = nil
            pcall(function() objectID = object.ID end)
            if objectID ~= nil
                and tostring(objectID) == tostring(record.id)
            then
                return object
            end
        end
    end

    return nil
end

function RenameManager:ResolveByID(targetID)
    if targetID == nil then return nil end

    for _, object in pairs(
        Scripts:GetObjectGroupByProperty(Properties.ShipModuleOwner) or {}
    ) do
        if isOwned(object) then
            local objectID = nil
            pcall(function() objectID = object.ID end)
            if objectID ~= nil
                and tostring(objectID) == tostring(targetID)
            then
                return object
            end
        end
    end

    return nil
end

function RenameManager:OpenReport(mode, reason)
    mode = mode or "all"
    local records = self:ReportRecords(mode)
    local pages = math.max(1, math.ceil(#records / 9))
    if pages > 12 then pages = 12 end

    self.report.mode = mode
    self.report.page = 0
    self.report.visible = {}
    self.report.active = false
    self.report.opening = true

    local storyline = PAGE_STORY_BASE + pages
    local ok, err = pcall(function()
        GovernorDecision:CheatStartGovernorDecisionForCurrentPlayerNet(
            storyline
        )
    end)

    log(
        "REPORT OPEN"
        .. " | reason=" .. tostring(reason or "direct")
        .. " | mode=" .. tostring(mode)
        .. " | island=" .. tostring(self.report.islandName or "")
        .. " | good=" .. tostring(self.report.goodName or "")
        .. " | records=" .. tostring(#records)
        .. " | pages=" .. tostring(pages)
        .. " | storyline=" .. tostring(storyline)
        .. " | success=" .. tostring(ok)
        .. " | error=" .. tostring(err or "")
    )

    if not ok then
        self.report.opening = false
    end

    return ok
end

function RenameManager:ParchmentShortcut(slot)
    slot = tonumber(slot) or 0
    if slot < 1 or slot > 9 then return false end
    if not self:IsReportOpen() then return false end

    local record = self.report.visible[slot]
    if record == nil then
        log(
            "SHIP SLOT EMPTY"
            .. " | mode=" .. tostring(self.report.mode or "")
            .. " | page=" .. tostring((self.report.page or 0) + 1)
            .. " | slot=" .. tostring(slot)
        )
        return false
    end

    if record.kind == "good" then
        local goodName =
            tostring(record.name or "")
        local goodKey =
            tostring(record.goodKey or "")

        self.resumeGoodName = goodName
        self.resumeGoodKey = goodKey

        local closeOK, closeErr =
            pcall(function()
                Scripts:PopUI()
            end)

        self.report.active = false
        self.report.opening = false
        self.report.visible = {}

        if closeOK then
            self.report.goodName = goodName
            self.report.goodKey = goodKey

            self.resumeMode =
                "trade_routes_for_good"
            self.resumePage = 0
            self.resumePending = true
            self.resumeTicks = 2
        end

        log(
            "GOODS PARCHMENT SELECT"
            .. " | good=" .. goodName
            .. " | key=" .. goodKey
            .. " | routes="
            .. tostring(
                self.routeGoodsRoutes[goodKey]
                and self.routeGoodsRoutes[goodKey].routeCount
                or 0
            )
            .. " | cache=true"
            .. " | closeSuccess=" .. tostring(closeOK)
            .. " | action=open-route-parchment"
            .. " | error=" .. tostring(closeErr or "")
        )

        return closeOK
    end

    if record.kind == "island" then
        local islandName = tostring(record.name or "")
        local islandKey = tostring(record.islandKey or "")
        local cached = self.routeIslandRoutes[islandKey]

        self.resumeIslandName = islandName
        self.resumeIslandKey = islandKey
        self.routeIslandTargetName = islandName
        self.routeIslandTargetKey = islandKey
        self.routeIslandTargetArrayIndex = record.arrayIndex

        local closeOK, closeErr = pcall(function()
            Scripts:PopUI()
        end)

        self.report.active = false
        self.report.opening = false
        self.report.visible = {}

        if not closeOK then
            log(
                "ISLAND PARCHMENT SELECT ABORT"
                .. " | island=" .. islandName
                .. " | error=" .. tostring(closeErr or "")
            )
            return false
        end

        if cached ~= nil
            and self.routeIslandMembershipComplete
        then
            self.resumeMode = "trade_routes_for_island"
            self.resumePage = 0
            self.resumePending = true
            self.resumeTicks = 2

            log(
                "ISLAND PARCHMENT SELECT"
                .. " | island=" .. islandName
                .. " | key=" .. islandKey
                .. " | cache=full-topology-hit"
                .. " | routes=" .. tostring(cached.routeCount or 0)
                .. " | action=open-sorted-route-parchment"
            )
            return true
        end

        -- Sorting by "the other island(s)" requires reverse membership for
        -- the other native island filters. Build only missing island caches,
        -- all in one overview session; no route editor is opened.
        local openOK =
            self:OpenNativeTradeRouteOverview(
                "island_membership"
            )

        log(
            "ISLAND PARCHMENT SELECT"
            .. " | island=" .. islandName
            .. " | key=" .. islandKey
            .. " | cache="
            .. (
                cached ~= nil
                and "partial-topology"
                or "miss"
            )
            .. " | action=build-missing-island-membership-cache"
            .. " | scanUnit=island-filter-not-route"
            .. " | openSuccess=" .. tostring(openOK)
        )

        return openOK
    end

    if self.report.mode == "trade_routes"
        or self.report.mode == "trade_routes_by_group"
        or self.report.mode == "trade_routes_for_island"
        or self.report.mode == "trade_routes_for_good"
        or record.kind == "trade_route"
    then
        self.resumeMode =
            self.report.mode or record.sourceMode or "trade_routes"
        self.resumePage = self.report.page or 0
        self.resumeIslandName = tostring(
            record.islandName or self.report.islandName or ""
        )
        self.resumeIslandKey = tostring(
            record.islandKey or self.report.islandKey or ""
        )
        self.resumeGoodName = tostring(
            record.goodName or self.report.goodName or ""
        )
        self.resumeGoodKey = tostring(
            record.goodKey or self.report.goodKey or ""
        )
        self.routeTargetSourceMode = self.resumeMode
        self.routeTargetSourceIslandName = self.resumeIslandName
        self.routeTargetSourceIslandKey = self.resumeIslandKey
        self.routeTargetSourceGoodName = self.resumeGoodName
        self.routeTargetSourceGoodKey = self.resumeGoodKey
        self.resumePending = false
        self.resumeTicks = 0

        self.routeTargetID = record.routeID
        self.routeTargetName = tostring(record.name or "")
        self.routeTargetFromParchment = true
        self.routeTargetExpandRounds = 0
        self.routeTargetSearchApplied = false
        self.routeTargetSearchTicks = 0
        self.routeTargetSearchAttempt = 0
        self.routeTargetSearchQuery = ""

        local closeOK, closeError = pcall(function()
            Scripts:PopUI()
        end)

        self.report.active = false
        self.report.opening = false
        self.report.visible = {}

        local openOK = false
        if closeOK then
            openOK = self:OpenNativeTradeRouteOverview("target")
        end

        log(
            "TRADE ROUTE PARCHMENT SELECT"
            .. " | page="
            .. tostring((self.resumePage or 0) + 1)
            .. " | slot=" .. tostring(slot)
            .. " | routeID=" .. tostring(record.routeID)
            .. " | routeName=" .. tostring(record.name)
            .. " | sourceMode=" .. tostring(self.resumeMode)
            .. " | closeParchmentSuccess="
            .. tostring(closeOK)
            .. " | openOverviewSuccess="
            .. tostring(openOK)
            .. " | error=" .. tostring(closeError or "")
        )

        return closeOK and openOK
    end

    local fresh = self:ResolveFresh(record)
    if fresh == nil then
        log(
            "SHIP UNAVAILABLE"
            .. " | slot=" .. tostring(slot)
            .. " | name=" .. tostring(record.name)
            .. " | objectID=" .. tostring(record.id)
        )
        return false
    end

    local nativeID = fresh.ID

    -- Preserve the user's category/page context before leaving the parchment.
    -- v0.2.2 safely restores the same category automatically. Native TextPopup
    -- current-page control is not yet proven, so page restoration is logged and
    -- intentionally falls back to page 1 after the rename.
    self.resumeMode = self.report.mode
    self.resumePage = self.report.page or 0
    self.resumePending = false
    self.resumeTicks = 0
    self.renameMonitoring = false
    self.renameMonitorTicks = 0

    local closeOK, closeError = pcall(function()
        Scripts:PopUI()
    end)
    local selectOK, selectError = pcall(function()
        Selection:SelectByID(nativeID)
    end)
    local jumpOK, jumpError = pcall(function()
        Scripts:JumpToObject(nativeID)
    end)

    self.report.active = false
    self.report.opening = false
    self.report.visible = {}

    if closeOK and selectOK and jumpOK then
        self.renamePending = true
        self.renameTargetID = nativeID
        self.renameTargetIDText = tostring(nativeID)
        self.renameTargetName = readName(fresh)
        self.omReadyTicks = 0
        self.renameAttempts = 0
        self.ticksSinceRenameAttempt = 0
    end

    log(
        "SHIP SELECT"
        .. " | mode=" .. tostring(self.report.mode or "")
        .. " | page=" .. tostring((self.report.page or 0) + 1)
        .. " | slot=" .. tostring(slot)
        .. " | name=" .. tostring(record.name)
        .. " | objectID=" .. tostring(nativeID)
        .. " | closeSuccess=" .. tostring(closeOK)
        .. " | selectSuccess=" .. tostring(selectOK)
        .. " | jumpSuccess=" .. tostring(jumpOK)
        .. " | renameArmed=" .. tostring(self.renamePending)
        .. " | closeError=" .. tostring(closeError or "")
        .. " | selectError=" .. tostring(selectError or "")
        .. " | jumpError=" .. tostring(jumpError or "")
    )

    return closeOK and selectOK and jumpOK
end

function RenameManager:BackToMenu()
    if not self:IsReportOpen() then return false end

    local mode = tostring(self.report.mode or "")
    local islandName = tostring(self.report.islandName or "")
    local closeOK, closeError = pcall(function()
        Scripts:PopUI()
    end)

    self.report.active = false
    self.report.opening = false
    self.report.visible = {}

    if closeOK then
        if mode == "trade_routes_for_island" then
            self.resumeMode = "island_index"
            self.resumePage = 0
            self.resumeIslandName = ""
            self.resumeIslandKey = ""
            self.resumePending = true
            self.resumeTicks = 2
        elseif mode == "trade_routes_for_good" then
            self.resumeMode = "goods_index"
            self.resumePage = 0
            self.resumeGoodName = ""
            self.resumeGoodKey = ""
            self.resumePending = true
            self.resumeTicks = 2
        else
            self.returnMainPending = true
            self.returnMainTicks = 2
            self.returnMenuTarget =
                (
                    mode == "island_index"
                    or mode == "goods_index"
                )
                and "trade_routes"
                or "main"
        end
    end

    log(
        "BACK TO MENU"
        .. " | fromMode=" .. mode
        .. " | island=" .. islandName
        .. " | closeSuccess=" .. tostring(closeOK)
        .. " | next="
        .. (
            mode == "trade_routes_for_island"
            and "island_index"
            or mode == "trade_routes_for_good"
            and "goods_index"
            or tostring(self.returnMenuTarget)
        )
        .. " | delayTicks="
        .. tostring(
            (
                mode == "trade_routes_for_island"
                or mode == "trade_routes_for_good"
            )
            and self.resumeTicks
            or self.returnMainTicks
        )
        .. " | error=" .. tostring(closeError or "")
    )

    return closeOK
end

local function nativeRenameInput()
    local scene = ui and ui.Scenes and ui.Scenes.OMShipUnit or nil
    if scene == nil then return nil, "scene-missing" end

    local visible = nil
    pcall(function() visible = scene.IsVisible end)
    if visible == false then return nil, "scene-not-visible" end

    local input = nil
    local ok, err = pcall(function()
        input =
            scene.SceneData
            .OMBaseData
            .HeaderData
            .RenamableHeadline
    end)

    if not ok or input == nil then
        return nil, "rename-input-missing:" .. tostring(err or "")
    end

    return input, "ready"
end

function RenameManager:TickRename()
    if not self.renamePending then return false end

    local input, inputState = nativeRenameInput()

    if input ~= nil then
        self.omReadyTicks = self.omReadyTicks + 1
    else
        self.omReadyTicks = 0
        return false
    end

    local canAttempt =
        self.omReadyTicks >= OM_STABLE_TICKS
        and self.renameAttempts < RENAME_MAX_ATTEMPTS
        and (
            self.renameAttempts == 0
            or self.ticksSinceRenameAttempt >= RENAME_RETRY_INTERVAL_TICKS
        )

    if canAttempt then
        self.renameAttempts = self.renameAttempts + 1
        self.ticksSinceRenameAttempt = 0

        local activeBefore = nil
        pcall(function() activeBefore = input.TextInputIsActive end)

        local ok, err = pcall(function()
            input:RequestActivation()
        end)

        local activeAfter = nil
        pcall(function() activeAfter = input.TextInputIsActive end)

        log(
            "RENAME INPUT REQUEST"
            .. " | attempt=" .. tostring(self.renameAttempts)
            .. " | objectID=" .. tostring(self.renameTargetIDText)
            .. " | name=" .. tostring(self.renameTargetName)
            .. " | omReadyTicks=" .. tostring(self.omReadyTicks)
            .. " | activeBefore=" .. tostring(activeBefore)
            .. " | requestSuccess=" .. tostring(ok)
            .. " | activeAfter=" .. tostring(activeAfter)
            .. " | inputState=" .. tostring(inputState)
            .. " | error=" .. tostring(err or "")
        )

        if ok and activeAfter == true then
            log(
                "RENAME INPUT ACTIVE"
                .. " | success=true"
                .. " | objectID=" .. tostring(self.renameTargetIDText)
                .. " | name=" .. tostring(self.renameTargetName)
                .. " | resumeMode=" .. tostring(self.resumeMode or "")
                .. " | resumePage=" .. tostring((self.resumePage or 0) + 1)
            )
            self.renamePending = false
            self.renameMonitoring = true
            self.renameMonitorTicks = 0
            return true
        end
    elseif self.renameAttempts > 0 then
        self.ticksSinceRenameAttempt =
            self.ticksSinceRenameAttempt + 1
    end

    if self.renameAttempts >= RENAME_MAX_ATTEMPTS
        and self.ticksSinceRenameAttempt >= RENAME_RETRY_INTERVAL_TICKS + 2
    then
        log(
            "RENAME INPUT FAILED"
            .. " | attempts=" .. tostring(self.renameAttempts)
            .. " | objectID=" .. tostring(self.renameTargetIDText)
            .. " | name=" .. tostring(self.renameTargetName)
        )
        self.renamePending = false
    end

    return false
end

function RenameManager:TickRenameMonitor()
    if not self.renameMonitoring then return false end

    self.renameMonitorTicks = self.renameMonitorTicks + 1

    local input, inputState = nativeRenameInput()
    if input == nil then
        -- If the ship panel itself disappeared while editing, abandon the auto-return
        -- rather than forcing UI state the player may have intentionally changed.
        if self.renameMonitorTicks >= 20 then
            log(
                "RENAME MONITOR STOP"
                .. " | reason=input-unavailable"
                .. " | inputState=" .. tostring(inputState)
            )
            self.renameMonitoring = false
        end
        return false
    end

    local active = nil
    pcall(function() active = input.TextInputIsActive end)

    if active == true then
        return false
    end

    -- Require a couple of inactive ticks so the native TextInput close has settled.
    if self.renameMonitorTicks < 2 then
        return false
    end

    local live = self:ResolveByID(self.renameTargetID)
    local currentName = live and readName(live) or ""
    local changed = currentName ~= "" and currentName ~= self.renameTargetName

    log(
        "RENAME COMPLETE"
        .. " | changed=" .. tostring(changed)
        .. " | objectID=" .. tostring(self.renameTargetIDText)
        .. " | oldName=" .. tostring(self.renameTargetName)
        .. " | newName=" .. tostring(currentName)
        .. " | resumeMode=" .. tostring(self.resumeMode or "")
        .. " | rememberedPage=" .. tostring((self.resumePage or 0) + 1)
        .. " | restorePolicy=same-category-page1"
    )

    self.renameMonitoring = false

    local closeOK, closeError = pcall(function()
        Scripts:PopUI()
    end)

    if closeOK and self.resumeMode ~= nil then
        self.resumePending = true
        self.resumeTicks = 2
    end

    log(
        "RETURN PREPARE"
        .. " | closeShipPanelSuccess=" .. tostring(closeOK)
        .. " | resumePending=" .. tostring(self.resumePending)
        .. " | delayTicks=" .. tostring(self.resumeTicks)
        .. " | error=" .. tostring(closeError or "")
    )

    return true
end

function RenameManager:TickResume()
    if not self.resumePending then return false end

    self.resumeTicks = self.resumeTicks - 1
    if self.resumeTicks > 0 then return true end

    self.resumePending = false
    local mode = self.resumeMode or "all"
    local rememberedPage = self.resumePage or 0

    if mode == "trade_routes_for_island" then
        self.report.islandName = tostring(self.resumeIslandName or "")
        self.report.islandKey = tostring(self.resumeIslandKey or "")
    elseif mode == "island_index" then
        self.report.islandName = ""
        self.report.islandKey = ""
    elseif mode == "trade_routes_for_good" then
        self.report.goodName = tostring(self.resumeGoodName or "")
        self.report.goodKey = tostring(self.resumeGoodKey or "")
    elseif mode == "goods_index" then
        self.report.goodName = ""
        self.report.goodKey = ""
    end

    self.pageRestoreProbePending =
        rememberedPage > 0
    self.pageRestoreProbeLogged = false

    log(
        "RETURN REPORT"
        .. " | mode=" .. tostring(mode)
        .. " | rememberedPage=" .. tostring(rememberedPage + 1)
        .. " | openingPage=1"
        .. " | exactPageRestore="
        .. (
            rememberedPage > 0
            and "native-control-probe-pending"
            or "not-needed-page1"
        )
    )

    self:OpenReport(mode, "post-rename-auto-return")
    return true
end

function RenameManager:Tick()
    -- First handle/close TextPopup markers, as in Ship Finder.
    if self:TickTextPopup() then
        return
    end

    if self:TickTradeRouteEditReturn() then
        return
    end

    if self:TickRenameMonitor() then
        return
    end

    if self:TickResume() then
        return
    end

    if self:TickTradeRouteOverview() then
        return
    end

    if self.returnMainPending then
        self.returnMainTicks = self.returnMainTicks - 1
        if self.returnMainTicks <= 0 then
            self.returnMainPending = false
            local target = self.returnMenuTarget or "main"
            self.returnMenuTarget = "main"
            log(
                "RETURN MENU"
                .. " | target=" .. tostring(target)
            )
            if target == "trade_routes" then
                self:OpenTradeRoutesMenu()
            else
                self:Open()
            end
        end
        return
    end

    -- Safe Close has yielded before this signal is normally observed.
    if self:TickSignal() then
        return
    end

    if self.directOpenPending then
        if self:TryDirectOpen("DELAYED_RETRY") then
            self.directOpenPending = false
            log(
                "MENU READY"
                .. " | attempt=" .. tostring(self.directOpenAttempt)
            )
        elseif self.directOpenAttempt >= DIRECT_OPEN_MAX_ATTEMPTS then
            self.directOpenPending = false
            log(
                "MENU OPEN TIMEOUT"
                .. " | attempts=" .. tostring(self.directOpenAttempt)
            )
        end
    end

    self:TickRename()
end

function RenameManager:Load()
    self.observedSignal = signalValue()
    log(
        "LOADED"
        .. " | shortcut=Ctrl+Alt+R"
        .. " | architecture=Main3->ShipsSubmenu6/TradeRoutesSubmenu7->All+ByGroup+ByIslands+ByGoods+CombinedRescan-actionable"
        .. " | rowsPerPage=9"
        .. " | pagesMax=12"
        .. " | slots=Ctrl+Alt+1-9"
        .. " | back=Ctrl+Alt+0"
        .. " | rename=native-RenamableHeadline"
        .. " | autoReturn=same-category-page1"
        .. " | shipRows=trade-route-aware"
        .. " | tradeRoutes=harvest->all/by-group + cached-islands + cached-goods-from-TradeRouteItems->first-word-search->exact-RouteID->native-command"
        .. " | tradeRouteOpen=Scripts.ToggleTraderouteMenu"
        .. " | tradeRouteRename=native-context-menu-Rename-route-command"
        .. " | tradeRouteReturn=backend-RouteID-commit-primary->same-trade-routes-parchment"
        .. " | nativeLifecycle=exact-row-submenu->Rename-route-command->Anno-editor | routeUX=all+by-group+by-islands+by-goods | islandUX=list-first+native-filter-topology-cache+other-island-grouping+combined-rescan | goodsUX=list-first+overview-icon-cache+combined-rescan | all-route-views-actionable"
        .. " | signal=" .. tostring(self.observedSignal)
    )
end

return RenameManager
