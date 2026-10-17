-- Prison Life HvH v5
-- place 135564683255158
-- gun mods / auto kill / targeted arrest / auto grab weapon
-- all controls in one Matcha menu tab: HvH
-- Matcha LuauVM: no Instance.new, no hooks, no getconnections.

local NAME    = 'PLHvH'
local VERSION = 'v5'

if _G[NAME] and _G[NAME].stop then
    pcall(_G[NAME].stop)
end

local Players    = game:GetService('Players')
local RS         = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local UIS        = game:GetService('UserInputService')

local lp = Players.LocalPlayer

local gunRemotes = RS:FindFirstChild('GunRemotes')
local remotes    = RS:FindFirstChild('Remotes')
local shootEvent = gunRemotes and gunRemotes:FindFirstChild('ShootEvent')
local arrestFn   = remotes and remotes:FindFirstChild('ArrestPlayer')
local interactFn = remotes and remotes:FindFirstChild('InteractWithItem')

local running    = true
local conns      = {}
local targets    = {}
local aimTarget  = nil
local lastFire   = 0
local lastAction = 0
local busy       = false
local wantGrab   = false
local wantArrest = false
local built      = false

local cfg = {
    gunMods    = false,
    autoKill   = false,
    wallCheck  = false,
    sameTeam   = false,
    maxDist    = 500,
    rateMs     = 80,
    autoArrest = false,
    autoGrab   = false,
    actionCd   = 5,
}

