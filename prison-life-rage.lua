-- Prison Life Rage/HVH - Matcha LuaVM
-- silent aim (camera snap + click), triggerbot, ESP
local VERSION = '1.0'
local NAME = 'PLRage'
if _G[NAME] and _G[NAME].stop then pcall(_G[NAME].stop) end

local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local UIS = game:GetService('UserInputService')
local lp = Players.LocalPlayer
local cam = workspace.CurrentCamera

local running = true
local conns = {}

local CFG = {
    esp = true,
    aim = true,
    autoFire = true,
    teamCheck = true,
    radius = 300,
    fireDelay = 0.08,
    boxColor = Color3.fromRGB(255, 70, 70),
    hpColor = Color3.fromRGB(0, 255, 120),
    textColor = Color3.fromRGB(255, 255, 255),
}

local POOL = 32
local pool = {}
for i = 1, POOL do
    local box = Drawing.new('Square')
    box.Thickness = 1
    box.Filled = false
    box.Color = CFG.boxColor
    box.Visible = false
    local nm = Drawing.new('Text')
    nm.Size = 13
    nm.Center = true
    nm.Outline = true
    nm.Color = CFG.textColor
    nm.Visible = false
    local dt = Drawing.new('Text')
    dt.Size = 12
    dt.Center = true
    dt.Outline = true
    dt.Color = CFG.textColor
    dt.Visible = false
    local bg = Drawing.new('Square')
    bg.Filled = true
    bg.Thickness = 1
    bg.Color = Color3.fromRGB(20, 20, 20)
    bg.Visible = false
    local fg = Drawing.new('Square')
    fg.Filled = true
    fg.Thickness = 1
    fg.Color = CFG.hpColor
    fg.Visible = false
    pool[i] = { box = box, nm = nm, dt = dt, bg = bg, fg = fg }
end

local status = {}
for i = 1, 4 do
    local t = Drawing.new('Text')
    t.Size = 14
    t.Outline = true
    t.Color = CFG.textColor
    t.Position = Vector2.new(12, 8 + (i - 1) * 18)
    t.Visible = true
    t.Text = ''
    status[i] = t
end

