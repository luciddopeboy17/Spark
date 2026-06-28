--[[
    ========================================================================
    ORION HUB LITE: LIGHTWEIGHT PROCEDURAL UI ENGINE & CONTROLLER (ADVANCED)
    ========================================================================
    
    A clean, modern, and high-performance Roblox UI script written from scratch.
    It builds a complete interface with smooth dragging, toggle animations,
    sliders, tab pages, window minimizing, and a smooth bottom-right resizer!
    
    How to Use:
    1. Copy this entire script.
    2. Paste it directly into your Roblox Executor in-game OR a LocalScript
       inside Roblox Studio (it automatically adjusts its environment!).
]]

-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- Environment configuration
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local TargetParent = RunService:IsStudio() and PlayerGui or (game:GetService("CoreGui") or PlayerGui)

local Camera = workspace.CurrentCamera
local EntitiesFolder = workspace:WaitForChild("Entities", 15)

-- Functional States
local AimbotEnabled = false
local EspEnabled = false
local EspHealthEnabled = false
local EspNameEnabled = false
local EspOutlineEnabled = false
local EspSkeletonEnabled = false
local EspColor = Color3.fromRGB(0, 255, 255)
local LockKey = Enum.KeyCode.E
local LockedTarget = nil
local AimTargetPart = "Head"
local fovCheckAimbotEnabled = false

-- Modern Dark Palette (Default "Orion Blue")
local COLORS = {
    Background = Color3.fromRGB(15, 15, 15),
    Sidebar = Color3.fromRGB(10, 10, 10),
    Card = Color3.fromRGB(22, 22, 22),
    Accent = Color3.fromRGB(0, 120, 255), -- Active Accent (Blue)
    AccentOff = Color3.fromRGB(45, 45, 45), -- Inactive Toggle capsule
    Border = Color3.fromRGB(30, 30, 30),
    TextMain = Color3.fromRGB(255, 255, 255),
    TextMuted = Color3.fromRGB(160, 160, 160),
    TextDim = Color3.fromRGB(90, 90, 90)
}

-- Registry to track accent colors for real-time theme swapping across the ENTIRE UI
local ThemeableObjects = {
    Backgrounds = {}, -- Main background panels
    Sidebars = {},    -- Side menu panels
    Cards = {},       -- Component container frames
    Borders = {},     -- Stroke outlines and dividers
    Texts = {},       -- Primary bold/medium titles
    TextMuted = {},   -- Regular body description text labels
    TextDim = {},     -- Tiny muted section category headers
    Accents = {},     -- Toggles capsule sliders
    Fills = {},       -- Slider track fills
    Indicators = {}   -- Navigation active tab lines
}

local function registerThemeable(element, category)
    if ThemeableObjects[category] then
        table.insert(ThemeableObjects[category], element)
    end
end

-- Theme Definitions (Sourced from your visual JSON palettes)
local THEME_PALETTES = {
    ["Orion Blue"]    = { Background = Color3.fromRGB(15, 15, 20), Sidebar = Color3.fromRGB(10, 10, 15), Card = Color3.fromRGB(22, 22, 30), Border = Color3.fromRGB(40, 40, 55), Accent = Color3.fromRGB(0, 170, 255), AccentOff = Color3.fromRGB(30, 30, 45), TextMain = Color3.fromRGB(255, 255, 255), TextMuted = Color3.fromRGB(160, 160, 180), TextDim = Color3.fromRGB(100, 100, 120) },
    ["Sunset Glow"]   = { Background = Color3.fromRGB(20, 12, 12), Sidebar = Color3.fromRGB(15, 8, 8), Card = Color3.fromRGB(30, 18, 18), Border = Color3.fromRGB(55, 30, 30), Accent = Color3.fromRGB(255, 100, 80), AccentOff = Color3.fromRGB(45, 20, 20), TextMain = Color3.fromRGB(255, 240, 240), TextMuted = Color3.fromRGB(180, 140, 140), TextDim = Color3.fromRGB(120, 80, 80) },
    ["Neon Purple"]   = { Background = Color3.fromRGB(12, 8, 18), Sidebar = Color3.fromRGB(8, 5, 12), Card = Color3.fromRGB(20, 12, 30), Border = Color3.fromRGB(40, 20, 60), Accent = Color3.fromRGB(180, 50, 255), AccentOff = Color3.fromRGB(30, 15, 45), TextMain = Color3.fromRGB(250, 240, 255), TextMuted = Color3.fromRGB(160, 130, 190), TextDim = Color3.fromRGB(100, 70, 130) },
    ["Midnight Gold"] = { Background = Color3.fromRGB(10, 10, 12), Sidebar = Color3.fromRGB(6, 6, 8), Card = Color3.fromRGB(16, 16, 20), Border = Color3.fromRGB(45, 40, 20), Accent = Color3.fromRGB(255, 200, 50), AccentOff = Color3.fromRGB(30, 28, 15), TextMain = Color3.fromRGB(255, 250, 230), TextMuted = Color3.fromRGB(170, 160, 130), TextDim = Color3.fromRGB(110, 100, 70) },
    ["Nord"]          = { Background = Color3.fromRGB(46, 52, 64), Sidebar = Color3.fromRGB(36, 41, 51), Card = Color3.fromRGB(59, 66, 82), Border = Color3.fromRGB(76, 86, 106), Accent = Color3.fromRGB(136, 192, 208), AccentOff = Color3.fromRGB(67, 76, 94), TextMain = Color3.fromRGB(236, 239, 244), TextMuted = Color3.fromRGB(216, 222, 233), TextDim = Color3.fromRGB(143, 188, 187) },
    ["Rosé"]          = { Background = Color3.fromRGB(30, 20, 22), Sidebar = Color3.fromRGB(22, 14, 16), Card = Color3.fromRGB(42, 28, 32), Border = Color3.fromRGB(66, 44, 50), Accent = Color3.fromRGB(255, 150, 180), AccentOff = Color3.fromRGB(54, 34, 40), TextMain = Color3.fromRGB(255, 240, 245), TextMuted = Color3.fromRGB(200, 170, 180), TextDim = Color3.fromRGB(140, 100, 110) },
    ["Midnight"]      = { Background = Color3.fromRGB(8, 8, 10), Sidebar = Color3.fromRGB(5, 5, 6), Card = Color3.fromRGB(14, 14, 18), Border = Color3.fromRGB(25, 25, 30), Gradient = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 40, 200)), ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 40, 200))}), Accent = Color3.fromRGB(120, 60, 255), AccentOff = Color3.fromRGB(20, 20, 25), TextMain = Color3.fromRGB(240, 240, 240), TextMuted = Color3.fromRGB(140, 140, 150), TextDim = Color3.fromRGB(80, 80, 90) },
    ["Dark"]          = { Background = Color3.fromRGB(18, 18, 18), Sidebar = Color3.fromRGB(12, 12, 12), Card = Color3.fromRGB(24, 24, 24), Border = Color3.fromRGB(45, 45, 45), Accent = Color3.fromRGB(255, 255, 255), AccentOff = Color3.fromRGB(35, 35, 35), TextMain = Color3.fromRGB(255, 255, 255), TextMuted = Color3.fromRGB(150, 150, 150), TextDim = Color3.fromRGB(80, 80, 80) },
    ["Graphite"]      = { Background = Color3.fromRGB(25, 25, 25), Sidebar = Color3.fromRGB(20, 20, 20), Card = Color3.fromRGB(35, 35, 35), Border = Color3.fromRGB(60, 60, 60), Accent = Color3.fromRGB(10, 132, 255), AccentOff = Color3.fromRGB(45, 45, 45), TextMain = Color3.fromRGB(240, 240, 240), TextMuted = Color3.fromRGB(170, 170, 170), TextDim = Color3.fromRGB(100, 100, 100) },
    ["Light"]         = { Background = Color3.fromRGB(245, 245, 245), Sidebar = Color3.fromRGB(255, 255, 255), Card = Color3.fromRGB(255, 255, 255), Border = Color3.fromRGB(220, 220, 220), Accent = Color3.fromRGB(0, 122, 255), AccentOff = Color3.fromRGB(210, 210, 210), TextMain = Color3.fromRGB(0, 0, 0), TextMuted = Color3.fromRGB(100, 100, 100), TextDim = Color3.fromRGB(150, 150, 150) },
    ["Vibrant Red"]   = { Background = Color3.fromRGB(15, 15, 15), Sidebar = Color3.fromRGB(10, 10, 10), Card = Color3.fromRGB(22, 22, 22), Border = Color3.fromRGB(30, 30, 30), Accent = Color3.fromRGB(255, 50, 50), AccentOff = Color3.fromRGB(50, 20, 20), TextMain = Color3.fromRGB(255, 255, 255), TextMuted = Color3.fromRGB(160, 160, 160), TextDim = Color3.fromRGB(90, 90, 90) },
    ["Emerald"]       = { Background = Color3.fromRGB(15, 15, 15), Sidebar = Color3.fromRGB(10, 10, 10), Card = Color3.fromRGB(22, 22, 22), Border = Color3.fromRGB(30, 30, 30), Accent = Color3.fromRGB(50, 220, 100), AccentOff = Color3.fromRGB(20, 50, 30), TextMain = Color3.fromRGB(255, 255, 255), TextMuted = Color3.fromRGB(160, 160, 160), TextDim = Color3.fromRGB(90, 90, 90) }
}

local UI_ELEMENTS = {}

-- Registry for active dropdowns
local activeDropdownMenu = nil

