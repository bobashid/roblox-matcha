-- Build and Kill Zombies - Freeze Enemies - Matcha LuauVM - v8
-- place 105011592530400
-- one tab (Mods), one toggle: Freeze Enemies.
-- Nothing runs until the toggle is on. No getgc, no prescan, no cache.
--
-- Why fuel and the weapon mods are gone:
--   CmdrClient.Commands.UnlimitedFuel decompiles to { Args = { {} } } with no Run
--   findgc on live Fuel+FuelCapacity and Fuel+FuelDrain pairs returned 0, twice
--   no Fuel instance, ValueObject, attribute or RemoteEvent exists on the client
--   VehicleController only writes ThrottleFloat / SteerFloat
--   the 440 gc hits were Assets.CarParts stat definitions, not runtime values
-- None of that is reachable from the client, so the menu no longer offers it.
--
-- How freeze works with Matcha's writable set (no Anchored, no WalkSpeed):
--   Humanoid.WalkToPoint = the NPC's own position stops it pathing
--   HumanoidRootPart.Velocity and .AssemblyLinearVelocity zeroed kill momentum
-- Both are writes, which are the expensive ones, so the pass is throttled to
-- 5 Hz over a cached target list, and the list refreshes at 2 Hz.

local NAME    = 'ModsMenu'
local VERSION = 'v8'

if _G[NAME] and _G[NAME].stop then
    pcall(_G[NAME].stop)
end
print('[' .. NAME .. '] ' .. VERSION)

local Players = game:GetService('Players')
local lp = Players.LocalPlayer
local ws = game:GetService('Workspace')

local alive   = true
local built   = false
local frozen  = false
local targets = {}
local nTargets = 0

local ZERO = Vector3.new(0, 0, 0)

-- collector: 2 Hz, rebuilds the target list ---------------------------

local function scanModel(m, out)
    local hum  = m:FindFirstChildOfClass('Humanoid')
    local root = m:FindFirstChild('HumanoidRootPart')
    if hum and root then
        out[#out + 1] = { root = root, hum = hum }
    end
end

local function collect()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        names[p.Name] = true
    end

    local out = {}
    for _, m in ipairs(ws:GetChildren()) do
        if not names[m.Name] then
            local hum = m:FindFirstChildOfClass('Humanoid')
            if hum then
                scanModel(m, out)
            else
                for _, c in ipairs(m:GetChildren()) do
                    if not names[c.Name] then scanModel(c, out) end
                end
            end
        end
    end

    targets  = out
    nTargets = #out
end

-- freeze pass: 5 Hz, writes only -------------------------------------

local function freeze()
    for _, t in ipairs(targets) do
        pcall(function()
            t.hum.WalkToPoint          = t.root.Position
            t.root.Velocity            = ZERO
            t.root.AssemblyLinearVelocity = ZERO
        end)
    end
end

-- loops ---------------------------------------------------------------

task.spawn(function()
    while alive do
        if frozen then
            collect()
        else
            targets, nTargets = {}, 0
        end
        task.wait(0.5)
    end
end)

task.spawn(function()
    while alive do
        if frozen and nTargets > 0 then
            freeze()
        end
        task.wait(0.2)
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
