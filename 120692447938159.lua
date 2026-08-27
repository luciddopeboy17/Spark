-- Isaac's Minesweeper – Upgraded & Refined Engine v17.0
-- Features: Fixed Manual Click Spoofing, Tabbed UI, Scrollable Flag Selector with Rarity Badges, Part Pooling Flag Lights & Safety Automation

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Session Enforcement: Terminates background threads from previous executions
_G.IsaacMinesweeperSession = (_G.IsaacMinesweeperSession or 0) + 1
local currentSession = _G.IsaacMinesweeperSession

local player = Players.LocalPlayer
while not player do
task.wait()
player = Players.LocalPlayer
end

local playerGui = player:WaitForChild("PlayerGui")
local tilesFolder = workspace:FindFirstChild("tiles")

-- Configuration & State Variables
local WORK_RADIUS = 5                           -- Default grid radius (5 = 11x11 area)
local MINE_PROTECTION_ENABLED = false           -- Auto-flag nearby mines when enabled
local REMOVE_WRONG_FLAGS = false               -- Unflag safe tiles wrongly flagged
local MINE_PROTECTION_DISTANCE = 25.0          -- Manual distance threshold (studs)
local USE_WORK_RADIUS_FOR_SAFETY = true        -- Sync safety range with active Work Radius area

-- Flag Spoofer State
local SPOOF_FLAG_ENABLED = true
local SPOOF_MANUAL_CLICKS = true                -- Force manual mouse clicks to place spoofed flag skin
local availableFlags = {}                       -- Array of { name = "...", rarity = "..." }
local currentFlagIndex = 1

-- Speed & Timing Tuning Parameters
local FLAG_COOLDOWN = 0.08                     -- Global flag rate-limit delay (seconds)
local TILE_RETRY_COOLDOWN = 0.30               -- Per-tile retry cooldown (seconds)
local SAFETY_CHECK_INTERVAL = 0.05             -- Safety scan loop tick interval

local FLAG_LIGHTS_ENABLED = true
local MINE_COLOR = Color3.fromRGB(255, 65, 65)          -- Unflagged Mine (Red)
local FLAGGED_MINE_COLOR = Color3.fromRGB(255, 170, 0)   -- Flagged Mine (Yellow/Orange)
local WRONG_FLAG_COLOR = Color3.fromRGB(170, 0, 255)    -- Misplaced Flag (Purple)

local destroyed = false
local minimized = false

-- Rate-Limiting & Anti-Cheat Anti-Spam State
local tileCooldowns = {}
local lastGlobalFlagTime = 0

-- Visual Theme
local THEME = {
Background = Color3.fromRGB(15, 16, 20),
Surface = Color3.fromRGB(22, 24, 29),
Surface2 = Color3.fromRGB(28, 30, 37),
Surface3 = Color3.fromRGB(35, 38, 47),
Border = Color3.fromRGB(55, 60, 72),
BorderSoft = Color3.fromRGB(42, 46, 56),
Text = Color3.fromRGB(239, 241, 245),
SecondaryText = Color3.fromRGB(160, 165, 175),
MutedText = Color3.fromRGB(110, 116, 128),
Accent = Color3.fromRGB(88, 135, 235),
AccentHover = Color3.fromRGB(102, 150, 250),
Green = Color3.fromRGB(58, 150, 92),
GreenHover = Color3.fromRGB(72, 172, 108),
Red = Color3.fromRGB(190, 50, 60),
}

-- Rarity Colors for UI Badges
local RARITY_COLORS = {
common = Color3.fromRGB(176, 190, 197),
uncommon = Color3.fromRGB(76, 175, 80),
rare = Color3.fromRGB(33, 150, 243),
epic = Color3.fromRGB(156, 39, 176),
legendary = Color3.fromRGB(255, 152, 0),
mythical = Color3.fromRGB(233, 30, 99),
special = Color3.fromRGB(0, 188, 212),
}

-- Notification Helper
local function sendNotification(text)
pcall(function()
StarterGui:SetCore("SendNotification", {
Title = "Isaac's Minesweeper",
Text = text,
Duration = 2
})
end)
end

-- Cleanup Legacy & Previous GUI Instances
for _, oldName in ipairs({"MinesweeperAssistant", "MinesweeperAssistantRefined", "IsaacMinesweeper"}) do
local oldGui = playerGui:FindFirstChild(oldName)
if oldGui then oldGui:Destroy() end
end

-- REPLICATEDSTORAGE FLAG SCANNER & SPOOFER

local function scanReplicatedFlags()
table.clear(availableFlags)
local flagsFolder = ReplicatedStorage:FindFirstChild("flags")

if flagsFolder then
    for _, rarityFolder in ipairs(flagsFolder:GetChildren()) do
        local rarityName = string.lower(rarityFolder.Name)
        for _, flagObj in ipairs(rarityFolder:GetChildren()) do
            table.insert(availableFlags, {
                name = flagObj.Name,
                rarity = rarityName
            })
        end
    end
end

-- Fallback default if folder scan is empty
if #availableFlags == 0 then
    table.insert(availableFlags, { name = "red", rarity = "common" })
end


end

scanReplicatedFlags()

local function syncPlayerAttributes(color, rarity)
pcall(function()
player:SetAttribute("EquippedFlagColor", color)
player:SetAttribute("EquippedFlag", color)
player:SetAttribute("FlagColor", color)
player:SetAttribute("EquippedFlagRarity", rarity)
player:SetAttribute("FlagRarity", rarity)
end)
end

local function getActiveFlagData()
if SPOOF_FLAG_ENABLED and #availableFlags > 0 then
local flagData = availableFlags[currentFlagIndex]
if flagData then
return flagData.name, flagData.rarity
end
end

-- Auto-detect Player Attributes Fallback
local color = "red"
local rarity = "common"

pcall(function()
    if player:GetAttribute("EquippedFlagColor") or player:GetAttribute("EquippedFlag") or player:GetAttribute("FlagColor") then
        color = player:GetAttribute("EquippedFlagColor") or player:GetAttribute("EquippedFlag") or player:GetAttribute("FlagColor")
    end
    if player:GetAttribute("EquippedFlagRarity") or player:GetAttribute("FlagRarity") then
        rarity = player:GetAttribute("EquippedFlagRarity") or player:GetAttribute("FlagRarity")
    end
end)

