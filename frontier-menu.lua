-- Frontier Menu v2 (Matcha) - place 119263815547952
-- Tab lives in the Matcha menu (UI.AddTab). ESP is Matcha's own RegisterModel.
-- No custom GUI window, no hand-rolled ESP boxes.
local VERSION = "v2"
local NAME = "FrontierMenu"
if _G[NAME] and _G[NAME].stop then pcall(_G[NAME].stop) end
print("[FrontierMenu] " .. VERSION .. " loaded")

local Players    = game:GetService("Players")
local UserInput  = game:GetService("UserInputService")
local WS         = game:GetService("Workspace")
local LP         = Players.LocalPlayer

local TAB      = "Frontier"
local UNIT_CAP = 64

local running = true
local tabPing = 0
local tabArgsLogged = false
local pHandles, uHandles = {}, {}

local cfg = { pEsp = true, uEsp = false, fov = 70 }

local ROWS = {
    { key = "pEsp", label = "Player ESP" },
    { key = "uEsp", label = "Unit ESP"   },
    { key = "fov",  label = "FOV"        },
}
local MX, MY = 40, 190

-- ===================== native ESP (RegisterModel) =====================
local function findUnitPart(m)
    local hull = m:FindFirstChild("Hull")
    local p
    if hull then
        p = hull:FindFirstChild("Hull_Body")
            or hull:FindFirstChild("Hull_Fixed")
            or hull:FindFirstChildOfClass("MeshPart")
            or hull:FindFirstChildOfClass("Part")
    end
    if not p then
        p = m:FindFirstChildOfClass("MeshPart") or m:FindFirstChildOfClass("Part")
    end
    return p
end

local function drop(handle)
    if handle then pcall(function() handle:Remove() end) end
end

local function clearPlayers()
    for uid, e in pairs(pHandles) do
        drop(e.h)
        pHandles[uid] = nil
    end
end

local function clearUnits()
    for k, h in pairs(uHandles) do
        drop(h)
        uHandles[k] = nil
    end
end

local function syncPlayers()
    if not cfg.pEsp then clearPlayers(); return end
    local list = Players:GetPlayers()
    for i = 1, #list do
        local plr = list[i]
        if plr ~= LP then
            local ch = plr.Character
            local e = pHandles[plr.UserId]
            if not ch then
                if e then drop(e.h); pHandles[plr.UserId] = nil end
            else
                local addr = ch.Address
                if e and addr and e.addr and e.addr ~= addr then
                    drop(e.h)
                    pHandles[plr.UserId] = nil
                    e = nil
                end
                if not e then
                    local ok, h = pcall(RegisterModel, { entry = ch })
                    if ok and h then
                        pHandles[plr.UserId] = { h = h, addr = addr }
                    end
                end
            end
        end
    end
end