-- Function to close any active dropdown cleanly
local function closeActiveDropdown()
    if activeDropdownMenu then
        activeDropdownMenu:Destroy()
        activeDropdownMenu = nil
    end
end

-- Close active dropdown if clicking outside of its container
UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if activeDropdownMenu then
            local mousePos = UserInputService:GetMouseLocation()
            local absPos = activeDropdownMenu.AbsolutePosition
            local absSize = activeDropdownMenu.AbsoluteSize
            
            if mousePos.X < absPos.X or mousePos.X > absPos.X + absSize.X or
               mousePos.Y < absPos.Y or mousePos.Y > absPos.Y + absSize.Y then
                task.defer(closeActiveDropdown)
            end
        end
    end
end)

-- Tween Speed Configurations
local TWEEN_INFO = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Clean-up existing OrionUI instances to prevent overlapping execution
local oldUI = TargetParent:FindFirstChild("OrionUILite")
if oldUI then oldUI:Destroy() end

------------------------------------------------------------------------
-- DRAWING OVERLAY FOR INTERACTIVE FOV RING
------------------------------------------------------------------------
local FOVCircle = nil
local fovEnabled = false
local fovRadius = 120
local fovColor = Color3.fromRGB(0, 240, 255)

-- Safely instantiate dynamic viewport overlay to support exploit executors
local hasDrawing = pcall(function()
    return Drawing ~= nil
end)

if hasDrawing then
    pcall(function()
        FOVCircle = Drawing.new("Circle")
        FOVCircle.Visible = false
        FOVCircle.Thickness = 1.5
        FOVCircle.NumSides = 64
        FOVCircle.Filled = false
        FOVCircle.Radius = fovRadius
        FOVCircle.Color = fovColor
    end)
end

-- Hook up render loop to track the cursor positions cleanly
RunService.RenderStepped:Connect(function()
    if FOVCircle then
        pcall(function()
            FOVCircle.Visible = fovEnabled
            if fovEnabled then
                FOVCircle.Position = UserInputService:GetMouseLocation()
                FOVCircle.Radius = fovRadius
                FOVCircle.Color = fovColor
            end
        end)
    end
end)

------------------------------------------------------------------------
-- UTILITY CREATION HELPERS
------------------------------------------------------------------------
local function create(className, properties)
    local inst = Instance.new(className)
    for k, v in pairs(properties) do
        inst[k] = v
    end
    return inst
end

local function addCorner(parent, radius)
    return create("UICorner", {
        CornerRadius = UDim.new(0, radius),
        Parent = parent
    })
end

local function addStroke(parent, color, thickness)
    return create("UIStroke", {
        Color = color,
        Thickness = thickness,
        Transparency = 0.2,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
        Parent = parent
    })
end

------------------------------------------------------------------------
-- DYNAMIC MOTION ENGINES (Toggles, Sliders, Dragging, Resizing)
------------------------------------------------------------------------
local isMinimized = false
local normalSize = UDim2.new(0, 600, 0, 420) -- Default premium larger size

local function makeDraggable(topBar, frameToDrag)
    local dragging, dragInput, dragStart, startPos
    
    topBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frameToDrag.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    topBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            local targetPos = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X, 
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
            TweenService:Create(frameToDrag, TWEEN_INFO, {Position = targetPos}):Play()
        end
    end)
end

local function makeResizable(resizerBtn, frameToResize, sidebar, contentArea)
    local resizing = false
    local resizeStart = Vector2.new()
    local startSize = Vector2.new()
    
    resizerBtn.InputBegan:Connect(function(input)
        if isMinimized then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            resizing = true
            resizeStart = input.Position
            startSize = Vector2.new(frameToResize.AbsoluteSize.X, frameToResize.AbsoluteSize.Y)
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    resizing = false
                end
            end)
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - resizeStart
            local targetWidth = math.clamp(startSize.X + delta.X, 480, 800)
            local targetHeight = math.clamp(startSize.Y + delta.Y, 320, 600)
            
            normalSize = UDim2.new(0, targetWidth, 0, targetHeight)
            TweenService:Create(frameToResize, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = normalSize
            }):Play()
        end
    end)
end

------------------------------------------------------------------------
-- MAIN INTERFACE BUILDER
------------------------------------------------------------------------
-- 1. ScreenGui Container
local ScreenGui = create("ScreenGui", {
    Name = "OrionUILite",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = true,
    Parent = TargetParent
})

-- 2. Centralized Canvas Main Wrapper
local MainFrame = create("Frame", {
    Size = normalSize,
    Position = UDim2.new(0.5, 0, 0.5, 0),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = COLORS.Background,
    BackgroundTransparency = 0.05,
    Active = true,
    ClipsDescendants = true,
    Parent = ScreenGui
})
addCorner(MainFrame, 12)
local MainFrameStroke = addStroke(MainFrame, COLORS.Border, 1.2)
registerThemeable(MainFrame, "Backgrounds")
registerThemeable(MainFrameStroke, "Borders")

-- 3. TopBar Dragging Zone & Window Controls
local TopBar = create("Frame", {
    Size = UDim2.new(1, 0, 0, 38),
    BackgroundColor3 = COLORS.Background,
    BackgroundTransparency = 1,
    Parent = MainFrame
})
makeDraggable(TopBar, MainFrame)

local TitleLabel = create("TextLabel", {
    Size = UDim2.new(0.5, 0, 1, 0),
    Position = UDim2.new(0, 15, 0, 0),
    BackgroundTransparency = 1,
    Text = "Orion Hub",
    TextColor3 = COLORS.TextMain,
    TextSize = 14,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = TopBar
})
registerThemeable(TitleLabel, "Texts")

-- Sidebar Area
local Sidebar = create("Frame", {
    Size = UDim2.new(0, 150, 1, -38),
    Position = UDim2.new(0, 0, 0, 38),
    BackgroundColor3 = COLORS.Sidebar,
    BackgroundTransparency = 1,
    Parent = MainFrame
})
registerThemeable(Sidebar, "Sidebars")

-- Content Container
local ContentContainer = create("Frame", {
    Size = UDim2.new(1, -160, 1, -50),
    Position = UDim2.new(0, 155, 0, 45),
    BackgroundTransparency = 1,
    Parent = MainFrame
})

-- Corner Modern Custom Resizer
local Resizer = create("TextButton", {
    Size = UDim2.new(0, 15, 0, 15),
    Position = UDim2.new(1, -15, 1, -15),
    BackgroundTransparency = 1,
    Text = "◢",
    TextColor3 = COLORS.TextDim,
    TextSize = 12,
    Font = Enum.Font.Gotham,
    AutoButtonColor = false,
    ZIndex = 10,
    Parent = MainFrame
})
makeResizable(Resizer, MainFrame, Sidebar, ContentContainer)
registerThemeable(Resizer, "TextDim")

-- Window Controls (Minimize / Close)
local CloseBtn = create("TextButton", {
    Size = UDim2.new(0, 24, 0, 24),
    Position = UDim2.new(1, -34, 0.5, -12),
    BackgroundColor3 = COLORS.Card,
    BackgroundTransparency = 1,
    Text = "×",
    TextColor3 = COLORS.TextDim,
    TextSize = 18,
    Font = Enum.Font.GothamBold,
    AutoButtonColor = false,
    Parent = TopBar
})

local MinimizeBtn = create("TextButton", {
    Size = UDim2.new(0, 24, 0, 24),
    Position = UDim2.new(1, -64, 0.5, -12),
    BackgroundColor3 = COLORS.Card,
    BackgroundTransparency = 1,
    Text = "-",
    TextColor3 = COLORS.TextDim,
    TextSize = 18,
    Font = Enum.Font.GothamBold,
    AutoButtonColor = false,
    Parent = TopBar
})

-- Control Buttons Hovers and Actions
CloseBtn.MouseEnter:Connect(function()
    TweenService:Create(CloseBtn, TWEEN_INFO, {TextColor3 = Color3.fromRGB(255, 75, 75)}):Play()
end)
CloseBtn.MouseLeave:Connect(function()
    TweenService:Create(CloseBtn, TWEEN_INFO, {TextColor3 = COLORS.TextDim}):Play()
end)
CloseBtn.MouseButton1Click:Connect(function()
    if FOVCircle then
        pcall(function() FOVCircle:Destroy() end)
    end
    ScreenGui:Destroy()
end)

MinimizeBtn.MouseEnter:Connect(function()
    TweenService:Create(MinimizeBtn, TWEEN_INFO, {TextColor3 = COLORS.Accent}):Play()
end)
MinimizeBtn.MouseLeave:Connect(function()
    TweenService:Create(MinimizeBtn, TWEEN_INFO, {TextColor3 = COLORS.TextDim}):Play()
end)
MinimizeBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    local targetSize = isMinimized and UDim2.new(0, normalSize.X.Offset, 0, 38) or normalSize
    
    -- Smoothly toggle the panel layouts
    Sidebar.Visible = not isMinimized
    ContentContainer.Visible = not isMinimized
    Resizer.Visible = not isMinimized
    
    TweenService:Create(MainFrame, TWEEN_INFO, {Size = targetSize}):Play()
end)

-- Divider Border Line
local TopDividerLine = create("Frame", {
    Size = UDim2.new(1, -20, 0, 1),
    Position = UDim2.new(0, 10, 0, 37),
    BackgroundColor3 = COLORS.Border,
    BorderSizePixel = 0,
    Parent = TopBar
})
registerThemeable(TopDividerLine, "Borders")

-- Sidebar Navigation Layout
local TabButtonsList = create("UIListLayout", {
    Padding = UDim.new(0, 6),
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = Sidebar
})

