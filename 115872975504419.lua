--[[
    ╔═══════════════════════════════════════════════════════════════╗
    ║  XCMEN HUB - DesertStorm [EXTRACTION]                         ║
    ║  Educational Testing Only — Private Environment               ║
    ╚═══════════════════════════════════════════════════════════════╝
    
    Tabs: Combat | ESP | NPC | Containers | World | Misc | Settings
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer

-- ─── DYNAMISCHE CAMERA ─────────────────────────────────────────
local function GetCamera()
    return Workspace.CurrentCamera
end

-- ─── WORKSPACE PFADE ───────────────────────────────────────────
local CONTAINER_FOLDER = Workspace:WaitForChild("Containers")
local BOT_FOLDER = Workspace:WaitForChild("IngameBots")
local EXTRACTION_FOLDER = Workspace:WaitForChild("Extractions")
local AIRDROP_FOLDER = Workspace:WaitForChild("AirdropPositions")
local DEAD_BODIES_FOLDER = Workspace:WaitForChild("DeadBodies")
local NATURE_FOLDER = Workspace:WaitForChild("Nature")

-- ─── REMOTES ───────────────────────────────────────────────────
local Remotes = {
    OpenContainerEvent = ReplicatedStorage:WaitForChild("OpenContainerEvent"),
    ExtractionSync = ReplicatedStorage:WaitForChild("ExtractionSync"),
    HitmarkerEvent = ReplicatedStorage:WaitForChild("HitmarkerEvent"),
    PingLocation = ReplicatedStorage:WaitForChild("PingLocation"),
    RemoteEvent = ReplicatedStorage:WaitForChild("RemoteEvent"),
}

-- ─── MAPPINGS ──────────────────────────────────────────────────
local ContainerTypes = {
    ["Ammo Box"] = "ammo", ["Civilian Airdrop"] = "airdrop",
    ["Double Metal Crates"] = "crate", ["Duffel Bag"] = "bag",
    ["Food Crate"] = "crate", ["Leather Pouch"] = "pouch",
    ["Medical Pouch"] = "medical", ["Metal Crate"] = "crate",
    ["Military Laptop"] = "electronics", ["PC Tower"] = "electronics",
    ["Safe"] = "safe", ["Specops Supply Crate"] = "crate",
    ["Supply Crate"] = "crate", ["T.C.R Supply Crate"] = "crate",
    ["Tall Metal Crate"] = "crate", ["Tanker Truck"] = "vehicle",
    ["Vault"] = "safe", ["Wooden Crate"] = "crate",
    ["Abandoned Car"] = "vehicle", ["DroppedItemContainer"] = "loot",
}

local BotTypes = {
    ["GOVSoldier"] = "gov", ["RebelElite"] = "rebel",
    ["RebelSniper"] = "rebel", ["RebelSoldier"] = "rebel",
    ["Scav"] = "scav", ["TCRElite"] = "tcr",
    ["TCRGuard"] = "tcr", ["Tyrant"] = "boss",
}

local ExtractionNames = {
    ["Getaway Car"] = "Getaway Car", ["Mountain Cave"] = "Mountain Cave",
    ["North-Western Boat"] = "NW Boat", ["Northern Mountain"] = "N Mountain",
    ["Radio Tower"] = "Radio Tower", ["Ruined Hideout"] = "Ruined Hideout",
    ["Southern Boat"] = "S Boat", ["Southern Tunnel"] = "S Tunnel",
    ["Tunnel Exit"] = "Tunnel Exit", ["Western Boat"] = "W Boat",
}

-- ═══════════════════════════════════════════════════════════════
-- CONFIG MANAGER
-- ═══════════════════════════════════════════════════════════════
local ConfigManager = {}
ConfigManager.Current = {}
ConfigManager.Path = "XCMEN_HUB_DesertStorm/"
ConfigManager.FileName = "config.json"
ConfigManager.AutoSaveEnabled = true

function ConfigManager:Init()
    if not isfolder(self.Path) then makefolder(self.Path) end
    self:Load()
    task.spawn(function()
        while self.AutoSaveEnabled do
            task.wait(30)
            if self.AutoSaveEnabled then pcall(function() self:Save() end) end
        end
    end)
end

function ConfigManager:Load()
    local fullPath = self.Path .. self.FileName
    if isfile(fullPath) then
        local ok, data = pcall(function() return HttpService:JSONDecode(readfile(fullPath)) end)
        if ok and type(data) == "table" then self.Current = data; return end
    end
    self:Reset()
end

function ConfigManager:Save()
    local ok, encoded = pcall(function() return HttpService:JSONEncode(self.Current) end)
    if ok then pcall(function() writefile(self.Path .. self.FileName, encoded) end) end
end

function ConfigManager:Reset()
    self.Current = {
        -- Combat / Aimbot
        AimbotEnabled = false, AimbotSmoothness = 0.5,
        AimbotFOV = 150, AimbotMaxDistance = 1000,
        AimbotTeamCheck = false, AimbotVisibilityCheck = false,
        AimbotShowFOV = true, AimbotTargetBots = true,
        
        -- Player ESP
        PlayerESP = false, BoxESP = false, NameESP = false,
        DistanceESP = false, HealthESP = false, Tracers = false,
        Chams = false,
        
        -- NPC ESP
        BotESP = false, BotBoxESP = false, BotNameESP = false,
        BotDistanceESP = false, BotHealthESP = false, BotTracers = false,
        
        -- Container ESP
        LootESP = false, LootNameESP = false, LootDistanceESP = false,
        LootTracers = false,
        
        -- Object ESP
        ExtractionESP = false, AirdropESP = false, DeadBodyESP = false,
        
        -- Colors
        ESPEnemyColor = {R = 255, G = 50, B = 50},
        ESPBotColor = {R = 255, G = 165, B = 0},
        ESPLootColor = {R = 255, G = 215, B = 0},
        ESPExtractionColor = {R = 0, G = 255, B = 255},
        ESPAirdropColor = {R = 255, G = 0, B = 255},
        ESPDeadBodyColor = {R = 128, G = 128, B = 128},
        
        -- World
        FullBright = false, TimeChanger = false, CustomTime = 12,
        RemoveFog = false, WeatherToggle = false, ShowInteractive = false,
        
        -- Misc
        FPSBoost = false,
        
        -- Settings
        Theme = "Default", GUIBind = "RightShift",
        Watermark = true, Notifications = true,
    }
    self:Save()
end

function ConfigManager:Set(key, value) self.Current[key] = value end
function ConfigManager:Get(key) return self.Current[key] end

-- ═══════════════════════════════════════════════════════════════
-- CONNECTION MANAGER
-- ═══════════════════════════════════════════════════════════════
local ConnectionManager = {}
ConnectionManager.Connections = {}

function ConnectionManager:Add(name, connection)
    if self.Connections[name] then pcall(function() self.Connections[name]:Disconnect() end) end
    self.Connections[name] = connection
end

function ConnectionManager:Clear()
    for _, conn in pairs(self.Connections) do pcall(function() conn:Disconnect() end) end
    table.clear(self.Connections)
end

-- ═══════════════════════════════════════════════════════════════
-- UTILITY
-- ═══════════════════════════════════════════════════════════════
local Utils = {}
Utils._cachedFolder = nil

function Utils:GetPlayerFolder()
    if self._cachedFolder and self._cachedFolder.Parent and self._cachedFolder:FindFirstChild(LocalPlayer.Name) then
        return self._cachedFolder
    end
    for _, child in pairs(Workspace:GetChildren()) do
        if (child:IsA("Folder") or child:IsA("Model")) and child:FindFirstChild(LocalPlayer.Name) then
            self._cachedFolder = child
            return child
        end
    end
    return nil
end

function Utils:GetCharacter(player)
    if not player then return nil end
    local folder = self:GetPlayerFolder()
    if not folder then return nil end
    local char = folder:FindFirstChild(player.Name)
    if char and char:FindFirstChild("Humanoid") and char:FindFirstChild("HumanoidRootPart") then
        return char
    end
    return nil
end

function Utils:GetHealth(char)
    if not char then return 0, 100 end
    local healthObj = char:FindFirstChild("Health")
    if healthObj and healthObj:IsA("ValueBase") then return healthObj.Value, 100 end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then return hum.Health, hum.MaxHealth end
    return 0, 100
end

function Utils:IsAlive(char)
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

function Utils:GetDistance(pos)
    if not LocalPlayer.Character then return 99999 end
    local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if root then return (root.Position - pos).Magnitude end
    return 99999
end

function Utils:WorldToScreen(pos)
    local cam = GetCamera()
    if not cam then return Vector2.new(0, 0), false end
    local sp, onScreen = cam:WorldToViewportPoint(pos)
    return Vector2.new(sp.X, sp.Y), onScreen
end

function Utils:ColorFromConfig(key)
    local c = ConfigManager:Get(key)
    return Color3.fromRGB(c.R, c.G, c.B)
end

function Utils:FormatNumber(n) return tostring(math.floor(n + 0.5)) end

function Utils:CopyToClipboard(text) pcall(function() setclipboard(text) end) end

-- ═══════════════════════════════════════════════════════════════
-- DRAWING POOL
-- ═══════════════════════════════════════════════════════════════
local DrawingPool = {}
function DrawingPool:Create(type)
    local ok, d = pcall(function() return Drawing.new(type) end)
    if ok then d.Visible = false; return d end
    return nil
end
function DrawingPool:Destroy(d) pcall(function() d:Remove() end) end

-- ═══════════════════════════════════════════════════════════════
-- ESP ENGINE (ROBUST + CLEANUP)
-- ═══════════════════════════════════════════════════════════════
local ESPManager = {}
ESPManager.PlayerObjects = {}
ESPManager.BotObjects = {}
ESPManager.LootObjects = {}
ESPManager.OtherObjects = {}

-- Hilfsfunktion: Bounding Box aus Character-Parts
local function GetCharBounds(character)
    if not character then return nil end
    local cam = GetCamera()
    if not cam then return nil end
    
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local any = false
    
    for _, part in pairs(character:GetChildren()) do
        if part:IsA("BasePart") then
            local size = part.Size
            local cf = part.CFrame
            local corners = {
                cf * CFrame.new(-size.X/2, -size.Y/2, -size.Z/2),
                cf * CFrame.new(-size.X/2, -size.Y/2, size.Z/2),
                cf * CFrame.new(-size.X/2, size.Y/2, -size.Z/2),
                cf * CFrame.new(-size.X/2, size.Y/2, size.Z/2),
                cf * CFrame.new(size.X/2, -size.Y/2, -size.Z/2),
                cf * CFrame.new(size.X/2, -size.Y/2, size.Z/2),
                cf * CFrame.new(size.X/2, size.Y/2, -size.Z/2),
                cf * CFrame.new(size.X/2, size.Y/2, size.Z/2),
            }
            for _, c in pairs(corners) do
                local sp, onScreen = cam:WorldToViewportPoint(c.Position)
                if onScreen then
                    any = true
                    minX = math.min(minX, sp.X)
                    minY = math.min(minY, sp.Y)
                    maxX = math.max(maxX, sp.X)
                    maxY = math.max(maxY, sp.Y)
                end
            end
        end
    end
    
    if any and minX ~= math.huge then
        return Vector2.new(minX, minY), Vector2.new(maxX, maxY)
    end
    return nil
end

-- ─── PLAYER ESP ────────────────────────────────────────────────
local PlayerESP = {}
PlayerESP.__index = PlayerESP

function PlayerESP.new(player)
    local self = setmetatable({}, PlayerESP)
    self.Player = player
    self.Drawings = {
        Box = DrawingPool:Create("Square"),
        BoxOutline = DrawingPool:Create("Square"),
        Name = DrawingPool:Create("Text"),
        Distance = DrawingPool:Create("Text"),
        Health = DrawingPool:Create("Text"),
        HealthBar = DrawingPool:Create("Square"),
        HealthBarOutline = DrawingPool:Create("Square"),
        Tracer = DrawingPool:Create("Line"),
    }
    self.Highlight = nil
    return self
end

function PlayerESP:Update()
    local ok, err = pcall(function()
        local char = Utils:GetCharacter(self.Player)
        if not char or not Utils:IsAlive(char) then
            self:Hide()
            return
        end
        
        local topLeft, bottomRight = GetCharBounds(char)
        if not topLeft then self:Hide(); return end
        
        local size = bottomRight - topLeft
        if size.X < 4 or size.Y < 4 then self:Hide(); return end
        
        local root = char:FindFirstChild("HumanoidRootPart")
        local dist = root and Utils:GetDistance(root.Position) or 0
        local color = Utils:ColorFromConfig("ESPEnemyColor")
        
        -- Box
        if ConfigManager:Get("BoxESP") then
            self.Drawings.BoxOutline.Size = size + Vector2.new(2, 2)
            self.Drawings.BoxOutline.Position = topLeft - Vector2.new(1, 1)
            self.Drawings.BoxOutline.Visible = true
            self.Drawings.BoxOutline.Color = Color3.new(0, 0, 0)
            self.Drawings.BoxOutline.Thickness = 1
            self.Drawings.BoxOutline.Filled = false
            
            self.Drawings.Box.Size = size
            self.Drawings.Box.Position = topLeft
            self.Drawings.Box.Visible = true
            self.Drawings.Box.Color = color
            self.Drawings.Box.Thickness = 1
            self.Drawings.Box.Filled = false
        else
            self.Drawings.Box.Visible = false
            self.Drawings.BoxOutline.Visible = false
        end
        
        -- Name
        if ConfigManager:Get("NameESP") then
            self.Drawings.Name.Text = self.Player.Name
            self.Drawings.Name.Position = Vector2.new(topLeft.X + size.X/2, topLeft.Y - 16)
            self.Drawings.Name.Size = 13
            self.Drawings.Name.Center = true
            self.Drawings.Name.Visible = true
            self.Drawings.Name.Color = color
            self.Drawings.Name.Outline = true
        else
            self.Drawings.Name.Visible = false
        end
        
        -- Distance
        if ConfigManager:Get("DistanceESP") then
            self.Drawings.Distance.Text = Utils:FormatNumber(dist) .. "m"
            self.Drawings.Distance.Position = Vector2.new(topLeft.X + size.X/2, bottomRight.Y + 2)
            self.Drawings.Distance.Size = 11
            self.Drawings.Distance.Center = true
            self.Drawings.Distance.Visible = true
            self.Drawings.Distance.Color = Color3.new(1, 1, 1)
            self.Drawings.Distance.Outline = true
        else
            self.Drawings.Distance.Visible = false
        end
        
        -- Health
        if ConfigManager:Get("HealthESP") then
            local hp, maxHp = Utils:GetHealth(char)
            local pct = math.clamp(hp / maxHp, 0, 1)
            
            self.Drawings.Health.Text = Utils:FormatNumber(hp) .. " HP"
            self.Drawings.Health.Position = Vector2.new(topLeft.X + size.X/2, topLeft.Y - 30)
            self.Drawings.Health.Size = 11
            self.Drawings.Health.Center = true
            self.Drawings.Health.Visible = true
            self.Drawings.Health.Color = Color3.fromRGB(255*(1-pct), 255*pct, 0)
            self.Drawings.Health.Outline = true
            
            local barW = size.X
            local barH = 3
            local barPos = Vector2.new(topLeft.X, topLeft.Y - 8)
            
            self.Drawings.HealthBarOutline.Size = Vector2.new(barW+2, barH+2)
            self.Drawings.HealthBarOutline.Position = barPos - Vector2.new(1,1)
            self.Drawings.HealthBarOutline.Visible = true
            self.Drawings.HealthBarOutline.Color = Color3.new(0,0,0)
            self.Drawings.HealthBarOutline.Filled = true
            
            self.Drawings.HealthBar.Size = Vector2.new(barW * pct, barH)
            self.Drawings.HealthBar.Position = barPos
            self.Drawings.HealthBar.Visible = true
            self.Drawings.HealthBar.Color = Color3.fromRGB(255*(1-pct), 255*pct, 0)
            self.Drawings.HealthBar.Filled = true
        else
            self.Drawings.Health.Visible = false
            self.Drawings.HealthBar.Visible = false
            self.Drawings.HealthBarOutline.Visible = false
        end
        
        -- Tracer
        if ConfigManager:Get("Tracers") then
            local cam = GetCamera()
            if cam then
                self.Drawings.Tracer.From = Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y)
                self.Drawings.Tracer.To = Vector2.new(topLeft.X + size.X/2, topLeft.Y + size.Y/2)
                self.Drawings.Tracer.Visible = true
                self.Drawings.Tracer.Color = color
                self.Drawings.Tracer.Thickness = 1
            end
        else
            self.Drawings.Tracer.Visible = false
        end
        
        -- Chams
        if ConfigManager:Get("Chams") then
            if not self.Highlight then
                self.Highlight = Instance.new("Highlight")
                self.Highlight.Parent = char
            end
            self.Highlight.FillColor = color
            self.Highlight.OutlineColor = Color3.new(1,1,1)
            self.Highlight.FillTransparency = 0.5
            self.Highlight.OutlineTransparency = 0
            self.Highlight.Enabled = true
        elseif self.Highlight then
            self.Highlight.Enabled = false
        end
    end)
    if not ok then self:Hide() end
end

function PlayerESP:Hide()
    for _, d in pairs(self.Drawings) do d.Visible = false end
    if self.Highlight then self.Highlight.Enabled = false end
end

function PlayerESP:Destroy()
    self:Hide()
    for _, d in pairs(self.Drawings) do DrawingPool:Destroy(d) end
    if self.Highlight then self.Highlight:Destroy() end
end

-- ─── BOT / NPC ESP ─────────────────────────────────────────────
local BotESP = {}
BotESP.__index = BotESP

function BotESP.new(model)
    local self = setmetatable({}, BotESP)
    self.Model = model
    self.Drawings = {
        Box = DrawingPool:Create("Square"),
        BoxOutline = DrawingPool:Create("Square"),
        Name = DrawingPool:Create("Text"),
        Distance = DrawingPool:Create("Text"),
        Health = DrawingPool:Create("Text"),
        HealthBar = DrawingPool:Create("Square"),
        HealthBarOutline = DrawingPool:Create("Square"),
        Tracer = DrawingPool:Create("Line"),
    }
    return self
end

function BotESP:Update()
    local ok, err = pcall(function()
        if not self.Model or not self.Model.Parent then self:Hide(); return end
        
        local hum = self.Model:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then self:Hide(); return end
        
        local hrp = self.Model:FindFirstChild("HumanoidRootPart")
        if not hrp then self:Hide(); return end
        
        local topLeft, bottomRight = GetCharBounds(self.Model)
        if not topLeft then self:Hide(); return end
        
        local size = bottomRight - topLeft
        if size.X < 4 or size.Y < 4 then self:Hide(); return end
        
        local dist = Utils:GetDistance(hrp.Position)
        local color = Utils:ColorFromConfig("ESPBotColor")
        local botType = Utils:GetBotType(self.Model)
        
        -- Box
        if ConfigManager:Get("BotBoxESP") then
            self.Drawings.BoxOutline.Size = size + Vector2.new(2,2)
            self.Drawings.BoxOutline.Position = topLeft - Vector2.new(1,1)
            self.Drawings.BoxOutline.Visible = true
            self.Drawings.BoxOutline.Color = Color3.new(0,0,0)
            self.Drawings.BoxOutline.Thickness = 1
            self.Drawings.BoxOutline.Filled = false
            
            self.Drawings.Box.Size = size
            self.Drawings.Box.Position = topLeft
            self.Drawings.Box.Visible = true
            self.Drawings.Box.Color = color
            self.Drawings.Box.Thickness = 1
            self.Drawings.Box.Filled = false
        else
            self.Drawings.Box.Visible = false
            self.Drawings.BoxOutline.Visible = false
        end
        
        -- Name
        if ConfigManager:Get("BotNameESP") then
            self.Drawings.Name.Text = self.Model.Name .. " [" .. botType .. "]"
            self.Drawings.Name.Position = Vector2.new(topLeft.X + size.X/2, topLeft.Y - 16)
            self.Drawings.Name.Size = 12
            self.Drawings.Name.Center = true
            self.Drawings.Name.Visible = true
            self.Drawings.Name.Color = color
            self.Drawings.Name.Outline = true
        else
            self.Drawings.Name.Visible = false
        end
        
        -- Distance
        if ConfigManager:Get("BotDistanceESP") then
            self.Drawings.Distance.Text = Utils:FormatNumber(dist) .. "m"
            self.Drawings.Distance.Position = Vector2.new(topLeft.X + size.X/2, bottomRight.Y + 2)
            self.Drawings.Distance.Size = 11
            self.Drawings.Distance.Center = true
            self.Drawings.Distance.Visible = true
            self.Drawings.Distance.Color = Color3.new(1,1,1)
            self.Drawings.Distance.Outline = true
        else
            self.Drawings.Distance.Visible = false
        end
        
        -- HealthBar
        if ConfigManager:Get("BotHealthESP") then
            local pct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
            local barW = size.X
            local barH = 3
            local barPos = Vector2.new(topLeft.X, topLeft.Y - 8)
            
            self.Drawings.HealthBarOutline.Size = Vector2.new(barW+2, barH+2)
            self.Drawings.HealthBarOutline.Position = barPos - Vector2.new(1,1)
            self.Drawings.HealthBarOutline.Visible = true
            self.Drawings.HealthBarOutline.Color = Color3.new(0,0,0)
            self.Drawings.HealthBarOutline.Filled = true
            
            self.Drawings.HealthBar.Size = Vector2.new(barW * pct, barH)
            self.Drawings.HealthBar.Position = barPos
            self.Drawings.HealthBar.Visible = true
            self.Drawings.HealthBar.Color = Color3.fromRGB(255*(1-pct), 255*pct, 0)
            self.Drawings.HealthBar.Filled = true
            
            self.Drawings.Health.Text = Utils:FormatNumber(hum.Health) .. " HP"
            self.Drawings.Health.Position = Vector2.new(topLeft.X + size.X/2, topLeft.Y - 22)
            self.Drawings.Health.Size = 10
            self.Drawings.Health.Center = true
            self.Drawings.Health.Visible = true
            self.Drawings.Health.Color = Color3.fromRGB(255*(1-pct), 255*pct, 0)
            self.Drawings.Health.Outline = true
        else
            self.Drawings.Health.Visible = false
            self.Drawings.HealthBar.Visible = false
            self.Drawings.HealthBarOutline.Visible = false
        end
        
        -- Tracer
        if ConfigManager:Get("BotTracers") then
            local cam = GetCamera()
            if cam then
                self.Drawings.Tracer.From = Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y)
                self.Drawings.Tracer.To = Vector2.new(topLeft.X + size.X/2, topLeft.Y + size.Y/2)
                self.Drawings.Tracer.Visible = true
                self.Drawings.Tracer.Color = color
                self.Drawings.Tracer.Thickness = 1
            end
        else
            self.Drawings.Tracer.Visible = false
        end
    end)
    if not ok then self:Hide() end