return color, rarity


end

-- Update local player attributes whenever flag selection changes
local initialColor, initialRarity = getActiveFlagData()
syncPlayerAttributes(initialColor, initialRarity)

-- MANUAL CLICK REMOTE INTERCEPTOR & SPOOFER HOOK (FIXED)

local function setupRemoteSpooferHooks()
local remotesFolder = ReplicatedStorage:FindFirstChild("remotes")
local flagRemote = remotesFolder and remotesFolder:FindFirstChild("flag")

-- 1. Hook __namecall (Intercepts all client scripts calling :FireServer)
if typeof(hookmetamethod) == "function" then
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        if (method == "FireServer" or method == "fireServer" or method == "InvokeServer" or method == "invokeServer") then
            local isFlagRemote = (flagRemote and self == flagRemote) 
                or (self and typeof(self) == "Instance" and self.Name == "flag" and self.Parent and self.Parent.Name == "remotes")

            if isFlagRemote and SPOOF_FLAG_ENABLED and SPOOF_MANUAL_CLICKS then
                local args = {...}
                -- Check if argument 2 is true (placing a flag)
                if args[2] == true then
                    local spoofColor, spoofRarity = getActiveFlagData()
                    args[3] = spoofColor
                    args[4] = spoofRarity
                    return oldNamecall(self, table.unpack(args))
                end
            end
        end
        return oldNamecall(self, ...)
    end)
end

-- 2. Hook hookfunction on FireServer method directly (Direct call fallback)
if flagRemote and typeof(hookfunction) == "function" then
    local oldFireServer
    oldFireServer = hookfunction(flagRemote.FireServer, function(self, tile, state, color, rarity, options)
        if SPOOF_FLAG_ENABLED and SPOOF_MANUAL_CLICKS and state == true then
            local spoofColor, spoofRarity = getActiveFlagData()
            return oldFireServer(self, tile, state, spoofColor, spoofRarity, options or {})
        end
        return oldFireServer(self, tile, state, color, rarity, options)
    end)
end


end

setupRemoteSpooferHooks()

-- TILE & FLAG HELPER FUNCTIONS

local function hasPhysicalFlag(tile)
if not tile then return false end
for _, child in ipairs(tile:GetChildren()) do
local nameLower = string.lower(child.Name)
if string.find(nameLower, "flag") then
return true
end
end
return false
end

local function isTileFlagged(tile)
if not tile then return false end
local attrFlagged = tile:GetAttribute("flagged") == true
return attrFlagged or hasPhysicalFlag(tile)
end

-- ANTI-CHEAT SAFE REMOTE DISPATCHER

local function getFlagRemote()
local remotesFolder = ReplicatedStorage:FindFirstChild("remotes")
return remotesFolder and remotesFolder:FindFirstChild("flag")
end

local function fireFlagRemoteVerified(tile, targetFlagState, callback)
if not tile or destroyed or _G.IsaacMinesweeperSession ~= currentSession then return end

local now = os.clock()
if (now - lastGlobalFlagTime) < FLAG_COOLDOWN then
    if callback then callback(false) end
    return
end

local isCurrentlyFlagged = isTileFlagged(tile)
if isCurrentlyFlagged == targetFlagState then
    if callback then callback(true) end
    return
end

lastGlobalFlagTime = now

task.spawn(function()
    local remote = getFlagRemote()
    if not remote then return end

    local color, rarity = getActiveFlagData()
    syncPlayerAttributes(color, rarity)

    pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(tile, targetFlagState, color, rarity, {})
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(tile, targetFlagState, color, rarity, {})
        end
    end)

    task.wait(0.04)

    local verifiedState = isTileFlagged(tile)
    local success = (verifiedState == targetFlagState)

    if callback then
        callback(success)
    end
end)


end

-- HIGH-PERFORMANCE PART POOL FOR FLAG LIGHTS

local highlightPool = {}
local activeHighlights = {}

local poolFolder = workspace:FindFirstChild("IsaacMinesweeperHighlights")
if not poolFolder then
poolFolder = Instance.new("Folder")
poolFolder.Name = "IsaacMinesweeperHighlights"
poolFolder.Parent = workspace
end

local function getHighlightPart()
local part = table.remove(highlightPool)
if not part or not part.Parent then
part = Instance.new("Part")
part.Name = "TileHighlight"
part.Anchored = true
part.CanCollide = false
part.CanQuery = false
part.CanTouch = false
part.CastShadow = false
part.Material = Enum.Material.SmoothPlastic
part.Transparency = 0.35
end
part.Parent = poolFolder
return part
end

local function clearHighlights()
for _, part in ipairs(activeHighlights) do
if part and part.Parent then
part.Transparency = 1
part.Position = Vector3.new(0, -5000, 0)
table.insert(highlightPool, part)
end
end
table.clear(activeHighlights)
end

local function updateFlagLights()
clearHighlights()
if not FLAG_LIGHTS_ENABLED or not tilesFolder or destroyed then return end

local char = player.Character
local root = char and char:FindFirstChild("HumanoidRootPart")
if not root then return end

local position = root.Position
local halfSide = WORK_RADIUS * 5.0
local tiles = tilesFolder:GetChildren()

for i = 1, #tiles do
    if destroyed or _G.IsaacMinesweeperSession ~= currentSession then return end
    local tile = tiles[i]
    if tile:IsA("BasePart") then
        local dx = tile.Position.X - position.X
        local dz = tile.Position.Z - position.Z

        if math.abs(dx) <= halfSide and math.abs(dz) <= halfSide then
            local isMine = tile:GetAttribute("mine") == true
            local isFlagged = isTileFlagged(tile)

            local targetColor = nil
            if isMine and isFlagged then
                targetColor = FLAGGED_MINE_COLOR
            elseif isMine then
                targetColor = MINE_COLOR
            elseif isFlagged then
                targetColor = WRONG_FLAG_COLOR
            end

            if targetColor then
                local part = getHighlightPart()
                part.Size = Vector3.new(tile.Size.X, 0.12, tile.Size.Z)
                part.Position = tile.Position + Vector3.new(0, tile.Size.Y / 2 + 0.06, 0)
                part.Color = targetColor
                part.Transparency = 0.35
                table.insert(activeHighlights, part)
            end
        end
    end
