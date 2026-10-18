-- Tower Incremental - Mine ESP + Ore Aura
-- place 75766778174856
-- v6: v5 3D ESP (ore + stone, CFrame corners, no hover) plus a mine aura that
--     fires ReplicatedStorage.Remotes.MineBlock at nearby blocks.
--
-- IMPORTANT: the MineBlock argument shape is not confirmed. The aura therefore
-- starts with Dry Run ON and only prints what it would fire. Set Dry Run off in
-- the menu (or press J) once you have seen the log lines and are happy.
--
-- Matcha LuauVM: no Instance.new, no hooks, no Highlight/SelectionBox.
-- All overlay goes through Drawing.

local NAME    = 'TIOreESP'
local VERSION = 'v6'

if _G[NAME] and _G[NAME].stop then
    pcall(_G[NAME].stop)
end

local Players    = game:GetService('Players')
local RS         = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local UIS        = game:GetService('UserInputService')

local lp = Players.LocalPlayer

local remotes  = RS:FindFirstChild('Remotes')
local mineEvt  = remotes and remotes:FindFirstChild('MineBlock')

local running = true
local conns   = {}
local built   = false

local cfg = {
    enabled    = true,
    oreESP     = true,
    stoneESP   = true,
    showNames  = true,
    nameNear   = 6,
    maxDist    = 500,
    maxBoxes   = 40,
    fade       = true,
    thickness  = 1,
    scaleThick = true,
    silver     = Color3.fromRGB(220, 225, 240),
    iron       = Color3.fromRGB(215, 150, 110),
    stone      = Color3.fromRGB(150, 160, 175),

    -- aura
    aura       = false,
    dryRun     = true,
    auraRadius = 25,
    auraMs     = 150,
    auraOre    = true,
    auraStone  = true,
    argMode    = 'part',   -- 'part' or 'model'
}

local POOL = 64

local EDGES = {
    {1,2},{3,4},{5,6},{7,8},
    {1,3},{2,4},{5,7},{6,8},
    {1,5},{2,6},{3,7},{4,8},
}

local pool    = {}
local targets = {}