end

function BotESP:Hide()
    for _, d in pairs(self.Drawings) do d.Visible = false end
end

function BotESP:Destroy()
    self:Hide()
    for _, d in pairs(self.Drawings) do DrawingPool:Destroy(d) end
end

-- ─── LOOT / CONTAINER ESP ──────────────────────────────────────
local LootESP = {}
LootESP.__index = LootESP

function LootESP.new(model)
    local self = setmetatable({}, LootESP)
    self.Model = model
    self.Drawings = {
        Name = DrawingPool:Create("Text"),
        Distance = DrawingPool:Create("Text"),
        Tracer = DrawingPool:Create("Line"),
    }
    return self
end

function LootESP:Update()
    local ok, err = pcall(function()
        if not self.Model or not self.Model.Parent then self:Hide(); return end
        
        local primary = self.Model:IsA("Model") and (self.Model.PrimaryPart or self.Model:FindFirstChildWhichIsA("BasePart")) or self.Model
        if not primary then primary = self.Model:FindFirstChildWhichIsA("BasePart") end
        if not primary then self:Hide(); return end
        
        local pos, onScreen = Utils:WorldToScreen(primary.Position)
        if not onScreen then self:Hide(); return end
        
        local dist = Utils:GetDistance(primary.Position)
        local color = Utils:ColorFromConfig("ESPLootColor")
        
        if ConfigManager:Get("LootNameESP") then
            self.Drawings.Name.Text = self.Model.Name
            self.Drawings.Name.Position = pos
            self.Drawings.Name.Size = 12
            self.Drawings.Name.Center = true
            self.Drawings.Name.Visible = true
            self.Drawings.Name.Color = color
            self.Drawings.Name.Outline = true
        else
            self.Drawings.Name.Visible = false
        end
        
        if ConfigManager:Get("LootDistanceESP") then
            self.Drawings.Distance.Text = Utils:FormatNumber(dist) .. "m"
            self.Drawings.Distance.Position = pos + Vector2.new(0, 14)
            self.Drawings.Distance.Size = 10
            self.Drawings.Distance.Center = true
            self.Drawings.Distance.Visible = true
            self.Drawings.Distance.Color = Color3.new(1,1,1)
            self.Drawings.Distance.Outline = true
        else
            self.Drawings.Distance.Visible = false
        end
        
        if ConfigManager:Get("LootTracers") then
            local cam = GetCamera()
            if cam then
                self.Drawings.Tracer.From = Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y)
                self.Drawings.Tracer.To = pos
                self.Drawings.Tracer.Visible = true
                self.Drawings.Tracer.Color = color
                self.Drawings.Tracer.Thickness = 1
            end
        else
            self.Drawings.Tracer.Visible = false
        end
    end)
    if not ok then self:Hide() end
