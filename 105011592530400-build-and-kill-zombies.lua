-- Build and Kill Zombies - Inf Fuel only - Matcha LuauVM - v4
-- place 105011592530400
-- one Matcha menu tab: Mods, one section: Fuel, one toggle.
-- No getgc at load, no prescan, no cache, no weapon mods.
-- Nothing runs until you flip the toggle.
--
-- Probed facts for this place:
--   HUD %      PlayerGui.MainGui.HUD.Vehicle.DrivePanel.Fuel.Status.Text
--   ride flag  LocalPlayer:GetAttribute('VehicleRideId')
--   gc keys    numeric Fuel / FuelCapacity / FuelDrain exist (FuelDrain 6)
--   absent     no Fuel instance, no fuel ValueObject in Workspace or
--              ReplicatedStorage, no *Fuel* RemoteEvent
--   decompile  VehicleController only writes ThrottleFloat/SteerFloat, no fuel code
-- Fuel is likely server-owned, so treat this as best effort, not a guarantee.
--
-- How it works: setgc writes by key name, so no scan and no cache is needed.
-- A pass is 6 short setgc calls. Passes are bounded and spaced apart because
-- the cost of setgc on this build is unknown and could be as heavy as getgc.

local NAME    = 'ModsMenu'
local VERSION = 'v4'

if _G[NAME] and _G[NAME].stop then
    pcall(_G[NAME].stop)
end
print('[' .. NAME .. '] ' .. VERSION)

local Players = game:GetService('Players')
local lp = Players.LocalPlayer

local running = true
local built   = false
local busy    = false

local cfg = {
    fuel    = false,
    fuelVal = 1000,
    passes  = 3,
    gap     = 2,
}

local FUEL_KEYS = { 'Fuel', 'FuelLevel', 'FuelAmount', 'CurrentFuel' }

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

local function pass(n)
    for _, k in ipairs(FUEL_KEYS) do
        pcall(setgc, k, cfg.fuelVal)
    end
    pcall(setgc, 'MaxFuel', cfg.fuelVal)
    pcall(setgc, 'FuelDrain', 0)
    print('[' .. NAME .. '] pass ' .. n .. ' hud=' .. hudFuelText() ..
          ' riding=' .. tostring(riding()))
end

local function runPasses()
    if busy then return end
    busy = true
    for i = 1, cfg.passes do
        if not running or not cfg.fuel then break end
        pass(i)
        task.wait(cfg.gap)
    end
    busy = false
    print('[' .. NAME .. '] done, hud=' .. hudFuelText())
    if not riding() then
        pcall(notify, 'Mods', 'fuel write sent - sit in a vehicle to check the HUD', 4)
    end
end

-- menu ---------------------------------------------------------------
-- tab:Section(name, 'Left') returns a usable handle, plain name does not.
-- Toggle / SliderInt / Button each get an argument-order retry.

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
        local fuel = mkSection(tab, 'Fuel')
        if not fuel then return end

        mkToggle(fuel, 'Inf Fuel', 'mm_fuel', false, function(v)
            cfg.fuel = v
            print('[' .. NAME .. '] inf fuel = ' .. tostring(v) ..
                  ' hud=' .. hudFuelText() .. ' riding=' .. tostring(riding()))
            if v then task.spawn(runPasses) end
        end)

        mkSlider(fuel, 'Fuel Value', 'mm_fuelval', 100, 100000, 1000, function(v)
            cfg.fuelVal = v
            print('[' .. NAME .. '] fuel value = ' .. tostring(v))
        end)

        mkButton(fuel, 'Reapply', function()
            print('[' .. NAME .. '] reapply, hud=' .. hudFuelText() ..
                  ' riding=' .. tostring(riding()))
            task.spawn(runPasses)
        end)
    end)

    if not ok then
        warn('[' .. NAME .. '] build error: ' .. tostring(err))
    end
    print('[' .. NAME .. '] tab widgets built')
end

if HAS_UI then
    local ok, err = pcall(function()
        UI.AddTab('Mods', function(tab)
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

-- stop ----------------------------------------------------------------

local function stop()
    running = false
    cfg.fuel = false
    if HAS_UI then
        pcall(function() UI.RemoveTab('Mods') end)
    end
    _G[NAME] = nil
    print('[' .. NAME .. '] stopped')
end

_G[NAME] = { stop = stop, reapply = runPasses, version = VERSION }
print('[' .. NAME .. '] ' .. VERSION .. ' loaded, menu=' .. tostring(HAS_UI) .. ' - open the Mods tab, Fuel section')
