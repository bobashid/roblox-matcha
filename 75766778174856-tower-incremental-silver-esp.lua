-- Tower Incremental - Auto Mine + ESP
-- place 75766778174856
-- Matcha LuauVM: no Instance.new, no hooks
--
-- v22:
--   * ESP transparency slider (0 = solid, 100 = invisible)
--   * first person auto mine MOVES THE MOUSE onto the ore with mousemoverel,
--     and only falls back to pointing the camera if the mouse does not
--     converge within a few frames
--   * walks to ore that is out of reach, mines whatever is in reach
--   * Set Key binds the next key you press, saved to towerincremental.cfg
--
-- Why keybinds failed before v21: Matcha's UserInputService.InputBegan hands
-- you a TABLE whose KeyCode is an INTEGER, not an EnumItem. Comparing it to
-- Enum.KeyCode.F is always false. This matches the integer, the EnumItem and
-- the name, and also polls iskeypressed with both forms.
--
-- Reach numbers are the game's own, from MineClient:
--   ore 22 level / 30 above, stone 18 level / 24.

local NAME    = 'TIOreESP'
local VERSION = 'v22'

if _G[NAME] and _G[NAME].stop then pcall(_G[NAME].stop) end

local Players    = game:GetService('Players')
local RunService = game:GetService('RunService')
local UIS        = game:GetService('UserInputService')

local lp = Players.LocalPlayer

local running = true
local conns   = {}

-- fixed numbers -------------------------------------------------------

local MAX_DIST     = 600
local MAX_BOXES    = 48
local NAME_NEAR    = 6
local HOLD_SEC     = 2.5
local GAP_SEC      = 0.2
local REARM_SEC    = 15
local WALK_RANGE   = 140
local STUCK_SEC    = 2.5
local FP_NEAR      = 2.0
local TOG_DEBOUNCE = 0.35
local AIM_TRIES    = 6
local AIM_TOL      = 16

-- state (declared early, the renderer reads these) --------------------

local holding    = false
local walking    = false
local holdTgt    = nil
local lastToggle = 0
local listening  = false
local statusText = 'idle'

-- config --------------------------------------------------------------

local cfg = {
    enabled  = false,
    silver   = true,
    iron     = true,
    stone    = false,
    names    = true,
    trans    = 0.15,             -- 0 solid .. 1 invisible
    keyCode  = Enum.KeyCode.F,
    keyVal   = nil,
    keyName  = 'F',
}

local KEY_LIST = {
    Enum.KeyCode.F, Enum.KeyCode.G, Enum.KeyCode.H, Enum.KeyCode.J,
    Enum.KeyCode.K, Enum.KeyCode.E, Enum.KeyCode.Q, Enum.KeyCode.R,
    Enum.KeyCode.T, Enum.KeyCode.V, Enum.KeyCode.B, Enum.KeyCode.C,
    Enum.KeyCode.X, Enum.KeyCode.Z, Enum.KeyCode.U, Enum.KeyCode.I,
    Enum.KeyCode.O, Enum.KeyCode.P, Enum.KeyCode.L, Enum.KeyCode.M,
    Enum.KeyCode.N, Enum.KeyCode.Y,
    Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift,
    Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl,
    Enum.KeyCode.LeftAlt, Enum.KeyCode.RightAlt,
    Enum.KeyCode.Tab, Enum.KeyCode.CapsLock,
}

local function codeValue(code)
    if code == nil then return nil end
    local ok, v = pcall(function() return code.Value end)
    if ok and type(v) == 'number' then return v end
    return nil
end

local function codeName(code)
    if code == nil then return '?' end
    local ok, v = pcall(function() return code.Name end)
    if ok and type(v) == 'string' and v ~= '' then return v end
    local s = tostring(code)
    s = string.gsub(s, 'Enum.KeyCode.', '')
    return s
end