create("UIPadding", {
    PaddingTop = UDim.new(0, 12),
    Parent = Sidebar
})

------------------------------------------------------------------------
-- PROCEDURAL TAB & COMPONENT INITIALIZER
------------------------------------------------------------------------
local Tabs = {}
local ActiveTab = nil

local function registerTab(name)
    local button = create("TextButton", {
        Size = UDim2.new(0, 130, 0, 34),
        BackgroundColor3 = COLORS.Card,
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Parent = Sidebar
    })
    addCorner(button, 8)
    registerThemeable(button, "Cards")
    
    local label = create("TextLabel", {
        Size = UDim2.new(1, -12, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = name,
        TextColor3 = COLORS.TextMuted,
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = button
    })
    registerThemeable(label, "TextMuted")

    local indicator = create("Frame", {
        Size = UDim2.new(0, 3, 0, 0),
        Position = UDim2.new(0, 2, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = COLORS.Accent,
        BorderSizePixel = 0,
        Parent = button
    })
    addCorner(indicator, 2)
    registerThemeable(indicator, "Indicators")
    
    -- Hidden Page layout
    local page = create("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Visible = false,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = COLORS.Border,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent = ContentContainer
    })
    
    create("UIListLayout", {
        Padding = UDim.new(0, 10),
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = page
    })

    create("UIPadding", {
        PaddingTop = UDim.new(0, 5),
        PaddingBottom = UDim.new(0, 5),
        Parent = page
    })

    -- Function to display page smoothly
    local function selectTab()
        if ActiveTab then
            ActiveTab.Page.Visible = false
            TweenService:Create(ActiveTab.Button, TWEEN_INFO, {BackgroundTransparency = 1}):Play()
            TweenService:Create(ActiveTab.Label, TWEEN_INFO, {TextColor3 = COLORS.TextMuted}):Play()
            TweenService:Create(ActiveTab.Indicator, TWEEN_INFO, {Size = UDim2.new(0, 3, 0, 0)}):Play()
        end
        
        ActiveTab = {Button = button, Page = page, Label = label, Indicator = indicator}
        page.Visible = true
        TweenService:Create(button, TWEEN_INFO, {BackgroundTransparency = 0}):Play()
        TweenService:Create(label, TWEEN_INFO, {TextColor3 = COLORS.TextMain}):Play()
        TweenService:Create(indicator, TWEEN_INFO, {Size = UDim2.new(0, 3, 0.6, 0)}):Play()
    end
    
    button.MouseButton1Click:Connect(selectTab)
    
    Tabs[name] = {Button = button, Page = page, Select = selectTab}
    return page
end

-- Custom Component Builders inside Pages
local function addHeader(text, page)
    local header = create("Frame", {
        Size = UDim2.new(0.92, 0, 0, 24),
        BackgroundTransparency = 1,
        Parent = page
    })
    
    local label = create("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = string.upper(text),
        TextColor3 = COLORS.TextDim,
        TextSize = 10,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = header
    })
    registerThemeable(label, "TextDim")
end

local function addToggle(labelText, page, default, callback)
    local container = create("Frame", {
        Size = UDim2.new(0.92, 0, 0, 42),
        BackgroundColor3 = COLORS.Card,
        Parent = page
    })
    addCorner(container, 8)
    local border = addStroke(container, COLORS.Border, 1)
    registerThemeable(container, "Cards")
    registerThemeable(border, "Borders")

    local label = create("TextLabel", {
        Size = UDim2.new(0.7, 0, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = labelText,
        TextColor3 = COLORS.TextMain,
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = container
    })
    registerThemeable(label, "Texts")

    local capsule = create("TextButton", {
        Size = UDim2.new(0, 38, 0, 20),
        Position = UDim2.new(1, -50, 0.5, -10),
        BackgroundColor3 = COLORS.AccentOff,
        Text = "",
        AutoButtonColor = false,
        Parent = container
    })
    addCorner(capsule, 10)
    registerThemeable(capsule, "Accents")

    local knob = create("Frame", {
        Size = UDim2.new(0, 14, 0, 14),
        Position = UDim2.new(0, 3, 0.5, -7),
        BackgroundColor3 = COLORS.TextMain,
        Parent = capsule
    })
    addCorner(knob, 8)

    local state = default or false
    
    local function updateToggle(instant)
        local targetPos = state and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
        local targetColor = state and COLORS.Accent or COLORS.AccentOff
        
        if instant then
            knob.Position = targetPos
            capsule.BackgroundColor3 = targetColor
        else
            TweenService:Create(knob, TWEEN_INFO, {Position = targetPos}):Play()
            TweenService:Create(capsule, TWEEN_INFO, {BackgroundColor3 = targetColor}):Play()
        end
        callback(state)
    end

    capsule.MouseButton1Click:Connect(function()
        state = not state
        updateToggle(false)
    end)

    updateToggle(true)
    
    UI_ELEMENTS[labelText] = {
        Type = "Toggle",
        Set = function(val)
            state = val
            updateToggle(true)
        end,
        Get = function() return state end
    }
end

local function addSlider(labelText, min, max, default, page, callback)
    local container = create("Frame", {
        Size = UDim2.new(0.92, 0, 0, 54),
        BackgroundColor3 = COLORS.Card,
        Parent = page
    })
    addCorner(container, 8)
    local border = addStroke(container, COLORS.Border, 1)
    registerThemeable(container, "Cards")
    registerThemeable(border, "Borders")

    local label = create("TextLabel", {
        Size = UDim2.new(0.7, 0, 0, 24),
        Position = UDim2.new(0, 12, 0, 4),
        BackgroundTransparency = 1,
        Text = labelText,
        TextColor3 = COLORS.TextMain,
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = container
    })
    registerThemeable(label, "Texts")

    local valLabel = create("TextLabel", {
        Size = UDim2.new(0.2, 0, 0, 24),
        Position = UDim2.new(1, -82, 0, 4),
        BackgroundTransparency = 1,
        Text = tostring(default),
        TextColor3 = COLORS.Accent,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = container
    })
    registerThemeable(valLabel, "Texts")

    local sliderTrack = create("Frame", {
        Size = UDim2.new(1, -24, 0, 6),
        Position = UDim2.new(0, 12, 0, 36),
        BackgroundColor3 = COLORS.AccentOff,
        BorderSizePixel = 0,
        Parent = container
    })
    addCorner(sliderTrack, 3)

    local fill = create("Frame", {
        Size = UDim2.new((default - min) / (max - min), 0, 1, 0),
        BackgroundColor3 = COLORS.Accent,
        BorderSizePixel = 0,
        Parent = sliderTrack
    })
    addCorner(fill, 3)
    registerThemeable(fill, "Fills")

    local knob = create("Frame", {
        Size = UDim2.new(0, 12, 0, 12),
        Position = UDim2.new((default - min) / (max - min), -6, 0.5, -6),
        BackgroundColor3 = COLORS.TextMain,
        Parent = sliderTrack
    })
    addCorner(knob, 6)

    local isSliding = false

    local function updateSlider(input)
        local percentage = math.clamp((input.Position.X - sliderTrack.AbsolutePosition.X) / sliderTrack.AbsoluteSize.X, 0, 1)
        local value = math.round(min + (percentage * (max - min)))
        
        valLabel.Text = tostring(value)
        TweenService:Create(fill, TweenInfo.new(0.08), {Size = UDim2.new(percentage, 0, 1, 0)}):Play()
        TweenService:Create(knob, TweenInfo.new(0.08), {Position = UDim2.new(percentage, -6, 0.5, -6)}):Play()
        
        callback(value)
    end

    sliderTrack.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isSliding = true
            updateSlider(input)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if isSliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateSlider(input)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isSliding = false
        end
    end)
    
    UI_ELEMENTS[labelText] = {
        Type = "Slider",
        Set = function(val)
            local clamped = math.clamp(val, min, max)
            local percentage = (clamped - min) / (max - min)
            valLabel.Text = tostring(clamped)
            fill.Size = UDim2.new(percentage, 0, 1, 0)
            knob.Position = UDim2.new(percentage, -6, 0.5, -6)
            callback(clamped)
        end
    }
end

