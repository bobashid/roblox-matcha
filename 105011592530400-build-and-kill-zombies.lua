-- Build and Kill Zombies -> Go To Roller, Press E - Matcha LuauVM - v19.0
-- place 105011592530400
--
-- Back to the simple thing, with the freeze suspect removed:
--   go to the roller -> press E -> read the result -> go to ItemPlace and
--   press E to buy when the item is on your list.
--
-- WHAT CHANGED FROM v18.0 (which froze your inputs):
--   v18 pressed E with setrobloxinput(true/false, 69). That is the only
--   input call in the whole script and it is the one that coincided with
--   the input freeze. It is GONE. This version presses with the documented
--   keypress/keyrelease pair, and releases E several times on every path
--   including stop(), so it cannot stay latched.
--
-- Movement has two modes, both in the menu:
--   Walk to roller (default ON)  - Humanoid.WalkToPoint, the character
--                                  walks, nothing is written to CFrame, so
--                                  it cannot desync the controller.
--   Snap (CFrame)                - default OFF. Instant, one write there
--                                  and one back. Only use if walking is
--                                  too slow for you.
--
-- Safety:
--   8 presses in a row with no change and it switches itself off.
--
-- Menu: Rollers tab
--   Master   Enabled (default off) - the stop switch
--   Go + Press
--     Walk to roller / Snap (CFrame)
--     Auto Roll / Auto Buy / Buy matched items
--   Test     Test one press
--   Engines/Fuels/Wheels/Blocks/Supports/Pushbars/Cosmetic/Seats
--            one toggle per item = your buy list, saved to disk

local NAME    = 'RollerMods'
local VERSION = 'v19.0'
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
    autoRoll   = false,
    buyMatched = true,
    walk       = true,
    snap       = false,
    hold       = 0.6,
    wait       = 2.5,
    want       = {},
}

local MAX_MISSES = 8
local misses = 0

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

local function rootPos()
    local char = lp.Character
    local root = char and char:FindFirstChild('HumanoidRootPart')
    return root and root.Position
end

-- movement ------------------------------------------------------------

local savedCFrame = nil

local function goTo(part)
    local char = lp.Character
    local hum  = char and char:FindFirstChildOfClass('Humanoid')
    local root = char and char:FindFirstChild('HumanoidRootPart')
    if not char or not part then return false end

    if state.snap and root then
        if not savedCFrame then savedCFrame = root.CFrame end
        local p = part.Position
        pcall(function() root.CFrame = CFrame.new(p.X, p.Y + 2, p.Z) end)
        task.wait(0.4)
        return true
    end

    if state.walk and hum then
        pcall(function() hum.WalkToPoint = part.Position end)
        local t0 = tick()
        while alive and (tick() - t0) < 4 do
            task.wait(0.15)
            local rp = rootPos()
            if rp and (rp - part.Position).Magnitude < 6 then break end
        end
        return true
    end

    return false
end

local function goBack()
    if not savedCFrame then return end
    local char = lp.Character
    local root = char and char:FindFirstChild('HumanoidRootPart')
    local hum  = char and char:FindFirstChildOfClass('Humanoid')
    if root then pcall(function() root.CFrame = savedCFrame end) end
    if hum then pcall(function() hum.WalkToPoint = savedCFrame.Position end) end
    savedCFrame = nil
    task.wait(0.2)
end

-- the only input this script performs --------------------------------

local function releaseE()
    pcall(keyrelease, Enum.KeyCode.E)
end

local function pressE(secs)
    pcall(keypress, Enum.KeyCode.E)
    task.wait(secs)
    releaseE()
    releaseE()
    task.wait(0.15)
end

-- one attempt ---------------------------------------------------------

