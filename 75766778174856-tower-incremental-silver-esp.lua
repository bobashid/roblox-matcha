-- Tower Incremental - Mine ESP + Auto Mine
-- place 75766778174856
-- v17: first person support, ONE Auto Mine toggle, ONE remappable key.
--      No sliders anywhere - every number is a fixed constant below.
--
-- First person: the game raycasts from the camera centre, so the camera is
-- turned onto the ore before the click (and held there while mining).
-- Third person: the cursor is moved onto the ore's screen position instead.
--
-- Auto Mine walks to ore that is out of reach, mines what is in reach.
--
-- Reach numbers are the game's own, from MineClient:
--   ore 22 level / 30 above, stone 18 level / 24.
--
-- Matcha LuauVM: no Instance.new, no hooks. Overlay via Drawing only.

local NAME    = 'TIOreESP'
local VERSION = 'v17'

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

-- fixed values (no sliders) -----------------------------------------

local MAX_DIST   = 600
local MAX_BOXES  = 48
local NAME_NEAR  = 8
local THICKNESS  = 1
local HOLD_SEC   = 2.5
local GAP_SEC    = 0.2
local REARM_SEC  = 15
local WALK_RANGE = 140
local REACH_PAD  = 0
local FP_NEAR    = 2.0   -- camera this close to the head means first person

local KEY_LIST = {
    Enum.KeyCode.F, Enum.KeyCode.G, Enum.KeyCode.H, Enum.KeyCode.J,
    Enum.KeyCode.K, Enum.KeyCode.Q, Enum.KeyCode.E, Enum.KeyCode.R,
    Enum.KeyCode.T, Enum.KeyCode.V, Enum.KeyCode.B, Enum.KeyCode.C,
}

local cfg = {
    enabled   = true,
    espSilver = true,
    espIron   = true,
    espStone  = false,
    showNames = true,
    showHud   = true,
    autoMine  = false,
}

local keyIdx = 1
local function keyName()
    return tostring(KEY_LIST[keyIdx]):gsub('Enum.KeyCode.', '')
end

local function espOn(kind)
    if kind == 'Silver' then return cfg.espSilver end
    if kind == 'Iron'   then return cfg.espIron end
    if kind == 'Stone'  then return cfg.espStone end
    return false
end

local COL_SILVER = Color3.fromRGB(220, 225, 240)
local COL_IRON   = Color3.fromRGB(215, 150, 110)
local COL_STONE  = Color3.fromRGB(150, 160, 175)

local function colorFor(kind)
    if kind == 'Iron'  then return COL_IRON end
    if kind == 'Stone' then return COL_STONE end
    return COL_SILVER
end

local function reachFor(kind, above)
    local ore = kind ~= 'Stone'
    local base = ore and 22 or 18
    local up   = ore and 30 or 24
    return (above and up or base) + REACH_PAD
end

-- drawing pool ------------------------------------------------------

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
        ln.Thickness = THICKNESS
        ln.Color = COL_SILVER
        ln.Visible = false
        lines[k] = ln
    end
    local tag = Drawing.new('Text')
    tag.Center = true
    tag.Outline = true
    tag.Size = 13
    tag.Color = COL_SILVER
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

-- first person detection --------------------------------------------

local function firstPerson(char)
    local cam = workspace.CurrentCamera
    local head = char and char:FindFirstChild('Head')
    if not cam or not head then return false end
    local ok, d = pcall(function()
        return (cam.CFrame.Position - head.Position).Magnitude
    end)
    if ok and type(d) == 'number' then return d < FP_NEAR end
    return false
end

