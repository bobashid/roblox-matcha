-- Tower Incremental - Mine ESP + Mining Helpers
-- place 75766778174856
-- v16: silent remote mining is impossible on this game - v11-v13 logs showed
--      every MineBlock fire rejected at 10m and 25m, so the server wants the
--      real hold. This version stops chasing that and helps the mining:
--
--        * Auto Walk - walks you to the closest ore that is out of reach
--        * Line of sight - only aims at ores a raycast can actually reach,
--          never clicks a block hidden behind another one
--        * Reach highlight - in-reach ores draw solid, out-of-reach ones fade,
--          so you know what you can mine right now
--        * Mine timer - reads workspace.Mine.Timer live
--        * HUD - timer, tracked count, in-reach count, state
--
-- Mining runs on the real hold: hold E, or turn on Auto Run to let it go
-- without the key. Everything else is a menu toggle.
--
-- Reach numbers are the game's own, from MineClient: ore 22 level / 30 above,
-- stone 18 level / 24.
--
-- Matcha LuauVM: no Instance.new, no hooks. Overlay via Drawing only.

local NAME    = 'TIOreESP'
local VERSION = 'v16'

if _G[NAME] and _G[NAME].stop then
    pcall(_G[NAME].stop)
end

local Players    = game:GetService('Players')
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
    reachOnly  = false,
    reachPad   = 0,
    showHud    = true,
    silver     = Color3.fromRGB(220, 225, 240),
    iron       = Color3.fromRGB(215, 150, 110),
    stone      = Color3.fromRGB(150, 160, 175),

    -- helpers
    autoWalk   = false,
    walkRange  = 60,
    walkStop   = 0.85,

    -- mining
    auraOn     = true,    -- hold E
    autoRun    = false,   -- mine without holding anything
    needLos    = true,    -- only click ores with a clear shot
    holdSec    = 2.5,
    gapSec     = 0.25,
    rearmSec   = 15,
    restore    = true,
}

local HOLD_KEY = Enum.KeyCode.E

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

local function reachFor(kind, above)
    local ore = kind ~= 'Stone'
    local base = ore and 22 or 18
    local up   = ore and 30 or 24
    return (above and up or base) + cfg.reachPad
end

-- drawing pool -------------------------------------------------------

local POOL = 64
local EDGES = {
    {1,2},{3,4},{5,6},{7,8},
    {1,3},{2,4},{5,7},{6,8},
    {1,5},{2,6},{3,7},{4,8},
}

local pool    = {}
local targets = {}
local timerText = nil
local reachN  = 0

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

local hud = Drawing.new('Text')
hud.Center = false
hud.Outline = true
hud.Size = 14
hud.Color = Color3.fromRGB(235, 235, 245)
hud.Position = Vector2.new(12, 96)
hud.Visible = false
local hudLast = ''

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

-- collector ----------------------------------------------------------

local function mineTimer()
    local mine = workspace:FindFirstChild('Mine')
    local t = mine and mine:FindFirstChild('Timer')
    local gui = t and t:FindFirstChild('SurfaceGui')
    local frame = gui and gui:FindFirstChild('Frame')
    local label = frame and frame:FindFirstChild('Timer')
    if label then
        local ok, v = pcall(function() return label.Text end)
        if ok and type(v) == 'string' then return v end
    end
    return nil
end