-- UPGRADED PREMIUM DROPDOWN WITH VISUAL COLOR & GRADIENT BOX PREVIEWS
local function addDropdown(labelText, options, default, page, callback)
    local container = create("Frame", {
        Size = UDim2.new(0.92, 0, 0, 42),
        BackgroundColor3 = COLORS.Card,
        Parent = page
    })
    addCorner(container, 8)
    local border = addStroke(container, COLORS.Border, 1)
    registerThemeable(container, "Cards")
    registerThemeable(border, "Borders")

    local label = create("TextLabel", {
        Size = UDim2.new(0.5, 0, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = labelText,
        TextColor3 = COLORS.TextMain,
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = container
    })
    registerThemeable(label, "Texts")

    -- Selected item container button
    local selector = create("TextButton", {
        Size = UDim2.new(0, 130, 0, 26),
        Position = UDim2.new(1, -142, 0.5, -13),
        BackgroundColor3 = COLORS.Background,
        Text = "",
        AutoButtonColor = false,
        Parent = container
    })
    addCorner(selector, 6)
    local selBorder = addStroke(selector, COLORS.Border, 1)
    registerThemeable(selector, "Backgrounds")
    registerThemeable(selBorder, "Borders")

    -- Dynamic selector preview indicator
    local selPreview = create("Frame", {
        Name = "Preview",
        Size = UDim2.new(0, 14, 0, 14),
        Position = UDim2.new(0, 6, 0.5, -7),
        BorderSizePixel = 0,
        Visible = false,
        Parent = selector
    })
    addCorner(selPreview, 4)

    -- Text label for selection box
    local selLabel = create("TextLabel", {
        Name = "Label",
        Size = UDim2.new(1, -12, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = tostring(default),
        TextColor3 = COLORS.Accent,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = selector
    })
    registerThemeable(selLabel, "Texts")

    -- Normalize options structure (support array of strings or visual tables)
    local parsedOptions = {}
    for _, opt in ipairs(options) do
        if type(opt) == "string" then
            table.insert(parsedOptions, {Name = opt})
        else
            table.insert(parsedOptions, opt)
        end
    end

    -- Setup initial visual state of selector box
    local function setSelectionVisuals(optName)
        local currentOpt = nil
        for _, opt in ipairs(parsedOptions) do
            if opt.Name == optName then
                currentOpt = opt
                break
            end
        end
        if not currentOpt then currentOpt = parsedOptions[1] end

        selLabel.Text = currentOpt.Name
        local activeGrad = selPreview:FindFirstChild("PreviewGrad")
        if activeGrad then activeGrad:Destroy() end

        if currentOpt.Color or currentOpt.Gradient then
            selPreview.Visible = true
            selLabel.Size = UDim2.new(1, -26, 1, 0)
            selLabel.Position = UDim2.new(0, 26, 0, 0)
            
            if currentOpt.Color then
                selPreview.BackgroundColor3 = currentOpt.Color
            elseif currentOpt.Gradient then
                selPreview.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                create("UIGradient", {
                    Name = "PreviewGrad",
                    Color = currentOpt.Gradient,
                    Parent = selPreview
                })
            end
        else
            selPreview.Visible = false
            selLabel.Size = UDim2.new(1, -12, 1, 0)
            selLabel.Position = UDim2.new(0, 12, 0, 0)
        end
    end

    setSelectionVisuals(default)

    -- Click listener to expand choices
    selector.MouseButton1Click:Connect(function()
        local dropName = labelText .. "_Dropdown"
        if activeDropdownMenu and activeDropdownMenu.Name == dropName then
            closeActiveDropdown()
            return
        end
        closeActiveDropdown()

        -- Floating Dropdown box scaled properly without page clipping
        local count = #parsedOptions
        local targetMenuHeight = math.min(count * 28 + 8, 150)

        local menu = create("Frame", {
            Name = dropName,
            Size = UDim2.new(0, selector.AbsoluteSize.X, 0, targetMenuHeight),
            Position = UDim2.new(0, selector.AbsolutePosition.X - MainFrame.AbsolutePosition.X, 0, selector.AbsolutePosition.Y - MainFrame.AbsolutePosition.Y + selector.AbsoluteSize.Y + 2),
            BackgroundColor3 = COLORS.Background,
            ZIndex = 100,
            Parent = MainFrame
        })
        addCorner(menu, 8)
        addStroke(menu, COLORS.Border, 1)

        local scroll = create("ScrollingFrame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            CanvasSize = UDim2.new(0, 0, 0, count * 28 + 4),
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = COLORS.Border,
            ZIndex = 101,
            Parent = menu
        })

        create("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 2),
            Parent = scroll
        })

        create("UIPadding", {
            PaddingTop = UDim.new(0, 4),
            PaddingBottom = UDim.new(0, 4),
            PaddingLeft = UDim.new(0, 4),
            PaddingRight = UDim.new(0, 4),
            Parent = scroll
        })

        for i, opt in ipairs(parsedOptions) do
            local optBtn = create("TextButton", {
                Size = UDim2.new(1, 0, 0, 24),
                BackgroundColor3 = COLORS.Card,
                BackgroundTransparency = 1,
                Text = "",
                AutoButtonColor = false,
                ZIndex = 102,
                LayoutOrder = i,
                Parent = scroll
            })
            addCorner(optBtn, 4)

            -- Item visual color marker
            local optPreview = create("Frame", {
                Size = UDim2.new(0, 14, 0, 14),
                Position = UDim2.new(0, 6, 0.5, -7),
                BorderSizePixel = 0,
                Visible = false,
                ZIndex = 103,
                Parent = optBtn
            })
            addCorner(optPreview, 4)

            local optLabel = create("TextLabel", {
                Size = UDim2.new(1, -12, 1, 0),
                Position = UDim2.new(0, 12, 0, 0),
                BackgroundTransparency = 1,
                Text = opt.Name,
                TextColor3 = COLORS.TextMuted,
                TextSize = 11,
                Font = Enum.Font.GothamMedium,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 103,
                Parent = optBtn
            })

            if opt.Color or opt.Gradient then
                optPreview.Visible = true
                optLabel.Size = UDim2.new(1, -26, 1, 0)
                optLabel.Position = UDim2.new(0, 26, 0, 0)

                if opt.Color then
                    optPreview.BackgroundColor3 = opt.Color
                elseif opt.Gradient then
                    optPreview.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                    create("UIGradient", {
                        Color = opt.Gradient,
                        Parent = optPreview
                    })
                end
            end

            -- Click and hover sequences
            optBtn.MouseEnter:Connect(function()
                TweenService:Create(optBtn, TWEEN_INFO, {BackgroundTransparency = 0}):Play()
                TweenService:Create(optLabel, TWEEN_INFO, {TextColor3 = COLORS.TextMain}):Play()
            end)
            optBtn.MouseLeave:Connect(function()
                TweenService:Create(optBtn, TWEEN_INFO, {BackgroundTransparency = 1}):Play()
                TweenService:Create(optLabel, TWEEN_INFO, {TextColor3 = COLORS.TextMuted}):Play()
            end)

            optBtn.MouseButton1Click:Connect(function()
                setSelectionVisuals(opt.Name)
                callback(opt.Name)
                closeActiveDropdown()
            end)
        end

        activeDropdownMenu = menu
    end)
    
    UI_ELEMENTS[labelText] = {
        Type = "Dropdown",
        Set = function(val)
            setSelectionVisuals(val)
            callback(val)
        end,
        UpdateOptions = function(newOptions)
            parsedOptions = {}
            for _, opt in ipairs(newOptions) do
                if type(opt) == "string" then
                    table.insert(parsedOptions, {Name = opt})
                else
                    table.insert(parsedOptions, opt)
                end
            end
            local found = false
            for _, opt in ipairs(parsedOptions) do
                if opt.Name == selLabel.Text then found = true; break end
            end
            if not found and #parsedOptions > 0 then
                setSelectionVisuals(parsedOptions[1].Name)
                callback(parsedOptions[1].Name)
            elseif #parsedOptions == 0 then
                selLabel.Text = "None"
                selPreview.Visible = false
            end
        end
    }
end

local function addKeybind(labelText, default, page, callback)
    local container = create("Frame", {
        Size = UDim2.new(0.92, 0, 0, 42),
        BackgroundColor3 = COLORS.Card,
        Parent = page
    })
    addCorner(container, 8)
    local border = addStroke(container, COLORS.Border, 1)
    registerThemeable(container, "Cards")
    registerThemeable(border, "Borders")

    local label = create("TextLabel", {
        Size = UDim2.new(0.5, 0, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = labelText,
        TextColor3 = COLORS.TextMain,
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = container
    })
    registerThemeable(label, "Texts")

    local bindBtn = create("TextButton", {
        Size = UDim2.new(0, 100, 0, 26),
        Position = UDim2.new(1, -112, 0.5, -13),
        BackgroundColor3 = COLORS.Background,
        Text = default and default.Name or "None",
        TextColor3 = COLORS.TextMuted,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        AutoButtonColor = false,
        Parent = container
    })
    addCorner(bindBtn, 6)
    local bindBorder = addStroke(bindBtn, COLORS.Border, 1)
    registerThemeable(bindBtn, "Backgrounds")
    registerThemeable(bindBorder, "Borders")

    local isBinding = false
    local keybind = default

    bindBtn.MouseButton1Click:Connect(function()
        if isBinding then return end
        isBinding = true
        bindBtn.Text = "..."
        local connection
        connection = UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Keyboard then
                local key = input.KeyCode
                if key == Enum.KeyCode.Escape then
                    keybind = nil
                    bindBtn.Text = "None"
                else
                    keybind = key
                    bindBtn.Text = key.Name
                end
                isBinding = false
                callback(keybind)
                connection:Disconnect()
            end
        end)
    end)
end

