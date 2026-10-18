-- Build and Kill Zombies - Mods Menu - Matcha LuauVM - v3
-- place 105011592530400
-- one Matcha menu tab: Mods (Weapon / Stamina / Fuel)
-- no Instance.new, no hooks, no getconnections.
-- getgc on this build takes 10-20s per scan: it runs in the background,
-- never inside the apply loop.
--
-- Probed facts for this place:
--   HUD %      PlayerGui.MainGui.HUD.Vehicle.DrivePanel.Fuel.Status.Text
--   ride flag  LocalPlayer:GetAttribute('VehicleRideId')
--   gc keys    Fuel, FuelCapacity, FuelDrain (numeric; FuelDrain = 6 on one table)
--   absent     no Fuel instance, no fuel attribute, no *Fuel* RemoteEvent
-- Auto-rescan fires only while riding and only if the cache has no fuel keys.

local NAME    = 'ModsMenu'
local VERSION = 'v3'

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
local nWeapon  = 0
local nFuel    = 0
local lastScan = 0
local autoScan = 0

local cfg = {
    infammo  = false,
    norecoil = false,
    damage   = false,
    rapid    = false,
    nospread = false,
    stamina  = false,
    fuel     = false,
    drain    = false,
    dmgVal   = 100,
    rateVal  = 0.02,
    stamVal  = 100,
    fuelVal  = 1000,
}

local WEAPON_KEYS = {
    'Ammo', 'Clip', 'Magazine', 'ReserveAmmo', 'CurrentAmmo',
    'Damage', 'BaseDamage', 'FireRate', 'FireDelay',
    'Recoil', 'RecoilAmount', 'Spread', 'BulletSpread', 'Inaccuracy',
}

local STAMINA_KEYS = {
    'Stamina', 'CurrentStamina', 'MaxStamina', 'StaminaValue', 'Energy',
}

local FUEL_KEYS = {
    'Fuel', 'CurrentFuel', 'FuelLevel', 'FuelAmount', 'FuelValue',
    'MaxFuel', 'FuelCapacity', 'FuelDrain', 'Gas', 'Gasoline', 'Tank',
}

