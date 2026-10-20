-- Build and Kill Zombies -> Auto Roll and Buy - Matcha LuauVM - v13.1
-- place 105011592530400
--
-- Root causes found by live probing (this is why v12 and v13 did nothing):
--   1. keypress/keyrelease are INERT in this VM. keypress(87) returns ok,
--      iskeypressed stays false, character moves 0 studs. The prompt was
--      never pressed. The working primitive is
--      setrobloxinput(pressed, keycode) with the BOOLEAN FIRST:
--      setrobloxinput(true, 87) moved the character 7.12 studs.
--      setrobloxinput(87, true) moved 0.
--   2. The plot is identified by the OwnerUserId attribute, not by the
--      OwnerBillboard text. Live: Plot3 uid=2251313101 == LocalPlayer.
--      UserId, while its billboard read 'Tundr'. v12/v13 rolled another
--      player's roller.
--   3. A save dialog ('You haven't saved changes on This Build') can sit
--      open and block the prompt. It is dismissed first, every attempt.
--
-- Menu: one Rollers tab, two sections (Weapon Roller / Block Roller),
-- an auto roll toggle plus one buy toggle per rarity in each.

local NAME    = 'RollerMods'
local VERSION = 'v13.1'

if _G[NAME] and _G[NAME].stop then
    pcall(_G[NAME].stop)
end
print('[' .. NAME .. '] ' .. VERSION)

local Players = game:GetService('Players')
local ws      = game:GetService('Workspace')
local lp      = Players.LocalPlayer

local KEY_E = 69

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

-- input: setrobloxinput(pressed, keycode) ----------------------------

local function setKey(code, down)
    pcall(setrobloxinput, down, code)
end

local function tapKey(code, secs)
    setKey(code, true)
    task.wait(secs or 0.6)
    setKey(code, false)
    task.wait(0.1)
end

-- confirmation / save dialog -----------------------------------------

local function dialog()
    local pg   = lp:FindFirstChild('PlayerGui')
    local mg   = pg and pg:FindFirstChild('MainGui')
    local mn   = mg and mn and mg:FindFirstChild('Menu')
    if not mn then
        mn = mg and mg:FindFirstChild('Menu')
    end
    local cf   = mn and mn:FindFirstChild('Confirmation')
    local btns = cf and cf:FindFirstChild('Buttons')
    local inf  = cf and cf:FindFirstChild('Information')
    return btns, (inf and inf.Text) or ''
end

local function clickBtn(btn)
    if not btn then return false end
    local p, s = btn.AbsolutePosition, btn.AbsoluteSize
    if not p or not s then return false end
    if s.X < 4 or s.Y < 4 then return false end
    pcall(mousemoveabs, p.X + s.X * 0.5, p.Y + s.Y * 0.5)
    task.wait(0.06)
    pcall(mouse1click)
    return true
end

local function clearDialog()
    local btns, txt = dialog()
    if txt == '' then return false end
    local lower  = string.lower(txt)
    local target = btns and btns:FindFirstChild('Yes')
    if string.find(lower, 'save', 1, true) then
        target = btns and btns:FindFirstChild('No')
    end
    clickBtn(target)
    task.wait(0.25)
    return true
end

-- plot: OwnerUserId first, then nearest -----------------------------

local plotOrder  = {}
local orderIndex = 1

local function buildOrder()
    local pf   = plotsFolder()
    local root = getRoot()
    plotOrder  = {}
    if not pf then return end
    local mine = nil
    local rest = {}
    for _, p in ipairs(pf:GetChildren()) do
        if p:GetAttribute('OwnerUserId') == lp.UserId then
            mine = p
        else
            local anchor = p:FindFirstChild('PlayerSpawn') or p:FindFirstChild('Placement')
            local d = 999999
            if anchor and root then d = (anchor.Position - root.Position).Magnitude end
            rest[#rest + 1] = { plot = p, d = d }
        end
    end
    table.sort(rest, function(a, b) return a.d < b.d end)
    if mine then plotOrder[#plotOrder + 1] = mine end
    for _, e in ipairs(rest) do plotOrder[#plotOrder + 1] = e.plot end
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
    local p = currentPlot()
    print('[' .. NAME .. '] ' .. reason .. ' -> trying ' .. tostring(p and p.Name))
end

-- actions -------------------------------------------------------------

local function standOn(part)
    local root = getRoot()
    if not root or not part then return nil end
    local save = root.CFrame
    local pos  = part.Position
    pcall(function() root.CFrame = CFrame.new(pos.X, pos.Y + 3, pos.Z) end)
    return save
end

local function restore(save)
    if not save then return end
    local root = getRoot()
    if root then pcall(function() root.CFrame = save end) end
end

local function doRoll(roller)
    local part = roller and roller:FindFirstChild('Roll')
    if not part then return false end
    clearDialog()
    local before = readInfo(roller, 'ItemName')
    local save = standOn(part)
    task.wait(0.5)
    tapKey(KEY_E, 1.1)
    clearDialog()
    local changed = false
    local t0 = tick()
    while alive and (tick() - t0) < 3 do
        task.wait(0.15)
        if clearDialog() then task.wait(0.2) end
        local now = readInfo(roller, 'ItemName')
        if now and now ~= before and now ~= '???' then
            changed = true
            break
        end
    end
    restore(save)
    task.wait(0.15)
    return changed
end

local function doBuy(roller)
    local ip = roller and roller:FindFirstChild('ItemPlace')
    if not ip then return false end
    clearDialog()
    local before = itemPlaceCount(roller)
    if before == 0 then return false end
    local save = standOn(ip)
    task.wait(0.5)
    tapKey(KEY_E, 1.1)
    clearDialog()
    local bought = false
    local t0 = tick()
    while alive and (tick() - t0) < 2.5 do
        task.wait(0.15)
        if clearDialog() then task.wait(0.2) end
        if itemPlaceCount(roller) < before then
            bought = true
            break
        end
    end
    restore(save)
    task.wait(0.15)
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
            local plot  = currentPlot()
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
    pcall(setrobloxinput, false, KEY_E)
    if HAS_UI then
        pcall(function() UI.RemoveTab('Rollers') end)
    end
    _G[NAME] = nil
    print('[' .. NAME .. '] stopped')
end

_G[NAME] = { stop = stop, version = VERSION, state = state, plots = function() return plotOrder end }
print('[' .. NAME .. '] ' .. VERSION .. ' loaded, menu=' .. tostring(HAS_UI) .. ' - Rollers tab')