-- NEW: ADD TEXT BOX COMPONENT
local function addTextBox(labelText, placeholder, page, callback)
    local container = create("Frame", {
        Size = UDim2.new(0.92, 0, 0, 42),
        BackgroundColor3 = COLORS.Card,
        Parent = page
    })
    addCorner(container, 8)
    local border = addStroke(container, COLORS.Border, 1)
    registerThemeable(container, "Cards")
    registerThemeable(border, "Borders")

    local label = create("TextLabel", {
        Size = UDim2.new(0.5, 0, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = labelText,
        TextColor3 = COLORS.TextMain,
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = container
    })
    registerThemeable(label, "Texts")

    local inputBox = create("TextBox", {
        Size = UDim2.new(0, 130, 0, 26),
        Position = UDim2.new(1, -142, 0.5, -13),
        BackgroundColor3 = COLORS.Background,
        Text = "",
        PlaceholderText = placeholder,
        PlaceholderColor3 = COLORS.TextDim,
        TextColor3 = COLORS.TextMain,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        ClearTextOnFocus = false,
        Parent = container
    })
    addCorner(inputBox, 6)
    local inputBorder = addStroke(inputBox, COLORS.Border, 1)
    registerThemeable(inputBox, "Backgrounds")
    registerThemeable(inputBorder, "Borders")
    
    inputBox.FocusLost:Connect(function(enterPressed)
        if callback then
            callback(inputBox.Text, enterPressed)
        end
    end)
    
    UI_ELEMENTS[labelText] = {
        Type = "TextBox",
        Get = function() return inputBox.Text end,
        Set = function(val) inputBox.Text = val; callback(val, false) end
    }
end

------------------------------------------------------------------------
-- MASTER THEME SWITCHER ENGINE (MUTATES OVERALL INTERFACE STYLING)
------------------------------------------------------------------------
local CurrentThemeName = "Orion Blue"
local function applyTheme(themeName)
    CurrentThemeName = themeName
    local theme = THEME_PALETTES[themeName]
    if not theme then return end

    -- Update internal configurations dynamically
    COLORS.Background = theme.Background
    COLORS.Sidebar = theme.Sidebar
    COLORS.Card = theme.Card
    COLORS.Border = theme.Border
    COLORS.Accent = theme.Accent
    COLORS.TextMain = theme.TextMain
    COLORS.TextMuted = theme.TextMuted
    COLORS.TextDim = theme.TextDim

    local isGradient = theme.Gradient ~= nil
    local selectedAccent = isGradient and theme.Gradient.Keypoints[1].Value or theme.Accent

    local function tweenBg(obj, targetColor)
        if obj and obj.Parent then
            TweenService:Create(obj, TWEEN_INFO, {BackgroundColor3 = targetColor}):Play()
        end
    end

    local function tweenText(obj, targetColor)
        if obj and obj.Parent then
            TweenService:Create(obj, TWEEN_INFO, {TextColor3 = targetColor}):Play()
        end
    end

    local function tweenBorder(obj, targetColor)
        if obj and obj.Parent then
            if obj:IsA("UIStroke") then
                TweenService:Create(obj, TWEEN_INFO, {Color = targetColor}):Play()
            else
                TweenService:Create(obj, TWEEN_INFO, {BackgroundColor3 = targetColor}):Play()
            end
        end
    end

    -- Smooth color sweeps
    for _, obj in ipairs(ThemeableObjects.Backgrounds) do
        tweenBg(obj, theme.Background)
    end
    for _, obj in ipairs(ThemeableObjects.Sidebars) do
        tweenBg(obj, theme.Sidebar)
    end
    for _, obj in ipairs(ThemeableObjects.Cards) do
        tweenBg(obj, theme.Card)
    end
    for _, obj in ipairs(ThemeableObjects.Texts) do
        tweenText(obj, theme.TextMain)
    end
    for _, obj in ipairs(ThemeableObjects.TextMuted) do
        tweenText(obj, theme.TextMuted)
    end
    for _, obj in ipairs(ThemeableObjects.TextDim) do
        tweenText(obj, theme.TextDim)
    end

    -- Process borders and line dividers
    for _, obj in ipairs(ThemeableObjects.Borders) do
        if obj and obj.Parent then
            local existingGrad = obj:FindFirstChild("ActiveThemeGradient")
            if existingGrad then existingGrad:Destroy() end

            if isGradient then
                if obj:IsA("UIStroke") then
                    create("UIGradient", {
                        Name = "ActiveThemeGradient",
                        Color = theme.Gradient,
                        Parent = obj
                    })
                else -- Frame divider lines
                    obj.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                    create("UIGradient", {
                        Name = "ActiveThemeGradient",
                        Color = theme.Gradient,
                        Parent = obj
                    })
                end
            else
                tweenBorder(obj, theme.Border)
            end
        end
    end

    -- Process toggles capsules
    for _, obj in ipairs(ThemeableObjects.Accents) do
        if obj and obj.Parent then
            local existingGrad = obj:FindFirstChild("ActiveThemeGradient")
            if existingGrad then existingGrad:Destroy() end

            local knob = obj:FindFirstChild("Knob")
            local isActive = knob and knob.Position.X.Scale > 0.5
            if isActive then
                if isGradient then
                    create("UIGradient", {
                        Name = "ActiveThemeGradient",
                        Color = theme.Gradient,
                        Parent = obj
                    })
                else
                    TweenService:Create(obj, TWEEN_INFO, {BackgroundColor3 = selectedAccent}):Play()
                end
            else
                TweenService:Create(obj, TWEEN_INFO, {BackgroundColor3 = COLORS.AccentOff}):Play()
            end
        end
    end

    -- Process slider fills
    for _, obj in ipairs(ThemeableObjects.Fills) do
        if obj and obj.Parent then
            local existingGrad = obj:FindFirstChild("ActiveThemeGradient")
            if existingGrad then existingGrad:Destroy() end

            if isGradient then
                create("UIGradient", {
                    Name = "ActiveThemeGradient",
                    Color = theme.Gradient,
                    Parent = obj
                })
            else
                TweenService:Create(obj, TWEEN_INFO, {BackgroundColor3 = selectedAccent}):Play()
            end
        end
    end

    -- Process tab markers
    for _, obj in ipairs(ThemeableObjects.Indicators) do
        if obj and obj.Parent then
            local existingGrad = obj:FindFirstChild("ActiveThemeGradient")
            if existingGrad then existingGrad:Destroy() end

            if obj.Size.Y.Scale > 0.1 then
                if isGradient then
                    create("UIGradient", {
                        Name = "ActiveThemeGradient",
                        Color = theme.Gradient,
                        Parent = obj
                    })
                else
                    TweenService:Create(obj, TWEEN_INFO, {BackgroundColor3 = selectedAccent}):Play()
                end
            end
        end
    end
end

-- CUSTOM GRID-BASED THEME SELECTOR BLOCK
local function addThemeSelector(page)
    local container = create("Frame", {
        Size = UDim2.new(0.92, 0, 0, 185), -- Grid Card Container layout
        BackgroundColor3 = COLORS.Card,
        Parent = page
    })
    addCorner(container, 8)
    local border = addStroke(container, COLORS.Border, 1)
    registerThemeable(container, "Cards")
    registerThemeable(border, "Borders")

    local header = create("TextLabel", {
        Size = UDim2.new(1, -24, 0, 24),
        Position = UDim2.new(0, 12, 0, 8),
        BackgroundTransparency = 1,
        Text = "SELECT VISUAL THEMING PALETTE",
        TextColor3 = COLORS.TextDim,
        TextSize = 10,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = container
    })
    registerThemeable(header, "TextDim")

    local gridFrame = create("Frame", {
        Size = UDim2.new(1, -24, 1, -40),
        Position = UDim2.new(0, 12, 0, 32),
        BackgroundTransparency = 1,
        Parent = container
    })

    local gridLayout = create("UIGridLayout", {
        CellSize = UDim2.new(0.31, 0, 0, 32),
        CellPadding = UDim2.new(0.035, 0, 0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = gridFrame
    })

    -- Premium catalog themes
    local themeOrder = {
        "Orion Blue", "Sunset Glow", "Neon Purple",
        "Midnight Gold", "Nord", "Rosé",
        "Midnight", "Dark", "Graphite", "Light"
    }

    local themeButtons = {}

    for i, themeName in ipairs(themeOrder) do
        local themeData = THEME_PALETTES[themeName]
        if themeData then
            local btn = create("TextButton", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundColor3 = COLORS.Background,
                Text = "",
                AutoButtonColor = false,
                LayoutOrder = i,
                Parent = gridFrame
            })
            addCorner(btn, 6)
            local btnBorder = addStroke(btn, COLORS.Border, 1)
            registerThemeable(btn, "Backgrounds")
            registerThemeable(btnBorder, "Borders")

            -- Dynamic visual indicators
            local preview = create("Frame", {
                Size = UDim2.new(0, 12, 0, 12),
                Position = UDim2.new(0, 8, 0.5, -6),
                BorderSizePixel = 0,
                Parent = btn
            })
            addCorner(preview, 3)

            if themeData.Gradient then
                create("UIGradient", {
                    Color = themeData.Gradient,
                    Parent = preview
                })
            else
                preview.BackgroundColor3 = themeData.Accent
            end

            local label = create("TextLabel", {
                Size = UDim2.new(1, -28, 1, 0),
                Position = UDim2.new(0, 28, 0, 0),
                BackgroundTransparency = 1,
                Text = themeName,
                TextColor3 = COLORS.TextMuted,
                TextSize = 10,
                Font = Enum.Font.GothamMedium,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = btn
            })
            registerThemeable(label, "TextMuted")

            -- Highlight state trigger callback
            btn.MouseButton1Click:Connect(function()
                applyTheme(themeName)
                for tName, otherData in pairs(themeButtons) do
                    if tName == themeName then
                        otherData.Stroke.Color = COLORS.Accent
                        otherData.Label.TextColor3 = COLORS.TextMain
                    else
                        otherData.Stroke.Color = COLORS.Border
                        otherData.Label.TextColor3 = COLORS.TextMuted
                    end
                end
            end)

            themeButtons[themeName] = { Button = btn, Stroke = btnBorder, Label = label }
        end
    end

    -- Pre-select initial standard theme state
    if themeButtons["Orion Blue"] then
        themeButtons["Orion Blue"].Stroke.Color = COLORS.Accent
        themeButtons["Orion Blue"].Label.TextColor3 = COLORS.TextMain
    end
end

------------------------------------------------------------------------
-- SKELETON RENDER MANAGER (3D R6 JOINT ADORNMENTS)
------------------------------------------------------------------------
local ActiveSkeletons = {}

local function cleanSkeleton(entity)
    if ActiveSkeletons[entity] then
        for _, adorn in ipairs(ActiveSkeletons[entity]) do
            adorn:Destroy()
        end
        ActiveSkeletons[entity] = nil
    end
end

local function drawLine(part1, part2)
    local adorn = Instance.new("LineHandleAdornment")
    adorn.Thickness = 3.5
    adorn.Color3 = EspColor
    adorn.Transparency = 0
    adorn.AlwaysOnTop = true
    adorn.ZIndex = 5
    adorn.Parent = workspace.Terrain
    return adorn
end

local function applySkeleton(entity)
    if not EspSkeletonEnabled or not entity:IsA("Model") or entity.Name == LocalPlayer.Name then return end
    
    task.spawn(function()
        local torso = entity:WaitForChild("Torso", 5)
        local head = entity:WaitForChild("Head", 5)
        local leftArm = entity:WaitForChild("Left Arm", 5)
        local rightArm = entity:WaitForChild("Right Arm", 5)
        local leftLeg = entity:WaitForChild("Left Leg", 5)
        local rightLeg = entity:WaitForChild("Right Leg", 5)
        
        local hum = entity:FindFirstChildOfClass("Humanoid")
        if not (torso and head and leftArm and rightArm and leftLeg and rightLeg) then return end
        if hum and hum.Health <= 0 then return end
        
        cleanSkeleton(entity)
        
        local adornments = {
            drawLine(torso, head),
            drawLine(torso, leftArm),
            drawLine(torso, rightArm),
            drawLine(torso, leftLeg),
            drawLine(torso, rightLeg)
        }
        for _, adorn in ipairs(adornments) do adorn.Color3 = EspColor end
        
        ActiveSkeletons[entity] = adornments
    end)
end

RunService.RenderStepped:Connect(function()
    if EspSkeletonEnabled then
        for entity, adornments in pairs(ActiveSkeletons) do
            local hum = entity:FindFirstChildOfClass("Humanoid")
            if entity and entity.Parent and entity:FindFirstChild("Torso") and hum and hum.Health > 0 then
                local torso = entity.Torso
                local joints = {
                    entity:FindFirstChild("Head"),
                    entity:FindFirstChild("Left Arm"),
                    entity:FindFirstChild("Right Arm"),
                    entity:FindFirstChild("Left Leg"),
                    entity:FindFirstChild("Right Leg")
                }
                
                for idx, targetJoint in ipairs(joints) do
                    local adorn = adornments[idx]
                    if adorn and targetJoint then
                        local relativePos = torso.CFrame:PointToObjectSpace(targetJoint.Position)
                        adorn.Adornee = torso
                        adorn.CFrame = CFrame.new(Vector3.zero, relativePos)
                        adorn.Length = relativePos.Magnitude
                        adorn.Color3 = EspColor
                    end
                end
            else
                cleanSkeleton(entity)
            end
        end
    else
        for entity, _ in pairs(ActiveSkeletons) do
            cleanSkeleton(entity)
        end
    end
end)

------------------------------------------------------------------------
-- FUNCTIONAL ESP & INFO MANAGEMENT
------------------------------------------------------------------------
local function getEntityDisplayName(entity)
    -- Smart scanner to find custom nametags inside the entity model
    for _, desc in ipairs(entity:GetDescendants()) do
        if desc:IsA("TextLabel") or desc:IsA("TextButton") then
            local text = desc.Text
            if text and text ~= "" and text ~= "Label" and text ~= "TextLabel" then
                -- Look for common nametag identifiers in the parent or label name
                local pName = desc.Parent and desc.Parent.Name:lower() or ""
                local dName = desc.Name:lower()
                if pName:match("name") or pName:match("tag") or pName:match("billboard") or pName:match("title") or 
                   dName:match("name") or dName:match("tag") or dName:match("title") then
                    -- Clean rich text tags if any exist
                    local cleanText = text:gsub("<[^>]+>", "")
                    return cleanText
                end
            end
        end
    end
    -- Fallback to default name if no custom tag is found
    return entity.Name
end

local function applyESP(entity)
    if not entity:IsA("Model") or entity.Name == LocalPlayer.Name then return end
    
    task.spawn(function()
        local root = entity:WaitForChild("HumanoidRootPart", 5)
        local humanoid = entity:WaitForChild("Humanoid", 5)
        if not root or not humanoid then return end
        if humanoid.Health <= 0 then return end
        
        local old = nil
        for _, gui in ipairs(TargetParent:GetChildren()) do
            if ((gui:IsA("BillboardGui") and (gui.Name == "OrionESP_Box" or gui.Name == "OrionESP_Name" or gui.Name == "OrionESP_Health")) or 
               (gui:IsA("Highlight") and gui.Name == "OrionHighlight")) and 
               (gui.Adornee == root or gui.Adornee == entity) then
                gui:Destroy()
            end
        end
        
        if EspEnabled then
            local bgui = Instance.new("BillboardGui")
            bgui.Name = "OrionESP_Box"
            bgui.AlwaysOnTop = true
            bgui.ClipsDescendants = false
            bgui.Size = UDim2.new(4.2, 0, 5.8, 0)
            bgui.Adornee = root
            bgui.Parent = TargetParent
            
            local borderFrame = Instance.new("Frame")
            borderFrame.Name = "BorderFrame"
            borderFrame.Size = UDim2.new(1, 0, 1, 0)
            borderFrame.BackgroundTransparency = 1
            borderFrame.BorderSizePixel = 0
            borderFrame.Visible = EspEnabled
            borderFrame.Parent = bgui
            
            local stroke = Instance.new("UIStroke")
            stroke.Thickness = 2.0
            stroke.Color = EspColor
            stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
            stroke.Parent = borderFrame
            
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 4)
            corner.Parent = borderFrame
        end

        if EspHealthEnabled then
            local hbgui = Instance.new("BillboardGui")
            hbgui.Name = "OrionESP_Health"
            hbgui.AlwaysOnTop = true
            hbgui.ClipsDescendants = false
            hbgui.Size = UDim2.new(0, 4, 5.8, 0)
            hbgui.Adornee = root
            hbgui.StudsOffset = Vector3.new(-2.3, 0, 0)
            hbgui.Parent = TargetParent

            local healthContainer = Instance.new("Frame")
            healthContainer.Name = "HealthContainer"
            healthContainer.Size = UDim2.new(1, 0, 1, 0)
            healthContainer.Position = UDim2.new(0, 0, 0, 0)
            healthContainer.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
            healthContainer.BorderSizePixel = 0
            healthContainer.Parent = hbgui
            
            local healthStroke = Instance.new("UIStroke")
            healthStroke.Color = Color3.fromRGB(0, 0, 0)
            healthStroke.Thickness = 1
            healthStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
            healthStroke.Parent = healthContainer
            
            local healthCorner = Instance.new("UICorner")
            healthCorner.CornerRadius = UDim.new(0, 2)
            healthCorner.Parent = healthContainer
            
            local healthFill = Instance.new("Frame")
            healthFill.Name = "Fill"
            healthFill.Size = UDim2.new(1, 0, math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1), 0)
            healthFill.Position = UDim2.new(0, 0, 1, 0)
            healthFill.AnchorPoint = Vector2.new(0, 1)
            healthFill.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
            healthFill.BorderSizePixel = 0
            healthFill.Parent = healthContainer
            
            local healthChangedConnection
            healthChangedConnection = humanoid:GetPropertyChangedSignal("Health"):Connect(function()
                if humanoid.Health <= 0 then
                    hbgui:Destroy()
                    cleanSkeleton(entity)
                    healthChangedConnection:Disconnect()
                    return
                end
                local percent = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
                healthFill:TweenSize(UDim2.new(1, 0, percent, 0), "Out", "Quad", 0.15)
                healthFill.BackgroundColor3 = Color3.fromRGB(255 * (1 - percent), 255 * percent, 0)
            end)
            
            hbgui.Destroying:Connect(function()
                if healthChangedConnection then healthChangedConnection:Disconnect() end
            end)
        end

        if EspNameEnabled then
            local nameBgui = Instance.new("BillboardGui")
            nameBgui.Name = "OrionESP_Name"
            nameBgui.Size = UDim2.new(0, 200, 0, 50)
            nameBgui.Adornee = root
            nameBgui.AlwaysOnTop = true
            nameBgui.StudsOffset = Vector3.new(0, 3, 0)
            nameBgui.Parent = TargetParent

            local nameLabel = Instance.new("TextLabel")
            nameLabel.Name = "NameLabel"
            nameLabel.Size = UDim2.new(1, 0, 1, 0)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Text = getEntityDisplayName(entity)
            nameLabel.TextColor3 = EspColor
            nameLabel.TextSize = 12
            nameLabel.Font = Enum.Font.GothamBold
            nameLabel.Parent = nameBgui
            
            local textStroke = Instance.new("UIStroke")
            textStroke.Color = Color3.fromRGB(0, 0, 0)
            textStroke.Thickness = 1.5
            textStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
            textStroke.Parent = nameLabel
        end
        
        if EspOutlineEnabled then
            local highlight = Instance.new("Highlight")
            highlight.Name = "OrionHighlight"
            highlight.FillColor = EspColor
            highlight.FillTransparency = 0.6
            highlight.OutlineColor = EspColor
            highlight.OutlineTransparency = 0.1
            highlight.Adornee = entity
            highlight.Parent = TargetParent
        end
    end)