local RESOURCE_KEYS = {}
for _, k in ipairs(STAMINA_KEYS) do RESOURCE_KEYS[#RESOURCE_KEYS + 1] = k end
for _, k in ipairs(FUEL_KEYS)    do RESOURCE_KEYS[#RESOURCE_KEYS + 1] = k end

local FUEL_SET = {}
for _, k in ipairs(FUEL_KEYS) do FUEL_SET[k] = true end

local APPLY = {
    infammo  = { Ammo = 999, Clip = 999, Magazine = 999, ReserveAmmo = 999, CurrentAmmo = 999 },
    norecoil = { Recoil = 0, RecoilAmount = 0, CameraRecoil = 0, Kick = 0 },
    nospread = { Spread = 0, BulletSpread = 0, Inaccuracy = 0, Sway = 0 },
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

local function scanKeys(keys)
    local ok, res = pcall(getgc, keys)
    if ok and type(res) == 'table' then return res end
    return {}
end

local function scan()
    if scanning then return end
    scanning = true
    lastScan = tick()
    print('[' .. NAME .. '] scan started, this takes 10-20s')

    local w = scanKeys(WEAPON_KEYS)
    local r = scanKeys(RESOURCE_KEYS)

    local out = {}
    nWeapon, nFuel = 0, 0
    for _, e in ipairs(w) do
        out[#out + 1] = e
        nWeapon = nWeapon + 1
    end
    for _, e in ipairs(r) do
        if e.type == 'number' then
            out[#out + 1] = e
            if FUEL_SET[e.key] then nFuel = nFuel + 1 end
        end
    end

    cache = out
    print('[' .. NAME .. '] scan done: weapon ' .. nWeapon ..
          ', fuel ' .. nFuel .. ', hud ' .. hudFuelText() ..
          ', riding ' .. tostring(riding()))
    if nFuel == 0 then
        pcall(notify, 'Mods', 'no fuel keys yet - sit in a vehicle and press Rescan', 3)
    end
    scanning = false
end

-- apply loop ---------------------------------------------------------

task.spawn(function()
    while running do
        if cache then
            if cfg.infammo then
                for k, v in pairs(APPLY.infammo) do
                    pcall(applygc, cache, k, v)
                end
            end
            if cfg.norecoil then
                for k, v in pairs(APPLY.norecoil) do
                    pcall(applygc, cache, k, v)
                end
            end
            if cfg.nospread then
                for k, v in pairs(APPLY.nospread) do
                    pcall(applygc, cache, k, v)
                end
            end
            if cfg.damage then
                pcall(applygc, cache, 'Damage', cfg.dmgVal)
                pcall(applygc, cache, 'BaseDamage', cfg.dmgVal)
            end
            if cfg.rapid then
                pcall(applygc, cache, 'FireRate', cfg.rateVal)
                pcall(applygc, cache, 'FireDelay', 0)
            end
            if cfg.stamina then
                for _, k in ipairs(STAMINA_KEYS) do
                    pcall(applygc, cache, k, cfg.stamVal)
                end
            end
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
            print('[' .. NAME .. '] auto rescan ' .. autoScan .. ' (riding, no fuel keys cached)')
            task.spawn(scan)
        end

        task.wait(0.25)
    end
end)

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
        local gun = mkSection(tab, 'Weapon')
        if gun then
            mkToggle(gun, 'Inf Ammo',   'mm_infammo',  false, function(v) setBool('infammo', v) end)
            mkToggle(gun, 'No Recoil',  'mm_norecoil', false, function(v) setBool('norecoil', v) end)
            mkToggle(gun, 'No Spread',  'mm_nospread', false, function(v) setBool('nospread', v) end)
            mkToggle(gun, 'Damage Mod', 'mm_damage',   false, function(v) setBool('damage', v) end)
            mkToggle(gun, 'Rapid Fire', 'mm_rapid',    false, function(v) setBool('rapid', v) end)
            mkSlider(gun, 'Damage Value', 'mm_dmgval', 1, 1000, 100, function(v) setNum('dmgVal', v) end)
            mkSlider(gun, 'Fire Rate',    'mm_rate',   1, 100, 2,   function(v) setNum('rateVal', v / 100) end)
            mkButton(gun, 'Rescan', function()
                print('[' .. NAME .. '] rescan pressed')
                task.spawn(scan)
            end)
        end

        local stam = mkSection(tab, 'Stamina')
        if stam then
            mkToggle(stam, 'Inf Stamina', 'mm_stamina', false, function(v) setBool('stamina', v) end)
            mkSlider(stam, 'Stamina Value', 'mm_stamval', 100, 1000, 100, function(v) setNum('stamVal', v) end)
        end

        local fuel = mkSection(tab, 'Fuel')
        if fuel then
            mkToggle(fuel, 'Inf Fuel', 'mm_fuel', false, function(v)
                setBool('fuel', v)
                print('[' .. NAME .. '] fuel=' .. tostring(v) ..
                      ' cache=' .. tostring(cache and #cache or 0) ..
                      ' fuelKeys=' .. nFuel ..
                      ' hud=' .. hudFuelText() ..
                      ' riding=' .. tostring(riding()))
            end)
            mkSlider(fuel, 'Fuel Value', 'mm_fuelval', 100, 100000, 1000, function(v) setNum('fuelVal', v) end)
            mkToggle(fuel, 'Stop Drain', 'mm_drain', false, function(v) setBool('drain', v) end)
            mkButton(fuel, 'Rescan', function()
                print('[' .. NAME .. '] rescan pressed, hud=' .. hudFuelText() .. ', riding=' .. tostring(riding()))
                task.spawn(scan)
            end)
        end
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

-- boot ---------------------------------------------------------------

task.spawn(scan)

local function stop()
    running = false
    if HAS_UI then
        pcall(function() UI.RemoveTab('Mods') end)
    end
    _G[NAME] = nil
    print('[' .. NAME .. '] stopped')
end

_G[NAME] = { stop = stop, rescan = scan, version = VERSION }
print('[' .. NAME .. '] ' .. VERSION .. ' loaded, menu=' .. tostring(HAS_UI) .. ' - open the Mods tab, Fuel section')