local function track(c)
    conns[#conns + 1] = c
    return c
end

local function setBool(key, v)
    if cfg[key] ~= v then
        cfg[key] = v
        print('[PLHvH] ' .. key .. ' = ' .. tostring(v))
    end
end

local function setNum(key, v)
    if cfg[key] ~= v then
        cfg[key] = v
        print('[PLHvH] ' .. key .. ' = ' .. tostring(v))
    end
end

local rp = RaycastParams.new()
rp.FilterType  = Enum.RaycastFilterType.Exclude
rp.IgnoreWater = true

-- targets ------------------------------------------------------------

local function enemyList()
    local out = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= lp then
            local char = p.Character
            local hum  = char and char:FindFirstChild('Humanoid')
            local head = char and char:FindFirstChild('Head')
            local root = char and char:FindFirstChild('HumanoidRootPart')
            if hum and head and root and hum.Health > 0
                and not char:FindFirstChildOfClass('ForceField') then
                if cfg.sameTeam or p.Team ~= lp.Team then
                    out[#out + 1] = { plr = p, char = char, hum = hum, head = head, root = root }
                end
            end
        end
    end
    return out
end

local function closest(fromPos)
    local best, bestD = nil, math.huge
    for _, e in ipairs(targets) do
        local d = (e.head.Position - fromPos).Magnitude
        if (cfg.maxDist == 0 or d <= cfg.maxDist) and d < bestD then
            best, bestD = e, d
        end
    end
    return best
end

local function equippedGun()
    local char = lp.Character
    if not char then return nil end
    for _, c in ipairs(char:GetChildren()) do
        if c.ClassName == 'Tool' and c:GetAttribute('Damage') ~= nil then
            return c
        end
    end
    return nil
end

local function refill(gun)
    local max = gun:GetAttribute('MaxAmmo')
    if max then
        gun:SetAttribute('Local_CurrentAmmo', max)
    end
end

local function visibleFrom(origin, part)
    if not cfg.wallCheck then return true end
    local char = lp.Character
    rp.FilterDescendantsInstances = char and { char } or {}
    local hit = workspace:Raycast(origin, part.Position - origin, rp)
    if not hit then return true end
    return hit.Instance:IsDescendantOf(part.Parent)
end

local function fireAt(origin, e)
    if not shootEvent or not e then return false end
    local now = tick()
    if now - lastFire < cfg.rateMs / 1000 then return false end
    if cfg.maxDist > 0 and (e.head.Position - origin).Magnitude > cfg.maxDist then
        return false
    end
    if not visibleFrom(origin, e.head) then return false end
    lastFire = now
    shootEvent:FireServer({ { origin, e.head.Position, e.head } })
    return true
end

task.spawn(function()
    while running do
        targets = enemyList()
        task.wait(0.25)
    end
end)

track(RunService.RenderStepped:Connect(function()
    local cam = workspace.CurrentCamera
    if not cam then aimTarget = nil return end
    local vs = cam.ViewportSize
    local cx, cy = vs.X * 0.5, vs.Y * 0.5
    local best, bestD = nil, math.huge
    for _, e in ipairs(targets) do
        local sp, vis = WorldToScreen(e.head.Position)
        if vis then
            local dx, dy = sp.X - cx, sp.Y - cy
            local d = dx * dx + dy * dy
            if d < bestD then best, bestD = e, d end
        end
    end
    aimTarget = best
end))

task.spawn(function()
    while running do
        task.wait(0.02)
        local gun  = equippedGun()
        local char = lp.Character
        local head = char and char:FindFirstChild('Head')
        if gun and (cfg.gunMods or cfg.autoKill) then
            refill(gun)
        end
        if gun and head then
            local origin = head.Position
            if cfg.gunMods and ismouse1pressed() and aimTarget then
                fireAt(origin, aimTarget)
            elseif cfg.autoKill then
                fireAt(origin, closest(origin))
            end
        end
    end
end)

-- actions ------------------------------------------------------------

local RACK_NAMES = { 'Gun racks', 'SWAT gun rack', 'Gunstore_Display' }

local function firstPart(model)
    if model.ClassName == 'Part' or model.ClassName == 'MeshPart' then
        return model
    end
    for _, c in ipairs(model:GetChildren()) do
        if c.ClassName == 'Part' or c.ClassName == 'MeshPart' then
            return c
        end
    end
    return nil
end

local function doGrab()
    local my = lp.Character and lp.Character:FindFirstChild('HumanoidRootPart')
    if not my or not interactFn then return end
    for _, name in ipairs(RACK_NAMES) do
        local m = workspace:FindFirstChild(name)
        local part = m and firstPart(m)
        if part then
            local home = my.CFrame
            my.CFrame = CFrame.new(part.Position + Vector3.new(0, 3, 0))
            task.wait(0.2)
            local ok, err = pcall(function()
                return interactFn:InvokeServer(m)
            end)
            task.wait(0.2)
            local back = lp.Character and lp.Character:FindFirstChild('HumanoidRootPart')
            if back then back.CFrame = home end
            print('[PLHvH] grab ' .. name .. (ok and ' sent' or (' err ' .. tostring(err))))
            return
        end
    end
    print('[PLHvH] grab: no rack found')
end

local function doArrest()
    if not arrestFn then
        notify('arrest', 'ArrestPlayer remote missing', 2)
        return
    end
    local my = lp.Character and lp.Character:FindFirstChild('HumanoidRootPart')
    if not my then return end
    local t = aimTarget or closest(my.Position)
    if not t then
        notify('arrest', 'no target', 1.5)
        return
    end
    local home = my.CFrame
    my.CFrame = t.root.CFrame * CFrame.new(0, 0, -3)
    task.wait(0.2)
    -- UNVERIFIED: ArrestPlayer argument shape. If nothing happens,
    -- change t.plr to t.char on the next line.
    local ok, err = pcall(function()
        return arrestFn:InvokeServer(t.plr)
    end)
    task.wait(0.2)
    local back = lp.Character and lp.Character:FindFirstChild('HumanoidRootPart')
    if back then back.CFrame = home end
    print('[PLHvH] arrest ' .. t.plr.Name .. (ok and ' ok' or (' err ' .. tostring(err))))
end

task.spawn(function()
    while running do
        task.wait(0.2)
        if not busy then
            local now = tick()
            if wantArrest then
                wantArrest = false
                busy = true
                pcall(doArrest)
                busy = false
            elseif wantGrab then
                wantGrab = false
                busy = true
                pcall(doGrab)
                busy = false
            elseif cfg.autoArrest and now - lastAction >= cfg.actionCd then
                lastAction = now
                busy = true
                pcall(doArrest)
                busy = false
            elseif cfg.autoGrab and now - lastAction >= cfg.actionCd then
                lastAction = now
                busy = true
                pcall(doGrab)
                busy = false
            end
        end
    end
end)

-- menu ---------------------------------------------------------------
-- Live facts on this build:
--   * the AddTab callback DOES fire (logs: 'tab opened - building widgets')
--   * tab:Section(name) alone returns a non-table value and the widgets
--     vanish; tab:Section(name, 'Left') returns a usable handle.
--   * never test type(sec) == 'table', only sec ~= nil.
--   * UI.GetValue returned nil in every probe, so the widget callback is
--     the primary source of truth; poll only when the getter answers.

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
            print('[PLHvH] section ' .. name .. ' (' .. sides[i] .. ') -> ' .. type(sec))
            return sec
        end
    end
    local ok, sec = pcall(function() return tab:Section(name) end)
    if ok and sec ~= nil then
        print('[PLHvH] section ' .. name .. ' (no side) -> ' .. type(sec))
        return sec
    end
    warn('[PLHvH] section ' .. name .. ' FAILED')
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
    warn('[PLHvH] toggle failed: ' .. label)
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
    warn('[PLHvH] slider failed: ' .. label)
    return false
end

-- Button must be tried as (name, cb) FIRST: (name, id, cb) succeeds but
-- never wires the callback.
local function mkButton(sec, label, cb)
    if pcall(function() sec:Button(label, cb) end) then return true end
    if pcall(function() sec:Button(label, label .. '_btn', cb) end) then return true end
    warn('[PLHvH] button failed: ' .. label)
    return false
end

local function buildTab(tab)
    if built then return end
    built = true

    local ok, err = pcall(function()
        local gun = mkSection(tab, 'Gun')
        if gun then
            mkToggle(gun, 'Gun Mods', 'pl_gunmods', false, function(v) setBool('gunMods', v) end)
            mkToggle(gun, 'Auto Kill', 'pl_autokill', false, function(v) setBool('autoKill', v) end)
            mkToggle(gun, 'Wall Check', 'pl_wallcheck', false, function(v) setBool('wallCheck', v) end)
            mkToggle(gun, 'Same Team', 'pl_sameteam', false, function(v) setBool('sameTeam', v) end)
            mkSlider(gun, 'Max Distance', 'pl_maxdist', 0, 1000, 500, function(v) setNum('maxDist', v) end)
            mkSlider(gun, 'Fire Rate ms', 'pl_rate', 20, 500, 80, function(v) setNum('rateMs', v) end)
        end

        local act = mkSection(tab, 'Actions')
        if act then
            mkToggle(act, 'Auto Arrest', 'pl_autoarrest', false, function(v) setBool('autoArrest', v) end)
            mkToggle(act, 'Auto Grab Weapon', 'pl_autograb', false, function(v) setBool('autoGrab', v) end)
            mkSlider(act, 'Action Cooldown s', 'pl_actioncd', 1, 30, 5, function(v) setNum('actionCd', v) end)
            mkButton(act, 'Arrest Now', function()
                wantArrest = true
                print('[PLHvH] Arrest Now pressed')
            end)
            mkButton(act, 'Grab Now', function()
                wantGrab = true
                print('[PLHvH] Grab Now pressed')
            end)
        end
    end)

    if not ok then
        warn('[PLHvH] build error: ' .. tostring(err))
    end
    print('[PLHvH] tab widgets built')
end

if HAS_UI then
    local ok, err = pcall(function()
        UI.AddTab('HvH', function(tab)
            if built then return end
            print('[PLHvH] tab opened - building widgets')
            pcall(buildTab, tab)
        end)
    end)
    if not ok then
        warn('[PLHvH] UI.AddTab failed: ' .. tostring(err))
        HAS_UI = false
    end
end

-- fallback read-back: only applied when the getter actually answers ------

local function readVal(id, label)
    local ok, v = pcall(function() return UI.GetValue(id) end)
    if ok and v ~= nil then return v end
    ok, v = pcall(function() return UI.GetValue(label) end)
    if ok and v ~= nil then return v end
    return nil
end

local POLL = {
    { 'pl_gunmods',    'Gun Mods',          'gunMods',    'bool' },
    { 'pl_autokill',   'Auto Kill',         'autoKill',   'bool' },
    { 'pl_wallcheck',  'Wall Check',        'wallCheck',  'bool' },
    { 'pl_sameteam',   'Same Team',         'sameTeam',   'bool' },
    { 'pl_maxdist',    'Max Distance',      'maxDist',    'num'  },
    { 'pl_rate',       'Fire Rate ms',      'rateMs',     'num'  },
    { 'pl_autoarrest', 'Auto Arrest',       'autoArrest', 'bool' },
    { 'pl_autograb',   'Auto Grab Weapon',  'autoGrab',   'bool' },
    { 'pl_actioncd',   'Action Cooldown s', 'actionCd',   'num'  },
}

task.spawn(function()
    while running do
        task.wait(0.15)
        if HAS_UI and built then
            for _, w in ipairs(POLL) do
                local v = readVal(w[1], w[2])
                if v ~= nil then
                    if w[4] == 'bool' then
                        if type(v) == 'boolean' then setBool(w[3], v) end
                    elseif type(v) == 'number' then
                        setNum(w[3], v)
                    end
                end
            end
        end
    end
end)

-- keyboard fallback ---------------------------------------------------

if not HAS_UI then
    print('[PLHvH] menu unavailable - using keys X Z H G')
    track(UIS.InputBegan:Connect(function(input)
        local k = input.KeyCode
        if k == Enum.KeyCode.X then
            setBool('gunMods', not cfg.gunMods)
        elseif k == Enum.KeyCode.Z then
            setBool('autoKill', not cfg.autoKill)
        elseif k == Enum.KeyCode.H then
            wantGrab = true
        elseif k == Enum.KeyCode.G then
            wantArrest = true
        end
    end))
end

local function stop()
    running = false
    for _, c in ipairs(conns) do
        pcall(function() c:Disconnect() end)
    end
    conns = {}
    if HAS_UI then
        pcall(function() UI.RemoveTab('HvH') end)
    end
    _G[NAME] = nil
    print('[PLHvH] stopped')
end

_G[NAME] = { stop = stop, version = VERSION }
print('[PLHvH] ' .. VERSION .. ' loaded, menu=' .. tostring(HAS_UI) .. ' - open the HvH tab once')
