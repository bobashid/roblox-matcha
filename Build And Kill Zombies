-- Build and Kill Zombies -> Auto Roll Both - Matcha LuauVM - v30.0
-- place 105011592530400
--
-- WHAT WAS ACTUALLY BROKEN IN v29.1, found by a live check this session:
--   1. THE PENDING GUARD. Plot1 reported
--          W = Mini Missile   pendW = MiniMissile
--          B = DoubleBarrels  pendB = DoubleBarrels
--      so v29.1 printed 'blocked by pending' and returned WITHOUT EVER
--      PRESSING. Every pass, forever. The guard is removed: a pending item
--      is logged, not obeyed. The Roll prompt is enabled by OwnerUserId /
--      distance in RollController, not by pending state.
--   2. ONE PRESS METHOD ONLY. Each attempt now tries three, in order:
--          a) keypress E held 1.0s
--          b) keypress E held 2.2s   (in case HoldDuration is longer)
--          c) mouse1press held 1.2s on the prompt button, only if that
--             button has a real size (>2x2)
--      The log says which one produced the change.
--   3. 'press ignored' now means all three failed, not one.
--
-- NEW: 'Clear pending first' (default ON). Before rolling it teleports to
-- ItemPlace and presses E once, which buys the item sitting on the roller.
-- That is what actually unblocks a roller. Turn it off if you never want a
-- buy attempt.
--
-- setrobloxinput is never called. That is the API that froze the client.
-- Only keypress / keyrelease / mousemoveabs / mouse1press / mouse1release.
--
-- Menu: Rollers tab
--   Roll section
--     Enabled             master, default off - the stop
--     Auto Roll Both      one toggle rolls weapons then blocks
--     Teleport to roller  default ON
--     Clear pending first default ON

local NAME    = 'RollerMods'
local VERSION = 'v30.0'

if _G[NAME] and _G[NAME].stop then
    pcall(_G[NAME].stop)
end
print('[' .. NAME .. '] ' .. VERSION)

local Players = game:GetService('Players')
local ws      = game:GetService('Workspace')
local lp      = Players.LocalPlayer

local alive      = true
local running    = false
local autoBoth   = false
local teleport   = true
local clearFirst = true

local COOLDOWN_OK   = 3
local COOLDOWN_MISS = 6
local MAX_MISSES    = 6
local misses        = 0

local DISPLAY_NAMES = { Normal = true, Golden = true, Rainbow = true }

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

local function pendingItem(roller)
    local ip = roller and roller:FindFirstChild('ItemPlace')
    if not ip then return nil end
    for _, c in ipairs(ip:GetChildren()) do
        local cn = c.ClassName
        if cn == 'Model' or cn == 'MeshPart' or cn == 'Part' then
            if not DISPLAY_NAMES[c.Name] then return c.Name end
        end
    end
    return nil
end

local function getRoot()
    local char = lp.Character
    return char and char:FindFirstChild('HumanoidRootPart')
end

-- prompt inspection ---------------------------------------------------

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

local function promptButton()
    local pg = lp:FindFirstChild('PlayerGui')
    local pp = pg and pg:FindFirstChild('ProximityPrompts')
    if not pp then return nil end
    for _, root in ipairs(pp:GetChildren()) do
        for _, g in ipairs(root:GetDescendants()) do
            local cn = g.ClassName
            if cn == 'TextButton' or cn == 'ImageButton' then
                local p, s = g.AbsolutePosition, g.AbsoluteSize
                if p and s and s.X > 2 and s.Y > 2 then return g, p, s end
            end
        end
    end
    return nil
end

-- teleport, saved once per pass ---------------------------------------

local function goTo(part, cyc)
    if not teleport then return end
    local root = getRoot()
    if not root or not part then return end
    if not cyc.saved then cyc.saved = root.CFrame end
    local p = part.Position
    pcall(function() root.CFrame = CFrame.new(p.X, p.Y + 2, p.Z) end)
end

local function goBack(cyc)
    if not cyc.saved then return end
    local root = getRoot()
    if root then pcall(function() root.CFrame = cyc.saved) end end
    cyc.saved = nil
end

-- the only loop -------------------------------------------------------

