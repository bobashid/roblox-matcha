-- Build and Kill Zombies -> Roller (menu only) - Matcha LuauVM - v17.0
-- place 105011592530400
--
-- EVERYTHING is in the menu. No console command is needed to start, test or
-- stop this script.
--
--   Rollers tab
--     Master
--       Enabled              <- master switch, default OFF. Turn off to stop.
--     Auto
--       Teleport to roller   <- default ON
--       Auto Roll Weapons
--       Auto Roll Blocks
--       Buy matched items    <- default ON
--     Test
--       Test Roll Weapons    <- runs one attempt and reports
--       Test Roll Blocks
--       Test Buy Weapons
--     Engines / Fuels / Wheels / Blocks / Supports / Pushbars / Cosmetic
--       one toggle per item, that is your buy list
--
-- What v17.0 fixes from v16.0:
--   1. A pending item in ItemPlace BLOCKS the roller. The live probe showed
--      'itemplace children 1 item Rocket Turbo', so v16 could sit forever
--      rolling a blocked roller. runOne now checks first: if the pending
--      item is on your buy list it buys it, otherwise it prints and
--      notifies that the roller is blocked.
--   2. No console needed. Master switch stops everything, Test toggles run a
--      single attempt and print the outcome, status prints on load.
--
-- Honest limit, measured this session:
--   injected input has never triggered these prompts. keypress(69) is inert,
--   setrobloxinput(true,69) moves the character but not the prompt,
--   mouse1click and mouse1press on the prompt button did nothing, and the
--   Buy prompt rendered no clickable button at 1.45 studs. v17.0 tries the
--   prompt button with a mouse hold, then E held 1.2s, and proves the
--   result from the labels. If it cannot, it says so instead of lying.

local NAME    = 'RollerMods'
local VERSION = 'v17.0'
local KEY_E   = 69
local LIST_FILE = 'roller-buylist.json'

if _G[NAME] and _G[NAME].stop then
    pcall(_G[NAME].stop)
end
print('[' .. NAME .. '] ' .. VERSION)

local Players = game:GetService('Players')
local ws      = game:GetService('Workspace')
local lp      = Players.LocalPlayer

local alive = true
local built = false
local conn  = nil

local state = {
    enabled    = false,
    autoW      = false,
    autoB      = false,
    teleport   = true,
    buyMatched = true,
    hold       = 1.2,
    want       = {},
}

-- naming / catalog ----------------------------------------------------

local function norm(s)
    return (string.lower(tostring(s)):gsub('[^%w]', ''))
end

local CATS = { 'Engines', 'Fuels', 'Wheels', 'Blocks', 'Supports', 'Pushbars', 'Cosmetic', 'Seats' }

local catalog = nil

local function catalogMap()
    if catalog then return catalog end
    catalog = {}
    local rs = game:GetService('ReplicatedStorage')
    local assets = rs:FindFirstChild('Assets')
    local parts  = assets and assets:FindFirstChild('CarParts')
    if not parts then return catalog end
    for _, cat in ipairs(CATS) do
        local folder = parts:FindFirstChild(cat)
        if folder then
            for _, item in ipairs(folder:GetChildren()) do
                catalog[norm(item.Name)] = item.Name
            end
        end
    end
    return catalog
end