end

function LootESP:Hide()
    for _, d in pairs(self.Drawings) do d.Visible = false end
end

function LootESP:Destroy()
    self:Hide()
    for _, d in pairs(self.Drawings) do DrawingPool:Destroy(d) end
end

-- ─── SIMPLE OBJECT ESP (Extractions, Airdrops, Bodies) ─────────
local SimpleESP = {}
SimpleESP.__index = SimpleESP

function SimpleESP.new(model, displayName, colorKey)
    local self = setmetatable({}, SimpleESP)
    self.Model = model
    self.DisplayName = displayName
    self.ColorKey = colorKey
    self.Drawings = {
        Name = DrawingPool:Create("Text"),
        Distance = DrawingPool:Create("Text"),
        Tracer = DrawingPool:Create("Line"),
    }
    return self
end

function SimpleESP:Update()
    local ok, err = pcall(function()
        if not self.Model or not self.Model.Parent then self:Hide(); return end
        
        local primary = self.Model:IsA("Model") and (self.Model.PrimaryPart or self.Model:FindFirstChildWhichIsA("BasePart")) or self.Model
        if not primary then primary = self.Model:FindFirstChildWhichIsA("BasePart") end
        if not primary then self:Hide(); return end
        
        local pos, onScreen = Utils:WorldToScreen(primary.Position)
        if not onScreen then self:Hide(); return end
        
        local dist = Utils:GetDistance(primary.Position)
        local color = Utils:ColorFromConfig(self.ColorKey)
        
        self.Drawings.Name.Text = self.DisplayName
        self.Drawings.Name.Position = pos
        self.Drawings.Name.Size = 12
        self.Drawings.Name.Center = true
        self.Drawings.Name.Visible = true
        self.Drawings.Name.Color = color
        self.Drawings.Name.Outline = true
        
        self.Drawings.Distance.Text = Utils:FormatNumber(dist) .. "m"
        self.Drawings.Distance.Position = pos + Vector2.new(0, 14)
        self.Drawings.Distance.Size = 10
        self.Drawings.Distance.Center = true
        self.Drawings.Distance.Visible = true
        self.Drawings.Distance.Color = Color3.new(1,1,1)
        self.Drawings.Distance.Outline = true
        
        local cam = GetCamera()
        if cam then
            self.Drawings.Tracer.From = Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y)
            self.Drawings.Tracer.To = pos
            self.Drawings.Tracer.Visible = true
            self.Drawings.Tracer.Color = color
            self.Drawings.Tracer.Thickness = 1
        end
    end)
    if not ok then self:Hide() end
