-- UpgradeController.lua
-- Client-side interactive upgrade tree board with pan and zoom.
-- Renders upgrade nodes inside MenuGui.Upgrade.Canvas.Board as cloned UpgradeTileButton templates.
-- Handles purchase requests via Remotes.PurchaseUpgrade.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local PlayerDataClient = require(ReplicatedStorage.PlayerData.PlayerDataClient)
local UpgradeConfig = require(ReplicatedStorage.UpgradeConfig)
local Remotes = ReplicatedStorage.Remotes

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local gameplayGui = playerGui:WaitForChild("GameplayGui")
local menuGui = playerGui:WaitForChild("MenuGui")

-- Pre-fetch UI references at module top-level (project convention)
local upgradeWindow = menuGui:WaitForChild("Upgrade")
local canvas = upgradeWindow:WaitForChild("Canvas")
local board = canvas:WaitForChild("Board")
local uiScale = board:WaitForChild("UIScale")

-- HUD notification badge (red dot with count on the Upgrade button)
local bottomSide = gameplayGui:WaitForChild("BottomSide")
local upgradeHudFrame = bottomSide:WaitForChild("Upgrade")
local redPoint = upgradeHudFrame:WaitForChild("RedPoint")
local updateCountLabel = redPoint:WaitForChild("UpdateCountLabel")

-- Template for upgrade nodes, created by the user in ReplicatedStorage.UI.Objects
local tileTemplate = ReplicatedStorage.UI.Objects:WaitForChild("UpgradeTileButton")

local UpgradeController = {}

-- Tile background colors for each purchase status
local STATUS_COLORS = {
	owned     = Color3.fromRGB(74, 168, 230),    -- dark green
	buyable   = Color3.fromRGB(43, 43, 43),  -- blue
	locked    = Color3.fromRGB(81, 0, 1),    -- dark gray
	notenough = Color3.fromRGB(0, 0, 0),   -- dark orange
}

-- ============================================================================
-- DRAG (PAN) STATE
-- ============================================================================
-- Tracks whether the user is actively panning the board.
-- Roblox distinguishes button clicks from drags automatically (Activated does
-- not fire after significant cursor movement), but we also gate on thresholdMet
-- for safety.

local drag = {
	active = false,
	startInputPos = nil,
	startBoardPos = nil,
	thresholdMet = false,
}

local DRAG_THRESHOLD = 5
local hasRenderedOnce = false

-- ============================================================================
-- PRIVATE HELPERS
-- ============================================================================

-- Determines the status of a single upgrade for the current player.
-- @return string: "owned", "buyable", "locked", or "notenough"
function UpgradeController._getStatus(upgradeId, config, upgrades, coins, dice)
	if upgrades[upgradeId] then
		return "owned"
	end

	if config.requires and not upgrades[config.requires] then
		return "locked"
	end

	local balance = config.currency == "coins" and coins or dice
	if balance >= config.cost then
		return "buyable"
	end

	return "notenough"
end

-- Returns a Color3 for the IconLabel indicator, based on the upgrade's effect type

-- Builds the status/cost text shown at the bottom of each tile
function UpgradeController._getStatusText(status, config)
	if status == "owned" then
		return "✓ Owned"
	end
	if status == "locked" then
		local reqConfig = UpgradeConfig[config.requires]
		local reqName = reqConfig and reqConfig.displayName or config.requires
		return "Locked: " .. reqName
	end
	return tostring(config.cost) .. " " .. config.currency
end

-- ============================================================================
-- RENDER
-- ============================================================================

