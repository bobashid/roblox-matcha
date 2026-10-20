-- Build and Kill Zombies -> Auto Roll and Buy - Matcha LuauVM - v13.0
-- place 105011592530400
--
-- What v12 got wrong, proven by the RollController decompile:
--   1. OwnerBillboard text is not the username (plots read O_CsF, Tundr,
--      PlayerName, Borisder_2, Kozak). v12 silently fell back to the
--      nearest plot and rolled on somebody else.
--   2. RollController enables each roller's ProximityPrompt from
--      OwnerUserId / 70 studs, and the roll can be gated by the
--      Confirmation dialog (Menu.Confirmation). v12 pressed E for 0.25s
--      and never clicked ACCEPT.
--   3. Matcha cannot read ProximityPrompt.Enabled/HoldDuration, so the
--      script has to stay on the part long enough and poll the result.
--
-- v13 changes:
--   * plots are ordered by distance, and a plot that refuses to roll is
--     abandoned for the next one (logged).
--   * E is held 0.55s with the character standing on the prompt, then
--     the Confirmation dialog is clicked if it opened.
--   * roll success is proven by Info.ItemName changing before it is
--     counted, so a buy never fires on a stale label.
--   * buy success is proven by the ItemPlace model count dropping.

local NAME    = 'RollerMods'
local VERSION = 'v13.0'

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

-- helpers ------------------------------------------------------------

local function getRoot()
    local char = lp.Character
    return char and char:FindFirstChild('HumanoidRootPart')
end

local function plotsFolder()
    local g = ws:FindFirstChild('Game')
    local l = g and g:FindFirstChild('Lobby')
    return l and l:FindFirstChild('Plots')
end

local function readInfo(roller, field)
    local info = roller and roller:FindFirstChild('Info')
    local lbl  = info and info:FindFirstChild(field)
    if lbl then return lbl.Text end
    return nil
end

local function itemPlaceCount(roller)
    local ip = roller and roller:FindFirstChild('ItemPlace')
    if not ip then return 0 end
    local n = 0
    for _, c in ipairs(ip:GetChildren()) do
        local cn = c.ClassName
        if cn == 'Model' or cn == 'MeshPart' or cn == 'Part' then n = n + 1 end
    end
    return n
end

-- plot order: nearest first, name match promoted ---------------------

local plotOrder  = {}
local orderIndex = 1

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