end

local function clearESP()
    local folder = EntitiesFolder or workspace:FindFirstChild("Entities")
    if not folder then return end
    
    for _, entity in ipairs(folder:GetChildren()) do
        local root = entity:FindFirstChild("HumanoidRootPart")
        if root then
            for _, gui in ipairs(TargetParent:GetChildren()) do
                if ((gui:IsA("BillboardGui") and (gui.Name == "OrionESP_Box" or gui.Name == "OrionESP_Name" or gui.Name == "OrionESP_Health")) or 
                   (gui:IsA("Highlight") and gui.Name == "OrionHighlight")) and 
                   (gui.Adornee == root or gui.Adornee == entity) then
                    gui:Destroy()
                end
            end
        end
        cleanSkeleton(entity)
    end
end

local function updateActiveESP()
    refreshESP()
end

local function refreshESP()
    clearESP()
    
    local folder = EntitiesFolder or workspace:FindFirstChild("Entities")
    if not folder then return end
    
    for _, entity in ipairs(folder:GetChildren()) do
        if EspEnabled or EspHealthEnabled or EspNameEnabled or EspOutlineEnabled then
            applyESP(entity)
        end
        if EspSkeletonEnabled then
            applySkeleton(entity)
        end
    end
end

local folderConnection = nil
local folderRemoveConnection = nil
local function bindFolderListener()
    local folder = EntitiesFolder or workspace:FindFirstChild("Entities")
    if not folder then return end
    
    if folderConnection then folderConnection:Disconnect() end
    if folderRemoveConnection then folderRemoveConnection:Disconnect() end
    
    folderConnection = folder.ChildAdded:Connect(function(child)
        task.wait(0.1)
        if EspEnabled or EspHealthEnabled or EspNameEnabled or EspOutlineEnabled then
            applyESP(child)
        end
        if EspSkeletonEnabled then
            applySkeleton(child)
        end
    end)
    
    folderRemoveConnection = folder.ChildRemoved:Connect(function(child)
        cleanSkeleton(child)
        for _, gui in ipairs(TargetParent:GetChildren()) do
            if gui:IsA("BillboardGui") or gui:IsA("Highlight") then
                if gui.Adornee == child or (gui.Adornee and gui.Adornee.Parent == child) then
                    gui:Destroy()
                end
            end
        end
    end)