local function attempt(label, buyOnly)
    local w, b = rollersNow()
    if not w and not b then
        print('[' .. NAME .. '] ' .. label .. ': no rollers on your plot')
        return false
    end

    local roller = w or b
    local part   = buyOnly and roller:FindFirstChild('ItemPlace') or roller:FindFirstChild('Roll')
    if not part then
        print('[' .. NAME .. '] ' .. label .. ': roller has no part')
        return false
    end

    local wName0, bName0 = read(w, 'ItemName'), read(b, 'ItemName')
    local wPend0, bPend0 = pendingModel(w), pendingModel(b)

    goTo(part)
    pressE(state.hold)

    local rolledW, rolledB, boughtW, boughtB = false, false, false, false
    local t0 = tick()
    while alive and (tick() - t0) < state.wait do
        task.wait(0.15)
        if w then
            local n = read(w, 'ItemName')
            if not buyOnly and n and n ~= wName0 and n ~= '???' then rolledW = true end
            if wPend0 and pendingModel(w) ~= wPend0 then boughtW = true end
        end
        if b then
            local n = read(b, 'ItemName')
            if not buyOnly and n and n ~= bName0 and n ~= '???' then rolledB = true end
            if bPend0 and pendingModel(b) ~= bPend0 then boughtB = true end
        end
        if rolledW or rolledB or boughtW or boughtB then break end
    end

    goBack()

    if rolledW then
        print('[' .. NAME .. '] ' .. label .. ': weapons ROLLED ' .. tostring(read(w, 'ItemName')) .. ' (' .. tostring(read(w, 'Rarity')) .. ')')
        pcall(notify, 'weapons: ' .. tostring(read(w, 'ItemName')) .. ' (' .. tostring(read(w, 'Rarity')) .. ')', 'Rollers', 4)
    end
    if rolledB then
        print('[' .. NAME .. '] ' .. label .. ': blocks ROLLED ' .. tostring(read(b, 'ItemName')) .. ' (' .. tostring(read(b, 'Rarity')) .. ')')
        pcall(notify, 'blocks: ' .. tostring(read(b, 'ItemName')) .. ' (' .. tostring(read(b, 'Rarity')) .. ')', 'Rollers', 4)
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
        print('[' .. NAME .. '] ' .. label .. ': no change (' .. misses .. '/' .. MAX_MISSES .. ')')
        if misses >= MAX_MISSES then
            state.enabled  = false
            state.autoRoll = false
            misses = 0
            print('[' .. NAME .. '] stopping - E is not reaching the prompt. Stand on the roller and turn Enabled back on.')
            pcall(notify, 'stopped: E did not reach the prompt', 'Rollers', 8)
        end
    else
        misses = 0
    end

    return any, rolledW or rolledB
end

local function wants(name)
    return name and state.want[norm(name)] == true
end

-- loop ---------------------------------------------------------------

conn = task.spawn(function()
    while alive do
        if state.enabled and state.autoRoll then
            local any, rolled = attempt('auto', false)
            if any and rolled and state.buyMatched then
                local w, b = rollersNow()
                if wants(pendingModel(w)) or wants(pendingModel(b)) then
                    task.wait(0.3)
                    attempt('buy', true)
                end
            end
        end
        task.wait(1.0)
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
            mkToggle(secM, 'Enabled', 'rg_on', false, function(v)
                state.enabled = v
                misses = 0
                print('[' .. NAME .. '] enabled=' .. tostring(v))
                if v then status() end
            end)
        end

        local secG = mkSection(tab, 'Go + Press')
        if secG then
            mkToggle(secG, 'Walk to roller', 'rg_walk', true, function(v)
                state.walk = v
            end)
            mkToggle(secG, 'Snap (CFrame)', 'rg_snap', false, function(v)
                state.snap = v
            end)
            mkToggle(secG, 'Auto Roll', 'rg_auto', false, function(v)
                state.autoRoll = v
                misses = 0
                print('[' .. NAME .. '] auto roll ' .. (v and 'on' or 'off'))
            end)
            mkToggle(secG, 'Buy matched items', 'rg_buy', true, function(v)
                state.buyMatched = v
            end)
        end

        local secT = mkSection(tab, 'Test')
        if secT then
            mkToggle(secT, 'Test one press', 'rg_test', false, function(v)
                if not v then return end
                if tick() - lastTest < 3 then return end
                lastTest = tick()
                task.spawn(function() attempt('test', false) end)
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
                        mkToggle(sec, itemName, 'rg_buy_' .. key, state.want[key] == true, function(v)
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
    state.autoRoll = false
    if conn then pcall(task.cancel, conn) end
    conn = nil
    releaseE()
    releaseE()
    _G[NAME] = nil
    print('[' .. NAME .. '] stopped, E released')
end

_G[NAME] = { stop = stop, status = status, version = VERSION, state = state }
print('[' .. NAME .. '] ' .. VERSION .. ' loaded, menu=' .. tostring(HAS_UI) .. ' - walk + keypress E, no setrobloxinput')
