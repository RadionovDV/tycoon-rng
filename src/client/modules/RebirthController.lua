-- RebirthController.lua
-- Client-side rebirth menu. Renders requirements from RebirthConfig,
-- highlights unmet requirements in red, handles the confirmation popup,
-- and fires PerformRebirth on confirm.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local PlayerDataClient = require(ReplicatedStorage.PlayerData.PlayerDataClient)
local RebirthConfig = require(ReplicatedStorage.RebirthConfig)
local LocationConfig = require(ReplicatedStorage.LocationConfig)
local FormatNumber = require(ReplicatedStorage.FormatNumber)
local TableUtils = require(ReplicatedStorage.TableUtils)

local Remotes = ReplicatedStorage.Remotes

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local menuGui = playerGui:WaitForChild("MenuGui")
local messageGui = playerGui:WaitForChild("MessageGui")

local rebirthWindow = menuGui:WaitForChild("Rebirth")
local topBar = rebirthWindow:WaitForChild("TopBar")
local titleLabel = topBar:WaitForChild("Frame"):WaitForChild("TitleLabel")
local body = rebirthWindow:WaitForChild("Body")
local requirementBoard = body:WaitForChild("RequirementBoard")
local requirementTiles = requirementBoard:WaitForChild("Tiles")
local resultBoard = body:WaitForChild("ResultBoard")
local resultTiles = resultBoard:WaitForChild("Tiles")
local resultTile = resultTiles:WaitForChild("ItemTile")
local resultItemFrame = resultTile:WaitForChild("Frame")
local resultMultLabel = resultItemFrame:WaitForChild("MultLabel")
local rebirthButton = body:WaitForChild("RebirthButton")
local messageBackground = messageGui:WaitForChild("Background")

local itemTileTemplate = ReplicatedStorage.UI.Objects:WaitForChild("ItemTile")
local confirmationTemplate = ReplicatedStorage.UI.Objects:WaitForChild("ConfirmationMenu")

local RequireMentTileIcon = {
	unlockedLocations = "rbxassetid://109890773346587",
	coins = "rbxassetid://122995436726509",
	dices = "rbxassetid://132804116237326",
	rocks = "rbxassetid://110971351869251",
	enemyKills = "rbxassetid://88395994860267",
	pets = "rbxassetid://6774884752",
}

-- Tracks the last Activated connection so we can disconnect it on re-render
local rebirthButtonConn = nil

local RebirthController = {}

-- Reads current player data, evaluates the next rebirth tier,
-- and renders all requirement tiles + the result board.
function RebirthController.Refresh()
	local rebirthCount = PlayerDataClient.get("rebirthCount") or 0
	local rebirthBonusLuck = PlayerDataClient.get("rebirthBonusLuck") or 0
	local tyreConfig = RebirthConfig["Rebirth" .. tostring(rebirthCount + 1)]

	if not tyreConfig then
		titleLabel.Text = "Max Rebirths"
		rebirthButton.Active = false
		return
	end

	for _, child in requirementTiles:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local canClaimRebirth = true
	for reqType, reqSource in tyreConfig.requirements do		
		local itemTile = itemTileTemplate:Clone()
		local iconLabel = itemTile.Frame.IconLabel
		local countLabel = itemTile.Frame.CountLabel
		iconLabel.Image = RequireMentTileIcon[reqType]
		itemTile.Parent = requirementTiles
		
		local isReqFit = false
		local reqValue = nil
		if reqType == "unlockedLocations" then
			local unlockedLocations = PlayerDataClient.get(reqType) or {}
			reqValue = table.find(unlockedLocations, reqSource)
			isReqFit = reqValue ~= nil
			countLabel.Text = LocationConfig[reqSource].displayName
		elseif reqType == "pets" then
			reqValue = TableUtils.objLength(PlayerDataClient.get(reqType) or {})
			isReqFit = reqValue >= reqSource
			countLabel.Text = `{FormatNumber.Format(reqValue)}/{FormatNumber.Format(reqSource)}`
		else
			reqValue = PlayerDataClient.get(reqType) or 0
			isReqFit = reqValue >= reqSource
			countLabel.Text = `{FormatNumber.Format(reqValue)}/{FormatNumber.Format(reqSource)}`
		end
		
		if not isReqFit then
			canClaimRebirth = false
		end
		
		countLabel.TextColor3 = if isReqFit
			then Color3.fromRGB(0, 120, 0)
			else Color3.fromRGB(120, 0, 0)
	end

	titleLabel.Text = tyreConfig.displayName
	resultMultLabel.Text = tyreConfig.luckBonus
	rebirthButton.Active = canClaimRebirth
	rebirthButton.Unavailable.Visible = not canClaimRebirth

	-- Clear previous connection and bind new one
	if rebirthButtonConn then
		rebirthButtonConn:Disconnect()
		rebirthButtonConn = nil
	end
	rebirthButtonConn = rebirthButton.Activated:Connect(function()
		if not canClaimRebirth then return end
		RebirthController._showConfirmation(tyreConfig)
	end)
end

-- Shows the confirmation popup cloned from ReplicatedStorage.ConfirmationMenu.
function RebirthController._showConfirmation(config)
	local confirm = confirmationTemplate:Clone()
	messageBackground.Visible = true
	confirm.Parent = messageBackground

	local messageLabel = confirm:FindFirstChild("Body"):FindFirstChild("MessageLabel")
	if messageLabel then
		messageLabel.Text = string.format(
			"You will lose all pets, coins, upgrades, and locations.\nPermanently gain +%d%% luck. Continue?",
			math.floor(config.luckBonus * 100)
		)
	end

	local confirmButton = confirm:FindFirstChild("Body"):FindFirstChild("ConfirmButton")
	if confirmButton then
		confirmButton.Activated:Connect(function()
			messageBackground.Visible = false
			Remotes.PerformRebirth:FireServer()
			confirm:Destroy()
		end)
	end

	local closeButton = confirm:FindFirstChild("CloseButton", true)
	if closeButton then
		closeButton.Activated:Connect(function()
			messageBackground.Visible = false
			confirm:Destroy()
		end)
	end

	confirm.Visible = true
end

return RebirthController