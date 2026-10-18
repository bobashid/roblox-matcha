-- Build and Kill Zombies - Freeze Enemies - Matcha LuauVM - v10
-- place 105011592530400
-- one tab (Mods), one toggle: Freeze Enemies.
-- Nothing runs until the toggle is on. No getgc, no prescan, no cache.
--
-- v9 turned the toggle on fine and printed targets=0 every time. A clean probe
-- with the same logic returned 0 NPC humanoids in Workspace, so the collection
-- was the bug, not the freeze. v9 only walked Workspace children and their
-- direct children. v10 walks 4 container levels, skips player characters by
-- name, and accepts UpperTorso / Torso / PrimaryPart / first BasePart when a
-- model has no HumanoidRootPart. The walk is capped at 4000 visits so a deep
-- tree cannot stall the loop.
--
-- Writable set used (Matcha has no Anchored and no WalkSpeed):
--   Humanoid.WalkToPoint                    stop it pathing
--   root.Velocity                           kill momentum
--   root.AssemblyLinearVelocity             same, for the assembly
-- Root is HumanoidRootPart when present, otherwise the torso or primary part.

local NAME    = 'ModsMenu'
local VERSION = 'v10'

if _G[NAME] and _G[NAME].stop then
    pcall(_G[NAME].stop)
end
print('[' .. NAME .. '] ' .. VERSION)

local Players = game:GetService('Players')
local ws = game:GetService('Workspace')

local MAX_TARGETS = 30
local MAX_VISITS  = 4000

local alive    = true
local built    = false
local frozen   = false
local targets  = {}
local nTargets = 0

local ZERO = Vector3.new(0, 0, 0)

-- target helpers ------------------------------------------------------

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

-- collector: 2 Hz, walks 4 container levels ---------------------------

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
                local hum = c:FindFirstChildOfClass('Humanoid')
                if hum then
                    local root = rootOf(c)
                    if root then
                        out[#out + 1] = { root = root, hum = hum, pos = root.Position }
                    end
                elseif depth < 4 then
                    local cn = c.ClassName
                    if cn == 'Model' or cn == 'Folder' then
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

local function freeze()
    for _, t in ipairs(targets) do
        pcall(function()
            t.hum.WalkToPoint             = t.pos
            t.root.Velocity               = ZERO
            t.root.AssemblyLinearVelocity = ZERO
        end)
    end
end

-- loops ---------------------------------------------------------------

task.spawn(function()
    while alive do
        if frozen then collect() else targets, nTargets = {}, 0 end
        task.wait(0.5)
    end
end)

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
            if v then collect() end
            print('[' .. NAME .. '] freeze = ' .. tostring(v) .. ' targets=' .. nTargets)
            if v and nTargets == 0 then
                pcall(notify, 'Mods', 'freeze on but no NPC humanoids found in Workspace', 4)
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

_G[NAME] = { stop = stop, version = VERSION }
print('[' .. NAME .. '] ' .. VERSION .. ' loaded, menu=' .. tostring(HAS_UI) .. ' - Mods tab, Freeze Enemies')