-- Destroys all existing upgrade tile instances in the Board, then creates new
-- ones from scratch based on the latest player data. Preserves pan/zoom state
-- across re-renders.
function UpgradeController._renderUpgrades()
	-- --- 1.  Centre the cluster on the very first render  ---
	if not hasRenderedOnce then
		local canvasSize = canvas.AbsoluteSize
		if canvasSize.X > 0 and canvasSize.Y > 0 then
			board.Position = UDim2.fromOffset(
				math.floor(800),
				math.floor(400)
			)
		end
		hasRenderedOnce = true
	end

	-- --- 2.  Save current pan / zoom to restore after rebuild  ---
	local savedScale = uiScale.Scale
	local savedPos = UDim2.fromOffset(board.Position.X.Offset, board.Position.Y.Offset)

	-- --- 3.  Destroy old nodes (keep UIScale and any non-ImageButton children)  ---
	for _, child in board:GetChildren() do
		if child:IsA("ImageButton") then
			child:Destroy()
		end
	end

	-- --- 4.  Read current player data  ---
	local upgrades = PlayerDataClient.get("upgrades") or {}
	local coins = PlayerDataClient.get("coins") or 0
	local dice = PlayerDataClient.get("dice") or 0
	
	-- --- 5.  Create a tile for every upgrade defined in config  ---
	for upgradeId, config in UpgradeConfig do
		local pos = config.nodePosition

		local status = UpgradeController._getStatus(upgradeId, config, upgrades, coins, dice)
		
		-- Clone the template and position it in the Board
		local tile = tileTemplate:Clone()
		tile.Name = upgradeId
		tile.Position = UDim2.fromOffset(pos.x, pos.y)
		tile.ImageColor3 = STATUS_COLORS[status]

		-- Configure IconLabel as a coloured indicator based on effect type
		local iconLabel = tile.IconLabel
		iconLabel.Image = config.icon
		
		local nameLabel = tile.NameLabel
		nameLabel.Text = config.displayName
		
		local priceLabel = tile.Price.PriceLabel
		priceLabel.Text = config.cost
		
		local currencyImage = tile.Price.CurrencyImage
		currencyImage.Image = if config.currency == "coins"
			then "rbxassetid://122995436726509"
			else "rbxassetid://132804116237326"


		tile.Visible = status ~= "locked"
		
		if status ~= "buyable" then
			tile.Active = false
			tile.AutoButtonColor = false
		else
			tile.Activated:Connect(function()
				if drag.thresholdMet then
					return
				end
				Remotes.PurchaseUpgrade:FireServer(upgradeId)
			end)
		end

		tile.Parent = board
	end

	-- --- 6.  Restore pan / zoom  ---
	board.Position = savedPos
	uiScale.Scale = savedScale
end

-- ============================================================================
-- INPUT HANDLING (Pan & Zoom)
-- ============================================================================

-- Attaches all input listeners once at module load.
function UpgradeController._setupInput()
	local isDrag = false
	local startInputPosition = nil
	local prevOffsetX = 0
	local prevOffsetY = 0
	
	UserInputService.InputBegan:Connect(function(inputObject, gameProcessed)
		if inputObject.UserInputType == Enum.UserInputType.MouseButton1
			or inputObject.UserInputType == Enum.UserInputType.Touch then
			isDrag = true
			prevOffsetX = 0
			prevOffsetY = 0
			startInputPosition = inputObject.Position
		end
	end)
	
	UserInputService.InputEnded:Connect(function(inputObject, gameProcessed)
		if inputObject.UserInputType == Enum.UserInputType.MouseButton1
			or inputObject.UserInputType == Enum.UserInputType.Touch then
			isDrag = false
			
		end
	end)
	
	UserInputService.InputChanged:Connect(function(inputObject, gameProcessed)
		if isDrag then
			local inputOffsetRelative = startInputPosition - inputObject.Position
			local xOffsetRelative = board.Position.X.Offset - inputOffsetRelative.X + prevOffsetX
			local yOffsetRelative = board.Position.Y.Offset - inputOffsetRelative.Y + prevOffsetY

			board.Position = UDim2.fromOffset(xOffsetRelative, yOffsetRelative)

			prevOffsetX = inputOffsetRelative.X
			prevOffsetY = inputOffsetRelative.Y
		end
	end)
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

-- Called from GameClient when PlayerDataClient fires updated() with
-- "upgrades", "coins", or "dice".
-- Updates the HUD notification badge and re-renders the upgrade tree.
function UpgradeController.UpdateNotifications()
	local upgrades = PlayerDataClient.get("upgrades") or {}
	local coins = PlayerDataClient.get("coins") or 0
	local dice = PlayerDataClient.get("dice") or 0

	-- Count affordable upgrades for the red notification badge
	local count = 0
	for upgradeId, config in UpgradeConfig do
		if upgrades[upgradeId] then
			continue
		end
		if config.requires and not upgrades[config.requires] then
			continue
		end
		local balance = config.currency == "coins" and coins or dice
		if balance >= config.cost then
			count += 1
		end
	end

	if count > 0 then
		redPoint.Visible = true
		updateCountLabel.Text = tostring(count)
	else
		redPoint.Visible = false
	end

	-- Re-render the tree (wrapped in pcall for safety)
	UpgradeController._renderUpgrades()
	--local success, err = pcall(UpgradeController._renderUpgrades)
	--if not success then
	--	warn(string.format("UpgradeController render error: %s", tostring(err)))
	--end
end

-- ============================================================================
-- INIT
-- ============================================================================

UpgradeController._setupInput()

return UpgradeController