-- Build and Kill Zombies -> Item Buy List - Matcha LuauVM - v15.2
-- place 105011592530400
--
-- AUTO ROLL AND AUTO BUY ARE NOT POSSIBLE IN THIS VM. Evidence gathered live:
--   keypress(69)                            -> ok, iskeypressed stays false
--   setrobloxinput(true, 69)                -> W moves 7.12 studs, E does nothing
--   mouse1click on the Roll prompt button   -> no change
--   mouse1press + mouse1release 1.2s        -> no change
--   standing 1.45 studs from the Buy prompt -> no clickable prompt button
--   fireproximityprompt                     -> absent
--   require(Packets / RollController)       -> errors
-- So this version does what CAN be done: it watches both rollers and shouts
-- the moment an item YOU named lands, so you only press for those.
--
-- Commands:
--   _G.RollerMods.add("Quad Launcher")     -- fuzzy: "quadlauncher" works too
--   _G.RollerMods.remove("Quad Launcher")
--   _G.RollerMods.list()
--   _G.RollerMods.clear()
--   _G.RollerMods.status()
--   _G.RollerMods.stop()
-- The list is saved to roller-watchlist.json in the Matcha workspace.

local NAME    = 'RollerMods'
local VERSION = 'v15.2'
local WATCH_FILE = 'roller-watchlist.json'

if _G[NAME] and _G[NAME].stop then
    pcall(_G[NAME].stop)
end
print('[' .. NAME .. '] ' .. VERSION)

local Players = game:GetService('Players')
local ws      = game:GetService('Workspace')
local lp      = Players.LocalPlayer

local alive = true
local built = false
local conn  = nil

local state = {
    watchW = true,
    watchB = true,
    want   = {},
}

-- helpers -------------------------------------------------------------

local function norm(s)
    return (string.lower(tostring(s)):gsub('[^%w]', ''))
end

local catalog = nil

local function catalogMap()
    if catalog then return catalog end
    catalog = {}
    local rs = game:GetService('ReplicatedStorage')
    local assets = rs:FindFirstChild('Assets')
    local parts  = assets and assets:FindFirstChild('CarParts')
    if not parts then return catalog end
    for _, folder in ipairs(parts:GetChildren()) do
        for _, item in ipairs(folder:GetChildren()) do
            catalog[norm(item.Name)] = item.Name
        end
    end
    return catalog
end