local function track(c)
    conns[#conns + 1] = c
    return c
end

local function colorFor(kind)
    if kind == 'Iron' then return cfg.iron end
    if kind == 'Stone' then return cfg.stone end
    return cfg.silver
end

-- drawing pool --------------------------------------------------------

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
    pool[i] = { lines = lines, tag = tag, on = false, thick = -1, kind = '' }
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

-- collector -----------------------------------------------------------

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
                local kind, want, part, owner = nil, false, nil, nil
                if string.sub(n, -3) == 'Ore' then
                    kind  = string.sub(n, 1, #n - 3)
                    want  = cfg.oreESP
                    part  = m:FindFirstChild('Stone')
                    owner = m
                elseif n == 'Stone' then
                    kind = 'Stone'
                    want = cfg.stoneESP
                    part = m
                end
                if want and part then
                    local cf = part.CFrame
                    local d = origin and (cf.Position - origin).Magnitude or 0
                    out[#out + 1] = {
                        cframe = cf,
                        size   = part.Size,
                        dist   = d,
                        kind   = kind,
                        part   = part,
                        owner  = owner,
                    }
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

track(RunService.RenderStepped:Connect(function()
    if not cfg.enabled then
        hideAll()
        return
    end

    local char   = lp.Character
    local root   = char and char:FindFirstChild('HumanoidRootPart')
    local origin = root and root.Position
    local maxD   = cfg.maxDist
    local maxSq  = maxD * maxD
    local cap    = math.min(cfg.maxBoxes, POOL)
    local list   = targets
    local n      = 0

    for i = 1, #list do
        if n >= cap then break end
        local t  = list[i]
        local cf = t.cframe
        local s  = t.size
        local dist = origin and (cf.Position - origin).Magnitude or t.dist

        if not origin or dist * dist <= maxSq then
            local hx, hy, hz = s.X * 0.5, s.Y * 0.5, s.Z * 0.5
            local sp, ok = {}, {}
            local seen = false
            local minX, minY, maxX, maxY

            for c = 0, 7 do
                local sx = (c % 2 == 0) and -hx or hx
                local sy = (math.floor(c / 2) % 2 == 0) and -hy or hy
                local sz = (math.floor(c / 4) % 2 == 0) and -hz or hz
                local world = cf:PointToWorldSpace(Vector3.new(sx, sy, sz))
                local v, vis = WorldToScreen(world)
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

                local th = cfg.thickness
                if cfg.scaleThick then
                    th = math.floor(cfg.thickness * 150 / math.max(dist, 40))
                    if th < 1 then th = 1 elseif th > 5 then th = 5 end
                end
                if e.thick ~= th then
                    for k = 1, 12 do e.lines[k].Thickness = th end
                    e.thick = th
                end

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

                if cfg.showNames and n <= cfg.nameNear then
                    e.tag.Text = t.kind
                    e.tag.Color = col
                    e.tag.Position = Vector2.new((minX + maxX) * 0.5, minY - 16)
                    e.tag.Visible = true
                elseif e.tag.Visible then
                    e.tag.Visible = false
                end

                e.kind = t.kind
                e.on = true
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
end))

-- aura ----------------------------------------------------------------
-- Fires Remotes.MineBlock at the closest block inside auraRadius.
-- Dry Run ON  -> prints the exact call, fires nothing.
-- Dry Run OFF -> actually fires, one block per interval.
-- The argument shape is not confirmed; argMode picks the Part or its parent Model.

local recent = {}
local firedCount = 0

local function pruneRecent(now)
    for addr, t in pairs(recent) do
        if now - t > 4 then recent[addr] = nil end
    end
end

local function auraArg(t)
    if cfg.argMode == 'model' and t.owner then return t.owner end
    return t.part
end

task.spawn(function()
    while running do
        task.wait(cfg.auraMs / 1000)
        if running and cfg.aura and mineEvt then
            local char = lp.Character
            local root = char and char:FindFirstChild('HumanoidRootPart')
            if root then
                local now = tick()
                pruneRecent(now)
                local best, bestD = nil, nil
                local list = targets
                for i = 1, #list do
                    local t = list[i]
                    local kindOK = (t.kind == 'Stone') and cfg.auraStone or cfg.auraOre
                    if kindOK then
                        local d = (t.cframe.Position - root.Position).Magnitude
                        if d <= cfg.auraRadius then
                            local addr = t.part.Address
                            if not recent[addr] then
                                if not bestD or d < bestD then
                                    best, bestD = t, d
                                end
                            end
                        end
                    end
                end
                if best then
                    local arg = auraArg(best)
                    recent[best.part.Address] = now
                    if cfg.dryRun then
                        print(string.format('[aura] dry %s %.1fm arg=%s',
                            best.kind, bestD, tostring(arg ~= nil)))
                    else
                        local ok, err = pcall(function()
                            mineEvt:FireServer(arg)
                        end)
                        firedCount = firedCount + 1
                        print(string.format('[aura] %s %s %.1fm #%d',
                            best.kind, ok and 'fired' or ('err ' .. tostring(err)),
                            bestD, firedCount))
                    end
                end
            end
        end
    end
end)

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
local STONE_ID  = 'ti_stone'

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

    local sec = mkSection(tab, 'Mine ESP')
    if sec then
        mkToggle(sec, 'Enabled', 'ti_enabled', cfg.enabled, function(v) cfg.enabled = v end)
        mkToggle(sec, 'Ore ESP', 'ti_ore', cfg.oreESP, function(v) cfg.oreESP = v end)
        mkToggle(sec, 'Stone ESP', 'ti_stoneon', cfg.stoneESP, function(v) cfg.stoneESP = v end)
        mkToggle(sec, 'Show Names', 'ti_label', cfg.showNames, function(v) cfg.showNames = v end)
        mkSlider(sec, 'Names On Nearest', 'ti_labelnear', 0, 30, cfg.nameNear, function(v) cfg.nameNear = v end)
        mkSlider(sec, 'Max Distance', 'ti_maxdist', 50, 2000, cfg.maxDist, function(v) cfg.maxDist = v end)
        mkSlider(sec, 'Max Boxes', 'ti_maxboxes', 5, 64, cfg.maxBoxes, function(v) cfg.maxBoxes = v end)
        mkToggle(sec, 'Distance Fade', 'ti_fade', cfg.fade, function(v) cfg.fade = v end)
        mkSlider(sec, 'Line Thickness', 'ti_thick', 1, 4, cfg.thickness, function(v) cfg.thickness = v end)
        mkToggle(sec, 'Thickness Scales', 'ti_scalethick', cfg.scaleThick, function(v) cfg.scaleThick = v end)
        pcall(function() sec:ColorPicker('Silver Color', cfg.silver.R, cfg.silver.G, cfg.silver.B, 1) end)
        pcall(function() sec:ColorPicker('Iron Color', cfg.iron.R, cfg.iron.G, cfg.iron.B, 1) end)
        pcall(function() sec:ColorPicker('Stone Color', cfg.stone.R, cfg.stone.G, cfg.stone.B, 1) end)
    end

    local au = mkSection(tab, 'Ore Aura')
    if au then
        mkToggle(au, 'Aura Enabled', 'ti_aura', cfg.aura, function(v) cfg.aura = v end)
        mkToggle(au, 'Dry Run (log only)', 'ti_dry', cfg.dryRun, function(v) cfg.dryRun = v end)
        mkSlider(au, 'Radius', 'ti_radius', 5, 120, cfg.auraRadius, function(v) cfg.auraRadius = v end)
        mkSlider(au, 'Interval ms', 'ti_aura_ms', 60, 800, cfg.auraMs, function(v) cfg.auraMs = v end)
        mkToggle(au, 'Mine Ore', 'ti_aura_ore', cfg.auraOre, function(v) cfg.auraOre = v end)
        mkToggle(au, 'Mine Stone', 'ti_aura_stone', cfg.auraStone, function(v) cfg.auraStone = v end)
        mkToggle(au, 'Arg = Model (off = Part)', 'ti_argmode', cfg.argMode == 'model', function(v)
            cfg.argMode = v and 'model' or 'part'
        end)
        mkButton(au, 'Reset Recent Blocks', function()
            recent = {}
            print('[aura] recent cleared')
        end)
    end
end

if HAS_UI then
    local ok, err = pcall(function()
        UI.AddTab('Mine ESP', function(tab)
            pcall(buildTab, tab)
        end)
    end)
    if not ok then
        warn('[TI] UI.AddTab failed: ' .. tostring(err))
        HAS_UI = false
    end
end

task.spawn(function()
    local lastS, lastI, lastT = cfg.silver, cfg.iron, cfg.stone
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
            local st = readColor(STONE_ID, cfg.stone)
            if st.R ~= lastT.R or st.G ~= lastT.G or st.B ~= lastT.B then
                cfg.stone, lastT = st, st
            end
        end
    end
end)

-- keys ----------------------------------------------------------------

track(UIS.InputBegan:Connect(function(input)
    local k = input and input.KeyCode
    if k == Enum.KeyCode.K then
        cfg.enabled = not cfg.enabled
        print('[TI] esp ' .. tostring(cfg.enabled))
    elseif k == Enum.KeyCode.L then
        cfg.showNames = not cfg.showNames
        print('[TI] names ' .. tostring(cfg.showNames))
    elseif k == Enum.KeyCode.O then
        cfg.oreESP = not cfg.oreESP
        print('[TI] ore ' .. tostring(cfg.oreESP))
    elseif k == Enum.KeyCode.M then
        cfg.stoneESP = not cfg.stoneESP
        print('[TI] stone ' .. tostring(cfg.stoneESP))
    elseif k == Enum.KeyCode.J then
        cfg.aura = not cfg.aura
        print('[TI] aura ' .. tostring(cfg.aura) .. ' dry=' .. tostring(cfg.dryRun))
    elseif k == Enum.KeyCode.N then
        cfg.dryRun = not cfg.dryRun
        print('[TI] dryrun ' .. tostring(cfg.dryRun))
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
print('[TI] ' .. VERSION .. ' loaded, menu=' .. tostring(HAS_UI) .. ', MineBlock=' .. tostring(mineEvt ~= nil))
print('[TI] aura off, dryRun on. J = aura, N = dry run, K = esp')

task.spawn(function()
    task.wait(0.8)
    if running then print('[TI] blocks tracked: ' .. #targets) end
end)
