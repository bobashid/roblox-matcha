-- Build and Kill Zombies -> Auto Roll (keypress only) - Matcha LuauVM - v27.0
-- place 105011592530400
--
-- setrobloxinput IS THE FREEZE. It is in every version that froze this
-- client (v18, v20, v21, v22, v23, v24, v25) and in neither of the versions
-- that did not (v14 read only, v15 watcher). keypress returns ok and is
-- inert, but it has never hung the client.
--
-- So this file contains NO setrobloxinput call at all. Search the source:
-- the only input primitives are keypress and keyrelease.
--
-- Press shape:
--   wait(0.4)                  let the prompt enable
--   keypress(Enum.KeyCode.E)
--   wait(0.9)                  hold
--   keyrelease(Enum.KeyCode.E)
--   keyrelease(Enum.KeyCode.E) again, in case one is dropped
--
-- A roller will not roll while ItemPlace holds an un-bought item, so clear
-- that by hand once before testing, or every press is wasted.
--
-- Menu: Rollers tab, one section
--   Enabled, Roll Weapons, Roll Blocks, Teleport to roller

local NAME    = 'RollerMods'
local VERSION = 'v27.0'

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

-- one roll, keypress only ---------------------------------------------

local function rollOne(roller, tag)
    local part = roller and roller:FindFirstChild('Roll')
    if not part then return end

    local saved = nil
    local root  = getRoot()
    if teleport and root then
        saved = root.CFrame
        local pp = part.Position
        pcall(function() root.CFrame = CFrame.new(pp.X, pp.Y + 2, pp.Z) end)
    end

    local before = read(roller, 'ItemName')

    wait(0.4)
    pcall(keypress, Enum.KeyCode.E)
    wait(0.9)
    pcall(keyrelease, Enum.KeyCode.E)
    pcall(keyrelease, Enum.KeyCode.E)

    local got = nil
    local t0  = tick()
    while alive and (tick() - t0) < 2.0 do
        wait(0.2)
        local now = read(roller, 'ItemName')
        if now and now ~= before and now ~= '???' then
            got = now
            break
        end
    end

    if saved then
        local r2 = getRoot()
        if r2 then pcall(function() r2.CFrame = saved end) end
    end

    if got then
        print('[' .. NAME .. '] ' .. tag .. ' -> ' .. got .. ' (' .. tostring(read(roller, 'Rarity')) .. ')')
        pcall(notify, tag .. ': ' .. got, 'Rollers', 3)
    else
        print('[' .. NAME .. '] ' .. tag .. ' no change')
    end
end

-- the single loop -----------------------------------------------------

task.spawn(function()
    while alive do
        if running and (doW or doB) then
            local ok, err = pcall(function()
                local w, b = rollers()
                if doW and w then rollOne(w, 'weapons') end
                if doB and b then rollOne(b, 'blocks') end
            end)
            if not ok then print('[' .. NAME .. '] pass error: ' .. tostring(err)) end
            wait(2)
        else
            wait(0.5)
        end
    end
end)

-- status inside a spawn, so load never yields -------------------------

task.spawn(function()
    local p = myPlot()
    if not p then
        print('[' .. NAME .. '] no plot with your OwnerUserId (' .. lp.UserId .. ')')
        return
    end
    local w, b = rollers()
    print('[' .. NAME .. '] plot ' .. p.Name)
    print('[' .. NAME .. '] weapons ' .. tostring(read(w, 'ItemName')) .. ' (' .. tostring(read(w, 'Rarity')) .. ')')
    print('[' .. NAME .. '] blocks  ' .. tostring(read(b, 'ItemName')) .. ' (' .. tostring(read(b, 'Rarity')) .. ')')
end)

-- menu: callbacks only set booleans -----------------------------------

local HAS_UI = type(UI) == 'table' and type(UI.AddTab) == 'function'

local function firstBool(...)
    for i = 1, select('#', ...) do
        local v = select(i, ...)
        if type(v) == 'boolean' then return v end
    end
    return nil
end

local function mkToggle(sec, label, id, default, setter)
    local cb = function(...)
        local v = firstBool(...)
        if v == nil then return end
        setter(v)
        print('[' .. NAME .. '] ' .. label .. ' = ' .. tostring(v))
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
            mkToggle(sec, 'Enabled', 'e1_on', false, function(v) running = v end)
            mkToggle(sec, 'Roll Weapons', 'e1_w', false, function(v) doW = v end)
            mkToggle(sec, 'Roll Blocks', 'e1_b', false, function(v) doB = v end)
            mkToggle(sec, 'Teleport to roller', 'e1_tp', false, function(v) teleport = v end)
        end)
    end)
    if not ok then print('[' .. NAME .. '] UI.AddTab failed: ' .. tostring(err)) end
else
    print('[' .. NAME .. '] no UI table')
end

-- stop ----------------------------------------------------------------

local function stop()
    alive   = false
    running = false
    doW     = false
    doB     = false
    pcall(keyrelease, Enum.KeyCode.E)
    _G[NAME] = nil
    print('[' .. NAME .. '] stopped')
end

_G[NAME] = { stop = stop, version = VERSION }
print('[' .. NAME .. '] ' .. VERSION .. ' loaded - keypress only, no setrobloxinput')