task.spawn(function()
    local function waitForPrompt(secs)
        local t0 = tick()
        while alive and (tick() - t0) < secs do
            if (promptState()) then return true end
            wait(0.2)
        end
        return false
    end

    local function pressKey(secs)
        pcall(keypress, Enum.KeyCode.E)
        wait(secs)
        pcall(keyrelease, Enum.KeyCode.E)
        pcall(keyrelease, Enum.KeyCode.E)
    end

    local function pressMouse(secs)
        local btn, bp, bs = promptButton()
        if not btn then return false end
        pcall(mousemoveabs, bp.X + bs.X * 0.5, bp.Y + bs.Y * 0.5)
        wait(0.15)
        pcall(mouse1press)
        wait(secs)
        pcall(mouse1release)
        return true
    end

    local function watchChange(roller, before, secs)
        local t0 = tick()
        while alive and (tick() - t0) < secs do
            wait(0.2)
            local now = read(roller, 'ItemName')
            if now and now ~= before and now ~= '???' then return now end
        end
        return nil
    end

    -- buy the item sitting on the roller, so the next roll is not wasted
    local function clearPending(roller, tag, cyc)
        local pend = pendingItem(roller)
        if not pend then return false end
        local ip = roller:FindFirstChild('ItemPlace')
        if not ip then return false end
        goTo(ip, cyc)
        wait(0.6)
        if not (promptState()) then waitForPrompt(2.5) end
        pressKey(1.2)
        local t0 = tick()
        while alive and (tick() - t0) < 2.5 do
            wait(0.2)
            if pendingItem(roller) ~= pend then
                print('[' .. NAME .. '] ' .. tag .. ' cleared pending ' .. pend)
                return true
            end
        end
        print('[' .. NAME .. '] ' .. tag .. ' could not clear pending ' .. pend)
        return false
    end

    local function rollOne(roller, tag, cyc)
        local part = roller and roller:FindFirstChild('Roll')
        if not part then return false end

        goTo(part, cyc)
        wait(0.6)

        local before = read(roller, 'ItemName')
        local pend   = pendingItem(roller)
        local up, kids, clickable = promptState()

        print('[' .. NAME .. '] ' .. tag .. ' before=' .. tostring(before)
            .. ' pending=' .. tostring(pend)
            .. ' prompt=' .. tostring(up) .. '(' .. tostring(kids) .. ')'
            .. ' clickable=' .. tostring(clickable))

        if not up then
            if not waitForPrompt(2.5) then
                print('[' .. NAME .. '] ' .. tag .. ' prompt never appeared')
                return false
            end
        end

        pressKey(1.0)
        local got = watchChange(roller, before, 2.0)
        if got then
            print('[' .. NAME .. '] ' .. tag .. ' ROLLED ' .. got .. ' via key-1.0')
            pcall(notify, tag .. ': ' .. got, 'Rollers', 3)
            return true
        end

        pressKey(2.2)
        got = watchChange(roller, before, 2.0)
        if got then
            print('[' .. NAME .. '] ' .. tag .. ' ROLLED ' .. got .. ' via key-2.2')
            pcall(notify, tag .. ': ' .. got, 'Rollers', 3)
            return true
        end

        if promptButton() then
            pressMouse(1.2)
            got = watchChange(roller, before, 2.0)
            if got then
                print('[' .. NAME .. '] ' .. tag .. ' ROLLED ' .. got .. ' via mouse')
                pcall(notify, tag .. ': ' .. got, 'Rollers', 3)
                return true
            end
        end

        print('[' .. NAME .. '] ' .. tag .. ' all 3 press methods ignored (still '
            .. tostring(read(roller, 'ItemName')) .. ')')
        return false
    end

    while alive do
        if running and autoBoth then
            local cyc = {}
            local any = false

            local w, b = rollers()
            if w then
                if clearFirst then clearPending(w, 'weapons', cyc) end
                if rollOne(w, 'weapons', cyc) then any = true end
            end
            if b then
                if clearFirst then clearPending(b, 'blocks', cyc) end
                if rollOne(b, 'blocks', cyc) then any = true end
            end

            goBack(cyc)

            if any then
                misses = 0
                wait(COOLDOWN_OK)
            else
                misses = misses + 1
                print('[' .. NAME .. '] dead pass ' .. misses .. '/' .. MAX_MISSES
                    .. ' - waiting ' .. COOLDOWN_MISS .. 's')
                if misses >= MAX_MISSES then
                    running  = false
                    autoBoth = false
                    misses   = 0
                    print('[' .. NAME .. '] switched off - no press method worked ' .. MAX_MISSES .. ' passes in a row')
                    pcall(notify, 'auto roll off: prompt ignored every press', 'Rollers', 8)
                else
                    wait(COOLDOWN_MISS)
                end
            end
        else
            wait(0.5)
        end
    end
end)

-- status inside a spawn so load never yields --------------------------

task.spawn(function()
    local p = myPlot()
    if not p then
        print('[' .. NAME .. '] no plot with your OwnerUserId (' .. lp.UserId .. ')')
        return
    end
    local w, b = rollers()
    print('[' .. NAME .. '] plot ' .. p.Name)
    print('[' .. NAME .. '] weapons ' .. tostring(read(w, 'ItemName'))
        .. ' (' .. tostring(read(w, 'Rarity')) .. ') pending=' .. tostring(pendingItem(w)))
    print('[' .. NAME .. '] blocks  ' .. tostring(read(b, 'ItemName'))
        .. ' (' .. tostring(read(b, 'Rarity')) .. ') pending=' .. tostring(pendingItem(b)))
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
            mkToggle(sec, 'Enabled', 'j1_on', false, function(v) running = v end)
            mkToggle(sec, 'Auto Roll Both', 'j1_both', false, function(v)
                autoBoth = v
                misses = 0
            end)
            mkToggle(sec, 'Teleport to roller', 'j1_tp', true, function(v) teleport = v end)
            mkToggle(sec, 'Clear pending first', 'j1_clr', true, function(v) clearFirst = v end)
        end)
    end)
    if not ok then print('[' .. NAME .. '] UI.AddTab failed: ' .. tostring(err)) end
else
    print('[' .. NAME .. '] no UI table')
end

-- stop ----------------------------------------------------------------

local function stop()
    alive    = false
    running  = false
    autoBoth = false
    pcall(keyrelease, Enum.KeyCode.E)
    pcall(mouse1release)
    _G[NAME] = nil
    print('[' .. NAME .. '] stopped')
end

_G[NAME] = { stop = stop, version = VERSION }
print('[' .. NAME .. '] ' .. VERSION .. ' loaded - one toggle rolls both')