end


end

-- SAFETY ENGINE LOOP

local function runSafetyChecks()
if not MINE_PROTECTION_ENABLED and not REMOVE_WRONG_FLAGS then return end
if not tilesFolder then return end

local char = player.Character
local root = char and char:FindFirstChild("HumanoidRootPart")
if not root then return end

local playerPos = root.Position
local now = os.clock()

local effectiveDist = USE_WORK_RADIUS_FOR_SAFETY and (WORK_RADIUS * 5.0) or MINE_PROTECTION_DISTANCE
local maxDistSq = effectiveDist * effectiveDist

local tiles = tilesFolder:GetChildren()
for i = 1, #tiles do
    if destroyed or _G.IsaacMinesweeperSession ~= currentSession then return end
    local tile = tiles[i]
    if tile:IsA("BasePart") then
        local dx = playerPos.X - tile.Position.X
        local dz = playerPos.Z - tile.Position.Z
        local distSq = dx * dx + dz * dz

        if distSq <= maxDistSq then
            local isMine = tile:GetAttribute("mine") == true
            local isFlagged = isTileFlagged(tile)

            if MINE_PROTECTION_ENABLED and isMine and not isFlagged then
                local lastTime = tileCooldowns[tile] or 0
                if (now - lastTime) > TILE_RETRY_COOLDOWN then
                    tileCooldowns[tile] = now
                    fireFlagRemoteVerified(tile, true, function(success)
                        if success then
                            sendNotification("Safety: Auto-flagged nearby mine!")
                        end
                    end)
                end
            end

            if REMOVE_WRONG_FLAGS and isFlagged and not isMine then
                local lastTime = tileCooldowns[tile] or 0
                if (now - lastTime) > TILE_RETRY_COOLDOWN then
                    tileCooldowns[tile] = now
                    fireFlagRemoteVerified(tile, false, function(success)
                        if success then
                            sendNotification("Safety: Removed misplaced flag!")
                        end
                    end)
                end
            end
        end
    end
end


end

-- MODERN UI UTILITIES

local function round(instance, radius)
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, radius)
corner.Parent = instance
return corner
end

local function stroke(instance, color, thickness, transparency)
local outline = Instance.new("UIStroke")
outline.Color = color
outline.Thickness = thickness
outline.Transparency = transparency or 0
outline.Parent = instance
return outline
end

local function createLabel(parent, text, size, position, textSize)
local label = Instance.new("TextLabel")
label.Size = size
label.Position = position
label.BackgroundTransparency = 1
label.Text = text
label.TextColor3 = THEME.Text
label.TextSize = textSize or 12
label.Font = Enum.Font.Gotham
label.TextXAlignment = Enum.TextXAlignment.Left
label.TextYAlignment = Enum.TextYAlignment.Center
label.Parent = parent
return label
end

local function createButton(parent, text, size, position)
local btn = Instance.new("TextButton")
btn.Size = size
btn.Position = position
btn.BackgroundColor3 = THEME.Surface3
btn.BorderSizePixel = 0
btn.Text = text
btn.TextColor3 = THEME.Text
btn.TextSize = 12
btn.Font = Enum.Font.GothamBold
btn.AutoButtonColor = false
btn.Parent = parent
round(btn, 8)

local outline = stroke(btn, THEME.Border, 1, 0.2)

btn.MouseEnter:Connect(function()
    if btn:GetAttribute("IsToggle") then
        btn.BackgroundColor3 = btn:GetAttribute("Enabled") and THEME.GreenHover or THEME.Surface2
    else
        btn.BackgroundColor3 = Color3.fromRGB(45, 50, 62)
    end
    outline.Transparency = 0
end)

btn.MouseLeave:Connect(function()
    if btn:GetAttribute("IsToggle") then
        btn.BackgroundColor3 = btn:GetAttribute("Enabled") and THEME.Green or THEME.Surface3
    else
        btn.BackgroundColor3 = THEME.Surface3
    end
    outline.Transparency = 0.2
end)

return btn


end

local function setToggleState(btn, enabled, prefix)
btn:SetAttribute("IsToggle", true)
btn:SetAttribute("Enabled", enabled)
btn.Text = (prefix or "") .. (enabled and "ON" or "OFF")
btn.BackgroundColor3 = enabled and THEME.Green or THEME.Surface3
end

local function createCard(parent, titleText, height, y)
local card = Instance.new("Frame")
card.Size = UDim2.new(1, 0, 0, height)
card.Position = UDim2.new(0, 0, 0, y)
card.BackgroundColor3 = THEME.Surface
card.BorderSizePixel = 0
card.Parent = parent
round(card, 12)
stroke(card, THEME.Border, 1, 0.3)

local title = createLabel(card, titleText, UDim2.new(1, -24, 0, 22), UDim2.new(0, 12, 0, 8), 11)
title.TextColor3 = THEME.SecondaryText
title.Font = Enum.Font.GothamBold
return card


end

-- MAIN INTERFACE CONSTRUCTION

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "IsaacMinesweeper"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 480, 0, 560)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.BackgroundColor3 = THEME.Background
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui
round(mainFrame, 16)
stroke(mainFrame, THEME.Border, 1, 0.1)

-- Header Bar
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 60)
header.BackgroundColor3 = THEME.Surface
header.BorderSizePixel = 0
header.Active = true
header.Parent = mainFrame

local headerAccent = Instance.new("Frame")
headerAccent.Size = UDim2.new(1, -24, 0, 2)
headerAccent.Position = UDim2.new(0, 12, 1, -2)
headerAccent.BackgroundColor3 = THEME.Accent
headerAccent.BorderSizePixel = 0
headerAccent.Parent = header
round(headerAccent, 2)

