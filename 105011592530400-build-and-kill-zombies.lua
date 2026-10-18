-- Build and Kill Zombies - Freeze Enemies - Matcha LuauVM - v9
-- place 105011592530400
-- one tab (Mods), one toggle: Freeze Enemies.
-- Nothing runs until the toggle is on. No getgc, no prescan, no cache.
--
-- v9 fixes v8. Measured on a live workspace.Zombie this session:
--   idle drift                      0.09 studs in 1s
--   velocity lock at 20Hz           0.00 studs drift
--   CFrame lock at 20Hz             0.00 studs drift
-- v8 ran the same writes at 5Hz, so the zombie walked between passes. The pass
-- now runs at 20Hz. Velocity-only was enough, so there are no CFrame writes and
-- none of the per-assignment physics cost that comes with them.
--
-- Writable set used (Matcha has no Anchored and no WalkSpeed):
--   Humanoid.WalkToPoint                    stop it pathing
--   HumanoidRootPart.Velocity               kill momentum
--   HumanoidRootPart.AssemblyLinearVelocity same, for the assembly

local NAME    = 'ModsMenu'
local VERSION = 'v9'

if _G[NAME] and _G[NAME].stop then
    pcall(_G[NAME].stop)
end
print('[' .. NAME .. '] ' .. VERSION)

local Players = game:GetService('Players')
local ws = game:GetService('Workspace')

local MAX_TARGETS = 30

local alive     = true
local built     = false
local frozen    = false
local targets   = {}
local nTargets  = 0

local ZERO = Vector3.new(0, 0, 0)

-- collector: 2 Hz, rebuilds the target list ---------------------------

local function addModel(m, out)
    local hum  = m:FindFirstChildOfClass('Humanoid')
    local root = m:FindFirstChild('HumanoidRootPart')
    if hum and root then
        out[#out + 1] = { root = root, hum = hum, pos = root.Position }
    end
end

local function collect()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        names[p.Name] = true
    end

    local out = {}
    for _, m in ipairs(ws:GetChildren()) do
        if #out >= MAX_TARGETS then break end
        if not names[m.Name] then
            if m:FindFirstChildOfClass('Humanoid') then
                addModel(m, out)
            else
                for _, c in ipairs(m:GetChildren()) do
                    if #out >= MAX_TARGETS then break end
                    if not names[c.Name] then addModel(c, out) end
                end
            end
        end
    end

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
