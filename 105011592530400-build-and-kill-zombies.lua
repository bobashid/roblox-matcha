-- Build and Kill Zombies - Freeze Enemies - Matcha LuauVM - v11
-- place 105011592530400
-- one tab (Mods), one toggle: Freeze Enemies.
-- Nothing runs until the toggle is on. Once it is on, the target list is
-- rebuilt every 0.5s for as long as the toggle stays on, so zombies that spawn
-- or respawn after build mode are picked up on their own. You do not need to
-- turn it off and on again.
--
-- Why v9/v10 printed targets=0 while you could see zombies:
--   the walk only accepted a model that had a Humanoid AND a direct
--   HumanoidRootPart, and it only looked 4 container levels deep. A zombie
--   driven by an Animator, a zombie nested deeper, or a zombie whose root is
--   named something else was skipped. v11 drops the Humanoid requirement for
--   enemy-named models and walks 6 levels with a visit cap.
--
-- Writable set used (Matcha has no Anchored and no WalkSpeed):
--   Humanoid.WalkToPoint        stop it pathing
--   root.Velocity               kill momentum
--   root.AssemblyLinearVelocity same, for the assembly
--   root.CFrame                 only for targets with no Humanoid

local NAME    = 'ModsMenu'
local VERSION = 'v11'

if _G[NAME] and _G[NAME].stop then
    pcall(_G[NAME].stop)
end
print('[' .. NAME .. '] ' .. VERSION)

local Players = game:GetService('Players')
local ws = game:GetService('Workspace')

local MAX_TARGETS = 40
local MAX_VISITS  = 6000
local MAX_DEPTH   = 6

local alive    = true
local built    = false
local frozen   = false
local targets  = {}
local nTargets = 0

local ZERO = Vector3.new(0, 0, 0)

local PATTERNS = { 'zombie', 'enemy', 'monster', 'undead', 'walker', 'npc', 'mob' }

local function enemyName(n)
    local l = string.lower(n)
    for _, p in ipairs(PATTERNS) do
        if string.find(l, p, 1, true) then return true end
    end
    return false
end

local function isPart(inst)
    local cn = inst.ClassName
    return cn == 'Part' or cn == 'MeshPart' or cn == 'UnionOperation'
        or cn == 'WedgePart' or cn == 'TrussPart' or cn == 'CornerWedgePart'
end

local function rootOf(model)
    local r = model:FindFirstChild('HumanoidRootPart')
    if r then return r end
    r = model:FindFirstChild('UpperTorso')
    if r then return r end
    r = model:FindFirstChild('Torso')
    if r then return r end
    r = model.PrimaryPart
    if r then return r end
    for _, c in ipairs(model:GetChildren()) do
        if isPart(c) then return c end
    end
    return nil
end

-- collector: 2 Hz, walks 6 levels, no Humanoid requirement ------------

local function collect()
    local pnames = {}
    for _, p in ipairs(Players:GetPlayers()) do
        pnames[p.Name] = true
    end

    local out    = {}
    local visits = 0

    local function walk(node, depth)
        if #out >= MAX_TARGETS or visits >= MAX_VISITS then return end
        for _, c in ipairs(node:GetChildren()) do
            if #out >= MAX_TARGETS or visits >= MAX_VISITS then return end
            visits = visits + 1

            if not pnames[c.Name] then
                local hum  = c:FindFirstChildOfClass('Humanoid')
                local root = nil
                local take = false

                if hum then
                    root = rootOf(c)
                    take = root ~= nil
                elseif enemyName(c.Name) then
                    root = rootOf(c)
                    take = root ~= nil
                end

                if take then
                    out[#out + 1] = { root = root, hum = hum, pos = root.Position }
                elseif depth < MAX_DEPTH then
                    local cn = c.ClassName
                    if cn == 'Model' or cn == 'Folder' or cn == 'Workspace' then
                        walk(c, depth + 1)
                    end
                end
            end
        end
    end

    walk(ws, 0)

    targets  = out
    nTargets = #out
end

-- freeze pass: 20 Hz, writes only ------------------------------------

local function freezeOne(t)
    if t.hum then
        t.hum.WalkToPoint             = t.pos
        t.root.Velocity               = ZERO
        t.root.AssemblyLinearVelocity = ZERO
    else
        t.root.CFrame                 = CFrame.new(t.pos)
        t.root.Velocity               = ZERO
        t.root.AssemblyLinearVelocity = ZERO
    end
end

local function freeze()
    for _, t in ipairs(targets) do
        pcall(freezeOne, t)
    end
end

-- loops ---------------------------------------------------------------

local lastN = -1

-- collector: keeps running while the toggle is on, so respawns are caught
task.spawn(function()
    while alive do
        if frozen then
            collect()
            if nTargets ~= lastN then
                lastN = nTargets
                print('[' .. NAME .. '] targets = ' .. nTargets)
                if nTargets > 0 and targets[1] then
                    print('[' .. NAME .. '] first = ' .. targets[1].root:GetFullName())
                end
            end
        else
            targets, nTargets, lastN = {}, 0, -1
        end
        task.wait(0.5)
    end
end)

-- freeze: 20 Hz, skips silently when the list is empty
task.spawn(function()
    while alive do
        if frozen and nTargets > 0 then freeze() end
        task.wait(0.05)
    end
end)

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
        local sec = mkSection(tab, 'Enemies')
        if not sec then return end
        mkToggle(sec, 'Freeze Enemies', 'mm_freeze', false, function(v)
            frozen = v
            if v then
                collect()
                print('[' .. NAME .. '] freeze on, targets = ' .. nTargets)
                if nTargets == 0 then
                    pcall(notify, 'Mods', 'ing - zombies are picked up as they spawn', 4)
                end
            else
                print('[' .. NAME .. '] freeze off')
            end
        end)
    end)

    if not ok then
        warn('[' .. NAME .. '] build error: ' .. tostring(err))
    end
    print('[' .. NAME .. '] tab built')
end

if HAS_UI then
    local ok, err = pcall(function()
        UI.AddTab('Mods', function(tab)
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

-- stop ----------------------------------------------------------------

local function stop()
    alive  = false
    frozen = false
    targets, nTargets = {}, 0
    if HAS_UI then
        pcall(function() UI.RemoveTab('Mods') end)
    end
    _G[NAME] = nil
    print('[' .. NAME .. '] stopped')
end

_G[NAME] = { stop = stop, collect = collect, version = VERSION }
print('[' .. NAME .. '] ' .. VERSION .. ' loaded, menu=' .. tostring(HAS_UI) .. ' - Mods tab, Freeze Enemies')
