-- Build and Kill Zombies -> E Roller - Matcha LuauVM - v18.0
-- place 105011592530400
--
-- This version presses E for you and nothing else.
--   no teleport, no CFrame or Position write, no mouse call at all
--   you stand at the roller, it presses E, reads the result, and presses
--   E again to buy when an item you want lands
--
-- Why teleport was removed:
--   the old loop wrote HumanoidRootPart.CFrame on every attempt while the
--   Humanoid was still simulating. That is what froze the game. This
--   version never touches your position.
--
-- Why the mouse was removed too:
--   mouse1press can leave the pointer captured if it is not released, which
--   stalls all input. Only setrobloxinput with E is used here.
--
-- Safety:
--   after 8 presses that change nothing it turns itself off and notifies,
--   so it can never hammer the roller indefinitely.
--
-- Honest limit, measured this session:
--   setrobloxinput(true,69) does reach the game (W moved the character
--   7.12 studs) but in my probes it did not trigger the roller prompt.
--   If yours behaves the same the log says 'no change' and it stops.
--
-- Menu: Rollers tab
--   Master      Enabled (default off) - turn off to stop
--   Press E     Auto Press, Buy matched items
--   Test        Test one press
--   Engines/Fuels/Wheels/Blocks/Supports/Pushbars/Cosmetic/Seats
--               one toggle per item = your buy list, saved to disk

local NAME    = 'RollerMods'
local VERSION = 'v18.0'
local KEY_E   = 69
local LIST_FILE = 'roller-buylist.json'

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
    enabled    = false,
    autoPress  = false,
    buyMatched = true,
    hold       = 0.8,
    wait       = 2.5,
    interval   = 1.6,
    want       = {},
}

local MAX_MISSES = 8
local misses = 0

-- naming / catalog ----------------------------------------------------

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
    if ok and type(enc) == 'string' then pcall(writefile, LIST_FILE, enc) end
end

local function loadList()
    local ok, data = pcall(readfile, LIST_FILE)
    if not ok or type(data) ~= 'string' or data == '' then return end
    local http = game:GetService('HttpService')
    local ok2, dec = pcall(function() return http:JSONDecode(data) end)
    if not ok2 or type(dec) ~= 'table' then return end
    for _, k in ipairs(dec) do
        if type(k) == 'string' then state.want[k] = true end
    end
end

local function setWant(name, on)
    local key = norm(name)
    if key == '' then return end
    if on then state.want[key] = true else state.want[key] = nil end
    saveList()
end

-- world reads ---------------------------------------------------------

local function myPlot()
    local g = ws:FindFirstChild('Game')
    local l = g and g:FindFirstChild('Lobby')
    local pf = l and l:FindFirstChild('Plots')
    if not pf then return nil end
    for _, p in ipairs(pf:GetChildren()) do
        if p:GetAttribute('OwnerUserId') == lp.UserId then return p end
    end
    return nil
end

local function rollersNow()
    local p = myPlot()
    local rolls = p and p:FindFirstChild('Rolls')
    if not rolls then return nil, nil end
    return rolls:FindFirstChild('RollWeapons'), rolls:FindFirstChild('RollBlocks')
end

local function read(roller, field)
    local info = roller and roller:FindFirstChild('Info')
    local lbl  = info and info:FindFirstChild(field)
    if lbl then return lbl.Text end
    return nil
end

local function pendingModel(roller)
    local ip = roller and roller:FindFirstChild('ItemPlace')
    if not ip then return nil end
    for _, c in ipairs(ip:GetChildren()) do
        local cn = c.ClassName
        if cn == 'Model' or cn == 'MeshPart' or cn == 'Part' then return c.Name end
    end
    return nil
end

-- the only input this script performs --------------------------------

local function pressE(secs)
    pcall(setrobloxinput, true, KEY_E)
    task.wait(secs)
    pcall(setrobloxinput, false, KEY_E)
    task.wait(0.15)
end

-- one press, observe both rollers ------------------------------------

