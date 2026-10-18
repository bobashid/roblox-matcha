-- Weapon Mods + Inf Stamina + Inf Fuel - Matcha LuauVM - v2
-- one Matcha menu tab: Mods (toggles + sliders, no keybinds)
-- no Instance.new, no hooks, no getconnections.
-- getgc on this build costs 10-20s: it runs ONCE in the background and
-- again only when you press Rescan. Never inside a loop.
--
-- NOTE on Inf Fuel: probed place 105011592530400 (Build and Kill Zombies) and
-- found no client-visible fuel value - no Instance named Fuel, and getgc('Fuel')
-- returned booleans/strings plus four unrelated numbers. The toggle is wired to
-- a candidate key list and only does something if the game really holds one.
-- Drive or refuel, then press Rescan and check the print line.

local NAME    = 'ModsMenu'
local VERSION = 'v2'

if _G[NAME] and _G[NAME].stop then
    pcall(_G[NAME].stop)
end
print('[' .. NAME .. '] ' .. VERSION)

local running  = true
local built    = false
local cache    = nil
local scanning = false
local nWeapon  = 0
local nStam    = 0
local nFuel    = 0

local cfg = {
    infammo  = false,
    norecoil = false,
    damage   = false,
    rapid    = false,
    nospread = false,
    stamina  = false,
    fuel     = false,
    dmgVal   = 100,
    rateVal  = 0.02,
    stamVal  = 100,
    fuelVal  = 100,
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
    'MaxFuel', 'FuelCapacity', 'Gas', 'Gasoline', 'Petrol', 'Tank',
}

-- stamina + fuel in ONE getgc call: a scan is the expensive part, not the keys.
local RESOURCE_KEYS = {}
for _, k in ipairs(STAMINA_KEYS) do RESOURCE_KEYS[#RESOURCE_KEYS + 1] = k end
for _, k in ipairs(FUEL_KEYS)    do RESOURCE_KEYS[#RESOURCE_KEYS + 1] = k end

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

-- scan ---------------------------------------------------------------

local function scan()
    if scanning then return end
    scanning = true
    nWeapon, nStam, nFuel = 0, 0, 0

    local ok, res = pcall(getgc, WEAPON_KEYS)
    if ok and type(res) == 'table' and #res > 0 then
        cache   = res
        nWeapon = #res
    end

    local ok2, res2 = pcall(getgc, RESOURCE_KEYS)
    if ok2 and type(res2) == 'table' and #res2 > 0 then
        cache = cache or {}
        local stamSet, fuelSet = {}, {}
        for _, k in ipairs(STAMINA_KEYS) do stamSet[k] = true end
        for _, k in ipairs(FUEL_KEYS)    do fuelSet[k] = true end
        for _, e in ipairs(res2) do
            -- only numeric entries are safe to write
            if e.type == 'number' then
                if stamSet[e.key] then
                    cache[#cache + 1] = e
                    nStam = nStam + 1
                elseif fuelSet[e.key] then
                    cache[#cache + 1] = e
                    nFuel = nFuel + 1
                end
            end
        end
    end

    print('[' .. NAME .. '] scan: weapon ' .. nWeapon .. ', stamina ' .. nStam .. ', fuel ' .. nFuel)
    if nStam == 0 then
        pcall(notify, 'Mods', 'no stamina keys - press Rescan while the bar drains', 3)
    end
    if nFuel == 0 then
        pcall(notify, 'Mods', 'no fuel keys - press Rescan while fuel drains', 3)
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
            if cfg.fuel then
                for _, k in ipairs(FUEL_KEYS) do
                    pcall(applygc, cache, k, cfg.fuelVal)
                end
            end
        end
        task.wait(0.25)
    end
end)

-- menu ---------------------------------------------------------------
-- Same widget pattern as prison-life-hvh.lua:
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
        if ok and sec ~= nil then
            return sec
        end
    end
    local ok, sec = pcall(function() return tab:Section(name) end)
    if ok and sec ~= nil then
        return sec
    end
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
        end

        local stam = mkSection(tab, 'Stamina')
        if stam then
            mkToggle(stam, 'Inf Stamina', 'mm_stamina', false, function(v) setBool('stamina', v) end)
            mkSlider(stam, 'Stamina Value', 'mm_stamval', 100, 1000, 100, function(v) setNum('stamVal', v) end)
        end

        local fuel = mkSection(tab, 'Fuel')
        if fuel then
            mkToggle(fuel, 'Inf Fuel', 'mm_fuel', false, function(v) setBool('fuel', v) end)
            mkSlider(fuel, 'Fuel Value', 'mm_fuelval', 100, 100000, 100, function(v) setNum('fuelVal', v) end)
            mkButton(fuel, 'Rescan', function()
                print('[' .. NAME .. '] rescan pressed')
                task.spawn(scan)
            end)
        end

        if gun then
            mkButton(gun, 'Rescan', function()
                print('[' .. NAME .. '] rescan pressed')
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

-- boot ----------------------------------------------------------------

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
print('[' .. NAME .. '] ' .. VERSION .. ' loaded, menu=' .. tostring(HAS_UI) .. ' - open the Mods tab')
