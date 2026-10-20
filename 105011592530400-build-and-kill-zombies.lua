-- Build and Kill Zombies -> Auto Roll Both - Matcha LuauVM - v29.0
-- place 105011592530400
--
-- ONE toggle rolls both rollers, in order, and waits out the cooldown.
--
-- Cycle (one pass of the loop):
--   1. save your CFrame once
--   2. teleport to RollWeapons.Roll, press E, read the result
--   3. teleport to RollBlocks.Roll,  press E, read the result
--   4. put you back where you started
--   5. wait the cooldown, then start the next pass
--
-- Because step 5 waits, it does not bounce between the two rollers during
-- the cooldown. One teleport pair per pass, not one per press.
--
-- Cooldown handling:
--   after a pass where at least one roller produced a new item, wait 3s
--   after a pass where nothing changed, wait 5s (the rollers are probably
--     still cooling, no point hammering them)
--   5 dead passes in a row -> switches itself off and notifies
--
-- Still no setrobloxinput anywhere (that call freezes this client).
-- keypress / keyrelease only.
--
-- The press is gated on the prompt being up, and every attempt logs:
--   before=<item> pending=<real item or nil> prompt=<bool>(<children>) clickable=<bool>
-- so a miss is never ambiguous.
--
-- Menu: Rollers tab, one section
--   Enabled            master, default off
--   Auto Roll Both     the single toggle you asked for
--   Teleport to roller default ON

local NAME    = 'RollerMods'
local VERSION = 'v29.0'

if _G[NAME] and _G[NAME].stop then
    pcall(_G[NAME].stop)
end
print('[' .. NAME .. '] ' .. VERSION)

local Players = game:GetService('Players')
local ws      = game:GetService('Workspace')
local lp      = Players.LocalPlayer

local alive    = true
local running  = false
local autoBoth = false
local teleport = true

local COOLDOWN_OK   = 3
local COOLDOWN_MISS = 5
local MAX_MISSES    = 5
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
        if (promptState()) then return true end
        wait(0.2)
    end
    return false
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
    if root then pcall(function() root.CFrame = cyc.saved end) end
    cyc.saved = nil
end

-- one roller ----------------------------------------------------------

local function rollOne(roller, tag, cyc)
    local part = roller and roller:FindFirstChild('Roll')
    if not part then return false end

    goTo(part, cyc)
    wait(0.5)

    local before  = read(roller, 'ItemName')
    local pending = pendingItem(roller)
    local up, kids, clickable = promptState()

    print('[' .. NAME .. '] ' .. tag .. ' before=' .. tostring(before)
        .. ' pending=' .. tostring(pending)
        .. ' prompt=' .. tostring(up) .. '(' .. tostring(kids) .. ')'
        .. ' clickable=' .. tostring(clickable))

    if pending then
        print('[' .. NAME .. '] ' .. tag .. ' blocked by pending ' .. pending)
        return false
    end

    if not up then
        if not waitForPrompt(2) then
            print('[' .. NAME .. '] ' .. tag .. ' prompt not up')
            return false
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

    if got then
        print('[' .. NAME .. '] ' .. tag .. ' ROLLED ' .. got .. ' (' .. tostring(read(roller, 'Rarity')) .. ')')
        pcall(notify, tag .. ': ' .. got, 'Rollers', 3)
        return true
    end

    print('[' .. NAME .. '] ' .. tag .. ' press ignored (still ' .. tostring(read(roller, 'ItemName')) .. ')')
    return false
end

-- the single loop -----------------------------------------------------

task.spawn(function()
    while alive do
        if running and autoBoth then
            local cyc = {}
            local any = false

            local w, b = rollers()
            if w then
                if rollOne(w, 'weapons', cyc) then any = true end
            end
            if b then
                if rollOne(b, 'blocks', cyc) then any = true end
            end

            goBack(cyc)

            if any then
                misses = 0
                wait(COOLDOWN_OK)
            else
                misses = misses + 1
                print('[' .. NAME .. '] dead pass ' .. misses .. '/' .. MAX_MISSES
                    .. ' - waiting ' .. COOLDOWN_MISS .. 's for cooldown')
                if misses >= MAX_MISSES then
                    running  = false
                    autoBoth = false
                    misses   = 0
                    print('[' .. NAME .. '] switched off - press ignored ' .. MAX_MISSES .. ' passes in a row')
                    pcall(notify, 'auto roll off: E not reaching the prompt', 'Rollers', 8)
                else
                    wait(COOLDOWN_MISS)
                end
            end
        else
            wait(0.5)
        end
    end
end)

-- status inside a spawn, load never yields ----------------------------

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
            mkToggle(sec, 'Enabled', 'h1_on', false, function(v) running = v end)
            mkToggle(sec, 'Auto Roll Both', 'h1_both', false, function(v)
                autoBoth = v
                misses = 0
            end)
            mkToggle(sec, 'Teleport to roller', 'h1_tp', true, function(v) teleport = v end)
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
    _G[NAME] = nil
    print('[' .. NAME .. '] stopped')
end

_G[NAME] = { stop = stop, version = VERSION }
print('[' .. NAME .. '] ' .. VERSION .. ' loaded - one toggle rolls both'
)