-- Build and Kill Zombies -> Teleport Roll + Buy - Matcha LuauVM - v16.0
-- place 105011592530400
--
-- What this does:
--   Auto Roll Weapons / Auto Roll Blocks teleport you onto the roller,
--   press its prompt, read the result, and if the item is on your buy list
--   teleport to ItemPlace and press the buy prompt. Your CFrame is saved
--   and restored on every single attempt, including on failure.
--
-- What was fixed from v15.2:
--   The Item Buy List section was built only from the saved list, which
--   starts empty, so the menu showed nothing. It now lists every part in
--   ReplicatedStorage.Assets.CarParts, grouped by category, all off.
--
-- Honest caveat, measured this session:
--   injected input has never triggered these prompts. keypress(69) is
--   inert, setrobloxinput(true,69) moves the character but not the prompt,
--   mouse1click / mouse1press on the prompt button did nothing, and the
--   Buy prompt renders no clickable button at all. This version tries the
--   prompt button with a mouse hold AND the E key with a long hold, then
--   proves success from the labels. If neither works you will see
--   'no change' in the log rather than a false 'rolled'.
--
-- Commands:
--   _G.RollerMods.test()     -- one roll attempt, prints what happened
--   _G.RollerMods.status()
--   _G.RollerMods.list()
--   _G.RollerMods.stop()

local NAME    = 'RollerMods'
local VERSION = 'v16.0'
local KEY_E   = 69
local WATCH_FILE = 'roller-buylist.json'

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
    autoW    = false,
    autoB    = false,
    teleport = true,
    hold     = 1.6,
    want     = {},
}

-- helpers -------------------------------------------------------------

local function norm(s)
    return (string.lower(tostring(s)):gsub('[^%w]', ''))
end

local CATS = { 'Engines', 'Fuels', 'Wheels', 'Blocks', 'Supports', 'Pushbars', 'Cosmetic', 'Seats' }

local catalog = nil

local function catalogMap()
    if catalog then return catalog end
    catalog = {}
    local rs = game:GetService('ReplicatedStorage')
    local assets = rs:FindFirstChild('Assets')
    local parts  = assets and assets:FindFirstChild('CarParts')
    if not parts then return catalog end
    for _, cat in ipairs(CATS) do
        local folder = parts:FindFirstChild(cat)
        if folder then
            for _, item in ipairs(folder:GetChildren()) do
                catalog[norm(item.Name)] = item.Name
            end
        end
    end
    return catalog
end

