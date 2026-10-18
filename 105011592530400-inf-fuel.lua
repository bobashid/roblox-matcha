-- Inf Fuel - Matcha LuauVM - v1
-- place 105011592530400 - the game probed this session.
-- no Instance.new, no hooks, no getconnections.
-- getgc costs 10-20s per scan on this build: background only, never in a loop.
--
-- probed here:
--   HUD %   PlayerGui.MainGui.HUD.Vehicle.DrivePanel.Fuel.Status.Text
--   ride    LocalPlayer:GetAttribute('VehicleRideId')
--   gc keys Fuel, FuelCapacity, FuelDrain come back numeric
--   no Instance named Fuel, no fuel attribute, no *Fuel* RemoteEvent exist

local NAME    = 'InfFuel'
local VERSION = 'v1'

if _G[NAME] and _G[NAME].stop then
    pcall(_G[NAME].stop)
end
print('[' .. NAME .. '] ' .. VERSION)

local Players = game:GetService('Players')
local lp = Players.LocalPlayer

local running  = true
local built    = false
local cache    = nil
local scanning = false
local nFuel    = 0
local lastScan = 0
local autoScan = 0

local cfg = {
    fuel    = false,
    drain   = false,
    fuelVal = 1000,
}

local FUEL_KEYS = {
    'Fuel', 'CurrentFuel', 'FuelLevel', 'FuelAmount', 'FuelValue',
    'MaxFuel', 'FuelCapacity', 'FuelDrain',
}

local function setBool(key, v)
    if cfg[key] ~= v then
        cfg[key] = v
        print('[' .. NAME .. '] ' .. key .. ' = ' .. tostring(v))
    end
end

local function setNum(key, v)
    if cfg[key] ~= v then
        cfg[key] = v
        print('[' .. NAME .. '] ' .. key .. ' = ' .. tostring(v))
    end
end

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

local function riding()
    return lp:GetAttribute('VehicleRideId') ~= nil
end

-- scan ---------------------------------------------------------------

local function scan()
    if scanning then return end
    scanning = true
    lastScan = tick()
    print('[' .. NAME .. '] scan started, hud=' .. hudFuelText() .. ', riding=' .. tostring(riding()))

    local ok, res = pcall(getgc, FUEL_KEYS)
    local out, n = {}, 0
    if ok and type(res) == 'table' then
        for _, e in ipairs(res) do
            if e.type == 'number' then
                out[#out + 1] = e
                n = n + 1
            end
        end
    end

    cache = out
    nFuel = n
    print('[' .. NAME .. '] scan done: ' .. nFuel .. ' fuel keys, hud=' .. hudFuelText())
    if nFuel == 0 then
        pcall(notify, 'Inf Fuel', 'no fuel keys - sit in a vehicle and press Rescan', 3)
    end
    scanning = false
end

-- apply loop ---------------------------------------------------------

task.spawn(function()
    while running do
        if cache then
            if cfg.drain then
                pcall(applygc, cache, 'FuelDrain', 0)
            end
            if cfg.fuel then
                pcall(applygc, cache, 'Fuel', cfg.fuelVal)
                pcall(applygc, cache, 'CurrentFuel', cfg.fuelVal)
                pcall(applygc, cache, 'FuelCapacity', cfg.fuelVal)
            end
        end

        -- one lazy rescan when riding with an empty fuel cache, max 3 times
        if cfg.fuel and nFuel == 0 and not scanning and autoScan < 3
           and (tick() - lastScan) > 20 and riding() then
            autoScan = autoScan + 1
            print('[' .. NAME .. '] auto rescan ' .. autoScan .. ' (riding, no fuel keys)')
            task.spawn(scan)
        end

        task.wait(0.25)
    end
end)

-- menu ---------------------------------------------------------------
-- same widget pattern as the other scripts in this repo:
--   tab:Section(name, 'Left') returns a usable handle, plain name does not.
--   Toggle / SliderInt / Button each get an argument-order retry.

local HAS_UI = type(UI) == 'table' and type(UI.AddTab) == 'function'

local function firstBool(...)
    for i = 1, select('#', ...) do
        local v = select(i, ...)
        if type(v) == 'boolean' then return v end
    end
    return nil
end

local function firstNumber(...)
    for i = 1, select('#', ...) do
        local v = select(i, ...)
        if type(v) == 'number' then return v end
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

local function mkToggle(sec, label, id, default, apply)
    local cb = function(...)
        local v = firstBool(...)
        if v ~= nil then apply(v) end
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

local function mkSlider(sec, label, id, min, max, default, apply)
    local cb = function(...)
        local v = firstNumber(...)
        if v ~= nil then apply(v) end
    end
    local tries = {
        function() sec:SliderInt(label, id, min, max, default, cb) end,
        function() sec:SliderInt(id, label, min, max, default, cb) end,
        function() sec:SliderInt(label, min, max, default, cb) end,
    }
    for i = 1, #tries do
        if pcall(tries[i]) then return true end
    end
    warn('[' .. NAME .. '] slider failed: ' .. label)
    return false
end

local function mkButton(sec, label, cb)
    if pcall(function() sec:Button(label, cb) end) then return true end
    if pcall(function() sec:Button(label, label .. '_btn', cb) end) then return true end
    warn('[' .. NAME .. '] button failed: ' .. label)
    return false
end

local function buildTab(tab)
    if built then return end
    built = true

    local ok, err = pcall(function()
        local sec = mkSection(tab, 'Fuel')
        if not sec then return end

        mkToggle(sec, 'Inf Fuel', 'if_fuel', false, function(v)
            setBool('fuel', v)
            print('[' .. NAME .. '] fuel=' .. tostring(v) ..
                  ' cache=' .. tostring(cache and #cache or 0) ..
                  ' hud=' .. hudFuelText() ..
                  ' riding=' .. tostring(riding()))
        end)
        mkToggle(sec, 'Stop Drain', 'if_drain', false, function(v) setBool('drain', v) end)
        mkSlider(sec, 'Fuel Value', 'if_fuelval', 100, 100000, 1000, function(v) setNum('fuelVal', v) end)
        mkButton(sec, 'Rescan', function()
            print('[' .. NAME .. '] rescan pressed, hud=' .. hudFuelText())
            task.spawn(scan)
        end)
    end)

    if not ok then
        warn('[' .. NAME .. '] build error: ' .. tostring(err))
    end
    print('[' .. NAME .. '] tab widgets built')
end

if HAS_UI then
    local ok, err = pcall(function()
        UI.AddTab('Inf Fuel', function(tab)
            if built then return end
            print('[' .. NAME .. '] tab opened - building widgets')
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

-- boot ---------------------------------------------------------------

task.spawn(scan)

local function stop()
    running = false
    if HAS_UI then
        pcall(function() UI.RemoveTab('Inf Fuel') end)
    end
    _G[NAME] = nil
    print('[' .. NAME .. '] stopped')
end

_G[NAME] = { stop = stop, rescan = scan, version = VERSION }
print('[' .. NAME .. '] ' .. VERSION .. ' loaded, menu=' .. tostring(HAS_UI) .. ' - open the Inf Fuel tab')
