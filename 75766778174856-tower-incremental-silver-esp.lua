-- Tower Incremental - Silver Ore ESP
-- place 75766778174856
-- Draws a 3D block box around every SilverOre under workspace.Mine.MineBlocks.
-- Probe facts: 97 SilverOre Models, each with a 'Stone' Part (~10x10x10) and a 'Veins' union.
-- Matcha LuauVM: no Instance.new, no hooks. All overlay goes through Drawing.

local NAME    = 'TISilverESP'
local VERSION = 'v1'

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
    enabled  = true,
    showName = true,
    showDist = true,
    maxDist  = 2000,
    color    = Color3.fromRGB(220, 220, 235),
}

local POOL    = 128
local pool    = {}
local targets = {}

local function track(c)
    conns[#conns + 1] = c
    return c
end

-- drawing pool --------------------------------------------------------

for i = 1, POOL do
    local box = Drawing.new('Square')
    box.Filled = false
    box.Thickness = 1
    box.Color = cfg.color
    box.Visible = false
    local tag = Drawing.new('Text')
    tag.Center = true
    tag.Outline = true
    tag.Size = 13
    tag.Color = cfg.color
    tag.Visible = false
    pool[i] = { box = box, tag = tag, on = false }
end

local function applyColor()
    for i = 1, POOL do
        pool[i].box.Color = cfg.color
        pool[i].tag.Color = cfg.color
    end
end

local function hideAll()
    for i = 1, POOL do
        local e = pool[i]
        if e.on then
            e.box.Visible = false
            e.tag.Visible = false
            e.on = false
        end
    end
end

-- collector: slow, does the tree lookups ------------------------------

task.spawn(function()
    while running do
        local out = {}
        local mine = workspace:FindFirstChild('Mine')
        local blocks = mine and mine:FindFirstChild('MineBlocks')
        if blocks then
            local kids = blocks:GetChildren()
            for i = 1, #kids do
                local m = kids[i]
                if m.Name == 'SilverOre' then
                    local stone = m:FindFirstChild('Stone')
                    if stone then
                        out[#out + 1] = { pos = stone.Position, size = stone.Size }
                    end
                end
            end
        end
        targets = out
        task.wait(0.5)
    end
end)

-- renderer: fast, reads only ------------------------------------------

track(RunService.RenderStepped:Connect(function()
    if not cfg.enabled then
        hideAll()
        return
    end

    local char   = lp.Character
    local root   = char and char:FindFirstChild('HumanoidRootPart')
    local origin = root and root.Position
    local maxSq  = cfg.maxDist * cfg.maxDist
    local list   = targets
    local n      = 0

    for i = 1, #list do
        if n >= POOL then break end
        local t = list[i]
        local p = t.pos
        local s = t.size
        local dist = origin and (p - origin).Magnitude or 0
        if not origin or dist * dist <= maxSq then
            local hx, hy, hz = s.X * 0.5, s.Y * 0.5, s.Z * 0.5
            local minX, minY, maxX, maxY, seen
            for c = 0, 7 do
                local sx = (c % 2 == 0) and -hx or hx
                local sy = (math.floor(c / 2) % 2 == 0) and -hy or hy
                local sz = (math.floor(c / 4) % 2 == 0) and -hz or hz
                local sp, vis = WorldToScreen(p + Vector3.new(sx, sy, sz))
                if vis then
                    if not seen then
                        minX, minY, maxX, maxY = sp.X, sp.Y, sp.X, sp.Y
                        seen = true
                    else
                        if sp.X < minX then minX = sp.X end
                        if sp.Y < minY then minY = sp.Y end
                        if sp.X > maxX then maxX = sp.X end
                        if sp.Y > maxY then maxY = sp.Y end
                    end
                end
            end

            if seen and maxX - minX > 1 and maxY - minY > 1 then
                n = n + 1
                local e = pool[n]
                e.box.Position = Vector2.new(minX, minY)
                e.box.Size = Vector2.new(maxX - minX, maxY - minY)
                e.box.Visible = true

                local parts = {}
                if cfg.showName then parts[#parts + 1] = 'Silver' end
                if cfg.showDist then parts[#parts + 1] = math.floor(dist) .. 'm' end
                if #parts > 0 then
                    e.tag.Text = table.concat(parts, ' ')
                    e.tag.Position = Vector2.new((minX + maxX) * 0.5, minY - 16)
                    e.tag.Visible = true
                else
                    e.tag.Visible = false
                end
                e.on = true
            end
        end
    end

    for i = n + 1, POOL do
        local e = pool[i]
        if e.on then
            e.box.Visible = false
            e.tag.Visible = false
            e.on = false
        end
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

local COLOR_ID = 'ti_color'

local function readColor(current)
    local ok, r, g, b = pcall(function() return UI.GetValue(COLOR_ID) end)
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
    local sec = mkSection(tab, 'Silver ESP')
    if not sec then return end
    mkToggle(sec, 'Enabled', 'ti_enabled', cfg.enabled, function(v) cfg.enabled = v end)
    mkToggle(sec, 'Show Label', 'ti_name', cfg.showName, function(v) cfg.showName = v end)
    mkToggle(sec, 'Show Distance', 'ti_dist', cfg.showDist, function(v) cfg.showDist = v end)
    mkSlider(sec, 'Max Distance', 'ti_maxdist', 50, 5000, cfg.maxDist, function(v) cfg.maxDist = v end)
    pcall(function()
        sec:ColorPicker('Box Color', cfg.color.R, cfg.color.G, cfg.color.B, 1)
    end)
    print('[TI] menu built')
end

if HAS_UI then
    local ok, err = pcall(function()
        UI.AddTab('Silver ESP', function(tab)
            pcall(buildTab, tab)
        end)
    end)
    if not ok then
        warn('[TI] UI.AddTab failed: ' .. tostring(err))
        HAS_UI = false
    end
end

task.spawn(function()
    local last = cfg.color
    while running do
        task.wait(1)
        if HAS_UI then
            local c = readColor(cfg.color)
            if c.R ~= last.R or c.G ~= last.G or c.B ~= last.B then
                cfg.color = c
                last = c
                applyColor()
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
        pcall(function() pool[i].box:Remove() end)
        pcall(function() pool[i].tag:Remove() end)
    end
    _G[NAME] = nil
    print('[TI] stopped')
end

_G[NAME] = { stop = stop, version = VERSION }
print('[TI] ' .. VERSION .. ' loaded, menu=' .. tostring(HAS_UI) .. ' - K toggles')

task.spawn(function()
    task.wait(0.8)
    if running then print('[TI] silver ores tracked: ' .. #targets) end
end)