local logo = Instance.new("Frame")
logo.Size = UDim2.new(0, 34, 0, 34)
logo.Position = UDim2.new(0, 12, 0, 13)
logo.BackgroundColor3 = THEME.Accent
logo.BorderSizePixel = 0
logo.Parent = header
round(logo, 9)

local logoTxt = createLabel(logo, "IM", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), 12)
logoTxt.TextColor3 = Color3.fromRGB(255, 255, 255)
logoTxt.Font = Enum.Font.GothamBlack
logoTxt.TextXAlignment = Enum.TextXAlignment.Center

local titleTxt = createLabel(header, "ISAAC'S MINESWEEPER", UDim2.new(0, 220, 0, 18), UDim2.new(0, 54, 0, 12), 13)
titleTxt.Font = Enum.Font.GothamBold

local subtitleTxt = createLabel(header, "WORK RADIUS • SAFETY • FLAG LIGHTS ENGINE", UDim2.new(0, 260, 0, 14), UDim2.new(0, 54, 0, 30), 8)
subtitleTxt.TextColor3 = THEME.MutedText
subtitleTxt.Font = Enum.Font.GothamBold

local statusPill = Instance.new("Frame")
statusPill.Size = UDim2.new(0, 68, 0, 22)
statusPill.Position = UDim2.new(1, -140, 0, 18)
statusPill.BackgroundColor3 = Color3.fromRGB(28, 67, 46)
statusPill.BorderSizePixel = 0
statusPill.Parent = header
round(statusPill, 11)

local statusDot = Instance.new("Frame")
statusDot.Size = UDim2.new(0, 6, 0, 6)
statusDot.Position = UDim2.new(0, 8, 0.5, -3)
statusDot.BackgroundColor3 = THEME.Green
statusDot.BorderSizePixel = 0
statusDot.Parent = statusPill
round(statusDot, 6)

local statusTxt = createLabel(statusPill, "ONLINE", UDim2.new(0, 46, 1, 0), UDim2.new(0, 18, 0, 0), 8)
statusTxt.TextColor3 = Color3.fromRGB(173, 225, 193)
statusTxt.Font = Enum.Font.GothamBold

local minimizeBtn = createButton(header, "−", UDim2.new(0, 26, 0, 26), UDim2.new(1, -62, 0, 16))
local closeBtn = createButton(header, "×", UDim2.new(0, 26, 0, 26), UDim2.new(1, -32, 0, 16))
closeBtn.BackgroundColor3 = THEME.Red

-- NAVIGATION TAB BAR

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -24, 0, 36)
tabBar.Position = UDim2.new(0, 12, 0, 68)
tabBar.BackgroundColor3 = THEME.Surface
tabBar.BorderSizePixel = 0
tabBar.Parent = mainFrame
round(tabBar, 10)
stroke(tabBar, THEME.BorderSoft, 1, 0.2)

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
tabLayout.Padding = UDim.new(0, 4)
tabLayout.Parent = tabBar

local tabButtons = {}
local tabPages = {}
local tabNames = { "Main", "Safety", "FlagLights", "FlagSpoofer" }

local pagesContainer = Instance.new("Frame")
pagesContainer.Size = UDim2.new(1, -24, 1, -120)
pagesContainer.Position = UDim2.new(0, 12, 0, 110)
pagesContainer.BackgroundTransparency = 1
pagesContainer.Parent = mainFrame

for _, tabName in ipairs(tabNames) do
local displayName = tabName == "FlagLights" and "Flag Lights" or (tabName == "FlagSpoofer" and "Flag Spoofer" or tabName)
local btn = createButton(tabBar, displayName, UDim2.new(0, 106, 0, 28), UDim2.new())
btn.Font = Enum.Font.GothamBold
btn.TextSize = 10
tabButtons[tabName] = btn

local page = Instance.new("ScrollingFrame")
page.Name = tabName .. "Page"
page.Size = UDim2.new(1, 0, 1, 0)
page.BackgroundTransparency = 1
page.BorderSizePixel = 0
page.ScrollBarThickness = 4
page.ScrollBarImageColor3 = THEME.Accent
page.CanvasSize = UDim2.new(0, 0, 0, 480)
page.Visible = false
page.Parent = pagesContainer
tabPages[tabName] = page


end

local function switchTab(targetName)
for name, page in pairs(tabPages) do
page.Visible = (name == targetName)
end
for name, btn in pairs(tabButtons) do
if name == targetName then
btn.BackgroundColor3 = THEME.Accent
btn.TextColor3 = Color3.fromRGB(255, 255, 255)
else
btn.BackgroundColor3 = THEME.Surface3
btn.TextColor3 = THEME.Text
end
end
end

for name, btn in pairs(tabButtons) do
btn.MouseButton1Click:Connect(function()
switchTab(name)
end)
end

switchTab("Main")

-- TAB 1: MAIN / WORK RADIUS PAGE

local mainPage = tabPages["Main"]
local radiusCard = createCard(mainPage, "WORK RADIUS & SCAN AREA", 140, 0)

local radiusValue = createLabel(radiusCard, "11 × 11", UDim2.new(0, 120, 0, 24), UDim2.new(0, 12, 0, 36), 16)
radiusValue.Font = Enum.Font.GothamBold

local radiusDetails = createLabel(radiusCard, "Scan range: 25 tiles (Area: 121 cells)", UDim2.new(1, -24, 0, 16), UDim2.new(0, 12, 0, 60), 9)
radiusDetails.TextColor3 = THEME.MutedText

local radiusSlider = Instance.new("Frame")
radiusSlider.Size = UDim2.new(1, -24, 0, 8)
radiusSlider.Position = UDim2.new(0, 12, 0, 88)
radiusSlider.BackgroundColor3 = THEME.Surface3
radiusSlider.BorderSizePixel = 0
radiusSlider.Active = true
radiusSlider.Parent = radiusCard
round(radiusSlider, 4)

local radiusFill = Instance.new("Frame")
radiusFill.Size = UDim2.new(0.2, 0, 1, 0)
radiusFill.BackgroundColor3 = THEME.Accent
radiusFill.BorderSizePixel = 0
radiusFill.Parent = radiusSlider
round(radiusFill, 4)