-- collector ---------------------------------------------------------

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
                    local above = origin and pos.Y > origin.Y + 4 or false
                    local inReach = origin ~= nil and d <= reachFor(kind, above)
                    if inReach then n = n + 1 end
                    out[#out + 1] = {
                        cframe  = cf,
                        pos     = pos,
                        size    = boxPart.Size,
                        dist    = d,
                        inReach = inReach,
                        kind    = kind,
                        top     = m,
                        cell    = m:GetAttribute('Cell'),
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

-- renderer ----------------------------------------------------------

track(RunService.RenderStepped:Connect(function()
    if not cfg.enabled then
        hideAll()
        hud.Visible = false
        return
    end

    local char   = lp.Character
    local root   = char and char:FindFirstChild('HumanoidRootPart')
    local origin = root and root.Position
    local maxSq  = MAX_DIST * MAX_DIST
    local cap    = math.min(MAX_BOXES, POOL)
    local list   = targets
    local n      = 0
    local stamp  = tick()

    for i = 1, #list do
        if n >= cap then break end
        local t  = list[i]
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
                local f = dist / MAX_DIST
                if f > 1 then f = 1 end
                tr = 0.1 + 0.65 * f
                if not t.inReach then tr = tr + 0.45 end

                local th = math.floor(THICKNESS * 150 / math.max(dist, 40))
                if th < 1 then th = 1 elseif th > 5 then th = 5 end
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

                if cfg.showNames and n <= NAME_NEAR then
                    e.tag.Text = t.kind
                    e.tag.Color = col
                    e.tag.Position = Vector2.new((minX + maxX) * 0.5, minY - 16)
                    e.tag.Visible = true
                elseif e.tag.Visible then
                    e.tag.Visible = false
                end

                t.sx  = (minX + maxX) * 0.5
                t.sy  = (minY + maxY) * 0.5
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

    if cfg.showHud then
        local txt = string.format('mine %s | tracked %d | reach %d | auto %s [%s]',
            timerText or '?', #targets, reachN,
            cfg.autoMine and 'ON' or 'off', keyName())
        if hudLast ~= txt then
            hud.Text = txt
            hudLast = txt
        end
        hud.Visible = true
    elseif hud.Visible then
        hud.Visible = false
    end
end))

-- mining ------------------------------------------------------------

local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude
rp.IgnoreWater = true

local function blocksFolder()
    local mine = workspace:FindFirstChild('Mine')
    return mine and mine:FindFirstChild('MineBlocks') or nil
end

local function clearShot(t)
    local cam = workspace.CurrentCamera
    if not cam then return true end
    local char = lp.Character
    rp.FilterDescendantsInstances = char and { char } or {}
    local hit = workspace:Raycast(cam.CFrame.Position, t.pos - cam.CFrame.Position, rp)
    if not hit then return true end
    local inst = hit.Instance
    if not inst then return true end
    if inst == t.top then return true end
    if t.top and inst:IsDescendantOf(t.top) then return true end
    local folder = blocksFolder()
    if folder and inst:IsDescendantOf(folder) then
        return false
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
local fpMode    = false

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
        if restore and not fpMode then
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
                if last and now - last < REARM_SEC then skip = true end
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

-- first person: keep the camera on the ore while the click is held
track(RunService.RenderStepped:Connect(function()
    if not holding or not fpMode or not holdTgt then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    local p = holdTgt.pos
    if not p then return end
    pcall(function()
        cam.CFrame = CFrame.lookAt(cam.CFrame.Position, p)
    end)
end))

task.spawn(function()
    while running do
        task.wait(0.1)
        if running then
            local char = lp.Character
            local root = char and char:FindFirstChild('HumanoidRootPart')
            local hum  = char and char:FindFirstChild('Humanoid')
            fpMode = firstPerson(char)

            if not root or not hum then
                releaseMouse(true)
                holdTgt = nil
                walking = false
            else
                if holding then
                    local gone = not holdTgt or not holdTgt.top or holdTgt.top.Parent == nil
                    if gone or tick() - holdStart > HOLD_SEC then
                        releaseMouse(true)
                        if holdTgt and type(holdTgt.cell) == 'number' then
                            done[holdTgt.cell] = tick()
                        end
                        if gone then minedN = minedN + 1 end
                        holdTgt = nil
                        lastEnd = tick()
                    end
                elseif cfg.autoMine and tick() - lastEnd >= GAP_SEC then
                    local best = pickTarget()
                    if best then
                        if fpMode then
                            local cam = workspace.CurrentCamera
                            if cam then
                                pcall(function()
                                    cam.CFrame = CFrame.lookAt(cam.CFrame.Position, best.pos)
                                end)
                            end
                            task.wait(0.03)
                            pcall(function() mouse1press() end)
                        else
                            local cx, cy = cursorPos()
                            if cx then saveX, saveY = cx, cy else saveX, saveY = best.sx, best.sy end
                            pcall(function() mousemoveabs(math.floor(best.sx), math.floor(best.sy)) end)
                            task.wait(0.05)
                            pcall(function() mouse1press() end)
                        end
                        holding   = true
                        holdStart = tick()
                        holdTgt   = best
                    end
                end

                if cfg.autoMine and not holding then
                    local far, farD
                    for i = 1, #targets do
                        local t = targets[i]
                        if t.top and t.top.Parent and not t.inReach and t.dist <= WALK_RANGE then
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

-- keybind ------------------------------------------------------------

track(UIS.InputBegan:Connect(function(input)
    local k = input and input.KeyCode
    if k and k == KEY_LIST[keyIdx] then
        cfg.autoMine = not cfg.autoMine
        if not cfg.autoMine then releaseMouse(true) end
        print('[TI] auto mine ' .. (cfg.autoMine and 'ON' or 'off'))
    end
end))

-- menu ---------------------------------------------------------------

local HAS_UI = type(UI) == 'table' and type(UI.AddTab) == 'function'

local function firstBool(...)
    for i = 1, select('#', ...) do
        local v = select(i, ...)
        if type(v) == 'boolean' then return v end
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

local function mkButton(sec, label, cb)
    if pcall(function() sec:Button(label, cb) end) then return true end
    if pcall(function() sec:Button(label, label .. '_btn', cb) end) then return true end
    warn('[TI] button failed: ' .. label)
    return false
end

local function buildTab(tab)
    if built then return end
    built = true

    local main = mkSection(tab, 'Mine')
    if main then
        mkToggle(main, 'Auto Mine (walk + mine)', 'ti_automine', cfg.autoMine, function(v)
            cfg.autoMine = v
            if not v then releaseMouse(true) end
        end)
        mkToggle(main, 'ESP Enabled', 'ti_enabled', cfg.enabled, function(v) cfg.enabled = v end)
        mkToggle(main, 'Silver Ore', 'ti_esp_silver', cfg.espSilver, function(v) cfg.espSilver = v end)
        mkToggle(main, 'Iron Ore', 'ti_esp_iron', cfg.espIron, function(v) cfg.espIron = v end)
        mkToggle(main, 'Stone Blocks', 'ti_esp_stone', cfg.espStone, function(v) cfg.espStone = v end)
        mkToggle(main, 'Show Names', 'ti_label', cfg.showNames, function(v) cfg.showNames = v end)
        mkToggle(main, 'Show HUD', 'ti_hud', cfg.showHud, function(v) cfg.showHud = v end)
        mkButton(main, 'Change Key (' .. keyName() .. ')', function()
            keyIdx = keyIdx + 1
            if keyIdx > #KEY_LIST then keyIdx = 1 end
            print('[TI] toggle key = ' .. keyName())
        end)
        mkButton(main, 'Clear Ignore List', function()
            done = {}
            print('[TI] ignore list cleared')
        end)
        mkButton(main, 'Stats', function()
            print('[TI] mined=' .. minedN .. ' tracked=' .. #targets ..
                ' reach=' .. reachN .. ' fp=' .. tostring(fpMode) ..
                ' holding=' .. tostring(holding) .. ' key=' .. keyName())
        end)
    end
end

if HAS_UI then
    local ok, err = pcall(function()
        UI.AddTab('Mine', function(tab)
            pcall(buildTab, tab)
        end)
    end)
    if not ok then
        warn('[TI] UI.AddTab failed: ' .. tostring(err))
        HAS_UI = false
    end
end

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
print('[TI] ' .. VERSION .. ' loaded - press ' .. keyName() .. ' to toggle Auto Mine')