end

bindFolderListener()

task.spawn(function()
    while true do
        task.wait(5)
        if not EntitiesFolder then
            local folder = workspace:FindFirstChild("Entities")
            if folder then
                EntitiesFolder = folder
                bindFolderListener()
                refreshESP()
            end
        end
    end
end)

------------------------------------------------------------------------
-- HIGH-SPEED AIMBOT ENGINE (WITH VELOCITY PREDICTION)
------------------------------------------------------------------------
local function getClosestPlayerToCursor()
    local closestEntity = nil
    local shortestDistance = math.huge
    local mousePos = UserInputService:GetMouseLocation()
    
    local folder = EntitiesFolder or workspace:FindFirstChild("Entities")
    if not folder then return nil end
    
    for _, entity in ipairs(folder:GetChildren()) do
        if entity:IsA("Model") and entity.Name ~= LocalPlayer.Name then
            local targetPart = entity:FindFirstChild(AimTargetPart) or entity:FindFirstChild("Head")
            local hum = entity:FindFirstChildOfClass("Humanoid")
            if targetPart and hum and hum.Health > 0 then
                local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                if onScreen then
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                    
                    if fovCheckAimbotEnabled and fovEnabled then
                        if dist <= fovRadius and dist < shortestDistance then
                            shortestDistance = dist
                            closestEntity = entity
                        end
                    else
                        if dist < shortestDistance then
                            shortestDistance = dist
                            closestEntity = entity
                        end
                    end
                end
            end
        end
    end
    
    return closestEntity
end

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == LockKey and AimbotEnabled then
        if LockedTarget then
            LockedTarget = nil
            print("[Orion Hub] Target unlocked.")
        else
            local target = getClosestPlayerToCursor()
            if target then
                LockedTarget = target
                print("[Orion Hub] Targeted and locked onto: " .. target.Name)
            end
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if AimbotEnabled and LockedTarget then
        local char = LockedTarget
        if char and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 then
            local part = char:FindFirstChild(AimTargetPart) or char:FindFirstChild("Head")
            local root = char:FindFirstChild("HumanoidRootPart")
            if part and root then
                local targetVelocity = root.AssemblyLinearVelocity
                local predictedPosition = part.Position + (targetVelocity * (1 / 60))
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, predictedPosition)
            else
                LockedTarget = nil
            end
        else
            LockedTarget = nil
        end
    end
end)

------------------------------------------------------------------------
-- REGISTER TABS & COMPONENTS
------------------------------------------------------------------------
-- Combat (Aimbot Setup)
local aimbotPage = registerTab("Combat")

addHeader("Aimbot", aimbotPage)
addToggle("Aimbot", aimbotPage, false, function(state)
    AimbotEnabled = state
    if not state then LockedTarget = nil end
    print("Aimbot: ", state)
end)
addKeybind("Aimbot Lock Key", Enum.KeyCode.E, aimbotPage, function(key)
    LockKey = key
    print("Lock Keybound to: ", key.Name)
end)
addToggle("Show Button (Mobile)", aimbotPage, false, function(state)
    print("Mobile Button: ", state)
end)
addDropdown("Aim Target", {"Head", "Torso", "Left Arm", "Right Arm"}, "Head", aimbotPage, function(choice)
    AimTargetPart = choice
    print("Aim Target: ", choice)
end)
addToggle("Wall Check", aimbotPage, false, function(state)
    print("Wall Check: ", state)
end)
addSlider("Smoothness", 0, 100, 0, aimbotPage, function(val)
    print("Smoothness: ", val)
end)

addHeader("Auto", aimbotPage)
addToggle("Auto Attack", aimbotPage, false, function(state)
    print("Auto Attack: ", state)
end)
addKeybind("Auto Attack Key", Enum.KeyCode.F, aimbotPage, function(key)
    print("Auto Attack Bind: ", key.Name)
end)
addSlider("Auto Attack Range", 1, 100, 20, aimbotPage, function(val)
    print("Attack Range: ", val)
end)


-- Visuals Tab Setup
local visualsPage = registerTab("Visuals")

addHeader("Player ESP", visualsPage)
addToggle("ESP Box", visualsPage, false, function(state)
    EspEnabled = state
    refreshESP()
    print("ESP Box: ", state)
end)
addToggle("Health ESP", visualsPage, false, function(state)
    EspHealthEnabled = state
    refreshESP()
    print("Health ESP: ", state)
end)
addToggle("Name ESP", visualsPage, false, function(state)
    EspNameEnabled = state
    refreshESP()
    print("Name ESP: ", state)
end)
addToggle("Outline ESP", visualsPage, false, function(state)
    EspOutlineEnabled = state
    refreshESP()
    print("Outline ESP: ", state)
end)
addToggle("ESP Skeleton", visualsPage, false, function(state)
    EspSkeletonEnabled = state
    refreshESP()
    print("ESP Skeleton: ", state)
end)
addSlider("Render Distance Limit", 100, 5000, 1000, visualsPage, function(val)
    print("Render Distance: ", val)
end)

local ESP_COLOR_OPTIONS = {
    {Name = "Cyan", Color = Color3.fromRGB(0, 240, 255)},
    {Name = "Red", Color = Color3.fromRGB(255, 50, 50)},
    {Name = "Blue", Color = Color3.fromRGB(50, 80, 255)},
    {Name = "Green", Color = Color3.fromRGB(50, 255, 50)},
    {Name = "Magenta", Color = Color3.fromRGB(255, 50, 255)},
    {Name = "Yellow", Color = Color3.fromRGB(255, 255, 50)},
    {Name = "White", Color = Color3.fromRGB(255, 255, 255)}
}
addDropdown("ESP Color", ESP_COLOR_OPTIONS, "Cyan", visualsPage, function(choice)
    for _, opt in ipairs(ESP_COLOR_OPTIONS) do
        if opt.Name == choice then
            EspColor = opt.Color
            refreshESP()
            break
        end
    end
    print("ESP Color Updated: ", choice)
end)


-- FOV Tab Setup
local fovPage = registerTab("FOV")

addHeader("FOV Ring Controls", fovPage)
addToggle("Toggle FOV Ring", fovPage, false, function(state)
    fovEnabled = state
    print("FOV Ring Enabled: ", state)
end)
addSlider("FOV Radius", 30, 400, 120, fovPage, function(val)
    fovRadius = val
    print("FOV Radius: ", val)
end)

-- Visual Color Dropdown showing actual color preview blocks inline!
local RING_COLOR_OPTIONS = {
    {Name = "Cyan", Color = Color3.fromRGB(0, 240, 255)},
    {Name = "Red", Color = Color3.fromRGB(255, 50, 50)},
    {Name = "Blue", Color = Color3.fromRGB(50, 80, 255)},
    {Name = "Green", Color = Color3.fromRGB(50, 255, 50)},
    {Name = "Magenta", Color = Color3.fromRGB(255, 50, 255)},
    {Name = "Yellow", Color = Color3.fromRGB(255, 255, 50)},
    {Name = "White", Color = Color3.fromRGB(255, 255, 255)}
}
addDropdown("Ring Color", RING_COLOR_OPTIONS, "Cyan", fovPage, function(choice)
    for _, opt in ipairs(RING_COLOR_OPTIONS) do
        if opt.Name == choice then
            fovColor = opt.Color
            break
        end
    end
    print("FOV Ring Color Updated: ", choice)
end)