local radiusKnob = Instance.new("Frame")
radiusKnob.Size = UDim2.new(0, 16, 0, 16)
radiusKnob.AnchorPoint = Vector2.new(0.5, 0.5)
radiusKnob.Position = UDim2.new(0.2, 0, 0.5, 0)
radiusKnob.BackgroundColor3 = Color3.fromRGB(250, 250, 255)
radiusKnob.BorderSizePixel = 0
radiusKnob.Parent = radiusSlider
round(radiusKnob, 8)
stroke(radiusKnob, THEME.Accent, 1)

-- TAB 2: SAFETY & AUTOMATED PROTECTION PAGE

local safetyPage = tabPages["Safety"]
local safetyCard = createCard(safetyPage, "SAFETY & AUTOMATED PROTECTION", 280, 0)

local mineProtectionLabel = createLabel(safetyCard, "Mine Protection Auto-Flag", UDim2.new(0, 200, 0, 20), UDim2.new(0, 12, 0, 36), 12)
mineProtectionLabel.Font = Enum.Font.GothamBold

local mineProtectionSub = createLabel(safetyCard, "Auto-flags unflagged mines when entering safety distance", UDim2.new(0, 260, 0, 14), UDim2.new(0, 12, 0, 54), 9)
mineProtectionSub.TextColor3 = THEME.MutedText

local mineProtectionBtn = createButton(safetyCard, "OFF", UDim2.new(0, 90, 0, 28), UDim2.new(1, -102, 0, 36))
setToggleState(mineProtectionBtn, false, "")

local wrongFlagsLabel = createLabel(safetyCard, "Remove Misplaced Flags", UDim2.new(0, 200, 0, 20), UDim2.new(0, 12, 0, 78), 12)
wrongFlagsLabel.Font = Enum.Font.GothamBold

local wrongFlagsSub = createLabel(safetyCard, "Automatically unflags safe tiles mistakenly flagged", UDim2.new(0, 260, 0, 14), UDim2.new(0, 12, 0, 96), 9)
wrongFlagsSub.TextColor3 = THEME.MutedText

local wrongFlagsBtn = createButton(safetyCard, "OFF", UDim2.new(0, 90, 0, 28), UDim2.new(1, -102, 0, 78))
setToggleState(wrongFlagsBtn, false, "")

local syncWorkRadiusBtn = createButton(safetyCard, "Use Work Radius Range: ON", UDim2.new(1, -24, 0, 26), UDim2.new(0, 12, 0, 118))
setToggleState(syncWorkRadiusBtn, true, "Use Work Radius Range: ")

-- Placement Speed Control
local speedLabel = createLabel(safetyCard, "Flag Placement Delay:", UDim2.new(0, 180, 0, 18), UDim2.new(0, 12, 0, 154), 10)
speedLabel.TextColor3 = THEME.SecondaryText

local speedValue = createLabel(safetyCard, "0.08s (Fast)", UDim2.new(0, 100, 0, 18), UDim2.new(1, -112, 0, 154), 11)
speedValue.Font = Enum.Font.GothamBold
speedValue.TextXAlignment = Enum.TextXAlignment.Right

local speedSlider = Instance.new("Frame")
speedSlider.Size = UDim2.new(1, -24, 0, 8)
speedSlider.Position = UDim2.new(0, 12, 0, 176)
speedSlider.BackgroundColor3 = THEME.Surface3
speedSlider.BorderSizePixel = 0
speedSlider.Active = true
speedSlider.Parent = safetyCard
round(speedSlider, 4)

local speedFill = Instance.new("Frame")
speedFill.Size = UDim2.new(0.18, 0, 1, 0)
speedFill.BackgroundColor3 = THEME.Accent
speedFill.BorderSizePixel = 0
speedFill.Parent = speedSlider
round(speedFill, 4)

local speedKnob = Instance.new("Frame")
speedKnob.Size = UDim2.new(0, 16, 0, 16)
speedKnob.AnchorPoint = Vector2.new(0.5, 0.5)
speedKnob.Position = UDim2.new(0.18, 0, 0.5, 0)
speedKnob.BackgroundColor3 = Color3.fromRGB(250, 250, 255)
speedKnob.BorderSizePixel = 0
speedKnob.Parent = speedSlider
round(speedKnob, 8)
stroke(speedKnob, THEME.Accent, 1)

-- Distance Control
local distLabel = createLabel(safetyCard, "Manual Distance Threshold:", UDim2.new(0, 180, 0, 18), UDim2.new(0, 12, 0, 198), 10)
distLabel.TextColor3 = THEME.SecondaryText

local distValue = createLabel(safetyCard, "25.0 studs", UDim2.new(0, 80, 0, 18), UDim2.new(1, -92, 0, 198), 11)
distValue.Font = Enum.Font.GothamBold
distValue.TextXAlignment = Enum.TextXAlignment.Right

local distSlider = Instance.new("Frame")
distSlider.Size = UDim2.new(1, -24, 0, 8)
distSlider.Position = UDim2.new(0, 12, 0, 220)
distSlider.BackgroundColor3 = THEME.Surface3
distSlider.BorderSizePixel = 0
distSlider.Active = true
distSlider.Parent = safetyCard
round(distSlider, 4)

local distFill = Instance.new("Frame")
distFill.Size = UDim2.new(0.22, 0, 1, 0)
distFill.BackgroundColor3 = THEME.Accent
distFill.BorderSizePixel = 0
distFill.Parent = distSlider
round(distFill, 4)

local distKnob = Instance.new("Frame")
distKnob.Size = UDim2.new(0, 16, 0, 16)
distKnob.AnchorPoint = Vector2.new(0.5, 0.5)
distKnob.Position = UDim2.new(0.22, 0, 0.5, 0)
distKnob.BackgroundColor3 = Color3.fromRGB(250, 250, 255)
distKnob.BorderSizePixel = 0
distKnob.Parent = distSlider
round(distKnob, 8)
stroke(distKnob, THEME.Accent, 1)

