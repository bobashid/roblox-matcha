-- Build and Kill Zombies -> Roll Watcher (no input) - Matcha LuauVM - v15.0
-- place 105011592530400
--
-- This version issues NO input and NO movement:
--   no keypress / keyrelease / setrobloxinput
--   no mouse1click / mouse1press / mousemoveabs
--   no CFrame or Position writes, no teleport
-- It only reads the two rollers' Info labels on your plot and reports
-- what changed. That is the only thing proven to work in this VM.
--
-- Why it cannot roll for you:
--   every input route was tested against the roller ProximityPrompt and
--   none of them reach it (keypress inert, setrobloxinput moves the
--   character but not the prompt, mouse1click and mouse1press/release on
--   the prompt button do nothing, fireproximityprompt is absent).
--   So this script watches and tells you; you press the prompt.
--
-- Use:
--   _G.RollerMods.status()   -> print both rollers now
--   _G.RollerMods.stop()     -> stop watching

local NAME    = 'RollerMods'
local VERSION = 'v15.0'

if _G[NAME] and _G[NAME].stop then
    pcall(_G[NAME].stop)
end
print('[' .. NAME .. '] ' .. VERSION)

local Players = game:GetService('Players')
local ws      = game:GetService('Workspace')
local lp      = Players.LocalPlayer

local alive  = true
local built  = false
local conn   = nil

local RARITIES = {
    'Common', 'Uncommon', 'Rare', 'Epic', 'Legendary',
    'Mythical', 'Secret', 'Divine', 'Celestial',
}

local state = {
    watchW = true,
    watchB = true,
    alert  = {},
}
for _, r in ipairs(RARITIES) do state.alert[r] = true end

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
    print('[' .. NAME .. '] ' .. tag .. ': ' .. item .. ' (' .. tostring(rar) .. ')')
    if state.alert[rar] then
        pcall(notify, tag .. ': ' .. item .. ' (' .. tostring(rar) .. ')', 'Rollers', 4)
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

conn = task.spawn(function()
    while alive do
        tickOnce()
        task.wait(0.5)
    end
end)

-- status --------------------------------------------------------------

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
        local secA = mkSection(tab, 'Alert on')
        if secA then
            for _, r in ipairs(RARITIES) do
                mkToggle(secA, r, 'rw_a_' .. string.lower(r), true, function(v)
                    state.alert[r] = v
                end)
            end
        end
    end)
    if not ok then warn('[' .. NAME .. '] build error: ' .. tostring(err)) end
    print('[' .. NAME .. '] tab built')
end

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

_G[NAME] = { stop = stop, status = status, version = VERSION, state = state }
print('[' .. NAME .. '] ' .. VERSION .. ' loaded - watch only, no input, no movement')
