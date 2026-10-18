-- Tower Incremental - Mine ESP + Hold-to-Aura
-- place 75766778174856
-- v15: the aura only runs WHILE YOU HOLD E. Release E and it stops instantly,
--      releases the mouse and puts your cursor back where it was.
--      You stay in control; nothing moves unless you are holding the key.
--
-- Why it is not fully silent: your v11-v13 logs proved the server rejects
-- MineBlock fired without a real hold (every cell rejected at 10m and 25m).
-- The only thing the server accepts is the game's own progress bar, so the
-- click has to happen for real. This makes that happen only on your command.
--
-- Matcha LuauVM: no Instance.new, no hooks. Overlay via Drawing only.

local NAME    = 'TIOreESP'
local VERSION = 'v15'

if _G[NAME] and _G[NAME].stop then
    pcall(_G[NAME].stop)
end

local Players    = game:GetService('Players')
local RS         = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')

local lp = Players.LocalPlayer

local running = true
local conns   = {}
local built   = false

local cfg = {
    enabled    = true,

    espSilver  = true,
    espIron    = true,
    espStone   = false,

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

    -- hold-to-aura: only acts while the key is down
    auraKey    = Enum.KeyCode.E,
    auraOn     = true,
    holdSec    = 2.5,
    gapSec     = 0.3,
    rearmSec   = 20,
    restore    = true,
}

local function espOn(kind)
    if kind == 'Silver' then return cfg.espSilver end
    if kind == 'Iron'   then return cfg.espIron end
    if kind == 'Stone'  then return cfg.espStone end
    return false
end

local function colorFor(kind)
    if kind == 'Iron'  then return cfg.iron end
    if kind == 'Stone' then return cfg.stone end
    return cfg.silver
end

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

-- collector ---------------------------------------------------------

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
                local kind, boxPart = nil, nil
                if string.sub(n, -3) == 'Ore' then
                    kind    = string.sub(n, 1, #n - 3)
                    boxPart = m:FindFirstChild('Stone')
                elseif n == 'Stone' then
                    kind    = 'Stone'
                    boxPart = m
                end
                if kind and boxPart and espOn(kind) then
                    local cf = boxPart.CFrame
                    local d = origin and (cf.Position - origin).Magnitude or 0
                    out[#out + 1] = {
                        cframe = cf,
                        pos    = cf.Position,
                        size   = boxPart.Size,
                        dist   = d,
                        kind   = kind,
                        top    = m,
                        cell   = m:GetAttribute('Cell'),
                    }
                end
            end
        end
        table.sort(out, function(a, b) return a.dist < b.dist end)
        while #out > POOL do out[#out] = nil end
        targets = out
        task.wait(0.4)
    end
end)

-- renderer ----------------------------------------------------------

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
    local stamp  = tick()

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

                t.sx = (minX + maxX) * 0.5
                t.sy = (minY + maxY) * 0.5
                t.sAt = stamp

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

-- hold-to-aura ------------------------------------------------------

local done      = {}
local holding   = false
local holdStart = 0
local holdTgt   = nil
local lastEnd   = 0
local minedN    = 0
local saveX, saveY = 0, 0

local function cursorPos()
    local ok, m = pcall(function() return lp:GetMouse() end)
    if ok and m then
        local okx, x = pcall(function() return m.X end)
        local oky, y = pcall(function() return m.Y end)
        if okx and type(x) == 'number' then return x end
        if oky and type(y) == 'number' then return y end
    end
    return nil
end

local function releaseMouse(restore)
    if holding then
        pcall(function() mouse1release() end)
        holding = false
        if restore and cfg.restore then
            pcall(function() mousemoveabs(saveX, saveY) end)
        end
    end
end

local function pickTarget(rp)
    local best, bestD
    local now = tick()
    for i = 1, #targets do
        local t = targets[i]
        if t.sx and t.sAt and now - t.sAt < 0.5 and t.top and t.top.Parent then
            local skip = false
            if type(t.cell) == 'number' then
                local last = done[t.cell]
                if last and now - last < cfg.rearmSec then skip = true end
            end
            if not skip then
                local isOre = t.kind ~= 'Stone'
                local above = t.pos.Y > rp.Y + 4
                local lim
                if isOre then
                    lim = above and 30 or 22
                else
                    lim = above and 24 or 18
                end
                local d = (t.pos - rp).Magnitude
                if d <= lim then
                    if not bestD or d < bestD then
                        best, bestD = t, d
                    end
                end
            end
        end
    end
    return best
end

task.spawn(function()
    while running do
        task.wait(0.1)
        if running then
            local keyDown = false
            if cfg.auraOn then
                local ok, down = pcall(function() return iskeypressed(cfg.auraKey) end)
                if ok then keyDown = down == true end
            end

            if not keyDown then
                -- you let go: stop immediately, give the mouse back
                if holding then
                    releaseMouse(true)
                    holdTgt = nil
                    lastEnd = tick()
                end
            elseif holding then
                local gone = not holdTgt or not holdTgt.top or holdTgt.top.Parent == nil
                if gone or tick() - holdStart > cfg.holdSec then
                    releaseMouse(true)
                    if holdTgt and type(holdTgt.cell) == 'number' then
                        done[holdTgt.cell] = tick()
                    end
                    if gone then minedN = minedN + 1 end
                    holdTgt = nil
                    lastEnd = tick()
                end
            elseif tick() - lastEnd >= cfg.gapSec then
                local char = lp.Character
                local root = char and char:FindFirstChild('HumanoidRootPart')
                if root then
                    local best = pickTarget(root.Position)
                    if best then
                        local cx, cy = cursorPos()
                        if cx then
                            saveX, saveY = cx, cy
                        else
                            saveX, saveY = best.sx, best.sy
                        end
                        pcall(function() mousemoveabs(math.floor(best.sx), math.floor(best.sy)) end)
                        task.wait(0.05)
                        pcall(function() mouse1press() end)
                        holding   = true
                        holdStart = tick()
                        holdTgt   = best
                    end
                end
            end
        end
    end
end)

