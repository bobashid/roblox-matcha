-- Build and Kill Zombies -> Auto Roll only - Matcha LuauVM - v23.0
-- place 105011592530400
--
-- STRIPPED TO THE MINIMUM because v22 froze the whole client even with the
-- toggles off. Two things ran at load in v22 and both are gone now:
--   1. releaseAllKeys() - six setrobloxinput(false, ...) calls at load
--   2. UI.AddTab with about 200 toggles (every CarParts item, each built
--      through up to 3 pcall retries) - hundreds of widgets with no yield
--
-- v23.0 does NONE of that. What happens at load:
--   one version print, one status print (three label reads), one tiny tab
--   with three toggles. No input call, no file IO, no catalog scan.
--
-- No buy. No item list. No saved file. No key release loop.
--
-- Menu: Rollers tab, one section
--   Enabled          master, default off
--   Roll Weapons
--   Roll Blocks
--   Teleport to roller   (default OFF - press E from where you stand)
--   Release E (once)     clears a stuck E, one call, nothing else
--
-- One press per 3 seconds. If a press does not change the label it prints
-- 'no change' and carries on once, then keeps the 3 second gap.

local NAME    = 'RollerMods'
local VERSION = 'v23.0'
local KEY_E   = 69

if _G[NAME] and _G[NAME].stop then
    pcall(_G[NAME].stop)
end
print('[' .. NAME .. '] ' .. VERSION)

local Players = game:GetService('Players')
local ws      = game:GetService('Workspace')
local lp      = Players.LocalPlayer

local alive    = true
local running  = false
local doW      = false
local doB      = false
local teleport = false
local busy     = false

-- reads ---------------------------------------------------------------

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

local function rollers()
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

local function getRoot()
    local char = lp.Character
    return char and char:FindFirstChild('HumanoidRootPart')
end

-- teleport (only if you turn it on) ----------------------------------

local savedCF = nil

local function snapTo(part)
    local root = getRoot()
    if not root or not part then return end
    if not savedCF then savedCF = root.CFrame end
    local p = part.Position
    pcall(function() root.CFrame = CFrame.new(p.X, p.Y + 2, p.Z) end)
end

local function snapBack()
    if not savedCF then return end
    local root = getRoot()
    if root then pcall(function() root.CFrame = savedCF end) end
    savedCF = nil
end

-- one press -----------------------------------------------------------

local down = false

local function releaseE()
    if not down then return end
    down = false
    pcall(setrobloxinput, false, KEY_E)
end

local function pressE(secs)
    down = true
    pcall(setrobloxinput, true, KEY_E)
    task.delay(secs, releaseE)      -- released even if this thread dies
    task.wait(secs + 0.15)
    releaseE()
end

-- one roll ------------------------------------------------------------

local function rollOne(roller, tag)
    local part = roller and roller:FindFirstChild('Roll')
    if not part then return end

    local before = read(roller, 'ItemName')
    if teleport then
        snapTo(part)
        task.wait(0.5)
    end

    pressE(0.8)

    local got = nil
    local t0 = tick()
    while alive and (tick() - t0) < 2.5 do
        task.wait(0.2)
        local now = read(roller, 'ItemName')
        if now and now ~= before and now ~= '???' then
            got = now
            break
        end
    end

    if teleport then snapBack() end

    if got then
        print('[' .. NAME .. '] ' .. tag .. ' -> ' .. got .. ' (' .. tostring(read(roller, 'Rarity')) .. ')')
        pcall(notify, tag .. ': ' .. got, 'Rollers', 3)
    else
        print('[' .. NAME .. '] ' .. tag .. ' no change')
    end
end

-- loop: exists always, does nothing until Enabled + a roller toggle --

task.spawn(function()
    while alive do
        if running and (doW or doB) and not busy then
            busy = true
            local ok, err = pcall(function()
                local w, b = rollers()
                if doW and w then rollOne(w, 'weapons') end
                if doB and b then rollOne(b, 'blocks') end
            end)
            if not ok then print('[' .. NAME .. '] pass error: ' .. tostring(err)) end
            busy = false
            task.wait(3)
        else
            task.wait(0.5)
        end
    end
end)

-- status --------------------------------------------------------------

local function status()
    local p = myPlot()
    if not p then
        print('[' .. NAME .. '] no plot with your OwnerUserId (' .. lp.UserId .. ')')
        return
    end
    local w, b = rollers()
    print('[' .. NAME .. '] plot ' .. p.Name .. ' | enabled=' .. tostring(running))
    print('[' .. NAME .. '] weapons ' .. tostring(read(w, 'ItemName')) .. ' (' .. tostring(read(w, 'Rarity')) .. ')')
    print('[' .. NAME .. '] blocks  ' .. tostring(read(b, 'ItemName')) .. ' (' .. tostring(read(b, 'Rarity')) .. ')')
end

-- menu: three toggles, one section -----------------------------------

local HAS_UI = type(UI) == 'table' and type(UI.AddTab) == 'function'

local function firstBool(...)
    for i = 1, select('#', ...) do
        local v = select(i, ...)
        if type(v) == 'boolean' then return v end
    end
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
    print('[' .. NAME .. '] toggle failed: ' .. label)
    return false
end

if HAS_UI then
    local ok, err = pcall(function()
        UI.AddTab('Rollers', function(tab)
            local ok2, sec = pcall(function() return tab:Section('Roll') end)
            if not ok2 or not sec then
                print('[' .. NAME .. '] section failed')
                return
            end

            mkToggle(sec, 'Enabled', 'a1_on', false, function(v)
                running = v
                print('[' .. NAME .. '] enabled=' .. tostring(v))
            end)
            mkToggle(sec, 'Roll Weapons', 'a1_w', false, function(v)
                doW = v
                print('[' .. NAME .. '] weapons ' .. (v and 'on' or 'off'))
            end)
            mkToggle(sec, 'Roll Blocks', 'a1_b', false, function(v)
                doB = v
                print('[' .. NAME .. '] blocks ' .. (v and 'on' or 'off'))
            end)
            mkToggle(sec, 'Teleport to roller', 'a1_tp', false, function(v)
                teleport = v
                print('[' .. NAME .. '] teleport ' .. (v and 'on' or 'off'))
            end)
            mkToggle(sec, 'Release E (once)', 'a1_rel', false, function(v)
                if v then
                    pcall(setrobloxinput, false, KEY_E)
                    down = false
                    print('[' .. NAME .. '] E released')
                end
            end)
        end)
    end)
    if not ok then print('[' .. NAME .. '] UI.AddTab failed: ' .. tostring(err)) end
else
    print('[' .. NAME .. '] no UI table')
end

status()

-- stop ----------------------------------------------------------------

local function stop()
    alive = false
    running = false
    doW = false
    doB = false
    releaseE()
    snapBack()
    _G[NAME] = nil
    print('[' .. NAME .. '] stopped')
end

_G[NAME] = { stop = stop, status = status, version = VERSION }
print('[' .. NAME .. '] ' .. VERSION .. ' loaded, menu=' .. tostring(HAS_UI) .. ' - auto roll only')