local function saveList()
    local http = game:GetService('HttpService')
    local keys = {}
    for k in pairs(state.want) do keys[#keys + 1] = k end
    table.sort(keys)
    local ok, enc = pcall(function() return http:JSONEncode(keys) end)
    if ok and type(enc) == 'string' then pcall(writefile, WATCH_FILE, enc) end
end

local function loadList()
    local ok, data = pcall(readfile, WATCH_FILE)
    if not ok or type(data) ~= 'string' or data == '' then return end
    local http = game:GetService('HttpService')
    local ok2, dec = pcall(function() return http:JSONDecode(data) end)
    if not ok2 or type(dec) ~= 'table' then return end
    for _, k in ipairs(dec) do
        if type(k) == 'string' then state.want[k] = true end
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
            print('[' .. NAME .. '] no item matches "' .. tostring(name) .. '"')
            return false
        elseif #hits == 1 then
            real, key = hits[1], norm(hits[1])
        else
            table.sort(hits)
            print('[' .. NAME .. '] ambiguous: ' .. table.concat(hits, ', '))
            return false
        end
    end
    state.want[key] = true
    saveList()
    print('[' .. NAME .. '] buying ' .. real)
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
    return false
end

local function listWant()
    local cat = catalogMap()
    local rows = {}
    for k in pairs(state.want) do rows[#rows + 1] = cat[k] or k end
    table.sort(rows)
    if #rows == 0 then print('[' .. NAME .. '] buy list empty') return end
    print('[' .. NAME .. '] buy list (' .. #rows .. '):')
    for _, n in ipairs(rows) do print('  ' .. n) end
end

-- world reads ---------------------------------------------------------

local function getRoot()
    local char = lp.Character
    return char and char:FindFirstChild('HumanoidRootPart')
end

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

local function itemCount(roller)
    local ip = roller and roller:FindFirstChild('ItemPlace')
    if not ip then return 0 end
    local n = 0
    for _, c in ipairs(ip:GetChildren()) do
        local cn = c.ClassName
        if cn == 'Model' or cn == 'MeshPart' or cn == 'Part' then n = n + 1 end
    end
    return n
end

-- prompt attempt ------------------------------------------------------

local function promptButton()
    local pg = lp:FindFirstChild('PlayerGui')
    local pp = pg and pg:FindFirstChild('ProximityPrompts')
    if not pp then return nil end
    for _, root in ipairs(pp:GetChildren()) do
        for _, g in ipairs(root:GetDescendants()) do
            local cn = g.ClassName
            if cn == 'TextButton' or cn == 'ImageButton' then
                local p, s = g.AbsolutePosition, g.AbsoluteSize
                if p and s and s.X > 2 and s.Y > 2 then return g, p, s end
            end
        end
    end
    return nil
end

local function pressPrompt(holdSecs)
    local btn, p, s = promptButton()
    if btn then
        pcall(mousemoveabs, p.X + s.X * 0.5, p.Y + s.Y * 0.5)
        task.wait(0.1)
        pcall(mouse1press)
        task.wait(holdSecs)
        pcall(mouse1release)
        return 'mouse'
    end
    pcall(setrobloxinput, true, KEY_E)
    task.wait(holdSecs)
    pcall(setrobloxinput, false, KEY_E)
    return 'key'
end

local function placeOn(part)
    local root = getRoot()
    if not root or not part then return nil end
    local save = root.CFrame
    local p = part.Position
    pcall(function() root.CFrame = CFrame.new(p.X, p.Y + 2, p.Z) end)
    return save
end

local function restore(save)
    if not save then return end
    local root = getRoot()
    if root then pcall(function() root.CFrame = save end) end
end

-- actions -------------------------------------------------------------

local function doRoll(roller, label)
    local part = roller and roller:FindFirstChild('Roll')
    if not part then return false end
    local before = read(roller, 'ItemName')
    local save = nil
    if state.teleport then
        save = placeOn(part)
        task.wait(0.8)
    end
    local how = pressPrompt(state.hold)
    local changed, item, rar = false, before, nil
    local t0 = tick()
    while alive and (tick() - t0) < 3 do
        task.wait(0.15)
        local now = read(roller, 'ItemName')
        if now and now ~= before and now ~= '???' then
            changed = true
            item  = now
            rar   = read(roller, 'Rarity')
            break
        end
    end
    if save then restore(save) end
    task.wait(0.1)
    if changed then
        print('[' .. NAME .. '] ' .. label .. ' rolled ' .. item .. ' (' .. tostring(rar) .. ') via ' .. how)
    else
        print('[' .. NAME .. '] ' .. label .. ' no change via ' .. how .. ' (still ' .. tostring(read(roller, 'ItemName')) .. ')')
    end
    return changed, item, rar
end

local function doBuy(roller, label)
    local ip = roller and roller:FindFirstChild('ItemPlace')
    if not ip then return false end
    local before = itemCount(roller)
    if before == 0 then
        print('[' .. NAME .. '] ' .. label .. ' nothing to buy')
        return false
    end
    local save = nil
    if state.teleport then
        save = placeOn(ip)
        task.wait(0.8)
    end
    local how = pressPrompt(state.hold)
    local bought = false
    local t0 = tick()
    while alive and (tick() - t0) < 2.5 do
        task.wait(0.15)
        if itemCount(roller) < before then bought = true break end
    end
    if save then restore(save) end
    task.wait(0.1)
    print('[' .. NAME .. '] ' .. label .. (bought and ' bought' or ' buy no change') .. ' via ' .. how)
    return bought
end

-- loop ---------------------------------------------------------------

local function runOne(roller, autoFlag, label)
    if not autoFlag or not roller then return end
    local ok, item, rar = doRoll(roller, label)
    if ok and state.want[norm(item)] then
        doBuy(roller, label)
    end
end

conn = task.spawn(function()
    while alive do
        if state.autoW or state.autoB then
            local p = myPlot()
            local rolls = p and p:FindFirstChild('Rolls')
            if rolls then
                runOne(rolls:FindFirstChild('RollWeapons'), state.autoW, 'weapons')
                runOne(rolls:FindFirstChild('RollBlocks'),  state.autoB, 'blocks')
            end
        end
        task.wait(0.3)
    end
end)

-- status / test -------------------------------------------------------

local function status()
    local p = myPlot()
    if not p then print('[' .. NAME .. '] no plot with your OwnerUserId') return end
    local rolls = p:FindFirstChild('Rolls')
    local w = rolls and rolls:FindFirstChild('RollWeapons')
    local b = rolls and rolls:FindFirstChild('RollBlocks')
    print('[' .. NAME .. '] plot ' .. p.Name)
    print('[' .. NAME .. '] weapons ' .. tostring(read(w, 'ItemName')) .. ' (' .. tostring(read(w, 'Rarity')) .. ') pending=' .. itemCount(w))
    print('[' .. NAME .. '] blocks  ' .. tostring(read(b, 'ItemName')) .. ' (' .. tostring(read(b, 'Rarity')) .. ') pending=' .. itemCount(b))
    local n = 0
    for _ in pairs(state.want) do n = n + 1 end
    print('[' .. NAME .. '] buy list ' .. n .. ' item(s), teleport=' .. tostring(state.teleport))
end

local function test()
    local p = myPlot()
    local rolls = p and p:FindFirstChild('Rolls')
    local w = rolls and rolls:FindFirstChild('RollWeapons')
    if not w then print('[' .. NAME .. '] no roller found') return end
    doRoll(w, 'test')
end

-- menu ---------------------------------------------------------------

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
    warn('[' .. NAME .. '] section ' .. name .. ' failed')
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
    warn('[' .. NAME .. '] toggle failed: ' .. label)
    return false
end

local function buildTab(tab)
    if built then return end
    built = true

    local ok, err = pcall(function()
        local secA = mkSection(tab, 'Auto Roll')
        if secA then
            mkToggle(secA, 'Teleport to roller', 'rb_tp', true, function(v)
                state.teleport = v
            end)
            mkToggle(secA, 'Auto Roll Weapons', 'rb_auto_w', false, function(v)
                state.autoW = v
                print('[' .. NAME .. '] weapon auto roll ' .. (v and 'on' or 'off'))
            end)
            mkToggle(secA, 'Auto Roll Blocks', 'rb_auto_b', false, function(v)
                state.autoB = v
                print('[' .. NAME .. '] block auto roll ' .. (v and 'on' or 'off'))
            end)
        end

        local rs = game:GetService('ReplicatedStorage')
        local assets = rs:FindFirstChild('Assets')
        local parts = assets and assets:FindFirstChild('CarParts')
        if not parts then return end

        for _, cat in ipairs(CATS) do
            local folder = parts:FindFirstChild(cat)
            if folder then
                local sec = mkSection(tab, cat)
                if sec then
                    local names = {}
                    for _, item in ipairs(folder:GetChildren()) do
                        names[#names + 1] = item.Name
                    end
                    table.sort(names)
                    for _, itemName in ipairs(names) do
                        local key = norm(itemName)
                        mkToggle(sec, itemName, 'rb_buy_' .. key, state.want[key] == true, function(v)
                            if v then state.want[key] = true else state.want[key] = nil end
                            saveList()
                        end)
                    end
                end
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
else
    warn('[' .. NAME .. '] no UI table - menu unavailable')
end

-- stop ---------------------------------------------------------------

local function stop()
    alive = false
    state.autoW = false
    state.autoB = false
    if conn then pcall(task.cancel, conn) end
    conn = nil
    pcall(setrobloxinput, false, KEY_E)
    pcall(mouse1release)
    if HAS_UI then
        pcall(function() UI.RemoveTab('Rollers') end)
    end
    _G[NAME] = nil
    print('[' .. NAME .. '] stopped')
end

_G[NAME] = {
    stop = stop, status = status, test = test, add = add, remove = remove,
    list = listWant, version = VERSION, state = state,
}
print('[' .. NAME .. '] ' .. VERSION .. ' loaded, menu=' .. tostring(HAS_UI) .. ' - teleport roll + item buy list')
