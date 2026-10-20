-- Build and Kill Zombies -> Teleport, Press E - Matcha LuauVM - v20.0
-- place 105011592530400
--
-- WHY YOUR INPUTS WERE FREEZING:
--   It was my bug, not the game. stop() and reloading called task.cancel on
--   the loop while it was inside pressE, waiting between key-down and
--   key-up. Cancelling there skips the release line, so E stayed held down.
--   A latched injected key is exactly what 'all my inputs are frozen' looks
--   like. Every version from v16 to v18 had that hole.
--
-- THE FIX:
--   E is now owned by a separate watchdog thread that is never cancelled.
--   Whenever no hold is in progress it releases E, every 200ms, forever.
--   Even if the worker thread is killed mid-hold, E comes back up within
--   200ms. stop() clears the hold flag FIRST, then cancels the worker, then
--   lets the watchdog keep releasing for another 2 seconds.
--
-- WHAT IT DOES (the simple thing you asked for):
--   teleport onto the Roll part, press E, read Info.ItemName, then teleport
--   onto ItemPlace and press E to buy when the item is on your list, then
--   put you back where you were.
--
-- setrobloxinput is the only input primitive that reaches this game
-- (keypress was measured inert: W moved 0 studs and iskeypressed stayed
-- false, while setrobloxinput(true,87) moved 7.12 studs).
--
-- Menu: Rollers tab
--   Master      Enabled (default off) - the stop switch
--   Go + Press  Auto Roll Weapons / Auto Roll Blocks / Buy matched items
--   Test        Test one press
--   Engines/Fuels/Wheels/Blocks/Supports/Pushbars/Cosmetic/Seats
--               one toggle per item = your buy list, saved to disk

local NAME    = 'RollerMods'
local VERSION = 'v20.0'
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
local worker = nil

local state = {
    enabled    = false,
    autoW      = false,
    autoB      = false,
    buyMatched = true,
    hold       = 0.7,
    want       = {},
}

local MAX_MISSES = 6
local misses = 0

-- E release watchdog: this is the fix -------------------------------

local holding    = false
local watchdogOn = true

local function releaseE()
    for _ = 1, 3 do
        pcall(setrobloxinput, false, KEY_E)
    end
end

task.spawn(function()
    while watchdogOn do
        if not holding then releaseE() end
        task.wait(0.2)
    end
    releaseE()
    releaseE()
end)

local function pressE(secs)
    holding = true
    pcall(setrobloxinput, true, KEY_E)
    task.wait(secs or 0.7)
    holding = false
    releaseE()
    task.wait(0.12)
end

-- helpers ------------------------------------------------------------

local function norm(s)
    return (string.lower(tostring(s)):gsub('[^%w]', ''))
end

local CATS = { 'Engines', 'Fuels', 'Wheels', 'Blocks', 'Supports', 'Pushbars', 'Cosmetic', 'Seats' }

local function catalogMap()
    local out = {}
    local rs = game:GetService('ReplicatedStorage')
    local assets = rs:FindFirstChild('Assets')
    local parts  = assets and assets:FindFirstChild('CarParts')
    if not parts then return out end
    for _, cat in ipairs(CATS) do
        local folder = parts:FindFirstChild(cat)
        if folder then
            for _, item in ipairs(folder:GetChildren()) do
                out[norm(item.Name)] = item.Name
            end
        end
    end
    return out
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

local function wants(name)
    return name and state.want[norm(name)] == true
end

-- world reads --------------------------------------------------------

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

local function getRoot()
    local char = lp.Character
    return char and char:FindFirstChild('HumanoidRootPart')
end

-- teleport -----------------------------------------------------------

local savedCFrame = nil

local function snapTo(part)
    local root = getRoot()
    if not root or not part then return end
    if not savedCFrame then savedCFrame = root.CFrame end
    local p = part.Position
    pcall(function() root.CFrame = CFrame.new(p.X, p.Y + 2, p.Z) end)
    task.wait(0.35)
end

local function snapBack()
    if not savedCFrame then return end
    local root = getRoot()
    if root then pcall(function() root.CFrame = savedCFrame end) end
    savedCFrame = nil
    task.wait(0.15)
end

-- roll / buy ---------------------------------------------------------

local function tryRoll(roller, tag)
    local part = roller and roller:FindFirstChild('Roll')
    if not part then return nil end
    local before = read(roller, 'ItemName')

    snapTo(part)

    local got = nil
    for attempt = 1, 2 do
        pressE(attempt == 1 and state.hold or 1.3)
        local t0 = tick()
        while alive and (tick() - t0) < 2.5 do
            task.wait(0.15)
            local now = read(roller, 'ItemName')
            if now and now ~= before and now ~= '???' then
                got = now
                break
            end
        end
        if got then break end
    end

    snapBack()

    if got then
        local rar = read(roller, 'Rarity')
        print('[' .. NAME .. '] ' .. tag .. ' ROLLED ' .. got .. ' (' .. tostring(rar) .. ')')
        pcall(notify, tag .. ': ' .. got .. ' (' .. tostring(rar) .. ')', 'Rollers', 4)
    else
        print('[' .. NAME .. '] ' .. tag .. ' no change, still ' .. tostring(read(roller, 'ItemName')))
    end
    return got
