-- Tower Incremental - Ore ESP
-- place 75766778174856
-- v4: true 3D wireframe boxes. Each ore block is projected corner by corner
--     and drawn as its 12 edges, so it reads as a box in the world instead of
--     a flat rectangle on screen. Hover highlights the box you point at, even
--     through walls.
-- Matcha LuauVM: no Instance.new, no hooks, no Highlight/SelectionBox.
-- All overlay goes through Drawing.

local NAME    = 'TIOreESP'
local VERSION = 'v4'

if _G[NAME] and _G[NAME].stop then
    pcall(_G[NAME].stop)
end

local Players    = game:GetService('Players')
local RunService = game:GetService('RunService')
local UIS        = game:GetService('UserInputService')

local lp = Players.LocalPlayer

local running = true
local conns   = {}
local built   = false

local cfg = {
    enabled    = true,
    showNames  = true,
    nameNear   = 6,     -- names only on the N closest boxes
    hoverGlow  = true,
    maxDist    = 500,
    maxBoxes   = 32,
    fade       = true,
    thickness  = 1,
    silver     = Color3.fromRGB(220, 225, 240),
    iron       = Color3.fromRGB(215, 150, 110),
    hoverColor = Color3.fromRGB(255, 255, 255),
}

local POOL = 48

-- corner id 1..8: bit0 = X, bit1 = Y, bit2 = Z, 0 = -half, 1 = +half.
-- These 12 pairs are the edges of a cube.
local EDGES = {
    {1,2},{3,4},{5,6},{7,8},   -- along X
    {1,3},{2,4},{5,7},{6,8},   -- along Y
    {1,5},{2,6},{3,7},{4,8},   -- along Z
}

local pool    = {}
local targets = {}

