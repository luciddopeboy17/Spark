--[[
  Airport Tycoon - Auto Grinder (Obsidian UI)
  Game: Airport Tycoon (grab name via get-game-info: "Airport Tycoon")
  Re-exec safe: running this again tears the previous instance down first.
  UI toggle key: Right Shift
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local Packages = ReplicatedStorage:WaitForChild("Packages")

local GNAME = "AirportTycoonGrinder"

-- Terminate any previous instance of this script.
local Old = getgenv()[GNAME]
if Old then
	Old.stopped = true
	if Old.Library and Old.Library.Unload then
		pcall(function() Old.Library:Unload() end)
	end
end

local State = { stopped = false, Library = nil }
getgenv()[GNAME] = State

-- Load Obsidian UI library.
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/main/Library.lua"))()
if not Library then
	warn("[AirportTycoon] Failed to load Obsidian library.")
	State.stopped = true
	getgenv()[GNAME] = nil
	return
end
State.Library = Library

-- Window. Icon intentionally omitted so the generic mspaint logo is gone.
local Window = Library:CreateWindow({
	Title = "Airport Tycoon",
	Footer = "Auto Grinder",
	ToggleKeybind = Enum.KeyCode.RightShift,
	AutoShow = true,
	Center = true,
	NotifySide = "Right",
	ShowCustomCursor = false,
})

local Main = Window:AddTab("Main")
local Grinder = Main:AddLeftGroupbox("Auto Farm")
local Status = Main:AddRightGroupbox("Status")

local T_AutoBuy = Grinder:AddToggle("AutoBuy", { Text = "Auto Buy All Buttons", Default = true })
local T_TpFall = Grinder:AddToggle("TpFall", {
	Text = "TP Fallback (if remote fails)",
	Default = false,
	Tooltip = "Teleports onto buttons to force the game's own purchase.",
})
local T_Upgrade = Grinder:AddToggle("UpgradeEnabled", { Text = "Auto Upgrade", Default = true })
local UpdDropdown = Grinder:AddDropdown("AutoUpgrade", {
	Text = "Upgrade Categories",
	Multi = true,
	Searchable = false,
	Values = {
		SecurityLane = "Security Lanes",
		GateDesk = "Gate Desks",
		Amenity = "Amenities",
		Runway = "Runway",
	},
	Default = "SecurityLane",
})
UpdDropdown:SetValue({ SecurityLane = true, GateDesk = true, Amenity = true, Runway = true })
local T_Collect = Grinder:AddToggle("AutoCollect", { Text = "Auto Collect Income (ATM)", Default = true })
local T_Rebirth = Grinder:AddToggle("AutoRebirth", { Text = "Auto Rebirth", Default = true })
local T_RebUp = Grinder:AddToggle("AutoRebUp", { Text = "Auto Buy Rebirth Upgrades", Default = true })

Grinder:AddDivider()
Grinder:AddLabel("Robux buttons are never bought (coin-only).", true)

local Lbl = Status:AddLabel("Loading...", true, "StatusLabel")

-- Locate the networker _remotes folder dynamically (robust to the _Index hash).
local function findRemotes()
	local idx = Packages:FindFirstChild("_Index")
	if not idx then return nil end
	for _, pkg in ipairs(idx:GetChildren()) do
		local nm = pkg:FindFirstChild("networker")
		if nm then
			local r = nm:FindFirstChild("_remotes")
			if r then return r end
		end
	end
	return nil
end

local remotes = findRemotes()
local Purchases = remotes and remotes.Purchases
local Upgrades = remotes and remotes.Upgrades
local Rebirths = remotes and remotes.Rebirths
local RebirthUpgrades = remotes and remotes.RebirthUpgrades
local PurchasesRF = Purchases and Purchases.RemoteFunction

-- Game client + config modules.
local client = require(Packages:WaitForChild("dataservice")).client
local RebirthConfig = require(ReplicatedStorage.Features.rebirth.RebirthConfig)
local RebirthUpgradeConfig = require(ReplicatedStorage.Features.rebirth.RebirthUpgradeConfig)
local UpgradeConfig = require(ReplicatedStorage.Features.upgrades.UpgradeConfig)
local ComponentServiceClient = require(ReplicatedStorage.Features.components.ComponentServiceClient)
local ShopConfig = require(ReplicatedStorage.Features.shop.ShopConfig)

-- Stop the shop from auto-opening. When a buy fails with "Insufficient coins" the game
-- calls ShopServiceClient:showMoneyOffers(), which pops the shop UI. Neutralising it here
-- (same module table, so the game's own reference sees our no-op) keeps the shop closed.
local ShopServiceClient = require(ReplicatedStorage.Features.shop.ShopServiceClient)
if ShopServiceClient and type(ShopServiceClient) == "table" then
	ShopServiceClient.showMoneyOffers = function() end
end

-- Gamepass-prompt models: touching their Touch parts fires a Roblox purchase prompt.
-- We disable CanTouch on them so the popup never appears.
local GAMEPASS_MODELS = {}
for k in pairs(ShopConfig.GAME_PASS_PROMPT_BY_MODEL_ID or {}) do GAMEPASS_MODELS[k] = true end
GAMEPASS_MODELS["LikeJoin"] = true

local function disableGamePassPrompts()
	local runtime = workspace:FindFirstChild("AirportTycoonClientRuntime")
	if not runtime then return end
	for _, m in ipairs(runtime:GetDescendants()) do
		if m:IsA("Model") and GAMEPASS_MODELS[m.Name] then
			for _, p in ipairs(m:GetDescendants()) do
				if p:IsA("BasePart") and p.CanTouch then
					p.CanTouch = false
				end
			end
		end
	end
end

-- Button ids that are gated behind a Robux gamepass / dev-product. These have a
-- coin-cost entry but buying them fires a purchase prompt, so we must never fire them.
local blockedButtons = {}
local function refreshBlockedButtons()
	local nextBlocked = {}
	local runtime = workspace:FindFirstChild("AirportTycoonClientRuntime")
	if runtime then
		for _, m in ipairs(runtime:GetDescendants()) do
			if m:IsA("Model") then
				local id = m:GetAttribute("PurchaseId")
				if id then
					local gp = m:GetAttribute("GamePassId") or 0
					local dp = m:GetAttribute("DevProductId") or 0
					if gp > 0 or dp > 0 then
						nextBlocked[id] = true
					end
				end
			end
		end
	end
	blockedButtons = nextBlocked
end

local ALL_UPGRADE_BEHAVIORS = { SecurityLane = true, GateDesk = true, Amenity = true, Runway = true }

-- Behaviors currently selected in the Auto Upgrade dropdown.
local function activeUpgradeBehaviors()
	local set = {}
	local vals = UpdDropdown:GetActiveValues()
	for _, k in ipairs(vals or {}) do
		if ALL_UPGRADE_BEHAVIORS[k] then
			set[k] = true
		end
	end
	return set
end

local lastSnap
local function refreshSnapshot()
	if not PurchasesRF then return end
	local ok, snap = pcall(function() return PurchasesRF:InvokeServer("requestOwnPlotSnapshot") end)
	if ok and type(snap) == "table" then
		lastSnap = snap
	end
end

local function getPlotId(snap)
	if snap and snap.isOwner and snap.plotId then return snap.plotId end
	local entities = workspace:FindFirstChild("Entities")
	local plots = entities and entities:FindFirstChild("Plots")
	if plots then
		for _, plot in ipairs(plots:GetChildren()) do
			if plot:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
				return plot.Name
			end
		end
	end
	return snap and snap.plotId or nil
end

local function coins() return client:get({ "coins" }) or 0 end
local function tokens() return client:get({ "starTokens" }) or 0 end
local function rebirthCount() return client:get({ "tycoon", "rebirth", "count" }) or 0 end
local function ownedUpgrades() return client:get({ "tycoon", "rebirth", "upgrades" }) or {} end
local function atmBalance() return client:get({ "tycoon", "accumulatorBalance" }) or 0 end

local function upgradeCostFor(modelId, level)
	local costs = UpgradeConfig.UPGRADE_COSTS_BY_MODEL_ID and UpgradeConfig.UPGRADE_COSTS_BY_MODEL_ID[modelId]
	if costs and costs[level] then return costs[level] end
	local rt = UpgradeConfig.TYPE_BY_ID and UpgradeConfig.TYPE_BY_ID.Runway
	if rt and rt.upgradeCosts and modelId == "Runway" and rt.upgradeCosts[level] then
		return rt.upgradeCosts[level]
	end
	return nil
end

local function findAccumulatorTouch(pid)
	local comps = ComponentServiceClient:getPlotComponents(pid)
	if type(comps) ~= "table" then return nil end
	for _, c in pairs(comps) do
		if c.descriptor and c.descriptor.accumulator and c.model then
			local t = c.model:FindFirstChild("Touch", true)
			if t and t:IsA("BasePart") then
				return t
			end
		end
	end
	return nil
end

local function tpTo(cf)
	if typeof(cf) ~= "CFrame" then return end
	local chr = LocalPlayer.Character
	local root = chr and chr:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = cf
	end
end

local function setStatus(text)
	if Lbl and Lbl.SetText then
		pcall(function() Lbl:SetText(text) end)
	end
end

local function formatMoney(n)
	n = math.floor(tonumber(n) or 0)
	if n >= 1e9 then return ("%.2fB"):format(n / 1e9) end
	if n >= 1e6 then return ("%.2fM"):format(n / 1e6) end
	if n >= 1e3 then return ("%.2fK"):format(n / 1e3) end
	return tostring(n)
end

local lastBuy = {}
local lastUpgrade = {}
local lastRebirth = 0
local lastNode = {}

-- Keep gamepass prompt models from firing Roblox purchase popups (they re-render),
-- and keep the robux-button block-list fresh.
task.spawn(function()
	refreshBlockedButtons()
	while not State.stopped do
		disableGamePassPrompts()
		refreshBlockedButtons()
		task.wait(1)
	end
end)

-- Snapshot refresher.
task.spawn(function()
	refreshSnapshot()
	while not State.stopped do
		task.wait(1.2)
		if T_AutoBuy.Value or (T_Upgrade.Value and next(activeUpgradeBehaviors()) ~= nil) or T_RebUp.Value then
			refreshSnapshot()
		end
	end
end)

-- Auto Buy All Buttons (coin-only: never fires on Robux/dev-product buttons).
task.spawn(function()
	while not State.stopped do
		if T_AutoBuy.Value then
			local snap = lastSnap
			if snap then
				local pid = getPlotId(snap)
				local visible = snap.visibleButtons
				local costs = snap.buttonCosts
				local gbt = snap.guideButtonTargets
				if pid and visible and costs then
					-- Buy cheapest-first so we spend the available budget as far as it goes,
					-- and never fire a buy we cannot afford (which would make the server reply
					-- "Insufficient coins" and auto-open the shop).
					local candidates = {}
					for _, btn in ipairs(visible) do
						if costs[btn] ~= nil and not blockedButtons[btn]
							and tick() - (lastBuy[btn] or 0) >= 1.2 then
							table.insert(candidates, { id = btn, cost = costs[btn] })
						end
					end
					table.sort(candidates, function(a, b) return a.cost < b.cost end)
					local budget = coins()
					for _, cand in ipairs(candidates) do
						if budget >= cand.cost then
							if Purchases then
								pcall(function() Purchases.RemoteEvent:FireServer("requestPurchase", pid, cand.id) end)
							end
							lastBuy[cand.id] = tick()
							budget -= cand.cost
							if T_TpFall.Value and gbt and gbt[cand.id] and gbt[cand.id].worldCFrame then
								tpTo(gbt[cand.id].worldCFrame)
							end
						end
					end
				end
			end
		end
		task.wait(0.8)
	end
end)

-- Auto Upgrade (on/off via toggle, categories via the dropdown).
task.spawn(function()
	while not State.stopped do
		if T_Upgrade.Value then
			local upgradeSet = activeUpgradeBehaviors()
			if next(upgradeSet) then
			local snap = lastSnap
			if snap then
				local pid = getPlotId(snap)
				if pid and snap.components then
					local c = coins()
					for _, comp in ipairs(snap.components) do
						if comp.hasUpgradeCore and comp.upgradeLevel and comp.upgradeLevel < UpgradeConfig.MAX_LEVEL then
							local isTarget = false
							for b in pairs(comp.behaviors or {}) do
								if upgradeSet[b] then isTarget = true break end
							end
							if isTarget then
								local modelId = comp.modelId
								if tick() - (lastUpgrade[modelId] or 0) >= 2.5 then
									local cost = upgradeCostFor(modelId, comp.upgradeLevel)
									if cost == nil or c >= cost then
										if Upgrades then
											pcall(function() Upgrades.RemoteEvent:FireServer("requestUpgrade", pid, modelId) end)
										end
										lastUpgrade[modelId] = tick()
									end
								end
							end
						end
					end
				end
			end
		end
		end
		task.wait(1.0)
	end
end)

-- Auto Collect Income (ATM): stand on the ATM whenever there is a balance to collect.
task.spawn(function()
	while not State.stopped do
		if T_Collect.Value and atmBalance() > 0 then
			local pid = getPlotId(lastSnap)
			if pid then
				local touch = findAccumulatorTouch(pid)
				if touch then
					local chr = LocalPlayer.Character
					local root = chr and chr:FindFirstChild("HumanoidRootPart")
					if root then
						root.CFrame = touch.CFrame
					end
				end
			end
		end
		task.wait(1)
	end
end)

-- Auto Rebirth.
task.spawn(function()
	while not State.stopped do
		if T_Rebirth.Value and tick() - lastRebirth >= 3 then
			local status = RebirthConfig.getRequirementStatus({ coins = coins(), tycoon = { rebirth = { count = rebirthCount() } } })
			if status and status.ready then
				if Rebirths then
					pcall(function() Rebirths.RemoteEvent:FireServer("requestRebirth") end)
				end
				lastRebirth = tick()
			end
		end
		task.wait(1.5)
	end
end)

-- Auto Buy Rebirth Upgrades.
task.spawn(function()
	while not State.stopped do
		if T_RebUp.Value then
			local owned = ownedUpgrades()
			local tk = tokens()
			for _, node in ipairs(RebirthUpgradeConfig.NODES) do
				if not owned[node.id] and RebirthUpgradeConfig.areRequirementsPurchased(node, owned) then
					if tk >= (node.cost or 0) and tick() - (lastNode[node.id] or 0) >= 2 then
						if RebirthUpgrades then
							pcall(function() RebirthUpgrades.RemoteEvent:FireServer("requestPurchase", node.id) end)
						end
						lastNode[node.id] = tick()
					end
				end
			end
		end
		task.wait(1.5)
	end
end)

-- Status.
task.spawn(function()
	while not State.stopped do
		local snap = lastSnap
		local visible = snap and snap.visibleButtons or {}
		local upgradeSet = activeUpgradeBehaviors()
		local pending = 0
		if snap and snap.components then
			for _, comp in ipairs(snap.components) do
				if comp.hasUpgradeCore and comp.upgradeLevel and comp.upgradeLevel < UpgradeConfig.MAX_LEVEL then
					for b in pairs(comp.behaviors or {}) do
						if upgradeSet[b] then pending += 1 break end
					end
				end
			end
		end
		setStatus(
			("Coins: %s | ATM: %s | Tokens: %s | Rebirths: %s | Buyables: %d | Upgradables: %d"):format(
				formatMoney(coins()),
				formatMoney(atmBalance()),
				tokens(),
				rebirthCount(),
				#visible,
				pending
			)
		)
		task.wait(1)
	end
end)

Library:OnUnload(function()
	State.stopped = true
	getgenv()[GNAME] = nil
end)