local targets = {}
task.spawn(function()
    while running do
        local out = {}
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= lp then
                local char = plr.Character
                local head = char and char:FindFirstChild('Head')
                local root = char and char:FindFirstChild('HumanoidRootPart')
                local hum = char and char:FindFirstChildOfClass('Humanoid')
                if head and root and hum and hum.Health > 0 then
                    out[#out + 1] = { player = plr, head = head, root = root, hum = hum, name = plr.Name, team = plr.Team }
                end
            end
        end
        targets = out
        task.wait(0.35)
    end
end)

local renderConn
renderConn = RunService.RenderStepped:Connect(function()
    local list = targets
    local n = 0
    for i = 1, #list do
        if n >= POOL then break end
        local t = list[i]
        local top, v1 = WorldToScreen(t.head.Position + Vector3.new(0, 0.6, 0))
        local bot, v2 = WorldToScreen(t.root.Position - Vector3.new(0, 3.0, 0))
        if CFG.esp and v1 and v2 then
            local h = bot.Y - top.Y
            if h > 4 then
                n = n + 1
                local e = pool[n]
                local w = h * 0.5
                e.box.Position = Vector2.new(top.X - w * 0.5, top.Y)
                e.box.Size = Vector2.new(w, h)
                e.box.Visible = true
                e.nm.Text = t.name
                e.nm.Position = Vector2.new(top.X, top.Y - 17)
                e.nm.Visible = true
                local d = (t.root.Position - cam.CFrame.Position).Magnitude
                e.dt.Text = string.format('%d studs', math.floor(d))
                e.dt.Position = Vector2.new(top.X, bot.Y + 2)
                e.dt.Visible = true
                local frac = math.clamp(t.hum.Health / math.max(t.hum.MaxHealth, 1), 0, 1)
                local bw = 4
                e.bg.Position = Vector2.new(top.X - w * 0.5 - bw - 4, top.Y)
                e.bg.Size = Vector2.new(bw, h)
                e.bg.Visible = true
                local fh = h * frac
                e.fg.Position = Vector2.new(top.X - w * 0.5 - bw - 4, top.Y + (h - fh))
                e.fg.Size = Vector2.new(bw, fh)
                e.fg.Visible = true
            end
        end
    end
    for i = n + 1, POOL do
        local e = pool[i]
        e.box.Visible = false
        e.nm.Visible = false
        e.dt.Visible = false
        e.bg.Visible = false
        e.fg.Visible = false
    end
end)
table.insert(conns, renderConn)

task.spawn(function()
    while running do
        status[1].Text = '[P] PL Rage v' .. VERSION
        status[2].Text = '[P] ESP ' .. (CFG.esp and 'ON' or 'OFF') .. ' - LeftAlt'
        status[3].Text = '[P] SilentAim ' .. (CFG.aim and 'ON' or 'OFF') .. ' - RightShift'
        status[4].Text = '[P] AutoFire ' .. (CFG.autoFire and 'ON' or 'OFF') .. ' - RightCtrl'
        task.wait(0.5)
    end
end)

local aimBusy = false

local function myPos()
    local char = lp.Character
    local root = char and char:FindFirstChild('HumanoidRootPart')
    if root then
        return root.Position
    end
    return nil
end

local function pickTarget()
    local mp = myPos()
    if not mp then
        return nil
    end
    local myTeam = lp.Team
    local best = nil
    local bestD = CFG.radius
    for i = 1, #targets do
        local t = targets[i]
        local ok = true
        if CFG.teamCheck and myTeam and t.team == myTeam then
            ok = false
        end
        if ok then
            local d = (t.root.Position - mp).Magnitude
            if d < bestD then
                bestD = d
                best = t
            end
        end
    end
    return best
end

task.spawn(function()
    while running do
        if (CFG.aim or CFG.autoFire) and not aimBusy then
            local t = pickTarget()
            if t then
                aimBusy = true
                task.spawn(function()
                    local saved = cam.CFrame
                    local aim = CFrame.lookAt(saved.Position, t.head.Position)
                    pcall(function()
                        cam.CFrame = aim
                    end)
                    task.wait(0.03)
                    if CFG.autoFire then
                        pcall(function()
                            mouse1click()
                        end)
                    end
                    task.wait(0.03)
                    pcall(function()
                        cam.CFrame = saved
                    end)
                    aimBusy = false
                end)
            end
        end
        task.wait(CFG.fireDelay)
    end
end)

local keyConn = UIS.InputBegan:Connect(function(input)
    if not running then
        return
    end
    local k = input.KeyCode
    if k == Enum.KeyCode.LeftAlt then
        CFG.esp = not CFG.esp
    elseif k == Enum.KeyCode.RightShift then
        CFG.aim = not CFG.aim
    elseif k == Enum.KeyCode.RightControl then
        CFG.autoFire = not CFG.autoFire
    elseif k == Enum.KeyCode.P then
        if _G[NAME] and _G[NAME].stop then
            pcall(_G[NAME].stop)
        end
    end
end)
table.insert(conns, keyConn)

local function stop()
    if not running then
        return
    end
    running = false
    for i = 1, #conns do
        pcall(function()
            conns[i]:Disconnect()
        end)
    end
    for i = 1, POOL do
        local e = pool[i]
        pcall(function() e.box:Remove() end)
        pcall(function() e.nm:Remove() end)
        pcall(function() e.dt:Remove() end)
        pcall(function() e.bg:Remove() end)
        pcall(function() e.fg:Remove() end)
    end
    for i = 1, #status do
        pcall(function() status[i]:Remove() end)
    end
    _G[NAME] = nil
end

_G[NAME] = { stop = stop, version = VERSION }
print('[PLRage] v' .. VERSION .. ' loaded - press P to unload')