task.spawn(function()
    while running do
        local out = {}
        local n = 0
        local mine = workspace:FindFirstChild('Mine')
        local blocks = mine and mine:FindFirstChild('MineBlocks')
        local char = lp.Character
        local root = char and char:FindFirstChild('HumanoidRootPart')
        local origin = root and root.Position
        timerText = mineTimer()
        if blocks then
            local kids = blocks:GetChildren()
            for i = 1, #kids do
                local m = kids[i]
                local nm = m.Name
                local kind, boxPart = nil, nil
                if string.sub(nm, -3) == 'Ore' then
                    kind    = string.sub(nm, 1, #nm - 3)
                    boxPart = m:FindFirstChild('Stone')
                elseif nm == 'Stone' then
                    kind    = 'Stone'
                    boxPart = m
                end
                if kind and boxPart and espOn(kind) then
                    local cf = boxPart.CFrame
                    local pos = cf.Position
                    local d = origin and (pos - origin).Magnitude or 0
                    local reach = reachFor(kind, origin and pos.Y > origin.Y + 4 or false)
                    local inReach = origin ~= nil and d <= reach
                    if inReach then n = n + 1 end
                    out[#out + 1] = {
                        cframe = cf,
                        pos    = pos,
                        size   = boxPart.Size,
                        dist   = d,
                        reach  = reach,
                        inReach = inReach,
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
        reachN = n
        task.wait(0.4)
    end
end)

-- renderer -----------------------------------------------------------

track(RunService.RenderStepped:Connect(function()
    if not cfg.enabled then
        hideAll()
        hud.Visible = false
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
        if cfg.reachOnly and not t.inReach then
            -- skip entirely
        else
            local cf = t.cframe
            local s  = t.size
            local dist = t.dist

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
                    -- out of reach reads faint so the mineable ones pop
                    if not t.inReach then tr = tr + 0.45 end

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

    if cfg.showHud then
        local txt = string.format('mine %s | tracked %d | reach %d',
            timerText or '?', #targets, reachN)
        if hudLast ~= txt then
            hud.Text = txt
            hudLast = txt
        end
        hud.Visible = true
    elseif hud.Visible then
        hud.Visible = false
    end
end))

-- mining + auto walk ------------------------------------------------

local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude
rp.IgnoreWater = true

local function blocksFolder()
    local mine = workspace:FindFirstChild('Mine')
    return mine and mine:FindFirstChild('MineBlocks') or nil
end

-- true when nothing else in MineBlocks sits between the camera and this ore
local function clearShot(t)
    if not cfg.needLos then return true end
    local cam = workspace.CurrentCamera
    if not cam then return true end
    local char = lp.Character
    rp.FilterDescendantsInstances = char and { char } or {}
    local hit = workspace:Raycast(cam.Position, t.pos - cam.Position, rp)
    if not hit then return true end
    local inst = hit.Instance
    if not inst then return true end
    if inst == t.top then return true end
    if t.top and inst:IsDescendantOf(t.top) then return true end
    local folder = blocksFolder()
    if folder and inst:IsDescendantOf(folder) then
        return false   -- another block is in the way
    end
    return true
end

local done      = {}
local holding   = false
local holdStart = 0
local holdTgt   = nil
local lastEnd   = 0
local minedN    = 0
local saveX, saveY = 0, 0
local walking   = false

local function cursorPos()
    local ok, m = pcall(function() return lp:GetMouse() end)
    if ok and m then
        local okx, x = pcall(function() return m.X end)
        local oky, y = pcall(function() return m.Y end)
        if okx and oky and type(x) == 'number' and type(y) == 'number' then
            return x, y
        end
    end
    return nil
end

local function releaseMouse(restore)
    if holding then
        pcall(function() mouse1release() end)
        holding = false
        if restore and cfg.restore then
            pcall(function() mousemoveabs(math.floor(saveX), math.floor(saveY)) end)
        end
    end
end

local function stopWalk(hum, root)
    if walking and hum and root then
        pcall(function() hum.WalkToPoint = root.Position end)
    end
    walking = false
end

local function pickTarget()
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
            if not skip and t.inReach and clearShot(t) then
                if not bestD or t.dist < bestD then
                    best, bestD = t, t.dist
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
            local char = lp.Character
            local root = char and char:FindFirstChild('HumanoidRootPart')
            local hum  = char and char:FindFirstChild('Humanoid')

            if not root or not hum then
                releaseMouse(true)
                holdTgt = nil
                walking = false
            else
                local keyDown = cfg.autoRun
                if not keyDown and cfg.auraOn then
                    local ok, down = pcall(function() return iskeypressed(HOLD_KEY) end)
                    if ok then keyDown = down == true end
                end

                if holding then
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
                elseif keyDown and tick() - lastEnd >= cfg.gapSec then
                    local best = pickTarget()
                    if best then
                        local cx, cy = cursorPos()
                        if cx then saveX, saveY = cx, cy else saveX, saveY = best.sx, best.sy end
                        pcall(function() mousemoveabs(math.floor(best.sx), math.floor(best.sy)) end)
                        task.wait(0.05)
                        pcall(function() mouse1press() end)
                        holding   = true
                        holdStart = tick()
                        holdTgt   = best
                    end
                end

                -- auto walk: only while not mining, only toward out-of-reach ore
                if cfg.autoWalk and not holding then
                    local far, farD
                    for i = 1, #targets do
                        local t = targets[i]
                        if t.top and t.top.Parent and not t.inReach and t.dist <= cfg.walkRange then
                            if not farD or t.dist < farD then
                                far, farD = t, t.dist
                            end
                        end
                    end
                    if far then
                        pcall(function() hum.WalkToPoint = far.pos end)
                        walking = true
                    else
                        stopWalk(hum, root)
                    end
                else
                    stopWalk(hum, root)
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
        mkToggle(sec, 'Only In Reach', 'ti_reachonly', cfg.reachOnly, function(v) cfg.reachOnly = v end)
        mkToggle(sec, 'Show HUD', 'ti_hud', cfg.showHud, function(v) cfg.showHud = v end)
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
        mkSlider(look, 'Reach Padding', 'ti_reachpad', -10, 20, cfg.reachPad, function(v) cfg.reachPad = v end)
        pcall(function() look:ColorPicker('Silver Color', cfg.silver.R, cfg.silver.G, cfg.silver.B, 1) end)
        pcall(function() look:ColorPicker('Iron Color', cfg.iron.R, cfg.iron.G, cfg.iron.B, 1) end)
        pcall(function() look:ColorPicker('Stone Color', cfg.stone.R, cfg.stone.G, cfg.stone.B, 1) end)
    end

    local walk = mkSection(tab, 'Auto Walk')
    if walk then
        mkToggle(walk, 'Walk To Out-Of-Reach Ore', 'ti_autowalk', cfg.autoWalk, function(v)
            cfg.autoWalk = v
        end)
        mkSlider(walk, 'Walk Range', 'ti_walkrange', 10, 200, cfg.walkRange, function(v) cfg.walkRange = v end)
    end

    local au = mkSection(tab, 'Mining')
    if au then
        mkToggle(au, 'Hold E To Mine', 'ti_auraon', cfg.auraOn, function(v)
            cfg.auraOn = v
            if not v then releaseMouse(true) end
        end)
        mkToggle(au, 'Auto Run (no key needed)', 'ti_autorun', cfg.autoRun, function(v)
            cfg.autoRun = v
            if not v then releaseMouse(true) end
        end)
        mkToggle(au, 'Line Of Sight Only', 'ti_los', cfg.needLos, function(v) cfg.needLos = v end)
        mkToggle(au, 'Put Cursor Back', 'ti_restore', cfg.restore, function(v) cfg.restore = v end)
        mkSlider(au, 'Hold Seconds x10', 'ti_hold', 5, 80, math.floor(cfg.holdSec * 10), function(v)
            cfg.holdSec = v / 10
        end)
        mkSlider(au, 'Gap Seconds x100', 'ti_gap', 0, 100, math.floor(cfg.gapSec * 100), function(v)
            cfg.gapSec = v / 100
        end)
        mkSlider(au, 'Ignore Block Sec', 'ti_rearm', 3, 60, cfg.rearmSec, function(v) cfg.rearmSec = v end)
        mkButton(au, 'Stats', function()
            print('[TI] mined=' .. minedN .. ' tracked=' .. #targets ..
                ' reach=' .. reachN .. ' holding=' .. tostring(holding))
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

-- stop ----------------------------------------------------------------

local function stop()
    running = false
    releaseMouse(true)
    walking = false
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
    pcall(function() hud:Remove() end)
    _G[NAME] = nil
    print('[TI] stopped')
end

_G[NAME] = { stop = stop, version = VERSION }
print('[TI] ' .. VERSION .. ' loaded - ESP + auto walk + timer. Hold E to mine.')
