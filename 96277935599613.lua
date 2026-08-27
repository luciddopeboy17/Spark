-- STREAMING_CHUNK:Initializing Services and Execution Safeguards...
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local HIGHLIGHT_FOLDER_NAME = "Nonogram_Solver_Highlights"

-- Target GUI parent detection (compatibility with gethui, CoreGui, or PlayerGui)
local parentGui = nil
if gethui then
parentGui = gethui()
elseif syn and syn.protect_gui then
local sg = Instance.new("ScreenGui")
syn.protect_gui(sg)
parentGui = CoreGui
elseif CoreGui:FindFirstChild("RobloxGui") then
parentGui = CoreGui
else
parentGui = LocalPlayer:WaitForChild("PlayerGui")
end

-- STREAMING_CHUNK:Clearing Old UI and Highlight Instances...
if parentGui:FindFirstChild("NonogramSolverGui") then
parentGui.NonogramSolverGui:Destroy()
end

local function clearHighlights()
local existingFolder = Workspace:FindFirstChild(HIGHLIGHT_FOLDER_NAME)
if existingFolder then
existingFolder:Destroy()
end
end
clearHighlights()

-- STREAMING_CHUNK:Constructing Injectable Floating UI Container...
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "NonogramSolverGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = parentGui

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainContainer"
mainFrame.Size = UDim2.new(0, 290, 0, 310)
mainFrame.Position = UDim2.new(0.05, 0, 0.25, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = mainFrame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(51, 65, 85)
stroke.Thickness = 1.5
stroke.Parent = mainFrame

-- Title Bar
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 42)
titleBar.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 12)
titleCorner.Parent = titleBar

local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(1, -20, 1, 0)
titleText.Position = UDim2.new(0, 14, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "🧩 Nonogram Master Solver"
titleText.TextColor3 = Color3.fromRGB(248, 250, 252)
titleText.TextSize = 13
titleText.Font = Enum.Font.GothamBold
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.Parent = titleBar

-- Status Log
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -24, 0, 45)
statusLabel.Position = UDim2.new(0, 12, 0, 52)
statusLabel.BackgroundColor3 = Color3.fromRGB(2, 6, 23)
statusLabel.TextColor3 = Color3.fromRGB(148, 163, 184)
statusLabel.Text = "Ready to scan workspace.Clues and workspace.Tiles."
statusLabel.TextSize = 11
statusLabel.Font = Enum.Font.Code
statusLabel.TextWrapped = true
statusLabel.Parent = mainFrame

local statusCorner = Instance.new("UICorner")
statusCorner.CornerRadius = UDim.new(0, 8)
statusCorner.Parent = statusLabel

-- Helper for styled UI buttons
local function createButton(text, pos, bgCol, hoverCol)
local btn = Instance.new("TextButton")
btn.Size = UDim2.new(1, -24, 0, 36)
btn.Position = pos
btn.BackgroundColor3 = bgCol
btn.Text = text
btn.TextColor3 = Color3.fromRGB(255, 255, 255)
btn.Font = Enum.Font.GothamSemibold
btn.TextSize = 12
btn.BorderSizePixel = 0
btn.Parent = mainFrame

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 8)
btnCorner.Parent = btn

btn.MouseEnter:Connect(function()
    TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = hoverCol}):Play()
end)
btn.MouseLeave:Connect(function()
    TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = bgCol}):Play()
end)

return btn



end

local solveBtn = createButton("⚡ Read Clues & Highlight Tiles", UDim2.new(0, 12, 0, 108), Color3.fromRGB(37, 99, 235), Color3.fromRGB(29, 78, 216))
local clearBtn = createButton("🧹 Clear Highlights", UDim2.new(0, 12, 0, 152), Color3.fromRGB(71, 85, 105), Color3.fromRGB(51, 65, 85))
local destroyBtn = createButton("❌ Destroy Solver UI", UDim2.new(0, 12, 0, 196), Color3.fromRGB(225, 29, 72), Color3.fromRGB(190, 18, 60))

-- Info Footer
local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, -24, 0, 45)
infoLabel.Position = UDim2.new(0, 12, 0, 248)
infoLabel.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
infoLabel.TextColor3 = Color3.fromRGB(203, 213, 225)
infoLabel.Text = "Reads SurfaceGuis in Workspace.Clues and highlights parts in Workspace.Tiles."
infoLabel.TextSize = 10
infoLabel.Font = Enum.Font.Gotham
infoLabel.TextWrapped = true
infoLabel.Parent = mainFrame

local infoCorner = Instance.new("UICorner")
infoCorner.CornerRadius = UDim.new(0, 8)
infoCorner.Parent = infoLabel

-- STREAMING_CHUNK:Nonogram Constraint Solver Logic Core...
local UNKNOWN = 0
local FILLED = 1
local EMPTY = 2

