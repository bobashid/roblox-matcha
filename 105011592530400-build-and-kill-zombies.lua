-- Build and Kill Zombies - Inf Fuel + Fire Rate + Gun Range - Matcha LuauVM - v7
-- place 105011592530400
-- one tab (Mods), two sections: Fuel and Weapon. toggles + values only.
-- No getgc at load and no prescan. A scan runs only when you turn a toggle on,
-- and the filtered key cache is reused after that.
--
-- Measured on this place this session, one getgc over the whole key list:
--   440 numeric hits in 14.2s
--   FireRate 22, Range 45, Damage 137, Cooldown 8, MaxRange 2
--   FuelDrain 19, Fuel 4, FuelCapacity 1
-- So the weapon keys are plentiful and client-side. Fuel keys exist but are few,
-- findgc Fuel+FuelCapacity and findgc Fuel+FuelDrain both returned 0, and there is
-- no Fuel instance, ValueObject or RemoteEvent. The tank looks server-owned.
-- Weapon writes are expected to work. Fuel is best effort: if the HUD keeps
-- draining, no client script can hold it.
--
-- v7: the scan now keeps only the keys this script writes. Unfiltered, the cache
-- was 440 entries and the apply loop walked all of them twice a second.

local NAME    = 'ModsMenu'
local VERSION = 'v7'

if _G[NAME] and _G[NAME].stop then
    pcall(_G[NAME].stop)
end
print('[' .. NAME .. '] ' .. VERSION)

local Players = game:GetService('Players')
local lp = Players.LocalPlayer

local WEAPON_KEYS = {
    'FireRate', 'FireDelay', 'Cooldown', 'FireInterval',
    'Range', 'MaxRange', 'BulletRange',
}

local FUEL_KEYS = {
    'Fuel', 'CurrentFuel', 'FuelLevel', 'FuelAmount', 'FuelValue',
    'MaxFuel', 'FuelCapacity', 'FuelDrain',
}

-- keys the apply loop actually writes: the scan keeps only these
local WANT = {}
for _, k in ipairs(WEAPON_KEYS) do WANT[k] = true end
for _, k in ipairs(FUEL_KEYS)   do WANT[k] = true end

local cfg = {
    fuel     = false,
    rapid    = false,
    range    = false,
    fuelVal  = 9999,
    rateVal  = 0.02,
    rangeVal = 2000,
}

local alive    = true
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
    print('[' .. NAME .. '] scanning, this takes 10-20s')

    local keys = {}
    for _, k in ipairs(WEAPON_KEYS) do keys[#keys + 1] = k end
    for _, k in ipairs(FUEL_KEYS)    do keys[#keys + 1] = k end

    local ok, res = pcall(getgc, keys)
    if ok and type(res) == 'table' then
        local out = {}
        for _, e in ipairs(res) do
            if e.type == 'number' and WANT[e.key] then
                out[#out + 1] = e
            end
        end
        cache = out
        print('[' .. NAME .. '] scan done: ' .. #out .. ' keys, hud=' .. hudFuelText())
    else
        print('[' .. NAME .. '] scan failed: ' .. tostring(res))
    end

    scanning = false
end

local function needsScan()
    return not cache and not scanning and (tick() - lastScan) > 15
end

local function write(key, value)
    if not cache then return end
    pcall(applygc, cache, key, value)
end

-- apply loop ---------------------------------------------------------

task.spawn(function()
    while alive do
        if (cfg.fuel or cfg.rapid or cfg.range) and needsScan() then
            scan()
        end

        if cache then
            if cfg.fuel then
                write('Fuel', cfg.fuelVal)
                write('CurrentFuel', cfg.fuelVal)
                write('FuelCapacity', cfg.fuelVal)
                write('MaxFuel', cfg.fuelVal)
                write('FuelDrain', 0)
            end
            if cfg.rapid then
                write('FireRate', cfg.rateVal)
                write('FireDelay', 0)
                write('Cooldown', 0)
                write('FireInterval', cfg.rateVal)
            end
            if cfg.range then
                write('Range', cfg.rangeVal)
                write('MaxRange', cfg.rangeVal)
                write('BulletRange', cfg.rangeVal)
            end
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

local function mkSlider(sec, label, id, min, max, default, fn)
    local cb = function(...)
        local v = firstNumber(...)
        if v ~= nil then fn(v) end
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

local function buildTab(tab)
    if built then return end
    built = true

    local ok, err = pcall(function()
        local fuel = mkSection(tab, 'Fuel')
        if fuel then
            mkToggle(fuel, 'Inf Fuel', 'mm_fuel', false, function(v)
                cfg.fuel = v
                print('[' .. NAME .. '] inf fuel = ' .. tostring(v) .. ' hud=' .. hudFuelText())
            end)
            mkSlider(fuel, 'Fuel Value', 'mm_fuelval', 100, 100000, 9999, function(v)
                cfg.fuelVal = v
            end)
        end

        local gun = mkSection(tab, 'Weapon')
        if gun then
            mkToggle(gun, 'Rapid Fire', 'mm_rapid', false, function(v)
                cfg.rapid = v
                print('[' .. NAME .. '] rapid fire = ' .. tostring(v))
            end)
            mkSlider(gun, 'Fire Rate', 'mm_rate', 1, 100, 2, function(v)
                cfg.rateVal = v / 100
            end)
            mkToggle(gun, 'Gun Range', 'mm_range', false, function(v)
                cfg.range = v
                print('[' .. NAME .. '] gun range = ' .. tostring(v))
            end)
            mkSlider(gun, 'Range Value', 'mm_rangeval', 100, 10000, 2000, function(v)
                cfg.rangeVal = v
            end)
        end
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
    cfg.fuel, cfg.rapid, cfg.range = false, false, false
    if HAS_UI then
        pcall(function() UI.RemoveTab('Mods') end)
    end
    _G[NAME] = nil
    print('[' .. NAME .. '] stopped')
end

_G[NAME] = { stop = stop, scan = scan, version = VERSION }
print('[' .. NAME .. '] ' .. VERSION .. ' loaded, menu=' .. tostring(HAS_UI) .. ' - Mods tab')
