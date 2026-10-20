-- Build and Kill Zombies -> Auto Roll and Buy - Matcha LuauVM - v12.0
-- place 105011592530400
-- The old Freeze Enemies feature is gone. This version drives the two
-- rollers on your plot: RollWeapons and RollBlocks.
--
-- Menu layout (one tab, two sections):
--   Weapon Roller : Auto Roll Weapons + one Buy toggle per rarity
--   Block Roller  : Auto Roll Blocks  + one Buy toggle per rarity
--
-- How it works (nothing in this game can be constructed, so no clicks):
--   both rollers are ProximityPrompts. Rolling is the prompt on
--   <Roller>.Roll, buying is the prompt under <Roller>.ItemPlace.
--   The loop parks the character on the prompt part for a moment, holds E,
--   then puts the character straight back where it was.
--   Result is read from <Roller>.Info.Rarity / <Roller>.Info.ItemName.
--   '???' means nothing has been rolled yet.
--
-- Writable set used: HumanoidRootPart.CFrame (short, on demand only).

local NAME    = 'RollerMods'
local VERSION = 'v12.0'

if _G[NAME] and _G[NAME].stop then
    pcall(_G[NAME].stop)
end
print('[' .. NAME .. '] ' .. VERSION)

local Players = game:GetService('Players')
local ws      = game:GetService('Workspace')
local lp      = Players.LocalPlayer

local alive = true
local built = false

local state = {
    autoW = false,
    autoB = false,
    buyW  = {},
    buyB  = {},
}

local RARITIES = {
    'Common', 'Uncommon', 'Rare', 'Epic', 'Legendary',
    'Mythical', 'Secret', 'Divine', 'Celestial',
}

-- locate -------------------------------------------------------------

local cachedPlot = nil

local function plotsFolder()
    local g = ws:FindFirstChild('Game')
    local l = g and g:FindFirstChild('Lobby')
    return l and l:FindFirstChild('Plots')
end

local function billboardOwner(plot)
    local ob = plot:FindFirstChild('OwnerBillboard')
    local bg = ob and ob:FindFirstChild('BillboardGui')
    if not bg then return nil end
    local found = nil
    local function walk(n, d)
        if found or d > 4 then return end
        for _, c in ipairs(n:GetChildren()) do
            if c.ClassName == 'TextLabel' and c.Text ~= '' then
                found = c.Text
                return
            end
            walk(c, d + 1)
        end
    end
    walk(bg, 0)
    return found
end

local function nearestPlot()
    local pf = plotsFolder()
    local char = lp.Character
    local root = char and char:FindFirstChild('HumanoidRootPart')
    if not pf or not root then return nil end
    local best = nil
    local bd = math.huge
    for _, p in ipairs(pf:GetChildren()) do
        local anchor = p:FindFirstChild('PlayerSpawn') or p:FindFirstChild('Placement')
        if anchor then
            local d = (anchor.Position - root.Position).Magnitude
            if d < bd then
                bd = d
                best = p
            end
        end
    end
    return best
end

local function getPlot()
    local pf = plotsFolder()
    if not pf then return nil end
    if cachedPlot and cachedPlot.Parent then return cachedPlot end
    for _, p in ipairs(pf:GetChildren()) do
        local owner = billboardOwner(p)
        if owner and owner == lp.Name then
            cachedPlot = p
            return p
        end
    end
    cachedPlot = nearestPlot()
    return cachedPlot
end

-- prompt driving -----------------------------------------------------

local function holdE(secs)
    pcall(keypress, Enum.KeyCode.E)
    task.wait(secs or 0.2)
    pcall(keyrelease, Enum.KeyCode.E)
end

local function tpTo(part)
    local char = lp.Character
    local root = char and char:FindFirstChild('HumanoidRootPart')
    if not root or not part then return nil end
    local save = root.CFrame
    pcall(function()
        root.CFrame = CFrame.new(part.Position + Vector3.new(0, 2.5, 0))
    end)
    task.wait(0.1)
    return save
end