local function track(c)
    conns[#conns + 1] = c
    return c
end

local function colorFor(kind)
    if kind == 'Iron' then return cfg.iron end
    return cfg.silver
end

-- drawing pool: 12 lines per box --------------------------------------

for i = 1, POOL do
    local lines = {}
    for k = 1, 12 do
        local ln = Drawing.new('Line')
        ln.Thickness = cfg.thickness
        ln.Color = cfg.silver
        ln.Visible = false
        lines[k] = ln
    end
    local tag = Drawing.new('Text')
    tag.Center = true
    tag.Outline = true
    tag.Size = 13
    tag.Color = cfg.silver
    tag.Visible = false
    pool[i] = {
        lines = lines,
        tag   = tag,
        on    = false,
        thick = cfg.thickness,
        kind  = '',
        dist  = 0,
        tagPos = Vector2.new(0, 0),
    }
end

local function hideAll()
    for i = 1, POOL do
        local e = pool[i]
        if e.on then
            for k = 1, 12 do
                if e.lines[k].Visible then e.lines[k].Visible = false end
            end
            e.tag.Visible = false
            e.on = false
        end
    end
end

-- collector: tree lookups at 2 Hz, nearest first ----------------------

task.spawn(function()
    while running do
        local out = {}
        local mine = workspace:FindFirstChild('Mine')
        local blocks = mine and mine:FindFirstChild('MineBlocks')
        local char = lp.Character
        local root = char and char:FindFirstChild('HumanoidRootPart')
        local origin = root and root.Position
        if blocks then
            local kids = blocks:GetChildren()
            for i = 1, #kids do
                local m = kids[i]
                local n = m.Name
                -- any model whose name ends in Ore counts
                if string.sub(n, -3) == 'Ore' then
                    local stone = m:FindFirstChild('Stone')
                    if stone then
                        local p = stone.Position
                        local d = origin and (p - origin).Magnitude or 0
                        out[#out + 1] = {
                            pos  = p,
                            size = stone.Size,
                            dist = d,
                            kind = string.sub(n, 1, #n - 3),
                        }
                    end
                end
            end
        end
        table.sort(out, function(a, b) return a.dist < b.dist end)
        while #out > POOL do out[#out] = nil end
        targets = out
        task.wait(0.5)
    end
end)

-- renderer ------------------------------------------------------------

local mouse = nil
do
    local ok, m = pcall(function() return lp:GetMouse() end)
    if ok then mouse = m end
end

track(RunService.RenderStepped:Connect(function()
    if not cfg.enabled then
        hideAll()
        return
    end

    local mx, my = -1, -1
    if mouse then
        local okx, x = pcall(function() return mouse.X end)
        local oky, y = pcall(function() return mouse.Y end)
        if okx and type(x) == 'number' then mx = x end
        if oky and type(y) == 'number' then my = y end
    end

    local char   = lp.Character
    local root   = char and char:FindFirstChild('HumanoidRootPart')
    local origin = root and root.Position
    local maxD   = cfg.maxDist
    local maxSq  = maxD * maxD
    local cap    = math.min(cfg.maxBoxes, POOL)
    local list   = targets
    local n      = 0

    local hoverSlot, hoverDist = nil, nil

    for i = 1, #list do
        if n >= cap then break end
        local t = list[i]
        local p = t.pos
        local s = t.size
        local dist = origin and (p - origin).Magnitude or t.dist

        if not origin or dist * dist <= maxSq then
            local hx, hy, hz = s.X * 0.5, s.Y * 0.5, s.Z * 0.5
            local sp, ok = {}, {}
            local seen = false
            local minX, minY, maxX, maxY

            -- project all 8 corners of the block
            for c = 0, 7 do
                local sx = (c % 2 == 0) and -hx or hx
                local sy = (math.floor(c / 2) % 2 == 0) and -hy or hy
                local sz = (math.floor(c / 4) % 2 == 0) and -hz or hz
                local v, vis = WorldToScreen(p + Vector3.new(sx, sy, sz))
                local id = c + 1
                sp[id] = v
                ok[id] = vis
                if vis then
                    if not seen then
                        minX, minY, maxX, maxY = v.X, v.Y, v.X, v.Y
                        seen = true
                    else
                        if v.X < minX then minX = v.X end
                        if v.Y < minY then minY = v.Y end
                        if v.X > maxX then maxX = v.X end
                        if v.Y > maxY then maxY = v.Y end
                    end
                end
            end

            if seen and maxX - minX >= 2 and maxY - minY >= 2 then
                n = n + 1
                local e = pool[n]
                local col = colorFor(t.kind)

                local tr = 0
                if cfg.fade and maxD > 0 then
                    local f = dist / maxD
                    if f > 1 then f = 1 end
                    tr = 0.1 + 0.65 * f
                end

                if e.thick ~= cfg.thickness then
                    for k = 1, 12 do e.lines[k].Thickness = cfg.thickness end
                    e.thick = cfg.thickness
                end

                -- draw the 12 edges, skipping any whose endpoint is behind us
                for k = 1, 12 do
                    local ed = EDGES[k]
                    local ln = e.lines[k]
                    if ok[ed[1]] and ok[ed[2]] then
                        ln.From = sp[ed[1]]
                        ln.To = sp[ed[2]]
                        ln.Color = col
                        ln.Transparency = tr
                        ln.Visible = true
                    elseif ln.Visible then
                        ln.Visible = false
                    end
                end

                e.tagPos = Vector2.new((minX + maxX) * 0.5, minY - 16)

                if cfg.showNames and n <= cfg.nameNear then
                    e.tag.Text = t.kind
                    e.tag.Color = col
                    e.tag.Position = e.tagPos
                    e.tag.Visible = true
                elseif e.tag.Visible then
                    e.tag.Visible = false
                end

                e.kind = t.kind
                e.dist = dist
                e.on = true

                if cfg.hoverGlow and mx >= minX and mx <= maxX
                    and my >= minY and my <= maxY then
                    if not hoverDist or dist < hoverDist then
                        hoverDist = dist
                        hoverSlot = n
                    end
                end
            end
        end
    end

    for i = n + 1, POOL do
        local e = pool[i]
        if e.on then
            for k = 1, 12 do
                if e.lines[k].Visible then e.lines[k].Visible = false end
            end
            e.tag.Visible = false
            e.on = false
        end
    end

    -- hover pass: brighten + thicken the box under the mouse, name it
    if hoverSlot then
        local e = pool[hoverSlot]
        for k = 1, 12 do
            local ln = e.lines[k]
            if ln.Visible then
                ln.Color = cfg.hoverColor
                ln.Thickness = cfg.thickness + 1
            end
        end
        e.thick = -1
        e.tag.Text = e.kind
        e.tag.Color = cfg.hoverColor
        e.tag.Position = e.tagPos
        e.tag.Visible = true
    end
end))

-- menu ----------------------------------------------------------------

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
    for _, side in ipairs({ 'Left', 'Right' }) do
        local ok, sec = pcall(function() return tab:Section(name, side) end)
        if ok and sec ~= nil then return sec end
    end
    local ok, sec = pcall(function() return tab:Section(name) end)
    if ok and sec ~= nil then return sec end
    warn('[TI] section failed: ' .. name)
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
    warn('[TI] toggle failed: ' .. label)
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
    warn('[TI] slider failed: ' .. label)
    return false
end

local SILVER_ID = 'ti_silver'
local IRON_ID   = 'ti_iron'
local HOVER_ID  = 'ti_hover'

local function readColor(id, current)
    local ok, r, g, b = pcall(function() return UI.GetValue(id) end)
    if not ok or r == nil then return current end
    if type(r) == 'number' then return Color3.new(r, g or 1, b or 1) end
    if type(r) == 'table' then
        if r.R ~= nil then return Color3.new(r.R, r.G, r.B) end
        if r[1] ~= nil then return Color3.new(r[1], r[2] or 1, r[3] or 1) end
    end
    return current
end

local function buildTab(tab)
    if built then return end
    built = true
    local sec = mkSection(tab, 'Ore ESP')
    if not sec then return end
    mkToggle(sec, 'Enabled', 'ti_enabled', cfg.enabled, function(v) cfg.enabled = v end)
    mkToggle(sec, 'Hover Highlight', 'ti_hoveron', cfg.hoverGlow, function(v) cfg.hoverGlow = v end)
    mkToggle(sec, 'Show Names', 'ti_label', cfg.showNames, function(v) cfg.showNames = v end)
    mkSlider(sec, 'Names On Nearest', 'ti_labelnear', 0, 30, cfg.nameNear, function(v) cfg.nameNear = v end)
    mkSlider(sec, 'Max Distance', 'ti_maxdist', 50, 2000, cfg.maxDist, function(v) cfg.maxDist = v end)
    mkSlider(sec, 'Max Boxes', 'ti_maxboxes', 5, 48, cfg.maxBoxes, function(v) cfg.maxBoxes = v end)
    mkToggle(sec, 'Distance Fade', 'ti_fade', cfg.fade, function(v) cfg.fade = v end)
    mkSlider(sec, 'Line Thickness', 'ti_thick', 1, 4, cfg.thickness, function(v)
        cfg.thickness = v
    end)
    pcall(function() sec:ColorPicker('Silver Color', cfg.silver.R, cfg.silver.G, cfg.silver.B, 1) end)
    pcall(function() sec:ColorPicker('Iron Color', cfg.iron.R, cfg.iron.G, cfg.iron.B, 1) end)
    pcall(function() sec:ColorPicker('Hover Color', cfg.hoverColor.R, cfg.hoverColor.G, cfg.hoverColor.B, 1) end)
    print('[TI] menu built')
end

if HAS_UI then
    local ok, err = pcall(function()
        UI.AddTab('Ore ESP', function(tab)
            pcall(buildTab, tab)
        end)
    end)
    if not ok then
        warn('[TI] UI.AddTab failed: ' .. tostring(err))
        HAS_UI = false
    end
end

task.spawn(function()
    local lastS, lastI, lastH = cfg.silver, cfg.iron, cfg.hoverColor
    while running do
        task.wait(1)
        if HAS_UI then
            local s = readColor(SILVER_ID, cfg.silver)
            if s.R ~= lastS.R or s.G ~= lastS.G or s.B ~= lastS.B then
                cfg.silver, lastS = s, s
            end
            local ir = readColor(IRON_ID, cfg.iron)
            if ir.R ~= lastI.R or ir.G ~= lastI.G or ir.B ~= lastI.B then
                cfg.iron, lastI = ir, ir
            end
            local hv = readColor(HOVER_ID, cfg.hoverColor)
            if hv.R ~= lastH.R or hv.G ~= lastH.G or hv.B ~= lastH.B then
                cfg.hoverColor, lastH = hv, hv
            end
        end
    end
end)

-- keybind fallback ----------------------------------------------------

track(UIS.InputBegan:Connect(function(input)
    local k = input and input.KeyCode
    if k == Enum.KeyCode.K then
        cfg.enabled = not cfg.enabled
        print('[TI] esp ' .. tostring(cfg.enabled))
    elseif k == Enum.KeyCode.L then
        cfg.showNames = not cfg.showNames
        print('[TI] names ' .. tostring(cfg.showNames))
    elseif k == Enum.KeyCode.H then
        cfg.hoverGlow = not cfg.hoverGlow
        print('[TI] hover ' .. tostring(cfg.hoverGlow))
    end
end))

-- stop ----------------------------------------------------------------

local function stop()
    running = false
    for i = 1, #conns do
        pcall(function() conns[i]:Disconnect() end)
    end
    conns = {}
    for i = 1, POOL do
        for k = 1, 12 do
            pcall(function() pool[i].lines[k]:Remove() end)
        end
        pcall(function() pool[i].tag:Remove() end)
    end
    _G[NAME] = nil
    print('[TI] stopped')
end

_G[NAME] = { stop = stop, version = VERSION }
print('[TI] ' .. VERSION .. ' loaded, menu=' .. tostring(HAS_UI) .. ' - K esp, L names, H hover')

task.spawn(function()
    task.wait(0.8)
    if running then print('[TI] ores tracked: ' .. #targets) end
end)