end

function SimpleESP:Hide()
    for _, d in pairs(self.Drawings) do d.Visible = false end
end

function SimpleESP:Destroy()
    self:Hide()
    for _, d in pairs(self.Drawings) do DrawingPool:Destroy(d) end
end

-- ─── ESP MANAGER LOGIC ─────────────────────────────────────────
function ESPManager:Init()
    -- Player Tracking
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            self.PlayerObjects[plr] = PlayerESP.new(plr)
        end
    end
    Players.PlayerAdded:Connect(function(plr)
        if plr ~= LocalPlayer then self.PlayerObjects[plr] = PlayerESP.new(plr) end
    end)
    Players.PlayerRemoving:Connect(function(plr)
        if self.PlayerObjects[plr] then
            self.PlayerObjects[plr]:Destroy()
            self.PlayerObjects[plr] = nil
        end
    end)
    
    -- Bot Tracking
    for _, bot in pairs(BOT_FOLDER:GetChildren()) do
        if bot:IsA("Model") then
            self.BotObjects[bot] = BotESP.new(bot)
        end
    end
    BOT_FOLDER.ChildAdded:Connect(function(bot)
        if bot:IsA("Model") then self.BotObjects[bot] = BotESP.new(bot) end
    end)
    BOT_FOLDER.ChildRemoved:Connect(function(bot)
        if self.BotObjects[bot] then
            self.BotObjects[bot]:Destroy()
            self.BotObjects[bot] = nil
        end
    end)
    
    -- Loot Tracking
    for _, item in pairs(CONTAINER_FOLDER:GetChildren()) do
        self.LootObjects[item] = LootESP.new(item)
    end
    CONTAINER_FOLDER.ChildAdded:Connect(function(item)
        self.LootObjects[item] = LootESP.new(item)
    end)
    CONTAINER_FOLDER.ChildRemoved:Connect(function(item)
        if self.LootObjects[item] then
            self.LootObjects[item]:Destroy()
            self.LootObjects[item] = nil
        end
    end)
    
    -- Main Loop
    ConnectionManager:Add("ESPMainLoop", RunService.RenderStepped:Connect(function()
        self:Update()
    end))
