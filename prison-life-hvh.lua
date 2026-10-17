-- Prison Life HvH v2
-- place 135564683255158
-- gun mods / auto kill / targeted arrest / auto grab weapon
-- all controls live in one Matcha tab: HvH
-- Matcha LuauVM: no Instance.new, no hooks, no getconnections.

local NAME    = 'PLHvH'
local VERSION = 'v2'

if _G[NAME] and _G[NAME].stop then
    pcall(_G[NAME].stop)
end

local Players    = game:GetService('Players')
local RS         = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')

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

local cfg = {
    gunMods    = false,
    autoKill   = false,
    wallCheck  = false,
    sameTeam   = false,
    maxDist    = 500,
    rate       = 0.08,
    autoGrab   = false,
    autoArrest = false,
    actionCd   = 5,
}

local function track(c)
    conns[#conns + 1] = c
    return c
end

local rp = RaycastParams.new()
rp.FilterType  = Enum.RaycastFilterType.Exclude
rp.IgnoreWater = true

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
    if now - lastFire < cfg.rate then return false end
    if cfg.maxDist > 0 and (e.head.Position - origin).Magnitude > cfg.maxDist then
        return false
    end
    if not visibleFrom(origin, e.head) then return false end
    lastFire = now
    shootEvent:FireServer({ { origin, e.head.Position, e.head } })
    return true
end

-- collector: 4 Hz, does the expensive lookups
task.spawn(function()
    while running do
        targets = enemyList()
        task.wait(0.25)
    end
end)

-- renderer: crosshair target only, reads the table
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

-- gun loop
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

-- actions
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
    -- change t.plr to t.char on the next line and re-exec.
    local ok, err = pcall(function()
        return arrestFn:InvokeServer(t.plr)
    end)
    task.wait(0.2)
    local back = lp.Character and lp.Character:FindFirstChild('HumanoidRootPart')
    if back then back.CFrame = home end
    print('[PLHvH] arrest ' .. t.plr.Name .. (ok and ' ok' or (' err ' .. tostring(err))))
end

-- action loop
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

-- UI: widget signatures differ between builds, so every widget is built
-- through a variant-trying helper and read back with UI.GetValue.
local built = false

local function mkToggle(sec, name, id, default)
    local ok = pcall(function() sec:Toggle(name, id, default, function() end) end)
    if ok then return end
    ok = pcall(function() sec:Toggle(id, name, default, function() end) end)
    if ok then return end
    pcall(function() sec:Toggle(name, default, function() end) end)
end

local function mkSlider(sec, name, id, min, max, default)
    local ok = pcall(function() sec:SliderInt(name, id, min, max, default, function() end) end)
    if ok then return end
    pcall(function() sec:SliderInt(name, min, max, default, function() end) end)
end

local function mkButton(sec, name, cb)
    local ok = pcall(function() sec:Button(name, cb) end)
    if ok then return end
    pcall(function() sec:Button(name, name .. '_btn', cb) end)
end

UI.AddTab('HvH', function(tab)
    if built then return end
    built = true
    pcall(function()
        local gun = tab:Section('Gun')
        mkToggle(gun, 'Gun Mods', 'pl_gunmods', false)
        mkToggle(gun, 'Auto Kill', 'pl_autokill', false)
        mkToggle(gun, 'Wall Check', 'pl_wallcheck', false)
        mkToggle(gun, 'Same Team', 'pl_sameteam', false)
        mkSlider(gun, 'Max Distance', 'pl_maxdist', 0, 1000, 500)
        mkSlider(gun, 'Fire Rate ms', 'pl_rate', 20, 500, 80)

        local act = tab:Section('Actions')
        mkToggle(act, 'Auto Arrest', 'pl_autoarrest', false)
        mkToggle(act, 'Auto Grab Weapon', 'pl_autograb', false)
        mkSlider(act, 'Action Cooldown s', 'pl_actioncd', 1, 30, 5)
        mkButton(act, 'Arrest Now', function() wantArrest = true end)
        mkButton(act, 'Grab Now', function() wantGrab = true end)
    end)
end)

local function readVal(id, name, fallback)
    local v = UI.GetValue(id)
    if v == nil then v = UI.GetValue(name) end
    if v == nil then return fallback end
    return v
end

local function asBool(v, fallback)
    if type(v) == 'boolean' then return v end
    if type(v) == 'number' then return v ~= 0 end
    return fallback
end

local function asNum(v, fallback)
    if type(v) == 'number' then return v end
    return fallback
end

task.spawn(function()
    while running do
        task.wait(0.1)
        cfg.gunMods    = asBool(readVal('pl_gunmods', 'Gun Mods', cfg.gunMods), cfg.gunMods)
        cfg.autoKill   = asBool(readVal('pl_autokill', 'Auto Kill', cfg.autoKill), cfg.autoKill)
        cfg.wallCheck  = asBool(readVal('pl_wallcheck', 'Wall Check', cfg.wallCheck), cfg.wallCheck)
        cfg.sameTeam   = asBool(readVal('pl_sameteam', 'Same Team', cfg.sameTeam), cfg.sameTeam)
        cfg.maxDist    = asNum(readVal('pl_maxdist', 'Max Distance', cfg.maxDist), cfg.maxDist)
        cfg.rate       = asNum(readVal('pl_rate', 'Fire Rate ms', cfg.rate * 1000), cfg.rate * 1000) / 1000
        cfg.autoArrest = asBool(readVal('pl_autoarrest', 'Auto Arrest', cfg.autoArrest), cfg.autoArrest)
        cfg.autoGrab   = asBool(readVal('pl_autograb', 'Auto Grab Weapon', cfg.autoGrab), cfg.autoGrab)
        cfg.actionCd   = asNum(readVal('pl_actioncd', 'Action Cooldown s', cfg.actionCd), cfg.actionCd)
    end
end)

local function stop()
    running = false
    for _, c in ipairs(conns) do
        pcall(function() c:Disconnect() end)
    end
    conns = {}
    pcall(function() UI.RemoveTab('HvH') end)
    _G[NAME] = nil
    print('[PLHvH] stopped')
end

_G[NAME] = { stop = stop, version = VERSION }
print('[PLHvH] ' .. VERSION .. ' loaded - open the HvH tab')