local function saveList()
    local http = game:GetService('HttpService')
    local keys = {}
    for k in pairs(state.want) do keys[#keys + 1] = k end
    table.sort(keys)
    local ok, encoded = pcall(function() return http:JSONEncode(keys) end)
    if ok and type(encoded) == 'string' then
        pcall(writefile, WATCH_FILE, encoded)
    end
end

local function loadList()
    local ok, data = pcall(readfile, WATCH_FILE)
    if not ok or type(data) ~= 'string' or data == '' then return end
    local http = game:GetService('HttpService')
    local ok2, decoded = pcall(function() return http:JSONDecode(data) end)
    if not ok2 or type(decoded) ~= 'table' then return end
    for _, key in ipairs(decoded) do
        if type(key) == 'string' then state.want[key] = true end
    end
end

local function add(name)
    local key = norm(name)
    if key == '' then return false end
    local cat = catalogMap()
    local real = cat[key]
    if not real then
        local hits = {}
        for k, v in pairs(cat) do
            if string.find(k, key, 1, true) then hits[#hits + 1] = v end
        end
        if #hits == 0 then
            print('[' .. NAME .. '] no catalog item matches "' .. tostring(name) .. '"')
            return false
        elseif #hits == 1 then
            real = hits[1]
            key = norm(real)
        else
            table.sort(hits)
            print('[' .. NAME .. '] ambiguous: ' .. table.concat(hits, ', '))
            return false
        end
    end
    state.want[key] = true
    saveList()
    print('[' .. NAME .. '] watching ' .. real)
    return true
end

local function remove(name)
    local key = norm(name)
    if state.want[key] then
        state.want[key] = nil
        saveList()
        print('[' .. NAME .. '] removed ' .. tostring(name))
        return true
    end
    print('[' .. NAME .. '] not in list: ' .. tostring(name))
    return false
end

local function listWant()
    local cat = catalogMap()
    local rows = {}
    for key in pairs(state.want) do rows[#rows + 1] = cat[key] or key end
    table.sort(rows)
    if #rows == 0 then
        print('[' .. NAME .. '] buy list empty - use add("Item Name")')
        return
    end
    print('[' .. NAME .. '] buy list (' .. #rows .. '):')
    for _, n in ipairs(rows) do print('  ' .. n) end
end

-- read only helpers ---------------------------------------------------

local function plotsFolder()
    local g = ws:FindFirstChild('Game')
    local l = g and g:FindFirstChild('Lobby')
    return l and l:FindFirstChild('Plots')
end

local function myPlot()
    local pf = plotsFolder()
    if not pf then return nil end
    for _, p in ipairs(pf:GetChildren()) do
        if p:GetAttribute('OwnerUserId') == lp.UserId then return p end
    end
    return nil
end

local function read(roller, field)
    local info = roller and roller:FindFirstChild('Info')
    local lbl  = info and info:FindFirstChild(field)
    if lbl then return lbl.Text end
    return nil
end

local function rollers()
    local p = myPlot()
    local rolls = p and p:FindFirstChild('Rolls')
    if not rolls then return nil, nil end
    return rolls:FindFirstChild('RollWeapons'), rolls:FindFirstChild('RollBlocks')
end

-- watcher -------------------------------------------------------------

local last = { wItem = nil, wRar = nil, bItem = nil, bRar = nil }

local function announce(tag, item, rar)
    if not item then return end
    local line = tag .. ': ' .. item .. ' (' .. tostring(rar) .. ')'
    if state.want[norm(item)] then
        print('[' .. NAME .. '] BUY NOW -> ' .. line)
        pcall(notify, 'BUY NOW: ' .. item .. ' (' .. tostring(rar) .. ')', tag, 8)
    else
        print('[' .. NAME .. '] ' .. line)
    end
end

local function tickOnce()
    if not alive then return end
    local w, b = rollers()
    if state.watchW and w then
        local item, rar = read(w, 'ItemName'), read(w, 'Rarity')
        if item and item ~= '???' and (item ~= last.wItem or rar ~= last.wRar) then
            last.wItem, last.wRar = item, rar
            announce('weapons', item, rar)
        end
    end
    if state.watchB and b then
        local item, rar = read(b, 'ItemName'), read(b, 'Rarity')
        if item and item ~= '???' and (item ~= last.bItem or rar ~= last.bRar) then
            last.bItem, last.bRar = item, rar
            announce('blocks', item, rar)
        end
    end
end

local function status()
    local p = myPlot()
    if not p then
        print('[' .. NAME .. '] no plot carries your OwnerUserId (' .. lp.UserId .. ')')
        return
    end
    local w, b = rollers()
    print('[' .. NAME .. '] plot ' .. p.Name)
    print('[' .. NAME .. '] weapons ' .. tostring(read(w, 'ItemName')) .. ' (' .. tostring(read(w, 'Rarity')) .. ')')
    print('[' .. NAME .. '] blocks  ' .. tostring(read(b, 'ItemName')) .. ' (' .. tostring(read(b, 'Rarity')) .. ')')
    local n = 0
    for _ in pairs(state.want) do n = n + 1 end
    print('[' .. NAME .. '] buy list has ' .. n .. ' item(s)')
end

-- menu ----------------------------------------------------------------

local HAS_UI = type(UI) == 'table' and type(UI.AddTab) == 'function'

local function firstBool(...)
    for i = 1, select('#', ...) do
        local v = select(i, ...)
        if type(v) == 'boolean' then return v end
    end
    return nil
end

local function mkSection(tab, name)
    local sides = { 'Left', 'Right' }
    for i = 1, #sides do
        local ok, sec = pcall(function() return tab:Section(name, sides[i]) end)
        if ok and sec ~= nil then return sec end
    end
    local ok, sec = pcall(function() return tab:Section(name) end)
    if ok and sec ~= nil then return sec end
    return nil
end

local function mkToggle(sec, label, id, default, fn)
    local cb = function(...)
        local v = firstBool(...)
        if v ~= nil then fn(v) end
    end
    local tries = {
        function() sec:Toggle(label, id, default, cb) end,
        function() sec:Toggle(id, label, default, cb) end,
        function() sec:Toggle(label, default, cb) end,
    }
    for i = 1, #tries do
        if pcall(tries[i]) then return true end
    end
    return false
end

local function buildTab(tab)
    if built then return end
    built = true
    local ok, err = pcall(function()
        local sec = mkSection(tab, 'Watch')
        if not sec then return end
        mkToggle(sec, 'Watch Weapons', 'rw_w', true, function(v) state.watchW = v end)
        mkToggle(sec, 'Watch Blocks',  'rw_b', true, function(v) state.watchB = v end)

        local secL = mkSection(tab, 'Item Buy List')
        if secL then
            local cat = catalogMap()
            local keys = {}
            for key in pairs(state.want) do keys[#keys + 1] = key end
            table.sort(keys)
            for _, key in ipairs(keys) do
                local label = cat[key] or key
                mkToggle(secL, label, 'rw_i_' .. key, true, function(v)
                    if v then state.want[key] = true else state.want[key] = nil end
                    saveList()
                end)
            end
        end
    end)
    if not ok then warn('[' .. NAME .. '] build error: ' .. tostring(err)) end
    print('[' .. NAME .. '] tab built')
end

loadList()

if HAS_UI then
    local ok, err = pcall(function()
        UI.AddTab('Rollers', function(tab)
            if built then return end
            pcall(buildTab, tab)
        end)
    end)
    if not ok then
        warn('[' .. NAME .. '] UI.AddTab failed: ' .. tostring(err))
        HAS_UI = false
    end
end

conn = task.spawn(function()
    while alive do
        tickOnce()
        task.wait(0.5)
    end
end)

-- stop ----------------------------------------------------------------

local function stop()
    alive = false
    if conn then pcall(task.cancel, conn) end
    conn = nil
    if HAS_UI then
        pcall(function() UI.RemoveTab('Rollers') end)
    end
    _G[NAME] = nil
    print('[' .. NAME .. '] stopped')
end

_G[NAME] = {
    stop = stop, status = status, add = add, remove = remove,
    list = listWant, clear = function() state.want = {} saveList() end,
    version = VERSION, state = state,
}
print('[' .. NAME .. '] ' .. VERSION .. ' loaded - no input, no movement. add("Item Name") to build the buy list')