-- TAB 3: FLAG LIGHTS PAGE

local lightsPage = tabPages["FlagLights"]
local lightsCard = createCard(lightsPage, "FLAG LIGHTS & VISUAL HIGHLIGHTS", 220, 0)

local lightsToggleBtn = createButton(lightsCard, "Flag Lights: ON", UDim2.new(1, -24, 0, 32), UDim2.new(0, 12, 0, 36))
setToggleState(lightsToggleBtn, true, "Flag Lights: ")

local function createColorRow(parent, labelText, defaultColor, y)
local lbl = createLabel(parent, labelText, UDim2.new(0, 180, 0, 24), UDim2.new(0, 12, 0, y), 11)
lbl.TextColor3 = THEME.SecondaryText

local swatch = Instance.new("Frame")
swatch.Size = UDim2.new(0, 24, 0, 24)
swatch.Position = UDim2.new(1, -150, 0, y)
swatch.BackgroundColor3 = defaultColor
swatch.BorderSizePixel = 0
swatch.Parent = parent
round(swatch, 6)
stroke(swatch, THEME.Border, 1)

local cycleBtn = createButton(parent, "Cycle Color", UDim2.new(0, 110, 0, 26), UDim2.new(1, -122, 0, y - 1))
return swatch, cycleBtn


end

local mineSwatch, mineCycleBtn = createColorRow(lightsCard, "Unflagged Mine Highlight", MINE_COLOR, 80)
local flaggedSwatch, flaggedCycleBtn = createColorRow(lightsCard, "Flagged Mine Highlight", FLAGGED_MINE_COLOR, 118)
local wrongSwatch, wrongCycleBtn = createColorRow(lightsCard, "Wrong Flag Highlight", WRONG_FLAG_COLOR, 156)

local colorPalette = {
Color3.fromRGB(255, 65, 65),   -- Red
Color3.fromRGB(255, 170, 0),  -- Gold/Orange
Color3.fromRGB(170, 0, 255),  -- Purple
Color3.fromRGB(0, 200, 255),  -- Cyan
Color3.fromRGB(50, 220, 100),  -- Lime
Color3.fromRGB(255, 100, 180), -- Pink
}

local function cycleColor(current)
for i, col in ipairs(colorPalette) do
if col == current then
return colorPalette[(i % #colorPalette) + 1]
end
end
return colorPalette[1]
end

-- TAB 4: FLAG SPOOFER & SCROLLABLE BROWSER

local spooferPage = tabPages["FlagSpoofer"]
local spoofCard = createCard(spooferPage, "FLAG SPOOFER & MANUAL MOUSE CLICK OVERRIDE", 380, 0)

local spoofToggleBtn = createButton(spoofCard, "Spoof Flag Skin: ON", UDim2.new(0, 210, 0, 30), UDim2.new(0, 12, 0, 34))
setToggleState(spoofToggleBtn, true, "Spoof Flag Skin: ")

local spoofClicksBtn = createButton(spoofCard, "Spoof Manual Clicks: ON", UDim2.new(0, 210, 0, 30), UDim2.new(1, -222, 0, 34))
setToggleState(spoofClicksBtn, true, "Spoof Manual Clicks: ")

local activeSkinLabel = createLabel(spoofCard, "Active Skin: Loading...", UDim2.new(1, -24, 0, 20), UDim2.new(0, 12, 0, 72), 11)
activeSkinLabel.Font = Enum.Font.GothamBold

-- Scrollable Flag Skin Selection Grid
local flagScrollFrame = Instance.new("ScrollingFrame")
flagScrollFrame.Size = UDim2.new(1, -24, 0, 260)
flagScrollFrame.Position = UDim2.new(0, 12, 0, 98)
flagScrollFrame.BackgroundColor3 = THEME.Surface2
flagScrollFrame.BorderSizePixel = 0
flagScrollFrame.ScrollBarThickness = 5
flagScrollFrame.ScrollBarImageColor3 = THEME.Accent
flagScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
flagScrollFrame.Parent = spoofCard
round(flagScrollFrame, 10)
stroke(flagScrollFrame, THEME.BorderSoft, 1)

local flagGridLayout = Instance.new("UIGridLayout")
flagGridLayout.CellSize = UDim2.new(0, 134, 0, 48)
flagGridLayout.CellPadding = UDim2.new(0, 8, 0, 8)
flagGridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
flagGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
flagGridLayout.Parent = flagScrollFrame

local flagGridPadding = Instance.new("UIPadding")
flagGridPadding.PaddingLeft = UDim.new(0, 8)
flagGridPadding.PaddingTop = UDim.new(0, 8)
flagGridPadding.PaddingRight = UDim.new(0, 8)
flagGridPadding.PaddingBottom = UDim.new(0, 8)
flagGridPadding.Parent = flagScrollFrame

local flagButtons = {}

local function updateFlagDisplayVisual()
if #availableFlags == 0 then
activeSkinLabel.Text = "Active Skin: None Discovered"
return
end

local flag = availableFlags[currentFlagIndex]
if flag then
    activeSkinLabel.Text = string.format("Active Skin: %s (%s)", string.upper(flag.name), string.upper(flag.rarity))
    syncPlayerAttributes(flag.name, flag.rarity)
end

for index, btnData in ipairs(flagButtons) do
    local btn = btnData.button
    local strokeObj = btnData.stroke
    if index == currentFlagIndex then
        btn.BackgroundColor3 = Color3.fromRGB(38, 55, 85)
        strokeObj.Color = THEME.Accent
        strokeObj.Transparency = 0
    else
        btn.BackgroundColor3 = THEME.Surface3
        strokeObj.Color = THEME.Border
        strokeObj.Transparency = 0.4
    end
end


end

local function populateFlagGrid()
for _, child in ipairs(flagScrollFrame:GetChildren()) do
if child:IsA("TextButton") then child:Destroy() end
end
table.clear(flagButtons)

for index, flagData in ipairs(availableFlags) do
    local cardBtn = Instance.new("TextButton")
    cardBtn.Size = UDim2.new(0, 134, 0, 48)
    cardBtn.BackgroundColor3 = THEME.Surface3
    cardBtn.BorderSizePixel = 0
    cardBtn.Text = ""
    cardBtn.AutoButtonColor = false
    cardBtn.Parent = flagScrollFrame
    round(cardBtn, 8)

    local btnStroke = stroke(cardBtn, THEME.Border, 1, 0.4)

    local nameLbl = createLabel(cardBtn, flagData.name, UDim2.new(1, -12, 0, 20), UDim2.new(0, 8, 0, 6), 11)
    nameLbl.Font = Enum.Font.GothamBold

    local rarityColor = RARITY_COLORS[string.lower(flagData.rarity)] or THEME.SecondaryText
    local rarityBadge = Instance.new("Frame")
    rarityBadge.Size = UDim2.new(0, 64, 0, 14)
    rarityBadge.Position = UDim2.new(0, 8, 0, 26)
    rarityBadge.BackgroundColor3 = rarityColor
    rarityBadge.BackgroundTransparency = 0.8
    rarityBadge.BorderSizePixel = 0
    rarityBadge.Parent = cardBtn
    round(rarityBadge, 4)

    local rarityTxt = createLabel(rarityBadge, string.upper(flagData.rarity), UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), 8)
    rarityTxt.TextColor3 = rarityColor
    rarityTxt.Font = Enum.Font.GothamBold
    rarityTxt.TextXAlignment = Enum.TextXAlignment.Center

    table.insert(flagButtons, { button = cardBtn, stroke = btnStroke })

    cardBtn.MouseButton1Click:Connect(function()
        currentFlagIndex = index
        updateFlagDisplayVisual()
        sendNotification("Equipped Skin: " .. tostring(flagData.name))
    end)
end

local rows = math.ceil(#availableFlags / 3)
flagScrollFrame.CanvasSize = UDim2.new(0, 0, 0, rows * 56 + 16)


end

populateFlagGrid()
updateFlagDisplayVisual()

-- UI EVENT CONNECTIONS

-- Dragging Main Panel
local dragging, dragStart, dragPos
header.InputBegan:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1 then
dragging = true
dragStart = input.Position
dragPos = mainFrame.Position
end
end)

UserInputService.InputChanged:Connect(function(input)
if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
local delta = input.Position - dragStart
mainFrame.Position = UDim2.new(dragPos.X.Scale, dragPos.X.Offset + delta.X, dragPos.Y.Scale, dragPos.Y.Offset + delta.Y)
end
end)

UserInputService.InputEnded:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)