end

function ESPManager:Update()
    -- Players
    if ConfigManager:Get("PlayerESP") then
        for plr, esp in pairs(self.PlayerObjects) do
            esp:Update()
        end
    else
        for _, esp in pairs(self.PlayerObjects) do esp:Hide() end
    end
    
    -- Bots
    if ConfigManager:Get("BotESP") then
        for bot, esp in pairs(self.BotObjects) do
            if bot.Parent and bot:FindFirstChildOfClass("Humanoid") and bot:FindFirstChildOfClass("Humanoid").Health > 0 then
                esp:Update()
            else
                esp:Hide()
            end
        end
    else
        for _, esp in pairs(self.BotObjects) do esp:Hide() end
    end
    
    -- Loot
    if ConfigManager:Get("LootESP") then
        for item, esp in pairs(self.LootObjects) do
            if item.Parent then
                esp:Update()
            else
                esp:Hide()
            end
        end
    else
        for _, esp in pairs(self.LootObjects) do esp:Hide() end
    end
    
    -- Extractions
    if ConfigManager:Get("ExtractionESP") then
        for _, extract in pairs(EXTRACTION_FOLDER:GetChildren()) do
            if not self.OtherObjects[extract] then
                local name = ExtractionNames[extract.Name] or extract.Name
                self.OtherObjects[extract] = SimpleESP.new(extract, "[EXTRACT] " .. name, "ESPExtractionColor")
            end
            self.OtherObjects[extract]:Update()
        end
    end
    
    -- Airdrops
    if ConfigManager:Get("AirdropESP") then
        for _, drop in pairs(AIRDROP_FOLDER:GetChildren()) do
            if not self.OtherObjects[drop] then
                self.OtherObjects[drop] = SimpleESP.new(drop, "[AIRDROP] " .. drop.Name, "ESPAirdropColor")
            end
            self.OtherObjects[drop]:Update()
        end
    end
    
    -- Dead Bodies
    if ConfigManager:Get("DeadBodyESP") then
        for _, body in pairs(DEAD_BODIES_FOLDER:GetChildren()) do
            if not self.OtherObjects[body] then
                self.OtherObjects[body] = SimpleESP.new(body, "[BODY] " .. body.Name, "ESPDeadBodyColor")
            end
            self.OtherObjects[body]:Update()
        end
    end
    
    -- Cleanup destroyed other objects
    for model, esp in pairs(self.OtherObjects) do
        if not model.Parent then
            esp:Destroy()
            self.OtherObjects[model] = nil
        elseif not (ConfigManager:Get("ExtractionESP") and model.Parent == EXTRACTION_FOLDER)
           and not (ConfigManager:Get("AirdropESP") and model.Parent == AIRDROP_FOLDER)
           and not (ConfigManager:Get("DeadBodyESP") and model.Parent == DEAD_BODIES_FOLDER) then
            esp:Hide()
        end
    end
end

function ESPManager:ClearAll()
    for _, esp in pairs(self.PlayerObjects) do esp:Hide() end
    for _, esp in pairs(self.BotObjects) do esp:Hide() end
    for _, esp in pairs(self.LootObjects) do esp:Hide() end
    for _, esp in pairs(self.OtherObjects) do esp:Hide() end
end

-- ═══════════════════════════════════════════════════════════════
-- AIMBOT
-- ═══════════════════════════════════════════════════════════════
local Aimbot = {}
Aimbot.Locked = false
Aimbot.Target = nil
Aimbot.FOVCircle = nil

function Aimbot:Init()
    self.FOVCircle = DrawingPool:Create("Circle")
    self.FOVCircle.Filled = false
    self.FOVCircle.Thickness = 1.5
    self.FOVCircle.NumSides = 64
    self.FOVCircle.Color = Color3.new(1, 1, 1)
    
    ConnectionManager:Add("AimbotLoop", RunService.RenderStepped:Connect(function()
        self:Update()
    end))
    
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            self.Locked = true
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            self.Locked = false
            self.Target = nil
        end
    end)
end

function Aimbot:GetClosestHead()
    local closestHead = nil
    local closestDist = math.huge
    local cam = GetCamera()
    if not cam then return nil end
    
    local center = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    local fov = ConfigManager:Get("AimbotFOV")
    local maxDist = ConfigManager:Get("AimbotMaxDistance")
    local visCheck = ConfigManager:Get("AimbotVisibilityCheck")
    local targetBots = ConfigManager:Get("AimbotTargetBots")
    
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    
    -- Players
    for _, plr in pairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local char = Utils:GetCharacter(plr)
        if not char then continue end
        local head = char:FindFirstChild("Head")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not head or not hum or hum.Health <= 0 then continue end
        
        local dist3D = myRoot and (head.Position - myRoot.Position).Magnitude or 0
        if dist3D > maxDist then continue end
        
        local pos, onScreen = Utils:WorldToScreen(head.Position)
        if not onScreen then continue end
        
        local dist2D = (pos - center).Magnitude
        if dist2D > fov then continue end
        
        if visCheck then
            local rp = RaycastParams.new()
            rp.FilterType = Enum.RaycastFilterType.Blacklist
            rp.FilterDescendantsInstances = {cam, myChar}
            local res = Workspace:Raycast(cam.CFrame.Position, head.Position - cam.CFrame.Position, rp)
            if res and not res.Instance:IsDescendantOf(char) then continue end
        end
        
        if dist2D < closestDist then
            closestDist = dist2D
            closestHead = head
        end
    end
    
    -- Bots
    if targetBots then
        for _, bot in pairs(BOT_FOLDER:GetChildren()) do
            if not bot:IsA("Model") then continue end
            local head = bot:FindFirstChild("Head")
            local hum = bot:FindFirstChildOfClass("Humanoid")
            if not head or not hum or hum.Health <= 0 then continue end
            
            local dist3D = myRoot and (head.Position - myRoot.Position).Magnitude or 0
            if dist3D > maxDist then continue end
            
            local pos, onScreen = Utils:WorldToScreen(head.Position)
            if not onScreen then continue end
            
            local dist2D = (pos - center).Magnitude
            if dist2D > fov then continue end
            
            if visCheck then
                local rp = RaycastParams.new()
                rp.FilterType = Enum.RaycastFilterType.Blacklist
                rp.FilterDescendantsInstances = {cam, myChar}
                local res = Workspace:Raycast(cam.CFrame.Position, head.Position - cam.CFrame.Position, rp)
                if res and not res.Instance:IsDescendantOf(bot) then continue end
            end
            
            if dist2D < closestDist then
                closestDist = dist2D
                closestHead = head
            end
        end
    end
    
    return closestHead
