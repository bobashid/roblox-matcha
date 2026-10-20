-- Build and Kill Zombies -> Roller Status (read only) - Matcha LuauVM - v14.0
-- place 105011592530400
--
-- Why this is read-only:
--   Every injected input route was tested against the roller ProximityPrompt
--   in this session and all of them failed:
--     keypress(69)                        -> ok, iskeypressed stays false
--     setrobloxinput(true, 69)            -> W moves 7.12 studs, E no effect
--     mouse1click on the prompt button    -> no change
--     mouse1press + mouse1release 1.2s    -> no change
--     fireproximityprompt                 -> does not exist in this VM
--   The prompt itself is present and on screen (ProximityPrompts has one
--   child, HoldLabel 107x35, at 2.01 studs). The input is discarded before
--   ProximityPromptService sees it, so a script cannot roll.
--
--   The previous version teleported the character on every attempt, which
--   desyncs the controller and is what broke the game. This version does
--   no input, no teleport, no CFrame writes and runs no loop.
--
-- Use:
--   _G.RollerMods.status()  -> prints your plot and both rollers

local NAME    = 'RollerMods'
local VERSION = 'v14.0'

if _G[NAME] and _G[NAME].stop then
    pcall(_G[NAME].stop)
end
print('[' .. NAME .. '] ' .. VERSION)

local Players = game:GetService('Players')
local ws      = game:GetService('Workspace')
local lp      = Players.LocalPlayer

local function plotsFolder()
    local g = ws:FindFirstChild('Game')
    local l = g and g:FindFirstChild('Lobby')
    return l and l:FindFirstChild('Plots')
end

local function myPlot()
    local pf = plotsFolder()
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

local function status()
    local p = myPlot()
    if not p then
        print('[' .. NAME .. '] no plot carries your OwnerUserId (' .. lp.UserId .. ')')
        return
    end
    local rolls = p:FindFirstChild('Rolls')
    local w = rolls and rolls:FindFirstChild('RollWeapons')
    local b = rolls and rolls:FindFirstChild('RollBlocks')
    print('[' .. NAME .. '] plot ' .. p.Name)
    print('[' .. NAME .. '] weapons ' .. tostring(read(w, 'ItemName')) .. ' (' .. tostring(read(w, 'Rarity')) .. ')')
    print('[' .. NAME .. '] blocks  ' .. tostring(read(b, 'ItemName')) .. ' (' .. tostring(read(b, 'Rarity')) .. ')')
end

status()

local function stop()
    _G[NAME] = nil
    print('[' .. NAME .. '] stopped')
end

_G[NAME] = { stop = stop, status = status, version = VERSION }
print('[' .. NAME .. '] ' .. VERSION .. ' loaded - read only, no input, no movement')
