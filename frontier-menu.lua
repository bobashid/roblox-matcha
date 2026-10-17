-- Frontier Menu v1 (Matcha) - place 119263815547952
-- Drawing-based menu, keyboard driven. No Instance.new, no GUI objects.
local VERSION = "v1"
local NAME = "FrontierMenu"
if _G[NAME] and _G[NAME].stop then pcall(_G[NAME].stop) end
print("[FrontierMenu] " .. VERSION .. " loaded")

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local WS         = game:GetService("Workspace")
local LP         = Players.LocalPlayer

local running = true
local conn, inputConn
local cfg = { menu = true, pEsp = true, uEsp = false, tracers = false, fov = 70 }

-- ============================ MENU ============================
local MX, MY = 24, 150
local ROWS = {
    { key = "pEsp",    label = "Player ESP" },
    { key = "uEsp",    label = "Unit ESP"   },
    { key = "tracers", label = "Tracers"    },
    { key = "fov",     label = "FOV"        },
}

local MENU_W = 232
local MENU_H = 34 + #ROWS * 18 + 20
local menuObjs = {}
local rowTexts = {}

local bg = Drawing.new("Square")
bg.Filled = true
bg.Color = Color3.fromRGB(14, 14, 18)
bg.Transparency = 0.15
bg.Position = Vector2.new(MX, MY)
bg.Size = Vector2.new(MENU_W, MENU_H)
bg.Visible = true
menuObjs[#menuObjs + 1] = bg

local border = Drawing.new("Square")
border.Filled = false
border.Thickness = 1
border.Color = Color3.fromRGB(255, 170, 60)
border.Transparency = 0.35
border.Position = Vector2.new(MX, MY)
border.Size = Vector2.new(MENU_W, MENU_H)
border.Visible = true
menuObjs[#menuObjs + 1] = border

local title = Drawing.new("Text")
title.Text = "FRONTIER  " .. VERSION
title.Size = 14
title.Outline = true
title.Font = 2
title.Color = Color3.fromRGB(255, 190, 80)
title.Position = Vector2.new(MX + 10, MY + 8)
title.Visible = true
menuObjs[#menuObjs + 1] = title

for i = 1, #ROWS do
    local t = Drawing.new("Text")
    t.Text = ""
    t.Size = 13
    t.Outline = true
    t.Font = 5
    t.Color = Color3.fromRGB(225, 225, 225)
    t.Position = Vector2.new(MX + 12, MY + 32 + (i - 1) * 18)
    t.Visible = true
    rowTexts[i] = t
    menuObjs[#menuObjs + 1] = t
end

local hint = Drawing.new("Text")
hint.Text = "[RShift] hide  [1-4] toggle  [5] unload"
hint.Size = 11
hint.Outline = true
hint.Font = 5
hint.Color = Color3.fromRGB(150, 150, 150)
hint.Position = Vector2.new(MX + 10, MY + 34 + #ROWS * 18)
hint.Visible = true
menuObjs[#menuObjs + 1] = hint

local function onoff(v) return v and "ON" or "OFF" end

local refreshRows

local function applyMenu()
    for _, o in ipairs(menuObjs) do o.Visible = cfg.menu end
    if cfg.menu then refreshRows() end
end

local function setFov(v)
    cfg.fov = v
    local cam = WS.CurrentCamera
    if cam then cam.FieldOfView = v end
    if refreshRows then refreshRows() end
end

refreshRows = function()
    for i = 1, #ROWS do
        local r = ROWS[i]
        local val
        if r.key == "fov" then
            val = tostring(cfg.fov)
        else
            val = onoff(cfg[r.key])
        end
        rowTexts[i].Text = string.format("[%d] %-12s %s", i, r.label, val)
        if r.key ~= "fov" and cfg[r.key] then
            rowTexts[i].Color = Color3.fromRGB(120, 230, 140)
        else
            rowTexts[i].Color = Color3.fromRGB(225, 225, 225)
        end
    end
end

setFov(cfg.fov)

-- ============================ ESP POOLS ============================
local PP, UP = 24, 48
local pPool, uPool = {}, {}

for i = 1, PP do
    local box = Drawing.new("Square")
    box.Thickness = 1
    box.Filled = false
    box.Color = Color3.fromRGB(255, 90, 90)
    box.Visible = false
    local nm = Drawing.new("Text")
    nm.Size = 13
    nm.Center = true
    nm.Outline = true
    nm.Color = Color3.fromRGB(255, 255, 255)
    nm.Visible = false
    local hb = Drawing.new("Square")
    hb.Filled = true
    hb.Color = Color3.fromRGB(25, 25, 25)
    hb.Visible = false
    local hf = Drawing.new("Square")
    hf.Filled = true
    hf.Color = Color3.fromRGB(90, 220, 110)
    hf.Visible = false
    local tr = Drawing.new("Line")
    tr.Thickness = 1
    tr.Color = Color3.fromRGB(255, 90, 90)
    tr.Visible = false
    pPool[i] = { box = box, name = nm, hb = hb, hf = hf, tr = tr }
end

for i = 1, UP do
    local box = Drawing.new("Square")
    box.Thickness = 1
    box.Filled = false
    box.Color = Color3.fromRGB(255, 200, 60)
    box.Visible = false
    uPool[i] = { box = box }
end

-- ============================ COLLECTORS ============================
local pTargets, uTargets = {}, {}

task.spawn(function()
    while running do
        local out = {}
        local list = Players:GetPlayers()
        for i = 1, #list do
            local plr = list[i]
            if plr ~= LP then
                local ch = plr.Character
                local head = ch and ch:FindFirstChild("Head")
                local root = ch and ch:FindFirstChild("HumanoidRootPart")
                local hum  = ch and ch:FindFirstChild("Humanoid")
                if head and root and hum then
                    out[#out + 1] = { name = plr.Name, head = head, root = root, hum = hum }
                end
            end
        end
        pTargets = out
        task.wait(0.35)
    end
end)

task.spawn(function()
    while running do
        local out = {}
        local uf = WS:FindFirstChild("Units")
        if uf then
            local kids = uf:GetChildren()
            for i = 1, #kids do
                if #out >= UP then break end
                local m = kids[i]
                local hull = m:FindFirstChild("Hull")
                local part
                if hull then
                    part = hull:FindFirstChild("Hull_Body")
                        or hull:FindFirstChild("Hull_Fixed")
                        or hull:FindFirstChildOfClass("MeshPart")
                        or hull:FindFirstChildOfClass("Part")
                end
                if not part then
                    part = m:FindFirstChildOfClass("MeshPart") or m:FindFirstChildOfClass("Part")
                end
                if part then
                    out[#out + 1] = { part = part }
                end
            end
        end
        uTargets = out
        task.wait(0.5)
    end
end)

-- ============================ RENDERER ============================
conn = RunService.RenderStepped:Connect(function()
    local cam = WS.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)

    local n = 0
    if cfg.pEsp or cfg.tracers then
        for i = 1, #pTargets do
            if n >= PP then break end
            local t = pTargets[i]
            local top, v1 = WorldToScreen(t.head.Position + Vector3.new(0, 0.8, 0))
            local bot, v2 = WorldToScreen(t.root.Position - Vector3.new(0, 3.0, 0))
            if v1 and v2 then
                n = n + 1
                local e = pPool[n]
                local h = bot.Y - top.Y
                if h < 4 then h = 4 end
                local w = h * 0.5

                if cfg.pEsp then
                    e.box.Position = Vector2.new(top.X - w * 0.5, top.Y)
                    e.box.Size = Vector2.new(w, h)
                    e.box.Visible = true

                    e.name.Text = t.name
                    e.name.Position = Vector2.new(top.X, top.Y - 16)
                    e.name.Visible = true

                    local hp = 1
                    local maxh = t.hum.MaxHealth
                    if maxh and maxh > 0 then hp = t.hum.Health / maxh end
                    if hp < 0 then hp = 0 end
                    if hp > 1 then hp = 1 end

                    e.hb.Position = Vector2.new(top.X - w * 0.5 - 6, top.Y)
                    e.hb.Size = Vector2.new(3, h)
                    e.hb.Visible = true

                    e.hf.Position = Vector2.new(top.X - w * 0.5 - 6, top.Y + h * (1 - hp))
                    e.hf.Size = Vector2.new(3, h * hp)
                    e.hf.Visible = true
                else
                    e.box.Visible = false
                    e.name.Visible = false
                    e.hb.Visible = false
                    e.hf.Visible = false
                end

                if cfg.tracers then
                    e.tr.From = Vector2.new(vp.X * 0.5, vp.Y)
                    e.tr.To = Vector2.new(bot.X, bot.Y)
                    e.tr.Visible = true
                else
                    e.tr.Visible = false
                end
            end
        end
    end

    for i = n + 1, PP do
        local e = pPool[i]
        e.box.Visible = false
        e.name.Visible = false
        e.hb.Visible = false
        e.hf.Visible = false
        e.tr.Visible = false
    end

    if not cfg.pEsp and not cfg.tracers then
        for i = 1, PP do
            local e = pPool[i]
            e.box.Visible = false
            e.name.Visible = false
            e.hb.Visible = false
            e.hf.Visible = false
            e.tr.Visible = false
        end
    end

    local un = 0
    if cfg.uEsp then
        for i = 1, #uTargets do
            if un >= UP then break end
            local p = uTargets[i].part
            local top, v1 = WorldToScreen(p.Position + Vector3.new(0, 6, 0))
            local bot, v2 = WorldToScreen(p.Position - Vector3.new(0, 2, 0))
            if v1 and v2 then
                un = un + 1
                local e = uPool[un]
                local h = bot.Y - top.Y
                if h < 3 then h = 3 end
                local w = h * 0.8
                e.box.Position = Vector2.new(top.X - w * 0.5, top.Y)
                e.box.Size = Vector2.new(w, h)
                e.box.Visible = true
            end
        end
    end
    for i = un + 1, UP do
        uPool[i].box.Visible = false
    end
end)

-- ============================ INPUT ============================
inputConn = UIS.InputBegan:Connect(function(input)
    local k = input.KeyCode
    if k == Enum.KeyCode.RightShift then
        cfg.menu = not cfg.menu
        applyMenu()
        return
    end
    if not cfg.menu then return end

    if k == Enum.KeyCode.One then
        cfg.pEsp = not cfg.pEsp
        refreshRows()
    elseif k == Enum.KeyCode.Two then
        cfg.uEsp = not cfg.uEsp
        refreshRows()
    elseif k == Enum.KeyCode.Three then
        cfg.tracers = not cfg.tracers
        refreshRows()
    elseif k == Enum.KeyCode.Four then
        if cfg.fov == 70 then setFov(90)
        elseif cfg.fov == 90 then setFov(110)
        elseif cfg.fov == 110 then setFov(120)
        else setFov(70) end
    elseif k == Enum.KeyCode.Five then
        if _G[NAME] and _G[NAME].stop then _G[NAME].stop() end
    end
end)

-- ============================ STOP ============================
local function stop()
    if not running then return end
    running = false
    if conn then conn:Disconnect(); conn = nil end
    if inputConn then inputConn:Disconnect(); inputConn = nil end
    for i = 1, PP do
        local e = pPool[i]
        e.box:Remove()
        e.name:Remove()
        e.hb:Remove()
        e.hf:Remove()
        e.tr:Remove()
    end
    for i = 1, UP do
        uPool[i].box:Remove()
    end
    for _, o in ipairs(menuObjs) do o:Remove() end
    local cam = WS.CurrentCamera
    if cam then cam.FieldOfView = 70 end
    _G[NAME] = nil
    print("[FrontierMenu] stopped")
end

applyMenu()
_G[NAME] = { stop = stop, version = VERSION }
print("[FrontierMenu] ready - RShift menu, 1 player ESP, 2 unit ESP, 3 tracers, 4 FOV, 5 unload")