-- Work Radius Slider
local radiusDragging = false
local function updateRadiusVisual()
local pct = math.clamp((WORK_RADIUS - 1) / 24, 0, 1)
radiusFill.Size = UDim2.new(pct, 0, 1, 0)
radiusKnob.Position = UDim2.new(pct, 0, 0.5, 0)

local side = WORK_RADIUS * 2 + 1
radiusValue.Text = string.format("%d × %d", side, side)
radiusDetails.Text = string.format("Scan range: %d tiles (Area: %d cells)", WORK_RADIUS * 5, side * side)


end

local function setRadiusFromInput(x)
local startX = radiusSlider.AbsolutePosition.X
local width = radiusSlider.AbsoluteSize.X
if width > 0 then
local pct = math.clamp((x - startX) / width, 0, 1)
WORK_RADIUS = math.round(1 + pct * 24)
updateRadiusVisual()
end
end

radiusSlider.InputBegan:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1 then
radiusDragging = true
setRadiusFromInput(input.Position.X)
end
end)
radiusKnob.InputBegan:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1 then radiusDragging = true end
end)

-- Flag Speed Slider
local speedDragging = false
local function updateSpeedVisual()
local pct = math.clamp((FLAG_COOLDOWN - 0.03) / 0.27, 0, 1)
speedFill.Size = UDim2.new(pct, 0, 1, 0)
speedKnob.Position = UDim2.new(pct, 0, 0.5, 0)

local labelMode = FLAG_COOLDOWN <= 0.05 and "Ultra-Fast" or (FLAG_COOLDOWN <= 0.12 and "Fast" or "Safe")
speedValue.Text = string.format("%.2fs (%s)", FLAG_COOLDOWN, labelMode)


end

local function setSpeedFromInput(x)
local startX = speedSlider.AbsolutePosition.X
local width = speedSlider.AbsoluteSize.X
if width > 0 then
local pct = math.clamp((x - startX) / width, 0, 1)
FLAG_COOLDOWN = 0.03 + pct * 0.27
updateSpeedVisual()
end
end

speedSlider.InputBegan:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1 then
speedDragging = true
setSpeedFromInput(input.Position.X)
end
end)
speedKnob.InputBegan:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1 then speedDragging = true end
end)

-- Manual Safety Distance Slider
local distDragging = false
local function updateDistVisual()
local pct = math.clamp((MINE_PROTECTION_DISTANCE - 3.0) / 97.0, 0, 1)
distFill.Size = UDim2.new(pct, 0, 1, 0)
distKnob.Position = UDim2.new(pct, 0, 0.5, 0)
distValue.Text = string.format("%.1f studs", MINE_PROTECTION_DISTANCE)
end

local function setDistFromInput(x)
local startX = distSlider.AbsolutePosition.X
local width = distSlider.AbsoluteSize.X
if width > 0 then
local pct = math.clamp((x - startX) / width, 0, 1)
MINE_PROTECTION_DISTANCE = 3.0 + pct * 97.0
updateDistVisual()
end
end

distSlider.InputBegan:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1 then
distDragging = true
setDistFromInput(input.Position.X)
end
end)
distKnob.InputBegan:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1 then distDragging = true end
end)

UserInputService.InputChanged:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseMovement then
if radiusDragging then setRadiusFromInput(input.Position.X) end
if speedDragging then setSpeedFromInput(input.Position.X) end
if distDragging then setDistFromInput(input.Position.X) end
end
end)

UserInputService.InputEnded:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1 then
radiusDragging = false
speedDragging = false
distDragging = false
end
end)