local function syncUnits()
    local uf = WS:FindFirstChild("Units")
    if not uf then return end

    local live, order = {}, {}
    local kids = uf:GetChildren()
    for i = 1, #kids do
        local m = kids[i]
        local key = tostring(m.Address or (m.Name .. "_" .. i))
        live[key] = m
        order[#order + 1] = key
    end

    for key, h in pairs(uHandles) do
        if not live[key] then
            drop(h)
            uHandles[key] = nil
        end
    end

    if not cfg.uEsp then return end

    local count = 0
    for _ in pairs(uHandles) do count = count + 1 end

    for i = 1, #order do
        if count >= UNIT_CAP then break end
        local key = order[i]
        if not uHandles[key] then
            local m = live[key]
            local part = m and findUnitPart(m)
            if part then
                local ok, h = pcall(RegisterModel, {
                    entry = m,
                    GetHead = function() return part end,
                    GetRoot = function() return part end,
                })
                if ok and h then
                    uHandles[key] = h
                    count = count + 1
                end
            end
        end
    end
end

-- ===================== tab row text (Drawing, tab-gated) =====================
local rowTexts, hintText = {}, nil

for i = 1, #ROWS do
    local t = Drawing.new("Text")
    t.Text = ""
    t.Size = 14
    t.Outline = true
    t.Font = 2
    t.Color = Color3.fromRGB(230, 230, 230)
    t.Position = Vector2.new(MX, MY + (i - 1) * 18)
    t.Visible = false
    rowTexts[i] = t
end

hintText = Drawing.new("Text")
hintText.Text = "[1] players  [2] units  [3] fov  [4] unload"
hintText.Size = 11
hintText.Outline = true
hintText.Font = 5
hintText.Color = Color3.fromRGB(150, 150, 150)
hintText.Position = Vector2.new(MX, MY + #ROWS * 18 + 6)
hintText.Visible = false

local function setFov(v)
    cfg.fov = v
    local cam = WS.CurrentCamera
    if cam then cam.FieldOfView = v end
end

local function refreshRows()
    for i = 1, #ROWS do
        local r = ROWS[i]
        local val
        if r.key == "fov" then
            val = tostring(cfg.fov)
        else
            val = cfg[r.key] and "ON" or "OFF"
        end
        rowTexts[i].Text = string.format("[%d] %s: %s", i, r.label, val)
        if r.key ~= "fov" and cfg[r.key] then
            rowTexts[i].Color = Color3.fromRGB(120, 230, 140)
        else
            rowTexts[i].Color = Color3.fromRGB(230, 230, 230)
        end
    end
end

-- ===================== native menu tab =====================
pcall(function() UI.RemoveTab(TAB) end)
pcall(function()
    UI.AddTab(TAB, function(...)
        tabPing = tick()
        if not tabArgsLogged then
            tabArgsLogged = true
            local n = select("#", ...)
            local out = {}
            for i = 1, n do
                local a = select(i, ...)
                out[#out + 1] = i .. ":" .. type(a) .. ":" .. tostring(a)
            end
            print("[FrontierMenu] tab callback n=" .. n .. " " .. table.concat(out, " "))
        end
    end)
end)

-- ===================== state loop =====================
task.spawn(function()
    local acc = 0
    while running do
        local open = (tick() - tabPing) < 0.4
        for i = 1, #rowTexts do rowTexts[i].Visible = open end
        hintText.Visible = open

        acc = acc + 0.15
        if acc >= 1.0 then
            acc = 0
            pcall(syncPlayers)
            pcall(syncUnits)
        end
        task.wait(0.15)
    end
end)

-- ===================== input =====================
local inputConn = UserInput.InputBegan:Connect(function(input)
    local k = input.KeyCode
    if k == Enum.KeyCode.One then
        cfg.pEsp = not cfg.pEsp
        pcall(syncPlayers)
        refreshRows()
    elseif k == Enum.KeyCode.Two then
        cfg.uEsp = not cfg.uEsp
        pcall(syncUnits)
        refreshRows()
    elseif k == Enum.KeyCode.Three then
        if cfg.fov == 70 then setFov(90)
        elseif cfg.fov == 90 then setFov(110)
        elseif cfg.fov == 110 then setFov(120)
        else setFov(70) end
        refreshRows()
    elseif k == Enum.KeyCode.Four then
        if _G[NAME] and _G[NAME].stop then _G[NAME].stop() end
    end
end)

-- ===================== init / stop =====================
setFov(cfg.fov)
refreshRows()
pcall(syncPlayers)

local function stop()
    if not running then return end
    running = false
    if inputConn then inputConn:Disconnect(); inputConn = nil end
    clearPlayers()
    clearUnits()
    for i = 1, #rowTexts do pcall(function() rowTexts[i]:Remove() end) end
    if hintText then pcall(function() hintText:Remove() end) end
    pcall(function() UI.RemoveTab(TAB) end)
    local cam = WS.CurrentCamera
    if cam then cam.FieldOfView = 70 end
    _G[NAME] = nil
    print("[FrontierMenu] stopped")
end

_G[NAME] = { stop = stop, version = VERSION }
pcall(function() notify("FrontierMenu " .. VERSION .. " ready", "Frontier", 4) end)
print("[FrontierMenu] ready - tab 'Frontier' in the Matcha menu, keys 1-4")