local function solveLine(lineLength, clues, currentLine)
local validConfigurations = {}

local function generate(clueIdx, pos, currentArr)
    if clueIdx > #clues then
        local fullArr = table.clone(currentArr)
        while #fullArr < lineLength do
            table.insert(fullArr, EMPTY)
        end
        if #fullArr == lineLength then
            local matches = true
            for i = 1, lineLength do
                if currentLine[i] ~= UNKNOWN and currentLine[i] ~= fullArr[i] then
                    matches = false; break
                end
            end
            if matches then
                table.insert(validConfigurations, fullArr)
            end
        end
        return
    end

    local currentClue = clues[clueIdx]
    local remainingCluesSum = 0
    for i = clueIdx + 1, #clues do remainingCluesSum = remainingCluesSum + clues[i] end
    local remainingCluesMinSpaces = (#clues - clueIdx)
    local maxStartPos = lineLength - (currentClue + remainingCluesSum + remainingCluesMinSpaces) + 1

    for startPos = pos, maxStartPos do
        local arr = table.clone(currentArr)
        while #arr < (startPos - 1) do
            table.insert(arr, EMPTY)
        end
        for i = 1, currentClue do
            table.insert(arr, FILLED)
        end
        if clueIdx < #clues then
            table.insert(arr, EMPTY)
        end
        generate(clueIdx + 1, #arr + 1, arr)
    end
end

if #clues == 0 or (#clues == 1 and clues[1] == 0) then
    local allEmpty = {}
    for i = 1, lineLength do allEmpty[i] = EMPTY end
    return { result = allEmpty, count = 1 }
end

generate(1, 1, {})
if #validConfigurations == 0 then return nil end

local result = {}
for i = 1, lineLength do
    local firstVal = validConfigurations[1][i]
    local identical = true
    for c = 2, #validConfigurations do
        if validConfigurations[c][i] ~= firstVal then
            identical = false; break
        end
    end
    result[i] = identical and firstVal or UNKNOWN
end

return { result = result, count = #validConfigurations }



end

-- STREAMING_CHUNK:Reading SurfaceGui Clues and 3D Tile Locations...
local function parseClueNumbersFromObject(obj)
local numbers = {}
for _, desc in ipairs(obj:GetDescendants()) do
if desc:IsA("TextLabel") or desc:IsA("TextButton") then
local text = desc.Text
for numStr in string.gmatch(text, "%d+") do
local n = tonumber(numStr)
if n and n > 0 then
table.insert(numbers, n)
end
end
end
end
return numbers
end

local function executeNonogramSolver()
statusLabel.Text = "Scanning workspace.Tiles and workspace.Clues..."
task.wait(0.05)

local tilesFolder = Workspace:FindFirstChild("Tiles")
local cluesFolder = Workspace:FindFirstChild("Clues")

if not tilesFolder then
    statusLabel.Text = "❌ Folder 'workspace.Tiles' not found!"
    return
end
if not cluesFolder then
    statusLabel.Text = "❌ Folder 'workspace.Clues' not found!"
    return
end

local tiles = {}
for _, child in ipairs(tilesFolder:GetChildren()) do
    if child:IsA("BasePart") then
        table.insert(tiles, child)
    elseif child:IsA("Model") and child.PrimaryPart then
        table.insert(tiles, child.PrimaryPart)
    elseif child:IsA("Model") then
        local p = child:FindFirstChildWhichIsA("BasePart")
        if p then table.insert(tiles, p) end
    end
end

if #tiles == 0 then
    statusLabel.Text = "❌ No tile parts found inside workspace.Tiles."
    return
end

local xCoords, zCoords = {}, {}
local threshold = 1.0

local function getOrAddCoord(list, val)
    for _, existing in ipairs(list) do
        if math.abs(existing - val) < threshold then
            return existing
        end
    end
    table.insert(list, val)
    return val
end

for _, tile in ipairs(tiles) do
    local pos = tile.Position
    getOrAddCoord(xCoords, pos.X)
    getOrAddCoord(zCoords, pos.Z)
end

table.sort(xCoords)
table.sort(zCoords)

local numCols = #xCoords
local numRows = #zCoords

statusLabel.Text = string.format("Detected Board: %dx%d (%d Tiles)", numCols, numRows, #tiles)
task.wait(0.1)

local gridTiles = {}
for r = 1, numRows do gridTiles[r] = {} end

for _, tile in ipairs(tiles) do
    local pos = tile.Position
    local colIdx, rowIdx = 1, 1

    for c, x in ipairs(xCoords) do
        if math.abs(x - pos.X) < threshold then colIdx = c; break end
    end
    for r, z in ipairs(zCoords) do
        if math.abs(z - pos.Z) < threshold then rowIdx = r; break end
    end

    gridTiles[rowIdx][colIdx] = tile
end

local clueObjects = {}
for _, desc in ipairs(cluesFolder:GetDescendants()) do
    if desc.Name == "Clue" or desc:FindFirstChild("SurfaceGui") then
        table.insert(clueObjects, desc)
    end
end

local rowClues = {}
local colClues = {}

for r = 1, numRows do rowClues[r] = {} end
for c = 1, numCols do colClues[c] = {} end

for _, clueObj in ipairs(clueObjects) do
    local part = clueObj:IsA("BasePart") and clueObj or clueObj:FindFirstChildWhichIsA("BasePart", true)
    if part then
        local pos = part.Position
        local numbers = parseClueNumbersFromObject(clueObj)

        if #numbers > 0 then
            local closestRow, minZDist = 1, math.huge
            local closestCol, minXDist = 1, math.huge

            for r, z in ipairs(zCoords) do
                local dist = math.abs(z - pos.Z)
                if dist < minZDist then minZDist = dist; closestRow = r end
            end

            for c, x in ipairs(xCoords) do
                local dist = math.abs(x - pos.X)
                if dist < minXDist then minXDist = dist; closestCol = c end
            end

            if minZDist < minXDist then
                rowClues[closestRow] = numbers
            else
                colClues[closestCol] = numbers
            end
        end
    end
end

-- STREAMING_CHUNK:Solving Constraint Satisfiability Matrix...
statusLabel.Text = "Computing Nonogram solution matrix..."
task.wait(0.05)

local solutionGrid = {}
for r = 1, numRows do
    solutionGrid[r] = {}
    for c = 1, numCols do solutionGrid[r][c] = UNKNOWN end
end

local progress = true
local passes = 0

while progress and passes < 50 do
    progress = false
    passes = passes + 1

    for r = 1, numRows do
        local clues = rowClues[r] or {}
        local res = solveLine(numCols, clues, solutionGrid[r])
        if res and res.result then
            for c = 1, numCols do
                if solutionGrid[r][c] == UNKNOWN and res.result[c] ~= UNKNOWN then
                    solutionGrid[r][c] = res.result[c]
                    progress = true
                end
            end
        end
    end

    for c = 1, numCols do
        local line = {}
        for r = 1, numRows do table.insert(line, solutionGrid[r][c]) end
        local clues = colClues[c] or {}
        local res = solveLine(numRows, clues, line)
        if res and res.result then
            for r = 1, numRows do
                if solutionGrid[r][c] == UNKNOWN and res.result[r] ~= UNKNOWN then
                    solutionGrid[r][c] = res.result[r]
                    progress = true
                end
            end
        end
    end
end

-- STREAMING_CHUNK:Applying Visual Highlights to Workspace Parts...
clearHighlights()
local highlightFolder = Instance.new("Folder")
highlightFolder.Name = HIGHLIGHT_FOLDER_NAME
highlightFolder.Parent = Workspace

local filledCount = 0
for r = 1, numRows do
    for c = 1, numCols do
        local tilePart = gridTiles[r] and gridTiles[r][c]
        if tilePart then
            local val = solutionGrid[r][c]

            if val == FILLED then
                filledCount = filledCount + 1
                local highlight = Instance.new("Highlight")
                highlight.Name = "FilledHighlight_" .. r .. "_" .. c
                highlight.Adornee = tilePart.Parent:IsA("Model") and tilePart.Parent or tilePart
                highlight.FillColor = Color3.fromRGB(0, 230, 120)
                highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                highlight.FillTransparency = 0.25
                highlight.OutlineTransparency = 0
                highlight.Parent = highlightFolder
            elseif val == EMPTY then
                local highlight = Instance.new("Highlight")
                highlight.Name = "EmptyHighlight_" .. r .. "_" .. c
                highlight.Adornee = tilePart.Parent:IsA("Model") and tilePart.Parent or tilePart
                highlight.FillColor = Color3.fromRGB(239, 68, 68)
                highlight.OutlineColor = Color3.fromRGB(180, 0, 0)
                highlight.FillTransparency = 0.8
                highlight.OutlineTransparency = 0.5
                highlight.Parent = highlightFolder
            end
        end
    end
end

statusLabel.Text = string.format("✅ Complete! Highlighted %d Filled Tiles (%d passes).", filledCount, passes)



end

-- STREAMING_CHUNK:Event Listeners & Cleanup...
solveBtn.MouseButton1Click:Connect(function()
pcall(executeNonogramSolver)
end)

clearBtn.MouseButton1Click:Connect(function()
clearHighlights()
statusLabel.Text = "🧹 Highlights cleared."
end)

destroyBtn.MouseButton1Click:Connect(function()
clearHighlights()
screenGui:Destroy()
end)

statusLabel.Text = "🟢 Nonogram Master Solver loaded!"