local function bindKey(k)
    if k == nil then return false end
    local asNum = (type(k) == 'number') and k or codeValue(k)
    for i = 1, #KEY_LIST do
        local item = KEY_LIST[i]
        local v = codeValue(item)
        if k == item then
            cfg.keyCode = item
            cfg.keyVal  = v
            cfg.keyName = codeName(item)
            return true
        end
        if asNum ~= nil and v ~= nil and asNum == v then
            cfg.keyCode = item
            cfg.keyVal  = v
            cfg.keyName = codeName(item)
            return true
        end
    end
    if asNum ~= nil then
        cfg.keyCode = nil
        cfg.keyVal  = asNum
        cfg.keyName = 'Key' .. tostring(asNum)
        return true
    end
    return false
end

local function keyMatches(k)
    if k == nil then return false end
    if cfg.keyCode ~= nil and k == cfg.keyCode then return true end
    local num = (type(k) == 'number') and k or codeValue(k)
    if num ~= nil and cfg.keyVal ~= nil and num == cfg.keyVal then return true end
    return false
end

local function keyIsDown()
    if cfg.keyCode ~= nil then
        local ok, d = pcall(function() return iskeypressed(cfg.keyCode) end)
        if ok and d == true then return true end
    end
    if cfg.keyVal ~= nil then
        local ok, d = pcall(function() return iskeypressed(cfg.keyVal) end)
        if ok and d == true then return true end
    end
    return false
end

-- persistence ---------------------------------------------------------

local CONFIG_FILE = 'towerincremental.cfg'

local function saveCfg()
    local lines = {
        'keyname=' .. tostring(cfg.keyName),
        'keyval=' .. tostring(cfg.keyVal),
        'silver=' .. tostring(cfg.silver),
        'iron=' .. tostring(cfg.iron),
        'stone=' .. tostring(cfg.stone),
        'names=' .. tostring(cfg.names),
        'trans=' .. tostring(cfg.trans),
    }
    pcall(function() writefile(CONFIG_FILE, table.concat(lines, '\n')) end)
end

local function loadCfg()
    local ok, data = pcall(function() return readfile(CONFIG_FILE) end)
    if not ok or not data or data == '' then return end
    local wantName, wantVal
    for line in string.gmatch(data, '[^\n]+') do
        local k, v = string.match(line, '^(%w+)=(.*)$')
        if k == 'keyname' and v and v ~= '' then
            wantName = v
        elseif k == 'keyval' and v and v ~= '' then
            wantVal = tonumber(v)
        elseif k == 'silver' then
            cfg.silver = v == 'true'
        elseif k == 'iron' then
            cfg.iron = v == 'true'
        elseif k == 'stone' then
            cfg.stone = v == 'true'
        elseif k == 'names' then
            cfg.names = v == 'true'
        elseif k == 'trans' then
            local n = tonumber(v)
            if n then cfg.trans = math.clamp(n, 0, 1) end
        end
    end
    if wantName then
        for i = 1, #KEY_LIST do
            if codeName(KEY_LIST[i]) == wantName then
                cfg.keyCode = KEY_LIST[i]
                cfg.keyVal  = codeValue(KEY_LIST[i])
                cfg.keyName = wantName
                return
            end
        end
        cfg.keyCode = nil
        cfg.keyVal  = wantVal
        cfg.keyName = wantName
    end
end

loadCfg()

if cfg.keyCode ~= nil and cfg.keyVal == nil then
    cfg.keyVal = codeValue(cfg.keyCode)
end

local function log(msg)
    print('[' .. NAME .. '] ' .. msg)
end