local function pulse(label)
    local w, b = rollersNow()
    if not w and not b then
        print('[' .. NAME .. '] ' .. label .. ': no rollers found')
        return false
    end

    local wName0 = w and read(w, 'ItemName')
    local bName0 = b and read(b, 'ItemName')
    local wPend0 = w and pendingModel(w)
    local bPend0 = b and pendingModel(b)

    pressE(state.hold)

    local rolledW, rolledB, boughtW, boughtB = false, false, false, false
    local t0 = tick()
    while alive and (tick() - t0) < state.wait do
        task.wait(0.15)
        if w then
            local n = read(w, 'ItemName')
            if n and n ~= wName0 and n ~= '???' then rolledW = true end
            if wPend0 and pendingModel(w) ~= wPend0 then boughtW = true end
        end
        if b then
            local n = read(b, 'ItemName')
            if n and n ~= bName0 and n ~= '???' then rolledB = true end
            if bPend0 and pendingModel(b) ~= bPend0 then boughtB = true end
        end
        if rolledW or rolledB or boughtW or boughtB then break end
    end

    if rolledW then
        local item = read(w, 'ItemName')
        local rar  = read(w, 'Rarity')
        print('[' .. NAME .. '] ' .. label .. ': weapons ROLLED ' .. tostring(item) .. ' (' .. tostring(rar) .. ')')
        pcall(notify, 'weapons: ' .. tostring(item) .. ' (' .. tostring(rar) .. ')', 'Rollers', 4)
    end
    if rolledB then
        local item = read(b, 'ItemName')
        local rar  = read(b, 'Rarity')
        print('[' .. NAME .. '] ' .. label .. ': blocks ROLLED ' .. tostring(item) .. ' (' .. tostring(rar) .. ')')
        pcall(notify, 'blocks: ' .. tostring(item) .. ' (' .. tostring(rar) .. ')', 'Rollers', 4)
    end
    if boughtW then
        print('[' .. NAME .. '] ' .. label .. ': weapons BOUGHT ' .. tostring(wPend0))
        pcall(notify, 'weapons bought ' .. tostring(wPend0), 'Rollers', 4)
    end
    if boughtB then
        print('[' .. NAME .. '] ' .. label .. ': blocks BOUGHT ' .. tostring(bPend0))
        pcall(notify, 'blocks bought ' .. tostring(bPend0), 'Rollers', 4)
    end

    local any = rolledW or rolledB or boughtW or boughtB
    if not any then
        misses = misses + 1
        print('[' .. NAME .. '] ' .. label .. ': no change (' .. misses .. '/' .. MAX_MISSES
            .. ') weapons=' .. tostring(read(w, 'ItemName'))
            .. ' pending=' .. tostring(pendingModel(w)))
        if misses >= MAX_MISSES then
            state.enabled   = false
            state.autoPress = false
            misses = 0
            print('[' .. NAME .. '] stopping - E is not reaching the prompt. Stand at the roller and turn Enabled back on.')
            pcall(notify, 'stopped: E did not trigger the prompt', 'Rollers', 8)
        end
    else
        misses = 0
    end

    return any, rolledW, rolledB
end

-- should this item be bought? ----------------------------------------

local function wants(name)
    return name and state.want[norm(name)] == true
end

-- loop ---------------------------------------------------------------

conn = task.spawn(function()
    while alive do
        if state.enabled and state.autoPress then
            local any, rolledW, rolledB = pulse('auto')
            if any and state.buyMatched then
                local w, b = rollersNow()
                local wPend = pendingModel(w)
                local bPend = pendingModel(b)
                if (rolledW and wants(wPend)) or (rolledB and wants(bPend)) then
                    task.wait(0.4)
                    pulse('buy')
                end
            end
        end
        task.wait(state.interval)
    end
end)

-- status --------------------------------------------------------------

local function status()
    local p = myPlot()
    if not p then
        print('[' .. NAME .. '] no plot carries your OwnerUserId (' .. lp.UserId .. ')')
        return
    end
    local w, b = rollersNow()
    print('[' .. NAME .. '] plot ' .. p.Name .. ' | enabled=' .. tostring(state.enabled))
    print('[' .. NAME .. '] weapons ' .. tostring(read(w, 'ItemName')) .. ' (' .. tostring(read(w, 'Rarity')) .. ') pending=' .. tostring(pendingModel(w)))
    print('[' .. NAME .. '] blocks  ' .. tostring(read(b, 'ItemName')) .. ' (' .. tostring(read(b, 'Rarity')) .. ') pending=' .. tostring(pendingModel(b)))
    local n = 0
    for _ in pairs(state.want) do n = n + 1 end
    print('[' .. NAME .. '] buy list ' .. n .. ' item(s)')
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

local lastTest = 0

local function buildTab(tab)
    if built then return end
    built = true

    local ok, err = pcall(function()
        local secM = mkSection(tab, 'Master')
        if secM then
            mkToggle(secM, 'Enabled', 're_on', false, function(v)
                state.enabled = v
                misses = 0
                print('[' .. NAME .. '] enabled=' .. tostring(v))
                if v then status() end
            end)
        end

        local secP = mkSection(tab, 'Press E')
        if secP then
            mkToggle(secP, 'Auto Press', 're_auto', false, function(v)
                state.autoPress = v
                misses = 0
                print('[' .. NAME .. '] auto press ' .. (v and 'on' or 'off') .. ' - stand at the roller')
            end)
            mkToggle(secP, 'Buy matched items', 're_buy', true, function(v)
                state.buyMatched = v
            end)
        end

        local secT = mkSection(tab, 'Test')
        if secT then
            mkToggle(secT, 'Test one press', 're_test', false, function(v)
                if not v then return end
                if tick() - lastTest < 2 then return end
                lastTest = tick()
                task.spawn(function() pulse('test') end)
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
                        mkToggle(sec, itemName, 're_buy_' .. key, state.want[key] == true, function(v)
                            setWant(itemName, v)
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

status()

-- stop ---------------------------------------------------------------

local function stop()
    alive = false
    state.enabled = false
    state.autoPress = false
    if conn then pcall(task.cancel, conn) end
    conn = nil
    pcall(setrobloxinput, false, KEY_E)
    if HAS_UI then
        pcall(function() UI.RemoveTab('Rollers') end)
    end
    _G[NAME] = nil
    print('[' .. NAME .. '] stopped')
end

_G[NAME] = { stop = stop, status = status, version = VERSION, state = state }
print('[' .. NAME .. '] ' .. VERSION .. ' loaded, menu=' .. tostring(HAS_UI) .. ' - press E only, no teleport, no mouse')