local function buildOrder()
    local pf  = plotsFolder()
    local root = getRoot()
    local list = {}
    if not pf then plotOrder = {} return end
    for _, p in ipairs(pf:GetChildren()) do
        local anchor = p:FindFirstChild('PlayerSpawn') or p:FindFirstChild('Placement')
        local d = 999999
        if anchor and root then d = (anchor.Position - root.Position).Magnitude end
        local owner = billboardOwner(p)
        if owner and owner == lp.Name then d = -1 end
        list[#list + 1] = { plot = p, d = d }
    end
    table.sort(list, function(a, b) return a.d < b.d end)
    plotOrder = {}
    for i, e in ipairs(list) do plotOrder[i] = e.plot end
    if orderIndex > #plotOrder then orderIndex = 1 end
end

local function currentPlot()
    if #plotOrder == 0 then buildOrder() end
    return plotOrder[orderIndex]
end

local function nextPlot(reason)
    if #plotOrder == 0 then return end
    orderIndex = orderIndex + 1
    if orderIndex > #plotOrder then orderIndex = 1 end
    print('[' .. NAME .. '] ' .. reason .. ' -> trying ' .. tostring(currentPlot() and currentPlot().Name))
end

-- confirmation dialog -------------------------------------------------

local function confirmIfOpen()
    local pg   = lp:FindFirstChild('PlayerGui')
    local mg   = pg and pg:FindFirstChild('MainGui')
    local menu = mg and mg:FindFirstChild('Menu')
    local conf = menu and menu:FindFirstChild('Confirmation')
    if not conf then return false end
    local info = conf:FindFirstChild('Information')
    if not info or info.Text == '' then return false end
    local btns = conf:FindFirstChild('Buttons')
    local yes  = btns and btns:FindFirstChild('Yes')
    if not yes then return false end
    local pos, size = yes.AbsolutePosition, yes.AbsoluteSize
    if not pos or not size then return false end
    if size.X < 4 or size.Y < 4 then return false end
    pcall(mousemoveabs, pos.X + size.X * 0.5, pos.Y + size.Y * 0.5)
    task.wait(0.05)
    pcall(mouse1click)
    return true
end

-- prompt driving -----------------------------------------------------

local function standOn(part)
    local root = getRoot()
    if not root or not part then return nil end
    local save = root.CFrame
    pcall(function()
        root.CFrame = CFrame.new(part.Position + Vector3.new(0, 3, 0))
    end)
    return save
end

local function restore(save)
    if not save then return end
    local root = getRoot()
    if root then pcall(function() root.CFrame = save end) end
end

local function pressE()
    pcall(keypress, Enum.KeyCode.E)
    task.wait(0.55)
    pcall(keyrelease, Enum.KeyCode.E)
    task.wait(0.15)
end

local function doRoll(roller)
    local part = roller and roller:FindFirstChild('Roll')
    if not part then return false end
    local before = readInfo(roller, 'ItemName')
    local save = standOn(part)
    task.wait(0.4)
    pressE()
    confirmIfOpen()
    local changed = false
    local t0 = tick()
    while alive and (tick() - t0) < 3 do
        task.wait(0.1)
        confirmIfOpen()
        local now = readInfo(roller, 'ItemName')
        if now and now ~= before and now ~= '???' then
            changed = true
            break
        end
    end
    restore(save)
    task.wait(0.1)
    return changed
end

local function doBuy(roller)
    local ip = roller and roller:FindFirstChild('ItemPlace')
    if not ip then return false end
    local before = itemPlaceCount(roller)
    if before == 0 then return false end
    local save = standOn(ip)
    task.wait(0.4)
    pressE()
    confirmIfOpen()
    local bought = false
    local t0 = tick()
    while alive and (tick() - t0) < 2.5 do
        task.wait(0.1)
        confirmIfOpen()
        if itemPlaceCount(roller) < before then
            bought = true
            break
        end
    end
    restore(save)
    task.wait(0.1)
    return bought
end

-- loop ---------------------------------------------------------------

local fails = 0

local function runOne(roller, autoFlag, buyMap, tag)
    if not autoFlag or not roller then return end
    if doRoll(roller) then
        fails = 0
        local rar  = readInfo(roller, 'Rarity') or '?'
        local item = readInfo(roller, 'ItemName') or '?'
        print('[' .. NAME .. '] ' .. tag .. ' rolled ' .. item .. ' (' .. rar .. ')')
        if buyMap[rar] then
            if doBuy(roller) then
                print('[' .. NAME .. '] ' .. tag .. ' bought ' .. item)
            else
                print('[' .. NAME .. '] ' .. tag .. ' buy failed for ' .. item)
            end
        end
    else
        fails = fails + 1
        if fails >= 2 then
            fails = 0
            nextPlot(tag .. ' not responding')
        end
    end
end

task.spawn(function()
    while alive do
        if state.autoW or state.autoB then
            local plot = currentPlot()
            local rolls = plot and plot:FindFirstChild('Rolls')
            if rolls then
                runOne(rolls:FindFirstChild('RollWeapons'), state.autoW, state.buyW, 'weapons')
                runOne(rolls:FindFirstChild('RollBlocks'),  state.autoB, state.buyB, 'blocks')
            end
        end
        task.wait(0.3)
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
                fails = 0
                if v then buildOrder() end
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
                fails = 0
                if v then buildOrder() end
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

buildOrder()

-- stop ---------------------------------------------------------------

local function stop()
    alive = false
    state.autoW = false
    state.autoB = false
    state.buyW = {}
    state.buyB = {}
    plotOrder = {}
    orderIndex = 1
    pcall(keyrelease, Enum.KeyCode.E)
    if HAS_UI then
        pcall(function() UI.RemoveTab('Rollers') end)
    end
    _G[NAME] = nil
    print('[' .. NAME .. '] stopped')
end

_G[NAME] = { stop = stop, version = VERSION, state = state, plots = function() return plotOrder end }
print('[' .. NAME .. '] ' .. VERSION .. ' loaded, menu=' .. tostring(HAS_UI) .. ' - Rollers tab')