local function track(c)
    conns[#conns + 1] = c
    return c
end

local function espOn(kind)
    if kind == 'Silver' then return cfg.silver end
    if kind == 'Iron'   then return cfg.iron end
    if kind == 'Stone'  then return cfg.stone end
    return false
end

-- colours -------------------------------------------------------------

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
    return above and up or base
end

local function releaseMouse()
    if holding then
        pcall(function() mouse1release() end)
        holding = false
    end
end

local function toggleAuto()
    local now = tick()
    if now - lastToggle < TOG_DEBOUNCE then return end
    lastToggle = now
    cfg.enabled = not cfg.enabled
    if not cfg.enabled then
        releaseMouse()
        walking = false
    end
    log('auto mine ' .. (cfg.enabled and 'ON' or 'off'))
end

-- drawing pool --------------------------------------------------------

local POOL = 64
local EDGES = {
    {1,2},{3,4},{5,6},{7,8},
    {1,3},{2,4},{5,7},{6,8},
    {1,5},{2,6},{3,7},{4,8},
}

local pool    = {}
local targets = {}
local reachN  = 0

for i = 1, POOL do
    local lines = {}
    for k = 1, 12 do
        local ln = Drawing.new('Line')
        ln.Thickness = 1
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

-- first person --------------------------------------------------------

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

-- move the real mouse onto the ore; camera lookAt only as a fallback --

local function aimFirstPerson(t)
    local cam = workspace.CurrentCamera
    if not cam then return false end
    local vp = cam.ViewportSize
    if not vp then return false end
    local cx, cy = vp.X * 0.5, vp.Y * 0.5

    for _ = 1, AIM_TRIES do
        local sx, sy = t.sx, t.sy
        if not sx or not sy then break end
        local dx = sx - cx
        local dy = sy - cy
        if math.abs(dx) <= AIM_TOL and math.abs(dy) <= AIM_TOL then
            return true
        end
        pcall(function()
            mousemoverel(math.floor(dx * 0.85), math.floor(dy * 0.85))
        end)
        task.wait(0.04)
    end

    -- mouse did not converge (cursor locked, weird aspect): point the camera
    if t.pos then
        pcall(function()
            cam.CFrame = CFrame.lookAt(cam.CFrame.Position, t.pos)
        end)
        task.wait(0.03)
    end
    return true
end

-- collector -----------------------------------------------------------

task.spawn(function()
    while running do
        local out = {}
        local n = 0
        local mine = workspace:FindFirstChild('Mine')
        local blocks = mine and mine:FindFirstChild('MineBlocks')
        local char = lp.Character
        local root = char and char:FindFirstChild('HumanoidRootPart')
        local origin = root and root.Position
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

-- renderer ------------------------------------------------------------

track(RunService.RenderStepped:Connect(function()
    local char   = lp.Character
    local root   = char and char:FindFirstChild('HumanoidRootPart')
    local origin = root and root.Position
    local maxSq  = MAX_DIST * MAX_DIST
    local cap    = math.min(MAX_BOXES, POOL)
    local list   = targets
    local n      = 0
    local stamp  = tick()
    local userTr = math.clamp(cfg.trans, 0, 1)

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

                -- distance fade, then the user's transparency on top
                local f = dist / MAX_DIST
                if f > 1 then f = 1 end
                local tr = 0.1 + 0.65 * f
                if not t.inReach then tr = tr + 0.2 end
                tr = tr + userTr * (1 - tr)
                if tr > 1 then tr = 1 elseif tr < 0 then tr = 0 end

                local th = math.floor(150 / math.max(dist, 40))
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

                if cfg.names and n <= NAME_NEAR then
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

    local txt = string.format('auto %s [%s] | tracked %d | reach %d | %s',
        cfg.enabled and 'ON' or 'off', cfg.keyName, #targets, reachN,
        listening and 'press a key' or statusText)
    if hudLast ~= txt then
        hud.Text = txt
        hudLast = txt
    end
    hud.Visible = true
end))

-- remap listener -----------------------------------------------------

local function startListen()
    listening = true
    log('press any key to bind...')
end

local function readKeyCode(input)
    if input == nil then return nil end
    if type(input) == 'table' then
        return input.KeyCode
    end
    local ok, v = pcall(function() return input.KeyCode end)
    if ok and v ~= nil then return v end
    return input
end

track(UIS.InputBegan:Connect(function(input)
    local k = readKeyCode(input)
    if k == nil then return end

    if listening then
        listening = false
        if bindKey(k) then
            saveCfg()
            log('bound to ' .. cfg.keyName .. ' - press it to toggle')
        else
            log('could not bind that key')
        end
        return
    end

    if keyMatches(k) then
        toggleAuto()
    end
end))

task.spawn(function()
    local wasDown = false
    while running do
        task.wait(0.05)
        if not listening then
            if keyIsDown() then
                if not wasDown then
                    wasDown = true
                    toggleAuto()
                end
            else
                wasDown = false
            end
        else
            wasDown = false
        end
    end
end)

-- mining --------------------------------------------------------------

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
local holdStart = 0
local lastEnd   = 0
local saveX, saveY = 0, 0
local walkCell  = nil
local walkPos   = nil
local walkMove  = 0
local fpMode    = false
local minedN    = 0

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

local function pickWalkTarget()
    local best, bestD
    local now = tick()
    for i = 1, #targets do
        local t = targets[i]
        if t.top and t.top.Parent and t.dist <= WALK_RANGE then
            local skip = false
            if type(t.cell) == 'number' then
                local last = done[t.cell]
                if last and now - last < REARM_SEC then skip = true end
            end
            if not skip then
                if not bestD or t.dist < bestD then
                    best, bestD = t, t.dist
                end
            end
        end
    end
    return best
end

-- first person: keep nudging the mouse so the ore stays under the crosshair
track(RunService.RenderStepped:Connect(function()
    if not holding or not fpMode or not holdTgt then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    if not vp or not holdTgt.sx then return end
    local dx = holdTgt.sx - vp.X * 0.5
    local dy = holdTgt.sy - vp.Y * 0.5
    if math.abs(dx) > AIM_TOL or math.abs(dy) > AIM_TOL then
        pcall(function()
            mousemoverel(math.floor(dx * 0.5), math.floor(dy * 0.5))
        end)
    end
end))

task.spawn(function()
    while running do
        task.wait(0.1)
        local now  = tick()
        local char = lp.Character
        local root = char and char:FindFirstChild('HumanoidRootPart')
        local hum  = char and char:FindFirstChild('Humanoid')
        fpMode = firstPerson(char)

        if not root or not hum then
            releaseMouse()
            holdTgt = nil
            walking = false
            statusText = 'no character'
        elseif not cfg.enabled then
            releaseMouse()
            holdTgt = nil
            walking = false
            statusText = 'idle'
        elseif holding then
            statusText = fpMode and 'mining (fp)' or 'mining'
            local gone = not holdTgt or not holdTgt.top or holdTgt.top.Parent == nil
            if gone or now - holdStart > HOLD_SEC then
                releaseMouse()
                if holdTgt and type(holdTgt.cell) == 'number' then
                    done[holdTgt.cell] = now
                end
                if gone then minedN = minedN + 1 end
                holdTgt = nil
                lastEnd = now
            end
        else
            local best = nil
            if now - lastEnd >= GAP_SEC then best = pickTarget() end

            if best then
                walking = false
                if fpMode then
                    aimFirstPerson(best)
                    pcall(function() mouse1press() end)
                else
                    local cx, cy = cursorPos()
                    if cx then saveX, saveY = cx, cy else saveX, saveY = best.sx, best.sy end
                    pcall(function() mousemoveabs(math.floor(best.sx), math.floor(best.sy)) end)
                    task.wait(0.05)
                    pcall(function() mouse1press() end)
                end
                holding   = true
                holdStart = now
                holdTgt   = best
                statusText = fpMode and 'mining (fp)' or 'mining'
            else
                local near = pickWalkTarget()
                if near then
                    pcall(function() hum.WalkToPoint = near.pos end)
                    walking = true
                    statusText = 'walking'

                    if walkCell ~= near.cell then
                        walkCell = near.cell
                        walkPos  = root.Position
                        walkMove = now
                    else
                        local moved = walkPos and (root.Position - walkPos).Magnitude or 0
                        if moved > 2 then
                            walkPos  = root.Position
                            walkMove = now
                        elseif now - walkMove > STUCK_SEC then
                            if type(near.cell) == 'number' then done[near.cell] = now end
                            walkCell = nil
                            walkMove = now
                            log('skipped blocked block ' .. tostring(near.cell))
                        end
                    end
                else
                    walking = false
                    statusText = 'no ore'
                end
            end
        end
    end
end)

-- menu ----------------------------------------------------------------

local HAS_UI = type(UI) == 'table' and type(UI.AddTab) == 'function'

local function mkSection(tab, name)
    for _, side in ipairs({ 'Left', 'Right' }) do
        local ok, sec = pcall(function() return tab:Section(name, side) end)
        if ok and sec ~= nil then return sec end
    end
    local ok, sec = pcall(function() return tab:Section(name) end)
    if ok and sec ~= nil then return sec end
    return nil
end

local function mkToggle(sec, label, id, default, apply)
    local cb = function(...)
        local v = nil
        for i = 1, select('#', ...) do
            local x = select(i, ...)
            if type(x) == 'boolean' then v = x break end
        end
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
    return false
end

local function mkSlider(sec, label, id, min, max, default, apply)
    local cb = function(...)
        local v = nil
        for i = 1, select('#', ...) do
            local x = select(i, ...)
            if type(x) == 'number' then v = x break end
        end
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
    return false
end

local function mkButton(sec, label, cb)
    if pcall(function() sec:Button(label, cb) end) then return true end
    if pcall(function() sec:Button(label, label .. '_btn', cb) end) then return true end
    return false
end

if HAS_UI then
    local ok, err = pcall(function()
        UI.AddTab('Mine', function(tab)
            local sec = mkSection(tab, 'Mine')
            if not sec then return end

            mkToggle(sec, 'Auto Mine (walk + mine)', 'ti_enabled', cfg.enabled, function(v)
                cfg.enabled = v
                if not v then
                    releaseMouse()
                    walking = false
                end
            end)

            mkButton(sec, 'Set Key (' .. cfg.keyName .. ')', startListen)

            mkSlider(sec, 'ESP Transparency', 'ti_trans', 0, 100,
                math.floor(cfg.trans * 100), function(v)
                    cfg.trans = math.clamp(v / 100, 0, 1)
                    saveCfg()
                end)

            mkToggle(sec, 'Silver Ore', 'ti_silver', cfg.silver, function(v)
                cfg.silver = v; saveCfg()
            end)
            mkToggle(sec, 'Iron Ore', 'ti_iron', cfg.iron, function(v)
                cfg.iron = v; saveCfg()
            end)
            mkToggle(sec, 'Stone', 'ti_stone', cfg.stone, function(v)
                cfg.stone = v; saveCfg()
            end)
            mkToggle(sec, 'Names', 'ti_names', cfg.names, function(v)
                cfg.names = v; saveCfg()
            end)
            mkButton(sec, 'Stats', function()
                log('mined=' .. minedN .. ' tracked=' .. #targets ..
                    ' reach=' .. reachN .. ' fp=' .. tostring(fpMode) ..
                    ' walking=' .. tostring(walking) ..
                    ' trans=' .. string.format('%.2f', cfg.trans) ..
                    ' key=' .. cfg.keyName .. ' val=' .. tostring(cfg.keyVal))
            end)
            mkButton(sec, 'Clear Ignore List', function()
                done = {}
                log('ignore list cleared')
            end)
        end)
    end)
    if not ok then
        HAS_UI = false
        warn('[TI] menu failed: ' .. tostring(err))
    end
end

-- stop ----------------------------------------------------------------

local function stop()
    running = false
    releaseMouse()
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
    log('stopped')
end

_G[NAME] = { stop = stop, version = VERSION }
log(VERSION .. ' loaded - key ' .. cfg.keyName .. ', trans ' ..
    string.format('%.0f%%', cfg.trans * 100))