local function saveList()
    local http = game:GetService('HttpService')
    local keys = {}
    for k in pairs(state.want) do keys[#keys + 1] = k end
    table.sort(keys)
    local ok, enc = pcall(function() return http:JSONEncode(keys) end)
    if ok and type(enc) == 'string' then pcall(writefile, LIST_FILE, enc) end
end

local function loadList()
    local ok, data = pcall(readfile, LIST_FILE)
    if not ok or type(data) ~= 'string' or data == '' then return end
    local http = game:GetService('HttpService')
    local ok2, dec = pcall(function() return http:JSONDecode(data) end)
    if not ok2 or type(dec) ~= 'table' then return end
    for _, k in ipairs(dec) do
        if type(k) == 'string' then state.want[k] = true end
    end
end

local function setWant(name, on)
    local key = norm(name)
    if key == '' then return end
    local cat = catalogMap()
    local real = cat[key]
    if not real and on then
        local hits = {}
        for k, v in pairs(cat) do
            if string.find(k, key, 1, true) then hits[#hits + 1] = v end
        end
        if #hits == 1 then
            real, key = hits[1], norm(hits[1])
        elseif #hits > 1 then
            table.sort(hits)
            print('[' .. NAME .. '] ambiguous: ' .. table.concat(hits, ', '))
            return
        else
            print('[' .. NAME .. '] no item matches "' .. tostring(name) .. '"')
            return
        end
    end
    if on then state.want[key] = true else state.want[key] = nil end
    saveList()
end

-- world reads ---------------------------------------------------------

local function getRoot()
    local char = lp.Character
    return char and char:FindFirstChild('HumanoidRootPart')
end

local function myPlot()
    local g = ws:FindFirstChild('Game')
    local l = g and g:FindFirstChild('Lobby')
    local pf = l and l:FindFirstChild('Plots')
    if not pf then return nil end
    for _, p in ipairs(pf:GetChildren()) do
        if p:GetAttribute('OwnerUserId') == lp.UserId then return p end
    end
    return nil
end

local function read(roller, field)
    local info = roller and roller:FindFirstChild('Info')
    local lbl  = info and info:FindFirstChild(field)
    if lbl then return lbl.Text end
    return nil
end

local function pendingModel(roller)
    local ip = roller and roller:FindFirstChild('ItemPlace')
    if not ip then return nil end
    for _, c in ipairs(ip:GetChildren()) do
        local cn = c.ClassName
        if cn == 'Model' or cn == 'MeshPart' or cn == 'Part' then return c.Name end
    end
    return nil
end

-- prompt attempt ------------------------------------------------------

local function promptButton()
    local pg = lp:FindFirstChild('PlayerGui')
    local pp = pg and pg:FindFirstChild('ProximityPrompts')
    if not pp then return nil end
    for _, root in ipairs(pp:GetChildren()) do
        for _, g in ipairs(root:GetDescendants()) do
            local cn = g.ClassName
            if cn == 'TextButton' or cn == 'ImageButton' then
                local p, s = g.AbsolutePosition, g.AbsoluteSize
                if p and s and s.X > 2 and s.Y > 2 then return g, p, s end
            end
        end
    end
    return nil
end

local function pressPrompt(holdSecs)
    local btn, p, s = promptButton()
    if btn then
        pcall(mousemoveabs, p.X + s.X * 0.5, p.Y + s.Y * 0.5)
        task.wait(0.1)
        pcall(mouse1press)
        task.wait(holdSecs)
        pcall(mouse1release)
        return 'mouse'
    end
    pcall(setrobloxinput, true, KEY_E)
    task.wait(holdSecs)
    pcall(setrobloxinput, false, KEY_E)
    return 'key'
end

local function placeOn(part)
    local root = getRoot()
    if not root or not part then return nil end
    local save = root.CFrame
    local p = part.Position
    pcall(function() root.CFrame = CFrame.new(p.X, p.Y + 2, p.Z) end)
    return save
end

local function restore(save)
    if not save then return end
    local root = getRoot()
    if root then pcall(function() root.CFrame = save end) end
end

-- actions -------------------------------------------------------------

local function doRoll(roller, label)
    local part = roller and roller:FindFirstChild('Roll')
    if not part then
        print('[' .. NAME .. '] ' .. label .. ': no Roll part')
        return false
    end
    local before = read(roller, 'ItemName')
    local save = nil
    if state.teleport then
        save = placeOn(part)
        task.wait(0.8)
    end
    local hadButton = promptButton() ~= nil
    local how = pressPrompt(state.hold)
    local changed, item, rar = false, before, nil
    local t0 = tick()
    while alive and (tick() - t0) < 3 do
        task.wait(0.15)
        local now = read(roller, 'ItemName')
        if now and now ~= before and now ~= '???' then
            changed, item, rar = true, now, read(roller, 'Rarity')
            break
        end
    end
    if save then restore(save) end
    task.wait(0.1)
    if changed then
        print('[' .. NAME .. '] ' .. label .. ' ROLLED ' .. item .. ' (' .. tostring(rar) .. ') via ' .. how)
        pcall(notify, label .. ': ' .. item .. ' (' .. tostring(rar) .. ')', 'Rollers', 4)
    else
        print('[' .. NAME .. '] ' .. label .. ' no change via ' .. how
            .. ' | prompt button=' .. tostring(hadButton)
            .. ' | still ' .. tostring(read(roller, 'ItemName')))
        pcall(notify, label .. ': prompt did not trigger (input blocked)', 'Rollers', 4)
    end
    return changed, item, rar
end

local function doBuy(roller, label)
    local ip = roller and roller:FindFirstChild('ItemPlace')
    if not ip then return false end
    local pending = pendingModel(roller)
    if not pending then
        print('[' .. NAME .. '] ' .. label .. ': nothing pending to buy')
        return false
    end
    local save = nil
    if state.teleport then
        save = placeOn(ip)
        task.wait(0.8)
    end
    local how = pressPrompt(state.hold)
    local bought = false
    local t0 = tick()
    while alive and (tick() - t0) < 2.5 do
        task.wait(0.15)
        if pendingModel(roller) ~= pending then bought = true break end
    end
    if save then restore(save) end
    task.wait(0.1)
    print('[' .. NAME .. '] ' .. label .. ' buy ' .. pending .. (bought and ' OK' or ' FAILED') .. ' via ' .. how)
    pcall(notify, label .. ' buy ' .. pending .. (bought and ': ok' or ': failed'), 'Rollers', 4)
    return bought
end

-- loop ---------------------------------------------------------------

local function runOne(roller, autoFlag, label)
    if not autoFlag or not roller then return end
    local pending = pendingModel(roller)
    if pending then
        if state.want[norm(pending)] then
            print('[' .. NAME .. '] ' .. label .. ': pending ' .. pending .. ' is on the buy list -> buying')
            doBuy(roller, label)
        else
            print('[' .. NAME .. '] ' .. label .. ' BLOCKED by pending ' .. pending .. ' (not on buy list)')
            pcall(notify, label .. ': ' .. pending .. ' blocks the roller', 'Rollers', 5)
        end
        return
    end
    local ok, item = doRoll(roller, label)
    if ok and state.buyMatched and state.want[norm(item)] then
        doBuy(roller, label)
    end
end

conn = task.spawn(function()
    while alive do
        if state.enabled and (state.autoW or state.autoB) then
            local p = myPlot()
            local rolls = p and p:FindFirstChild('Rolls')
            if rolls then
                runOne(rolls:FindFirstChild('RollWeapons'), state.autoW, 'weapons')
                runOne(rolls:FindFirstChild('RollBlocks'),  state.autoB, 'blocks')
            end
        end
        task.wait(0.3)
    end
end)

-- status --------------------------------------------------------------

local function status()
    local p = myPlot()
    if not p then
        print('[' .. NAME .. '] no plot carries your OwnerUserId (' .. lp.UserId .. ')')
        return
    end
    local rolls = p:FindFirstChild('Rolls')
    local w = rolls and rolls:FindFirstChild('RollWeapons')
    local b = rolls and rolls:FindFirstChild('RollBlocks')
    print('[' .. NAME .. '] plot ' .. p.Name .. ' | enabled=' .. tostring(state.enabled))
    print('[' .. NAME .. '] weapons ' .. tostring(read(w, 'ItemName')) .. ' (' .. tostring(read(w, 'Rarity')) .. ') pending=' .. tostring(pendingModel(w)))
    print('[' .. NAME .. '] blocks  ' .. tostring(read(b, 'ItemName')) .. ' (' .. tostring(read(b, 'Rarity')) .. ') pending=' .. tostring(pendingModel(b)))
    local n = 0
    for _ in pairs(state.want) do n = n + 1 end
    print('[' .. NAME .. '] buy list ' .. n .. ' item(s)')
end

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
    local sides = { 'Left', 'Right' }
    for i = 1, #sides do
        local ok, sec = pcall(function() return tab:Section(name, sides[i]) end)
        if ok and sec ~= nil then return sec end
    end
    local ok, sec = pcall(function() return tab:Section(name) end)
    if ok and sec ~= nil then return sec end
    warn('[' .. NAME .. '] section ' .. name .. ' failed')
    return nil
end

local function mkToggle(sec, label, id, default, fn)
    local cb = function(...)
        local v = firstBool(...)
        if v ~= nil then fn(v) end
    end
    local tries = {
        function() sec:Toggle(label, id, default, cb) end,
        function() sec:Toggle(id, label, default, cb) end,
        function() sec:Toggle(label, default, cb) end,
    }
    for i = 1, #tries do
        if pcall(tries[i]) then return true end
    end
    warn('[' .. NAME .. '] toggle failed: ' .. label)
    return false
end

local function rollersNow()
    local p = myPlot()
    local rolls = p and p:FindFirstChild('Rolls')
    if not rolls then return nil, nil end
    return rolls:FindFirstChild('RollWeapons'), rolls:FindFirstChild('RollBlocks')
end

local function buildTab(tab)
    if built then return end
    built = true

    local ok, err = pcall(function()
        local secM = mkSection(tab, 'Master')
        if secM then
            mkToggle(secM, 'Enabled', 'rb_on', false, function(v)
                state.enabled = v
                print('[' .. NAME .. '] enabled=' .. tostring(v))
                if v then status() end
            end)
        end

        local secA = mkSection(tab, 'Auto')
        if secA then
            mkToggle(secA, 'Teleport to roller', 'rb_tp', true, function(v)
                state.teleport = v
            end)
            mkToggle(secA, 'Auto Roll Weapons', 'rb_auto_w', false, function(v)
                state.autoW = v
                print('[' .. NAME .. '] weapon auto roll ' .. (v and 'on' or 'off'))
            end)
            mkToggle(secA, 'Auto Roll Blocks', 'rb_auto_b', false, function(v)
                state.autoB = v
                print('[' .. NAME .. '] block auto roll ' .. (v and 'on' or 'off'))
            end)
            mkToggle(secA, 'Buy matched items', 'rb_buym', true, function(v)
                state.buyMatched = v
            end)
        end

        local secT = mkSection(tab, 'Test')
        if secT then
            mkToggle(secT, 'Test Roll Weapons', 'rb_t_w', false, function(v)
                if not v then return end
                task.spawn(function()
                    local w = rollersNow()
                    if not w then print('[' .. NAME .. '] test: no weapon roller') return end
                    doRoll(w, 'test-weapons')
                end)
            end)
            mkToggle(secT, 'Test Roll Blocks', 'rb_t_b', false, function(v)
                if not v then return end
                task.spawn(function()
                    local _, b = rollersNow()
                    if not b then print('[' .. NAME .. '] test: no block roller') return end
                    doRoll(b, 'test-blocks')
                end)
            end)
            mkToggle(secT, 'Test Buy Weapons', 'rb_t_buy', false, function(v)
                if not v then return end
                task.spawn(function()
                    local w = rollersNow()
                    if not w then print('[' .. NAME .. '] test: no weapon roller') return end
                    doBuy(w, 'test-weapons')
                end)
            end)
        end

        local rs = game:GetService('ReplicatedStorage')
        local assets = rs:FindFirstChild('Assets')
        local parts = assets and assets:FindFirstChild('CarParts')
        if not parts then return end

        for _, cat in ipairs(CATS) do
            local folder = parts:FindFirstChild(cat)
            if folder then
                local sec = mkSection(tab, cat)
                if sec then
                    local names = {}
                    for _, item in ipairs(folder:GetChildren()) do
                        names[#names + 1] = item.Name
                    end
                    table.sort(names)
                    for _, itemName in ipairs(names) do
                        local key = norm(itemName)
                        mkToggle(sec, itemName, 'rb_buy_' .. key, state.want[key] == true, function(v)
                            setWant(itemName, v)
                        end)
                    end
                end
            end
        end
    end)

    if not ok then warn('[' .. NAME .. '] build error: ' .. tostring(err)) end
    print('[' .. NAME .. '] tab built')
end

loadList()

if HAS_UI then
    local ok, err = pcall(function()
        UI.AddTab('Rollers', function(tab)
            if built then return end
            pcall(buildTab, tab)
        end)
    end)
    if not ok then
        warn('[' .. NAME .. '] UI.AddTab failed: ' .. tostring(err))
        HAS_UI = false
    end
else
    warn('[' .. NAME .. '] no UI table - menu unavailable')
end

status()

-- stop ---------------------------------------------------------------

local function stop()
    alive = false
    state.enabled = false
    state.autoW = false
    state.autoB = false
    if conn then pcall(task.cancel, conn) end
    conn = nil
    pcall(setrobloxinput, false, KEY_E)
    pcall(mouse1release)
    if HAS_UI then
        pcall(function() UI.RemoveTab('Rollers') end)
    end
    _G[NAME] = nil
    print('[' .. NAME .. '] stopped')
end

_G[NAME] = { stop = stop, status = status, version = VERSION, state = state }
print('[' .. NAME .. '] ' .. VERSION .. ' loaded, menu=' .. tostring(HAS_UI) .. ' - turn Enabled on in the Rollers tab')