end

function Aimbot:Update()
    local cam = GetCamera()
    if not cam then return end
    
    if ConfigManager:Get("AimbotShowFOV") and ConfigManager:Get("AimbotEnabled") then
        self.FOVCircle.Visible = true
        self.FOVCircle.Radius = ConfigManager:Get("AimbotFOV")
        self.FOVCircle.Position = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
        self.FOVCircle.Color = self.Locked and Color3.fromRGB(0, 255, 0) or Color3.new(1, 1, 1)
    else
        self.FOVCircle.Visible = false
    end
    
    if not ConfigManager:Get("AimbotEnabled") or not self.Locked then return end
    
    local target = self.Target or self:GetClosestHead()
    if target and target.Parent then
        self.Target = target
        local smoothness = ConfigManager:Get("AimbotSmoothness")
        local alpha = math.clamp(1.1 - smoothness, 0.02, 1)
        cam.CFrame = cam.CFrame:Lerp(CFrame.new(cam.CFrame.Position, target.Position), alpha)
    else
        self.Target = nil
    end
end

-- ═══════════════════════════════════════════════════════════════
-- WORLD MODULE
-- ═══════════════════════════════════════════════════════════════
local WorldModule = {}

function WorldModule:Init()
    self.Original = {
        Brightness = Lighting.Brightness,
        ClockTime = Lighting.ClockTime,
        FogStart = Lighting.FogStart,
        FogEnd = Lighting.FogEnd,
        FogColor = Lighting.FogColor,
        GlobalShadows = Lighting.GlobalShadows,
        OutdoorAmbient = Lighting.OutdoorAmbient,
        Ambient = Lighting.Ambient,
    }
    
    ConnectionManager:Add("WorldLoop", RunService.Heartbeat:Connect(function()
        if ConfigManager:Get("FullBright") then
            Lighting.Brightness = 2
            Lighting.GlobalShadows = false
            Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
            Lighting.Ambient = Color3.fromRGB(128, 128, 128)
        elseif not ConfigManager:Get("TimeChanger") then
            Lighting.Brightness = self.Original.Brightness
            Lighting.GlobalShadows = self.Original.GlobalShadows
            Lighting.OutdoorAmbient = self.Original.OutdoorAmbient
            Lighting.Ambient = self.Original.Ambient
        end
        
        if ConfigManager:Get("TimeChanger") then
            Lighting.ClockTime = ConfigManager:Get("CustomTime")
        elseif not ConfigManager:Get("FullBright") then
            Lighting.ClockTime = self.Original.ClockTime
        end
        
        if ConfigManager:Get("RemoveFog") then
            Lighting.FogStart = 0
            Lighting.FogEnd = 100000
            Lighting.FogColor = Color3.fromRGB(255, 255, 255)
        elseif not ConfigManager:Get("FullBright") then
            Lighting.FogStart = self.Original.FogStart
            Lighting.FogEnd = self.Original.FogEnd
            Lighting.FogColor = self.Original.FogColor
        end
        
        if ConfigManager:Get("WeatherToggle") and NATURE_FOLDER then
            for _, obj in pairs(NATURE_FOLDER:GetDescendants()) do
                if obj:IsA("ParticleEmitter") or obj:IsA("Beam") then obj.Enabled = false end
            end
        end
        
        if ConfigManager:Get("ShowInteractive") then
            for _, container in pairs(CONTAINER_FOLDER:GetChildren()) do
                if container:IsA("Model") and not container:FindFirstChild("DS_Highlight") then
                    local hl = Instance.new("Highlight")
                    hl.Name = "DS_Highlight"
                    hl.FillColor = Color3.fromRGB(255, 255, 0)
                    hl.OutlineColor = Color3.fromRGB(255, 255, 0)
                    hl.FillTransparency = 0.8
                    hl.OutlineTransparency = 0
                    hl.Parent = container
                end
            end
        else
            for _, container in pairs(CONTAINER_FOLDER:GetChildren()) do
                local hl = container:FindFirstChild("DS_Highlight")
                if hl then hl:Destroy() end
            end
        end
    end))
end

-- ═══════════════════════════════════════════════════════════════
-- MISC MODULE
-- ═══════════════════════════════════════════════════════════════
local MiscModule = {}

function MiscModule:Init()
    ConnectionManager:Add("FPSBoost", RunService.Heartbeat:Connect(function()
        if ConfigManager:Get("FPSBoost") then
            settings().Rendering.QualityLevel = 1
            for _, effect in pairs(Lighting:GetChildren()) do
                if effect:IsA("PostEffect") then effect.Enabled = false end
            end
        end
    end))
end

-- ═══════════════════════════════════════════════════════════════
-- RAYFIELD UI
-- ═══════════════════════════════════════════════════════════════
local RayfieldUI = {}

function RayfieldUI:Init()
    local ok, RayfieldLib = pcall(function()
        return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
    end)
    if not ok or not RayfieldLib then warn("[XCMEN] Rayfield failed"); return end
    
    self.Library = RayfieldLib
    
    local Window = RayfieldLib:CreateWindow({
        Name = "XCMEN HUB - DesertStorm",
        LoadingTitle = "XCMEN HUB",
        LoadingSubtitle = "DesertStorm [EXTRACTION]",
        ConfigurationSaving = { Enabled = false },
        Discord = { Enabled = false },
        KeySystem = false,
    })
    
    self.Window = Window
    self:CreateCombatTab()
    self:CreateESPTab()
    self:CreateNPCTab()
    self:CreateContainersTab()
    self:CreateWorldTab()
    self:CreateMiscTab()
    self:CreateSettingsTab()
    
    if ConfigManager:Get("Notifications") then
        RayfieldLib:Notify({
            Title = "XCMEN HUB",
            Content = "DesertStorm loaded! Press " .. ConfigManager:Get("GUIBind") .. " to toggle.",
            Duration = 5,
            Image = 4483362458,
        })
    end
end

function RayfieldUI:CreateCombatTab()
    local Tab = self.Window:CreateTab("Combat", 4483362458)
    
    Tab:CreateSection("Aimbot (Hold RMB)")
    
    Tab:CreateToggle({
        Name = "Enable Aimbot",
        CurrentValue = ConfigManager:Get("AimbotEnabled"),
        Flag = "AimbotEnabled",
        Callback = function(v) ConfigManager:Set("AimbotEnabled", v) end,
    })
    
    Tab:CreateSlider({
        Name = "Smoothness (0.1 = Strong / 1 = Weak)",
        Range = {0.1, 1}, Increment = 0.01,
        CurrentValue = ConfigManager:Get("AimbotSmoothness"),
        Flag = "AimbotSmoothness",
        Callback = function(v) ConfigManager:Set("AimbotSmoothness", v) end,
    })
    
    Tab:CreateSlider({
        Name = "FOV Radius", Range = {10, 500}, Increment = 5, Suffix = "px",
        CurrentValue = ConfigManager:Get("AimbotFOV"),
        Flag = "AimbotFOV",
        Callback = function(v) ConfigManager:Set("AimbotFOV", v) end,
    })
    
    Tab:CreateSlider({
        Name = "Max Distance", Range = {50, 3000}, Increment = 50, Suffix = "m",
        CurrentValue = ConfigManager:Get("AimbotMaxDistance"),
        Flag = "AimbotMaxDist",
        Callback = function(v) ConfigManager:Set("AimbotMaxDistance", v) end,
    })
    
    Tab:CreateToggle({
        Name = "Target Bots too",
        CurrentValue = ConfigManager:Get("AimbotTargetBots"),
        Flag = "AimbotTargetBots",
        Callback = function(v) ConfigManager:Set("AimbotTargetBots", v) end,
    })
    
    Tab:CreateToggle({
        Name = "Visibility Check",
        CurrentValue = ConfigManager:Get("AimbotVisibilityCheck"),
        Flag = "AimbotVisCheck",
        Callback = function(v) ConfigManager:Set("AimbotVisibilityCheck", v) end,
    })
    
    Tab:CreateToggle({
        Name = "Show FOV Circle",
        CurrentValue = ConfigManager:Get("AimbotShowFOV"),
        Flag = "AimbotShowFOV",
        Callback = function(v) ConfigManager:Set("AimbotShowFOV", v) end,
    })
