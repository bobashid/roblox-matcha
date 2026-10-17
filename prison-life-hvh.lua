-- Prison Life HvH v1
-- place 135564683255158
-- gun mods / targeted arrest / auto kill / auto grab weapon
-- Matcha LuauVM: no Instance.new, no hooks, no getconnections.

local NAME    = "PLHvH"
local VERSION = "v1"

if _G[NAME] and _G[NAME].stop then
    pcall(_G[NAME].stop)
end

local Players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")

local lp = Players.LocalPlayer

local gunRemotes = RS:FindFirstChild("GunRemotes")
local remotes    = RS:FindFirstChild("Remotes")

local shootEvent = gunRemotes and gunRemotes:FindFirstChild("ShootEvent")
local funcReload = gunRemotes and gunRemotes:FindFirstChild("FuncReload")
local arrestFn   = remotes and remotes:FindFirstChild("ArrestPlayer")
local interactFn = remotes and remotes:FindFirstChild("InteractWithItem")

local running = true
local conns   = {}
local function track(c)
    conns[#conns + 1] = c
    return c
end

local cfg = {
    gunMods   = false,  -- X: LMB fires a magic bullet at the crosshair target
    autoKill  = false,  -- Z: fires at the closest enemy non stop
    grab      = false,  -- H: auto grab a weapon from a rack
    rate      = 0.08,   -- minimum seconds between our shots
    maxDist   = 500,    -- 0 = unlimited
    wallCheck = false,  -- true = only shoot visible targets
    sameTeam  = false,  -- true = also shoot teammates
}

local lastFire  = 0
local aimTarget = nil
local targets   = {}
local busy      = false

local rp = RaycastParams.new()
rp.FilterType  = Enum.RaycastFilterType.Exclude
rp.IgnoreWater = true

local function enemyList()
    local out = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= lp then
            local char = p.Character
            local hum  = char and char:FindFirstChild("Humanoid")
            local head = char and char:FindFirstChild("Head")
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if hum and head and root and hum.Health > 0
                and not char:FindFirstChildOfClass("ForceField") then
                if cfg.sameTeam or p.Team ~= lp.Team then
                    out[#out + 1] = {
                        plr = p, char = char, hum = hum, head = head, root = root,
                    }
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
        if c.ClassName == "Tool" and c:GetAttribute("Damage") ~= nil then
            return c
        end
    end
    return nil
end

local function refill(gun)
    local max = gun:GetAttribute("MaxAmmo")
    if max then
        gun:SetAttribute("CurrentAmmo", max)
        gun:SetAttribute("Local_CurrentAmmo", max)
    end
end

local function visible(origin, part)
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
    if not visible(origin, e.head) then return false end
    lastFire = now
    shootEvent:FireServer({ { origin, e.head.Position, e.head } })
    return true
end

-- collector: expensive lookups, 4 Hz
task.spawn(function()
    while running do
        targets = enemyList()
        task.wait(0.25)
    end
end)

-- renderer: crosshair target only
track(RunService.RenderStepped:Connect(function()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vs = cam.ViewportSize
    local cx, cy = vs.X * 0.5, vs.Y * 0.5
    local best, bestD = nil, math.huge
    for _, e in ipairs(targets) do
        local sp, vis = WorldToScreen(e.head.Position)
        if vis then
            local d = (sp.X - cx) * (sp.X - cx) + (sp.Y - cy) * (sp.Y - cy)
            if d < bestD then
                best, bestD = e, d
            end
        end
    end
    aimTarget = best
end))

-- main action loop
task.spawn(function()
    while running do
        task.wait(0.02)
        local gun  = equippedGun()
        local char = lp.Character
        local head = char and char:FindFirstChild("Head")
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

-- auto grab weapon
local RACK_NAMES = { "Gun racks", "SWAT gun rack", "Gunstore_Display" }

local function firstPart(model)
    if model.ClassName == "Part" or model.ClassName == "MeshPart" then
        return model
    end
    for _, c in ipairs(model:GetChildren()) do
        if c.ClassName == "Part" or c.ClassName == "MeshPart" then
            return c
        end
    end
    return nil
end

local function tryGrab()
    local my = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
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
            local back = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
            if back then back.CFrame = home end
            print("[PLHvH] grab " .. name .. (ok and " sent" or (" err " .. tostring(err))))
            return
        end
    end
end

task.spawn(function()
    while running do
        task.wait(1)
        if cfg.grab and not busy then
            busy = true
            pcall(tryGrab)
            busy = false
            task.wait(4)
        end
    end
end)

-- targeted arrest
local function doArrest()
    if busy then return end
    if not arrestFn then
        notify("arrest", "ArrestPlayer remote missing", 2)
        return
    end
    local my = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    if not my then return end
    local t = aimTarget or closest(my.Position)
    if not t then
        notify("arrest", "no target", 1.5)
        return
    end
    busy = true
    local home = my.CFrame
    my.CFrame = t.root.CFrame * CFrame.new(0, 0, -3)
    task.wait(0.2)
    -- UNVERIFIED: argument shape of ArrestPlayer (player vs character).
    -- If nothing happens, change t.plr to t.char on the next line.
    local ok, err = pcall(function()
        return arrestFn:InvokeServer(t.plr)
    end)
    task.wait(0.2)
    local back = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    if back then back.CFrame = home end
    busy = false
    print("[PLHvH] arrest " .. t.plr.Name .. (ok and " ok" or (" err " .. tostring(err))))
end

-- keybinds
track(UIS.InputBegan:Connect(function(input)
    local k = input.KeyCode
    if k == Enum.KeyCode.X then
        cfg.gunMods = not cfg.gunMods
        notify("gun mods", cfg.gunMods and "on" or "off", 1.5)
    elseif k == Enum.KeyCode.Z then
        cfg.autoKill = not cfg.autoKill
        notify("auto kill", cfg.autoKill and "on" or "off", 1.5)
    elseif k == Enum.KeyCode.H then
        cfg.grab = not cfg.grab
        notify("auto grab", cfg.grab and "on" or "off", 1.5)
    elseif k == Enum.KeyCode.G then
        task.spawn(doArrest)
    end
end))

-- stop
local function stop()
    running = false
    for _, c in ipairs(conns) do
        pcall(function() c:Disconnect() end)
    end
    conns = {}
    _G[NAME] = nil
    print("[PLHvH] stopped")
end

_G[NAME] = { stop = stop, version = VERSION }
print("[PLHvH] " .. VERSION .. " loaded - X gun mods, Z auto kill, H grab, G arrest")