local function tpBack(save)
    if not save then return end
    local char = lp.Character
    local root = char and char:FindFirstChild('HumanoidRootPart')
    if root then
        pcall(function() root.CFrame = save end)
    end
    task.wait(0.1)
end

local function readInfo(roller, field)
    local info = roller and roller:FindFirstChild('Info')
    local lbl  = info and info:FindFirstChild(field)
    if lbl then return lbl.Text end
    return nil
end

local function doRoll(roller)
    local rollPart = roller and roller:FindFirstChild('Roll')
    if not rollPart then return false end
    local before = readInfo(roller, 'ItemName')
    local save = tpTo(rollPart)
    holdE(0.25)
    tpBack(save)
    local t0 = tick()
    while alive and (tick() - t0) < 4 do
        task.wait(0.15)
        local now = readInfo(roller, 'ItemName')
        if now and now ~= before and now ~= '???' then return true end
    end
    return false
end

local function doBuy(roller)
    local ip = roller and roller:FindFirstChild('ItemPlace')
    if not ip then return false end
    local save = tpTo(ip)
    holdE(0.25)
    tpBack(save)
    task.wait(0.2)
    return true
end

-- loop ---------------------------------------------------------------

local function runOne(roller, autoFlag, buyMap, tag)
    if not autoFlag then return end
    if not doRoll(roller) then return end
    local rar  = readInfo(roller, 'Rarity') or '?'
    local item = readInfo(roller, 'ItemName') or '?'
    print('[' .. NAME .. '] ' .. tag .. ' rolled ' .. item .. ' (' .. rar .. ')')
    if buyMap[rar] then
        doBuy(roller)
        print('[' .. NAME .. '] ' .. tag .. ' bought ' .. item)
    end
end

task.spawn(function()
    while alive do
        local plot = getPlot()
        local rolls = plot and plot:FindFirstChild('Rolls')
        if rolls and (state.autoW or state.autoB) then
            local W = rolls:FindFirstChild('RollWeapons')
            local B = rolls:FindFirstChild('RollBlocks')
            runOne(W, state.autoW, state.buyW, 'weapons')
            runOne(B, state.autoB, state.buyB, 'blocks')
        end
        task.wait(0.4)
    end
end)

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
        local secW = mkSection(tab, 'Weapon Roller')
        if secW then
            mkToggle(secW, 'Auto Roll Weapons', 'rb_auto_w', false, function(v)
                state.autoW = v
                print('[' .. NAME .. '] weapon auto roll ' .. (v and 'on' or 'off'))
            end)
            for _, rar in ipairs(RARITIES) do
                local key = string.lower(rar)
                mkToggle(secW, 'Buy ' .. rar, 'rb_w_' .. key, false, function(v)
                    state.buyW[rar] = v
                end)
            end
        end

        local secB = mkSection(tab, 'Block Roller')
        if secB then
            mkToggle(secB, 'Auto Roll Blocks', 'rb_auto_b', false, function(v)
                state.autoB = v
                print('[' .. NAME .. '] block auto roll ' .. (v and 'on' or 'off'))
            end)
            for _, rar in ipairs(RARITIES) do
                local key = string.lower(rar)
                mkToggle(secB, 'Buy ' .. rar, 'rb_b_' .. key, false, function(v)
                    state.buyB[rar] = v
                end)
            end
        end
    end)

    if not ok then
        warn('[' .. NAME .. '] build error: ' .. tostring(err))
    end
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
else
    warn('[' .. NAME .. '] no UI table - menu unavailable')
end

-- stop ---------------------------------------------------------------

local function stop()
    alive = false
    state.autoW = false
    state.autoB = false
    state.buyW = {}
    state.buyB = {}
    cachedPlot = nil
    pcall(keyrelease, Enum.KeyCode.E)
    if HAS_UI then
        pcall(function() UI.RemoveTab('Rollers') end)
    end
    _G[NAME] = nil
    print('[' .. NAME .. '] stopped')
end

_G[NAME] = { stop = stop, version = VERSION, state = state }
print('[' .. NAME .. '] ' .. VERSION .. ' loaded, menu=' .. tostring(HAS_UI) .. ' - Rollers tab')