end

local function tryBuy(roller, tag, item)
    local ip = roller and roller:FindFirstChild('ItemPlace')
    if not ip then return false end
    local pend = pendingModel(roller)
    if not pend then
        print('[' .. NAME .. '] ' .. tag .. ' nothing pending to buy')
        return false
    end

    snapTo(ip)

    local bought = false
    for attempt = 1, 2 do
        pressE(attempt == 1 and state.hold or 1.3)
        local t0 = tick()
        while alive and (tick() - t0) < 2.5 do
            task.wait(0.15)
            if pendingModel(roller) ~= pend then
                bought = true
                break
            end
        end
        if bought then break end
    end

    snapBack()

    print('[' .. NAME .. '] ' .. tag .. ' buy ' .. pend .. (bought and ' OK' or ' FAILED'))
    pcall(notify, tag .. ' buy ' .. pend .. (bought and ': ok' or ': failed'), 'Rollers', 4)
    return bought
end

-- one full pass -----------------------------------------------------

local function pass(label)
    local w, b = rollersNow()
    if not w and not b then
        print('[' .. NAME .. '] ' .. label .. ': no rollers on your plot')
        return false
    end

    local any = false

    if w and state.autoW then
        local item = tryRoll(w, 'weapons')
        if item then
            any = true
            if state.buyMatched and wants(item) then
                tryBuy(w, 'weapons', item)
            end
        end
    end

    if b and state.autoB then
        local item = tryRoll(b, 'blocks')
        if item then
            any = true
            if state.buyMatched and wants(item) then
                tryBuy(b, 'blocks', item)
            end
        end
    end

    if any then
        misses = 0
    else
        misses = misses + 1
        if misses >= MAX_MISSES then
            state.enabled = false
            state.autoW   = false
            state.autoB   = false
            misses = 0
            print('[' .. NAME .. '] stopping - E is not reaching the prompt. Stand on the roller, then turn Enabled back on.')
            pcall(notify, 'stopped: E did not reach the prompt', 'Rollers', 8)
        end
    end

    return any
end

worker = task.spawn(function()
    while alive do
        if state.enabled and (state.autoW or state.autoB) then
            pass('auto')
        end
        task.wait(1.2)
    end
end)

-- status -------------------------------------------------------------

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
            mkToggle(secM, 'Enabled', 'r2_on', false, function(v)
                state.enabled = v
                misses = 0
                print('[' .. NAME .. '] enabled=' .. tostring(v))
                if v then status() end
            end)
        end

        local secG = mkSection(tab, 'Go + Press')
        if secG then
            mkToggle(secG, 'Auto Roll Weapons', 'r2_w', false, function(v)
                state.autoW = v
                misses = 0
                print('[' .. NAME .. '] weapons ' .. (v and 'on' or 'off'))
            end)
            mkToggle(secG, 'Auto Roll Blocks', 'r2_b', false, function(v)
                state.autoB = v
                misses = 0
                print('[' .. NAME .. '] blocks ' .. (v and 'on' or 'off'))
            end)
            mkToggle(secG, 'Buy matched items', 'r2_buy', true, function(v)
                state.buyMatched = v
            end)
        end

        local secT = mkSection(tab, 'Test')
        if secT then
            mkToggle(secT, 'Test one press', 'r2_test', false, function(v)
                if not v then return end
                if tick() - lastTest < 4 then return end
                lastTest = tick()
                task.spawn(function()
                    local w, b = rollersNow()
                    local keepW, keepB = state.autoW, state.autoB
                    state.autoW, state.autoB = w ~= nil, false
                    pass('test')
                    state.autoW, state.autoB = keepW, keepB
                end)
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
                        mkToggle(sec, itemName, 'r2_buy_' .. key, state.want[key] == true, function(v)
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
    holding = false          -- first, so the watchdog releases E
    alive   = false
    state.enabled = false
    state.autoW   = false
    state.autoB   = false
    releaseE()
    if worker then pcall(task.cancel, worker) end
    worker = nil
    snapBack()
    task.delay(2, function() watchdogOn = false end)
    _G[NAME] = nil
    print('[' .. NAME .. '] stopped, E released')
end

_G[NAME] = { stop = stop, status = status, version = VERSION, state = state }
print('[' .. NAME .. '] ' .. VERSION .. ' loaded, menu=' .. tostring(HAS_UI) .. ' - teleport + E, watchdog releases E')