end

function RayfieldUI:CreateESPTab()
    local Tab = self.Window:CreateTab("ESP", 4483362458)
    
    Tab:CreateSection("Player ESP")
    
    Tab:CreateToggle({
        Name = "Enable Player ESP", CurrentValue = ConfigManager:Get("PlayerESP"), Flag = "PlayerESP",
        Callback = function(v) ConfigManager:Set("PlayerESP", v) end,
    })
    
    Tab:CreateToggle({
        Name = "Box ESP", CurrentValue = ConfigManager:Get("BoxESP"), Flag = "BoxESP",
        Callback = function(v) ConfigManager:Set("BoxESP", v) end,
    })
    
    Tab:CreateToggle({
        Name = "Name ESP", CurrentValue = ConfigManager:Get("NameESP"), Flag = "NameESP",
        Callback = function(v) ConfigManager:Set("NameESP", v) end,
    })
    
    Tab:CreateToggle({
        Name = "Distance ESP", CurrentValue = ConfigManager:Get("DistanceESP"), Flag = "DistanceESP",
        Callback = function(v) ConfigManager:Set("DistanceESP", v) end,
    })
    
    Tab:CreateToggle({
        Name = "Health ESP", CurrentValue = ConfigManager:Get("HealthESP"), Flag = "HealthESP",
        Callback = function(v) ConfigManager:Set("HealthESP", v) end,
    })
    
    Tab:CreateToggle({
        Name = "Tracers", CurrentValue = ConfigManager:Get("Tracers"), Flag = "Tracers",
        Callback = function(v) ConfigManager:Set("Tracers", v) end,
    })
    
    Tab:CreateToggle({
        Name = "Chams", CurrentValue = ConfigManager:Get("Chams"), Flag = "Chams",
        Callback = function(v) ConfigManager:Set("Chams", v) end,
    })
    
    Tab:CreateSection("Colors")
    
    Tab:CreateColorPicker({
        Name = "Enemy Color", Color = Utils:ColorFromConfig("ESPEnemyColor"), Flag = "EnemyColor",
        Callback = function(v)
            ConfigManager:Set("ESPEnemyColor", {R = math.floor(v.R*255), G = math.floor(v.G*255), B = math.floor(v.B*255)})
        end,
    })
end

function RayfieldUI:CreateNPCTab()
    local Tab = self.Window:CreateTab("NPC", 4483362458)
    
    Tab:CreateSection("Bot / NPC ESP")
    
    Tab:CreateToggle({
        Name = "Enable Bot ESP", CurrentValue = ConfigManager:Get("BotESP"), Flag = "BotESP",
        Callback = function(v) ConfigManager:Set("BotESP", v) end,
    })
    
    Tab:CreateToggle({
        Name = "Box ESP", CurrentValue = ConfigManager:Get("BotBoxESP"), Flag = "BotBoxESP",
        Callback = function(v) ConfigManager:Set("BotBoxESP", v) end,
    })
    
    Tab:CreateToggle({
        Name = "Name ESP", CurrentValue = ConfigManager:Get("BotNameESP"), Flag = "BotNameESP",
        Callback = function(v) ConfigManager:Set("BotNameESP", v) end,
    })
    
    Tab:CreateToggle({
        Name = "Distance ESP", CurrentValue = ConfigManager:Get("BotDistanceESP"), Flag = "BotDistanceESP",
        Callback = function(v) ConfigManager:Set("BotDistanceESP", v) end,
    })
    
    Tab:CreateToggle({
        Name = "Health ESP", CurrentValue = ConfigManager:Get("BotHealthESP"), Flag = "BotHealthESP",
        Callback = function(v) ConfigManager:Set("BotHealthESP", v) end,
    })
    
    Tab:CreateToggle({
        Name = "Tracers", CurrentValue = ConfigManager:Get("BotTracers"), Flag = "BotTracers",
        Callback = function(v) ConfigManager:Set("BotTracers", v) end,
    })
    
    Tab:CreateSection("Colors")
    
    Tab:CreateColorPicker({
        Name = "Bot Color", Color = Utils:ColorFromConfig("ESPBotColor"), Flag = "BotColor",
        Callback = function(v)
            ConfigManager:Set("ESPBotColor", {R = math.floor(v.R*255), G = math.floor(v.G*255), B = math.floor(v.B*255)})
        end,
    })
end

function RayfieldUI:CreateContainersTab()
    local Tab = self.Window:CreateTab("Containers", 4483362458)
    
    Tab:CreateSection("Loot / Container ESP")
    
    Tab:CreateToggle({
        Name = "Enable Loot ESP", CurrentValue = ConfigManager:Get("LootESP"), Flag = "LootESP",
        Callback = function(v) ConfigManager:Set("LootESP", v) end,
    })
    
    Tab:CreateToggle({
        Name = "Name ESP", CurrentValue = ConfigManager:Get("LootNameESP"), Flag = "LootNameESP",
        Callback = function(v) ConfigManager:Set("LootNameESP", v) end,
    })
    
    Tab:CreateToggle({
        Name = "Distance ESP", CurrentValue = ConfigManager:Get("LootDistanceESP"), Flag = "LootDistanceESP",
        Callback = function(v) ConfigManager:Set("LootDistanceESP", v) end,
    })
    
    Tab:CreateToggle({
        Name = "Tracers", CurrentValue = ConfigManager:Get("LootTracers"), Flag = "LootTracers",
        Callback = function(v) ConfigManager:Set("LootTracers", v) end,
    })
    
    Tab:CreateSection("Object ESP")
    
    Tab:CreateToggle({
        Name = "Extraction ESP", CurrentValue = ConfigManager:Get("ExtractionESP"), Flag = "ExtractionESP",
        Callback = function(v) ConfigManager:Set("ExtractionESP", v) end,
    })
    
    Tab:CreateToggle({
        Name = "Airdrop ESP", CurrentValue = ConfigManager:Get("AirdropESP"), Flag = "AirdropESP",
        Callback = function(v) ConfigManager:Set("AirdropESP", v) end,
    })
    
    Tab:CreateToggle({
        Name = "Dead Body ESP", CurrentValue = ConfigManager:Get("DeadBodyESP"), Flag = "DeadBodyESP",
        Callback = function(v) ConfigManager:Set("DeadBodyESP", v) end,
    })
    
    Tab:CreateSection("Colors")
    
    Tab:CreateColorPicker({
        Name = "Loot Color", Color = Utils:ColorFromConfig("ESPLootColor"), Flag = "LootColor",
        Callback = function(v)
            ConfigManager:Set("ESPLootColor", {R = math.floor(v.R*255), G = math.floor(v.G*255), B = math.floor(v.B*255)})
        end,
    })
    
    Tab:CreateColorPicker({
        Name = "Extraction Color", Color = Utils:ColorFromConfig("ESPExtractionColor"), Flag = "ExtractColor",
        Callback = function(v)
            ConfigManager:Set("ESPExtractionColor", {R = math.floor(v.R*255), G = math.floor(v.G*255), B = math.floor(v.B*255)})
        end,
    })
    
    Tab:CreateColorPicker({
        Name = "Airdrop Color", Color = Utils:ColorFromConfig("ESPAirdropColor"), Flag = "AirdropColor",
        Callback = function(v)
            ConfigManager:Set("ESPAirdropColor", {R = math.floor(v.R*255), G = math.floor(v.G*255), B = math.floor(v.B*255)})
        end,
    })