addHeader("Sensing Checks", fovPage)
addToggle("FOV Check (Aimbot)", fovPage, false, function(state)
    fovCheckAimbotEnabled = state
    print("FOV Check (Aimbot): ", state)
end)


------------------------------------------------------------------------
-- CONFIGURATION MANAGER FILESYSTEM LOGIC
------------------------------------------------------------------------
local HttpService = game:GetService("HttpService")
local CONFIG_FOLDER = "OrionConfigs"

if makefolder and not isfolder(CONFIG_FOLDER) then
    makefolder(CONFIG_FOLDER)
end

local ConfigManager = {}

function ConfigManager.GetConfigs()
    local configs = {}
    if listfiles then
        local success, files = pcall(function() return listfiles(CONFIG_FOLDER) end)
        if success and files then
            for _, file in ipairs(files) do
                if file:sub(-5) == ".json" then
                    local name = file:match("([^/\\]+)%.json$")
                    if name then
                        table.insert(configs, name)
                    end
                end
            end
        end
    end
    return configs
end

function ConfigManager.SaveConfig(name)
    if not name or name == "" then return false end
    if writefile then
        local data = {}
        for key, elem in pairs(UI_ELEMENTS) do
            if elem.Get then
                data[key] = elem.Get()
            end
        end
        data["CurrentThemeName"] = CurrentThemeName
        
        local success = pcall(function()
            local json = HttpService:JSONEncode(data)
            writefile(CONFIG_FOLDER .. "/" .. name .. ".json", json)
        end)
        return success
    end
    return false
end

function ConfigManager.LoadConfig(name)
    if not name or name == "" then return false end
    local path = CONFIG_FOLDER .. "/" .. name .. ".json"
    if readfile and isfile and isfile(path) then
        local success, result = pcall(function()
            local json = readfile(path)
            return HttpService:JSONDecode(json)
        end)
        if success and type(result) == "table" then
            for key, val in pairs(result) do
                if UI_ELEMENTS[key] and UI_ELEMENTS[key].Set then
                    UI_ELEMENTS[key].Set(val)
                end
            end
            if result.CurrentThemeName then
                applyTheme(result.CurrentThemeName)
                -- Update theme selection buttons visually
                -- This will rely on the user clicking, but we can do it automatically if needed.
            end
            if refreshESP then refreshESP() end
            return true
        end
    end
    return false
end

function ConfigManager.SetAutoLoad(name)
    if writefile then
        pcall(function()
            writefile(CONFIG_FOLDER .. "/autoload.txt", name)
        end)
    end
end

function ConfigManager.GetAutoLoad()
    local path = CONFIG_FOLDER .. "/autoload.txt"
    if readfile and isfile and isfile(path) then
        local success, result = pcall(function()
            return readfile(path)
        end)
        if success then return result end
    end
    return nil
end

-- Configs Tab Setup
local configsPage = registerTab("Configs")

addHeader("Configuration Profiles", configsPage)
addToggle("Auto Execute Script", configsPage, false, function(state)
    if state and queue_on_teleport then
        -- IMPORTANT: Replace the URL below with your actual raw script link (e.g. from GitHub/Pastebin)
        local loadstringCode = "loadstring(game:HttpGet('YOUR_GITHUB_RAW_URL_HERE'))()"
        queue_on_teleport(loadstringCode)
        print("Script successfully queued for next teleport!")
    elseif state then
        warn("Your executor does not support queue_on_teleport!")
    end
end)

-- Layout custom embedded palette selection grid
addThemeSelector(configsPage)

addHeader("Actions", configsPage)

local configNameInput = "MyConfig"
addTextBox("Config Name", "Type name to save...", configsPage, function(val)
    configNameInput = val
end)

local saveBtnContainer = create("Frame", {
    Size = UDim2.new(0.92, 0, 0, 42),
    BackgroundColor3 = COLORS.Card,
    Parent = configsPage
})
addCorner(saveBtnContainer, 8)
local saveBorder = addStroke(saveBtnContainer, COLORS.Border, 1)
registerThemeable(saveBtnContainer, "Cards")
registerThemeable(saveBorder, "Borders")

local saveBtn = create("TextButton", {
    Size = UDim2.new(0.94, 0, 0.7, 0),
    Position = UDim2.new(0.03, 0, 0.15, 0),
    BackgroundColor3 = COLORS.Accent,
    Text = "Save Configuration File",
    TextColor3 = COLORS.TextMain,
    TextSize = 12,
    Font = Enum.Font.GothamBold,
    AutoButtonColor = true,
    Parent = saveBtnContainer
})
addCorner(saveBtn, 6)
saveBtn.MouseButton1Click:Connect(function()
    if configNameInput and configNameInput ~= "" then
        if ConfigManager.SaveConfig(configNameInput) then
            print("Successfully saved config: " .. configNameInput)
            if UI_ELEMENTS["Available Configs"] and UI_ELEMENTS["Available Configs"].UpdateOptions then
                local configs = ConfigManager.GetConfigs()
                if #configs == 0 then configs = {"None"} end
                UI_ELEMENTS["Available Configs"].UpdateOptions(configs)
            end
        else
            print("Failed to save config: " .. configNameInput)
        end
    end
end)

local selectedConfig = "None"
local availableConfigs = ConfigManager.GetConfigs()
if #availableConfigs == 0 then availableConfigs = {"None"} end
addDropdown("Available Configs", availableConfigs, availableConfigs[1], configsPage, function(choice)
    selectedConfig = choice
end)

local loadBtnContainer = create("Frame", {
    Size = UDim2.new(0.92, 0, 0, 42),
    BackgroundColor3 = COLORS.Card,
    Parent = configsPage
})
addCorner(loadBtnContainer, 8)
local loadBorder = addStroke(loadBtnContainer, COLORS.Border, 1)
registerThemeable(loadBtnContainer, "Cards")
registerThemeable(loadBorder, "Borders")

local loadBtn = create("TextButton", {
    Size = UDim2.new(0.94, 0, 0.7, 0),
    Position = UDim2.new(0.03, 0, 0.15, 0),
    BackgroundColor3 = COLORS.Background,
    Text = "Load Selected Configuration",
    TextColor3 = COLORS.TextMain,
    TextSize = 12,
    Font = Enum.Font.GothamBold,
    AutoButtonColor = true,
    Parent = loadBtnContainer
})
addCorner(loadBtn, 6)
local loadBtnBorder = addStroke(loadBtn, COLORS.Border, 1)
registerThemeable(loadBtn, "Backgrounds")
registerThemeable(loadBtnBorder, "Borders")

loadBtn.MouseButton1Click:Connect(function()
    if selectedConfig and selectedConfig ~= "None" then
        if ConfigManager.LoadConfig(selectedConfig) then
            print("Successfully loaded config: " .. selectedConfig)
        else
            print("Failed to load config: " .. selectedConfig)
        end
    end
end)

local autoLoadBtnContainer = create("Frame", {
    Size = UDim2.new(0.92, 0, 0, 42),
    BackgroundColor3 = COLORS.Card,
    Parent = configsPage
})
addCorner(autoLoadBtnContainer, 8)
local autoLoadBorder = addStroke(autoLoadBtnContainer, COLORS.Border, 1)
registerThemeable(autoLoadBtnContainer, "Cards")
registerThemeable(autoLoadBorder, "Borders")

local autoLoadBtn = create("TextButton", {
    Size = UDim2.new(0.94, 0, 0.7, 0),
    Position = UDim2.new(0.03, 0, 0.15, 0),
    BackgroundColor3 = COLORS.Background,
    Text = "Set as Auto-Load",
    TextColor3 = COLORS.TextMuted,
    TextSize = 12,
    Font = Enum.Font.GothamBold,
    AutoButtonColor = true,
    Parent = autoLoadBtnContainer
})
addCorner(autoLoadBtn, 6)
local autoLoadBtnBorder = addStroke(autoLoadBtn, COLORS.Border, 1)
registerThemeable(autoLoadBtn, "Backgrounds")
registerThemeable(autoLoadBtnBorder, "Borders")

autoLoadBtn.MouseButton1Click:Connect(function()
    if selectedConfig and selectedConfig ~= "None" then
        ConfigManager.SetAutoLoad(selectedConfig)
        print("Set Auto-Load to config: " .. selectedConfig)
    end
end)

addHeader("Keybinds", configsPage)
local ToggleUIKeybind = Enum.KeyCode.RightControl
addKeybind("Toggle UI Keybind", ToggleUIKeybind, configsPage, function(key)
    ToggleUIKeybind = key
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if ToggleUIKeybind and input.KeyCode == ToggleUIKeybind then
        ScreenGui.Enabled = not ScreenGui.Enabled
    end
end)


-- Default to first page open
Tabs["Combat"].Select()

-- Auto-Load System Initialization
task.spawn(function()
    local autoLoadName = ConfigManager.GetAutoLoad()
    if autoLoadName and autoLoadName ~= "" then
        print("[Orion Hub Lite] Auto-Load Triggered: Found default config '" .. autoLoadName .. "'")
        local success = ConfigManager.LoadConfig(autoLoadName)
        if success then
            print("[Orion Hub Lite] Successfully auto-loaded: " .. autoLoadName)
        else
            print("[Orion Hub Lite] Failed to auto-load config: " .. autoLoadName)
        end
    end
end)

print("[Orion Hub Lite] Successfully compiled UI & motion engine!")