-- menu ---------------------------------------------------------------

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
    local triesList = {
        function() sec:Toggle(label, id, default, cb) end,
        function() sec:Toggle(id, label, default, cb) end,
        function() sec:Toggle(label, default, cb) end,
    }
    for i = 1, #triesList do
        if pcall(triesList[i]) then return true end
    end
    warn('[TI] toggle failed: ' .. label)
    return false
end

local function mkSlider(sec, label, id, min, max, default, apply)
    local cb = function(...)
        local v = firstNumber(...)
        if v ~= nil then apply(v) end
    end
    local triesList = {
        function() sec:SliderInt(label, id, min, max, default, cb) end,
        function() sec:SliderInt(id, label, min, max, default, cb) end,
        function() sec:SliderInt(label, min, max, default, cb) end,
    }
    for i = 1, #triesList do
        if pcall(triesList[i]) then return true end
    end
    warn('[TI] slider failed: ' .. label)
    return false
end

local function mkButton(sec, label, cb)
    if pcall(function() sec:Button(label, cb) end) then return true end
    if pcall(function() sec:Button(label, label .. '_btn', cb) end) then return true end
    warn('[TI] button failed: ' .. label)
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
        mkToggle(sec, 'ESP Enabled', 'ti_enabled', cfg.enabled, function(v) cfg.enabled = v end)
        mkToggle(sec, 'Silver Ore', 'ti_esp_silver', cfg.espSilver, function(v) cfg.espSilver = v end)
        mkToggle(sec, 'Iron Ore', 'ti_esp_iron', cfg.espIron, function(v) cfg.espIron = v end)
        mkToggle(sec, 'Stone Blocks', 'ti_esp_stone', cfg.espStone, function(v) cfg.espStone = v end)
    end

    local look = mkSection(tab, 'ESP Style')
    if look then
        mkToggle(look, 'Show Names', 'ti_label', cfg.showNames, function(v) cfg.showNames = v end)
        mkSlider(look, 'Names On Nearest', 'ti_labelnear', 0, 30, cfg.nameNear, function(v) cfg.nameNear = v end)
        mkSlider(look, 'Max Distance', 'ti_maxdist', 50, 2000, cfg.maxDist, function(v) cfg.maxDist = v end)
        mkSlider(look, 'Max Boxes', 'ti_maxboxes', 5, 64, cfg.maxBoxes, function(v) cfg.maxBoxes = v end)
        mkToggle(look, 'Distance Fade', 'ti_fade', cfg.fade, function(v) cfg.fade = v end)
        mkSlider(look, 'Line Thickness', 'ti_thick', 1, 4, cfg.thickness, function(v) cfg.thickness = v end)
        mkToggle(look, 'Thickness Scales', 'ti_scalethick', cfg.scaleThick, function(v) cfg.scaleThick = v end)
        pcall(function() look:ColorPicker('Silver Color', cfg.silver.R, cfg.silver.G, cfg.silver.B, 1) end)
        pcall(function() look:ColorPicker('Iron Color', cfg.iron.R, cfg.iron.G, cfg.iron.B, 1) end)
        pcall(function() look:ColorPicker('Stone Color', cfg.stone.R, cfg.stone.G, cfg.stone.B, 1) end)
    end

    local au = mkSection(tab, 'Hold Aura')
    if au then
        mkToggle(au, 'Aura While Holding E', 'ti_auraon', cfg.auraOn, function(v)
            cfg.auraOn = v
            if not v then releaseMouse(true) end
        end)
        mkToggle(au, 'Put Cursor Back', 'ti_restore', cfg.restore, function(v) cfg.restore = v end)
        mkSlider(au, 'Hold Seconds x10', 'ti_hold', 5, 80, math.floor(cfg.holdSec * 10), function(v)
            cfg.holdSec = v / 10
        end)
        mkSlider(au, 'Gap Seconds x10', 'ti_gap', 0, 30, math.floor(cfg.gapSec * 10), function(v)
            cfg.gapSec = v / 10
        end)
        mkSlider(au, 'Ignore Block Sec', 'ti_rearm', 5, 90, cfg.rearmSec, function(v) cfg.rearmSec = v end)
        mkButton(au, 'Stats', function()
            print('[TI] mined=' .. minedN .. ' tracked=' .. #targets .. ' holding=' .. tostring(holding))
        end)
        mkButton(au, 'Clear Ignore List', function()
            done = {}
            print('[TI] ignore list cleared')
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

local function stop()
    running = false
    releaseMouse(true)
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
print('[TI] ' .. VERSION .. ' loaded - hold E to mine, release to stop')