end

function RayfieldUI:CreateWorldTab()
    local Tab = self.Window:CreateTab("World", 4483362458)
    
    Tab:CreateSection("Lighting")
    
    Tab:CreateToggle({
        Name = "FullBright", CurrentValue = ConfigManager:Get("FullBright"), Flag = "FullBright",
        Callback = function(v) ConfigManager:Set("FullBright", v) end,
    })
    
    Tab:CreateToggle({
        Name = "Time Changer", CurrentValue = ConfigManager:Get("TimeChanger"), Flag = "TimeChanger",
        Callback = function(v) ConfigManager:Set("TimeChanger", v) end,
    })
    
    Tab:CreateSlider({
        Name = "Custom Time", Range = {0, 24}, Increment = 0.5, Suffix = "hr",
        CurrentValue = ConfigManager:Get("CustomTime"), Flag = "CustomTime",
        Callback = function(v) ConfigManager:Set("CustomTime", v) end,
    })
    
    Tab:CreateToggle({
        Name = "Remove Fog", CurrentValue = ConfigManager:Get("RemoveFog"), Flag = "RemoveFog",
        Callback = function(v) ConfigManager:Set("RemoveFog", v) end,
    })
    
    Tab:CreateToggle({
        Name = "Weather Toggle", CurrentValue = ConfigManager:Get("WeatherToggle"), Flag = "WeatherToggle",
        Callback = function(v) ConfigManager:Set("WeatherToggle", v) end,
    })
    
    Tab:CreateToggle({
        Name = "Show Interactive Objects", CurrentValue = ConfigManager:Get("ShowInteractive"), Flag = "ShowInteractive",
        Callback = function(v) ConfigManager:Set("ShowInteractive", v) end,
    })
end

function RayfieldUI:CreateMiscTab()
    local Tab = self.Window:CreateTab("Misc", 4483362458)
    
    Tab:CreateSection("Performance")
    
    Tab:CreateToggle({
        Name = "FPS Boost", CurrentValue = ConfigManager:Get("FPSBoost"), Flag = "FPSBoost",
        Callback = function(v) ConfigManager:Set("FPSBoost", v) end,
    })
    
    Tab:CreateSection("Teleport (Tween)")
    
    for _, extract in pairs(EXTRACTION_FOLDER:GetChildren()) do
        local name = ExtractionNames[extract.Name] or extract.Name
        Tab:CreateButton({
            Name = "TP: " .. name,
            Callback = function()
                pcall(function()
                    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                        local primary = extract:IsA("Model") and (extract.PrimaryPart or extract:FindFirstChildWhichIsA("BasePart")) or extract
                        if primary then
                            local root = LocalPlayer.Character.HumanoidRootPart
                            TweenService:Create(root, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                                CFrame = primary.CFrame + Vector3.new(0, 5, 0)
                            }):Play()
                        end
                    end
                end)
            end,
        })
    end
    
    Tab:CreateSection("Server")
    
    Tab:CreateButton({
        Name = "Rejoin Server",
        Callback = function()
            pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
        end,
    })
    
    Tab:CreateButton({
        Name = "Server Hop",
        Callback = function()
            pcall(function()
                local servers = game.HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
                for _, s in pairs(servers.data) do
                    if s.playing < s.maxPlayers and s.id ~= game.JobId then
                        TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
                        break
                    end
                end
            end)
        end,
    })
    
    Tab:CreateButton({
        Name = "Copy JobId", Callback = function() Utils:CopyToClipboard(game.JobId) end,
    })
    
    Tab:CreateButton({
        Name = "Copy PlaceId", Callback = function() Utils:CopyToClipboard(tostring(game.PlaceId)) end,
    })
end

function RayfieldUI:CreateSettingsTab()
    local Tab = self.Window:CreateTab("Settings", 4483362458)
    
    Tab:CreateSection("Config")
    
    Tab:CreateButton({
        Name = "Save Config",
        Callback = function()
            ConfigManager:Save()
            if ConfigManager:Get("Notifications") then
                self.Library:Notify({Title = "Saved", Content = "Config saved.", Duration = 3})
            end
        end,
    })
    
    Tab:CreateButton({
        Name = "Load Config",
        Callback = function()
            ConfigManager:Load()
            if ConfigManager:Get("Notifications") then
                self.Library:Notify({Title = "Loaded", Content = "Config loaded.", Duration = 3})
            end
        end,
    })
    
    Tab:CreateButton({
        Name = "Reset Config",
        Callback = function()
            ConfigManager:Reset()
            if ConfigManager:Get("Notifications") then
                self.Library:Notify({Title = "Reset", Content = "Defaults restored.", Duration = 3})
            end
        end,
    })
    
    Tab:CreateToggle({
        Name = "Auto Save", CurrentValue = ConfigManager.AutoSaveEnabled, Flag = "AutoSave",
        Callback = function(v) ConfigManager.AutoSaveEnabled = v end,
    })
    
    Tab:CreateSection("UI")
    
    Tab:CreateDropdown({
        Name = "Theme", Options = {"Default", "Ocean", "Midnight", "Sentinel", "Synapse", "Serpent"},
        CurrentOption = ConfigManager:Get("Theme"), Flag = "Theme",
        Callback = function(v) ConfigManager:Set("Theme", v) end,
    })
    
    Tab:CreateToggle({
        Name = "Notifications", CurrentValue = ConfigManager:Get("Notifications"), Flag = "Notifications",
        Callback = function(v) ConfigManager:Set("Notifications", v) end,
    })
    
    Tab:CreateKeybind({
        Name = "GUI Toggle", CurrentKeybind = ConfigManager:Get("GUIBind"), HoldToInteract = false, Flag = "GUIBind",
        Callback = function(k) ConfigManager:Set("GUIBind", tostring(k)) end,
    })
    
    Tab:CreateSection("Danger Zone")
    
    Tab:CreateButton({
        Name = "Destroy GUI",
        Callback = function()
            ConnectionManager:Clear()
            ESPManager:ClearAll()
            self.Library:Destroy()
        end,
    })
end

-- ═══════════════════════════════════════════════════════════════
-- BOOTSTRAP
-- ═══════════════════════════════════════════════════════════════
local function Bootstrap()
    ConfigManager:Init()
    ESPManager:Init()
    Aimbot:Init()
    WorldModule:Init()
    MiscModule:Init()
    RayfieldUI:Init()
    print("[XCMEN HUB] DesertStorm loaded!")
end

local ok, err = pcall(Bootstrap)
if not ok then
    warn("[XCMEN HUB] Error: " .. tostring(err))
end