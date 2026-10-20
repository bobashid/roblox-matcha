-- Build and Kill Zombies -> Auto Roll (prompt gated) - Matcha LuauVM - v28.1
-- place 105011592530400
--
-- v28.1 fixes two bugs in v28.0:
--   1. ItemPlace contains a DISPLAY model named 'Normal' (and 'Golden',
--      'Rainbow' for the fancy frames). v28.0 treated that as an un-bought
--      item and would have skipped every press with
--      'roller blocked by pending Normal'. Those names are now ignored.
--   2. The final print() was missing its closing paren, which is a syntax
--      error at load. Fixed.
--
-- What it does:
--   checks the roller prompt BEFORE pressing. Presses E only when
--   ProximityPrompts has a child and that child has a button with a
--   non-zero AbsoluteSize. Waits up to 2s for that. If the prompt never
--   appears it prints 'prompt not up' and does not press.
--
-- Three distinguishable outcomes in the log:
--   prompt not up            -> the game is not offering the prompt
--   roller blocked by X      -> a real un-bought item is sitting there
--   prompt was up, press ignored -> the prompt exists and rejected E
--
-- No setrobloxinput anywhere. keypress/keyrelease only.
--
-- Menu: Rollers tab, one section
--   Enabled, Roll Weapons, Roll Blocks, Teleport to roller

local NAME    = 'RollerMods'
local VERSION = 'v28.1'

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

-- display frames inside ItemPlace are not pending items ----------------

local DISPLAY_NAMES = { Normal = true, Golden = true, Rainbow = true }

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

local function pendingItem(roller)
    local ip = roller and roller:FindFirstChild('ItemPlace')
    if not ip then return nil end
    for _, c in ipairs(ip:GetChildren()) do
        local cn = c.ClassName
        if cn == 'Model' or cn == 'MeshPart' or cn == 'Part' then
            if not DISPLAY_NAMES[c.Name] then
                return c.Name
            end
        end
    end
    return nil
end

local function getRoot()
    local char = lp.Character
    return char and char:FindFirstChild('HumanoidRootPart')
end

-- prompt check --------------------------------------------------------

local function promptState()
    local pg = lp:FindFirstChild('PlayerGui')
    local pp = pg and pg:FindFirstChild('ProximityPrompts')
    if not pp then return false, 0, false end
    local kids = #pp:GetChildren()
    local clickable = false
    for _, root in ipairs(pp:GetChildren()) do
        for _, g in ipairs(root:GetDescendants()) do
            local cn = g.ClassName
            if cn == 'TextButton' or cn == 'ImageButton' then
                local s = g.AbsoluteSize
                if s and s.X > 2 and s.Y > 2 then clickable = true end
            end
        end
    end
    return kids > 0, kids, clickable
end

local function waitForPrompt(secs)
    local t0 = tick()
    while alive and (tick() - t0) < secs do
        local up = promptState()
        if up then return true end
        wait(0.2)
    end
    return false
end

-- one roll ------------------------------------------------------------

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

    local before  = read(roller, 'ItemName')
    local pending = pendingItem(roller)
    local up, kids, clickable = promptState()
    print('[' .. NAME .. '] ' .. tag .. ' before=' .. tostring(before)
        .. ' pending=' .. tostring(pending)
        .. ' prompt=' .. tostring(up) .. '(' .. tostring(kids) .. ')'
        .. ' clickable=' .. tostring(clickable))

    if pending then
        print('[' .. NAME .. '] ' .. tag .. ' roller blocked by pending ' .. pending .. ' - buy it by hand')
        if saved then
            local r0 = getRoot()
            if r0 then pcall(function() r0.CFrame = saved end) end
        end
        return
    end

    if not up then
        local appeared = waitForPrompt(2)
        up, kids, clickable = promptState()
        print('[' .. NAME .. '] ' .. tag .. ' waited for prompt -> ' .. tostring(appeared)
            .. ' prompt=' .. tostring(up) .. '(' .. tostring(kids) .. ')')
        if not appeared then
            print('[' .. NAME .. '] ' .. tag .. ' prompt not up - stand closer to the roller')
            if saved then
                local r1 = getRoot()
                if r1 then pcall(function() r1.CFrame = saved end) end
            end
            return
        end
    end

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
        print('[' .. NAME .. '] ' .. tag .. ' ROLLED ' .. got .. ' (' .. tostring(read(roller, 'Rarity')) .. ')')
        pcall(notify, tag .. ': ' .. got, 'Rollers', 3)
    else
        print('[' .. NAME .. '] ' .. tag .. ' prompt was up, press ignored (still ' .. tostring(read(roller, 'ItemName')) .. ')')
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

-- status inside a spawn -----------------------------------------------

task.spawn(function()
    local p = myPlot()
    if not p then
        print('[' .. NAME .. '] no plot with your OwnerUserId (' .. lp.UserId .. ')')
        return
    end
    local w, b = rollers()
    print('[' .. NAME .. '] plot ' .. p.Name)
    print('[' .. NAME .. '] weapons ' .. tostring(read(w, 'ItemName')) .. ' (' .. tostring(read(w, 'Rarity')) .. ') pending=' .. tostring(pendingItem(w)))
    print('[' .. NAME .. '] blocks  ' .. tostring(read(b, 'ItemName')) .. ' (' .. tostring(read(b, 'Rarity')) .. ') pending=' .. tostring(pendingItem(b)))
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
            mkToggle(sec, 'Enabled', 'g1_on', false, function(v) running = v end)
            mkToggle(sec, 'Roll Weapons', 'g1_w', false, function(v) doW = v end)
            mkToggle(sec, 'Roll Blocks', 'g1_b', false, function(v) doB = v end)
            mkToggle(sec, 'Teleport to roller', 'g1_tp', false, function(v) teleport = v end)
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
print('[' .. NAME .. '] ' .. VERSION .. ' loaded - prompt gated, keypress only')
