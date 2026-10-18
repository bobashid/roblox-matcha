-- Build and Kill Zombies - Inf Fuel - Matcha LuauVM - v5
-- place 105011592530400
-- one tab, one section, one toggle. no sliders, no buttons, no weapon mods.
-- No getgc at load. The scan runs only after you turn the toggle on.
--
-- What the probes actually found for this place:
--   HUD %      PlayerGui.MainGui.HUD.Vehicle.DrivePanel.Fuel.Status.Text  (reads, e.g. 93%)
--   ride flag  LocalPlayer:GetAttribute('VehicleRideId')
--   seat       Humanoid.SeatPart returns nil, so the car cannot be found that way
--   no fuel    no Fuel instance, no fuel ValueObject, no *Fuel* RemoteEvent,
--              no Workspace attribute matching the ride id
--   gc keys    Fuel / FuelCapacity / FuelDrain show up as numeric keys
-- Fuel looks server-owned, so this is best effort, not a guarantee.

local NAME    = 'ModsMenu'
local VERSION = 'v5'

if _G[NAME] and _G[NAME].stop then
    pcall(_G[NAME].stop)
end
print('[' .. NAME .. '] ' .. VERSION)

local Players = game:GetService('Players')
local lp = Players.LocalPlayer

local FUEL_KEYS = {
    'Fuel', 'CurrentFuel', 'FuelLevel', 'FuelAmount', 'FuelValue',
    'MaxFuel', 'FuelCapacity', 'FuelDrain',
}

local VALUE = 9999

local alive    = true
local running  = false
local built    = false
local scanning = false
local cache    = nil
local lastScan = 0

local function hudFuelText()
    local pg  = lp:FindFirstChild('PlayerGui')
    local mg  = pg and pg:FindFirstChild('MainGui')
    local hud = mg and mg:FindFirstChild('HUD')
    local veh = hud and hud:FindFirstChild('Vehicle')
    local dp  = veh and veh:FindFirstChild('DrivePanel')
    local fu  = dp and dp:FindFirstChild('Fuel')
    local st  = fu and fu:FindFirstChild('Status')
    return st and st.Text or 'no hud'
end

local function scan()
    if scanning then return end
    scanning = true
    lastScan = tick()
    print('[' .. NAME .. '] scanning for fuel keys, this takes 10-20s')

    local ok, res = pcall(getgc, FUEL_KEYS)
    if ok and type(res) == 'table' then
        local out = {}
        for _, e in ipairs(res) do
            if e.type == 'number' then
                out[#out + 1] = e
            end
        end
        cache = out
        print('[' .. NAME .. '] scan done: ' .. #out .. ' numeric keys, hud=' .. hudFuelText())
    else
        print('[' .. NAME .. '] scan failed: ' .. tostring(res))
    end

    scanning = false
end

local function apply()
    if not cache then return end
    for _, k in ipairs(FUEL_KEYS) do
        pcall(applygc, cache, k, VALUE)
    end
    pcall(applygc, cache, 'FuelDrain', 0)
end

-- apply loop: the only thing that runs in the background

task.spawn(function()
    while alive do
        if running then
            if not cache and not scanning and (tick() - lastScan) > 15 then
                scan()
            end
            apply()
        end
        task.wait(0.5)
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

local function mkToggle(sec, label, id, default, apply_fn)
    local cb = function(...)
        local v = firstBool(...)
        if v ~= nil then apply_fn(v) end
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
        local fuel = mkSection(tab, 'Fuel')
        if not fuel then return end

        mkToggle(fuel, 'Inf Fuel', 'mm_fuel', false, function(v)
            running = v
            print('[' .. NAME .. '] inf fuel = ' .. tostring(v) .. ' hud=' .. hudFuelText())
            if v and not cache then task.spawn(scan) end
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
    alive = false
    running = false
    if HAS_UI then
        pcall(function() UI.RemoveTab('Mods') end)
    end
    _G[NAME] = nil
    print('[' .. NAME .. '] stopped')
end

_G[NAME] = { stop = stop, version = VERSION }
print('[' .. NAME .. '] ' .. VERSION .. ' loaded, menu=' .. tostring(HAS_UI) .. ' - Mods tab, Inf Fuel')