-- Toggles
mineProtectionBtn.MouseButton1Click:Connect(function()
MINE_PROTECTION_ENABLED = not MINE_PROTECTION_ENABLED
setToggleState(mineProtectionBtn, MINE_PROTECTION_ENABLED, "")
sendNotification(MINE_PROTECTION_ENABLED and "Mine protection activated!" or "Mine protection disabled")
end)

wrongFlagsBtn.MouseButton1Click:Connect(function()
REMOVE_WRONG_FLAGS = not REMOVE_WRONG_FLAGS
setToggleState(wrongFlagsBtn, REMOVE_WRONG_FLAGS, "")
sendNotification(REMOVE_WRONG_FLAGS and "Misplaced flag removal activated!" or "Misplaced flag removal disabled")
end)

syncWorkRadiusBtn.MouseButton1Click:Connect(function()
USE_WORK_RADIUS_FOR_SAFETY = not USE_WORK_RADIUS_FOR_SAFETY
setToggleState(syncWorkRadiusBtn, USE_WORK_RADIUS_FOR_SAFETY, "Use Work Radius Range: ")
sendNotification(USE_WORK_RADIUS_FOR_SAFETY and "Safety uses Work Radius bounds" or "Safety uses manual distance threshold")
end)

lightsToggleBtn.MouseButton1Click:Connect(function()
FLAG_LIGHTS_ENABLED = not FLAG_LIGHTS_ENABLED
setToggleState(lightsToggleBtn, FLAG_LIGHTS_ENABLED, "Flag Lights: ")
if not FLAG_LIGHTS_ENABLED then clearHighlights() end
sendNotification(FLAG_LIGHTS_ENABLED and "Flag Lights enabled!" or "Flag Lights disabled")
end)

spoofToggleBtn.MouseButton1Click:Connect(function()
SPOOF_FLAG_ENABLED = not SPOOF_FLAG_ENABLED
setToggleState(spoofToggleBtn, SPOOF_FLAG_ENABLED, "Spoof Flag Skin: ")
sendNotification(SPOOF_FLAG_ENABLED and "Flag Spoofer activated!" or "Using equipped inventory flag")
end)

spoofClicksBtn.MouseButton1Click:Connect(function()
SPOOF_MANUAL_CLICKS = not SPOOF_MANUAL_CLICKS
setToggleState(spoofClicksBtn, SPOOF_MANUAL_CLICKS, "Spoof Manual Clicks: ")
sendNotification(SPOOF_MANUAL_CLICKS and "Manual clicks will use spoofed flag skin!" or "Manual clicks use inventory flag")
end)

-- Color Cycling Actions
mineCycleBtn.MouseButton1Click:Connect(function()
MINE_COLOR = cycleColor(MINE_COLOR)
mineSwatch.BackgroundColor3 = MINE_COLOR
end)

flaggedCycleBtn.MouseButton1Click:Connect(function()
FLAGGED_MINE_COLOR = cycleColor(FLAGGED_MINE_COLOR)
flaggedSwatch.BackgroundColor3 = FLAGGED_MINE_COLOR
end)

wrongCycleBtn.MouseButton1Click:Connect(function()
WRONG_FLAG_COLOR = cycleColor(WRONG_FLAG_COLOR)
wrongSwatch.BackgroundColor3 = WRONG_FLAG_COLOR
end)

-- FLOATING MINIMIZE TOGGLE BUTTON

local miniBtn = Instance.new("TextButton")
miniBtn.Name = "IM_MiniButton"
miniBtn.Size = UDim2.new(0, 52, 0, 52)
miniBtn.AnchorPoint = Vector2.new(1, 1)
miniBtn.Position = UDim2.new(1, -20, 1, -20)
miniBtn.BackgroundColor3 = THEME.Accent
miniBtn.BorderSizePixel = 0
miniBtn.Text = "IM"
miniBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
miniBtn.TextSize = 13
miniBtn.Font = Enum.Font.GothamBold
miniBtn.Visible = false
miniBtn.Parent = screenGui
round(miniBtn, 26)
stroke(miniBtn, THEME.AccentHover, 2)

local miniDrag, miniStartPos, miniDragStart, miniSuppressed
miniBtn.InputBegan:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1 then
miniDrag = true
miniSuppressed = false
miniDragStart = input.Position
miniStartPos = miniBtn.Position
end
end)

UserInputService.InputChanged:Connect(function(input)
if miniDrag and input.UserInputType == Enum.UserInputType.MouseMovement then
local delta = input.Position - miniDragStart
if math.abs(delta.X) > 3 or math.abs(delta.Y) > 3 then miniSuppressed = true end
miniBtn.Position = UDim2.new(miniStartPos.X.Scale, miniStartPos.X.Offset + delta.X, miniStartPos.Y.Scale, miniStartPos.Y.Offset + delta.Y)
end
end)

UserInputService.InputEnded:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1 then miniDrag = false end
end)

miniBtn.MouseButton1Click:Connect(function()
if miniSuppressed then miniSuppressed = false; return end
minimized = false
mainFrame.Visible = true
miniBtn.Visible = false
end)

minimizeBtn.MouseButton1Click:Connect(function()
minimized = true
mainFrame.Visible = false
miniBtn.Visible = true
end)

closeBtn.MouseButton1Click:Connect(function()
destroyed = true
clearHighlights()
if poolFolder then poolFolder:Destroy() end
if screenGui then screenGui:Destroy() end
sendNotification("Isaac's Minesweeper unloaded")
end)

-- MAIN EXECUTION LOOPS

updateRadiusVisual()
updateSpeedVisual()
updateDistVisual()
updateFlagDisplayVisual()

-- Render Loop for Highlights
task.spawn(function()
while not destroyed and _G.IsaacMinesweeperSession == currentSession do
updateFlagLights()
task.wait(0.05)
end
end)

-- Safety Automation Loop (Fast 0.05s polling)
task.spawn(function()
while not destroyed and _G.IsaacMinesweeperSession == currentSession do
runSafetyChecks()
task.wait(SAFETY_CHECK_INTERVAL)
end
end)

sendNotification("Isaac's Minesweeper v17.0 loaded!")