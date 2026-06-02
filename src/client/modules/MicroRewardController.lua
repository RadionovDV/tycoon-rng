-- MicroRewardController.lua
-- Renders 3 timer tiles inside MenuGui.Upgrade.MicroReward.
-- Each tile shows a countdown or Claim button, gated by corresponding upgrade.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local PlayerDataClient = require(ReplicatedStorage.PlayerData.PlayerDataClient)
local MicroRewardConfig = require(ReplicatedStorage.MicroRewardConfig)
local Remotes = ReplicatedStorage.Remotes

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local menuGui = playerGui:WaitForChild("MenuGui")
local upgradeWindow = menuGui:WaitForChild("Upgrade")
local microRewardContainer = upgradeWindow:WaitForChild("MicroReward")

local tileTemplate = ReplicatedStorage.UI.Objects:WaitForChild("UpgradeTileButton")

local MicroRewardController = {}

local STATUS_COLORS = {
	available = Color3.fromRGB(43, 43, 43),
	cooldown = Color3.fromRGB(30, 30, 30),
	locked = Color3.fromRGB(15, 15, 15),
}

local tiers = {}
local updateThread = nil

function MicroRewardController._formatTime(seconds)
	local m = math.floor(seconds / 60)
	local s = math.floor(seconds % 60)
	return string.format("%02d:%02d", m, s)
end

function MicroRewardController._renderTiles(status)
	for _, child in microRewardContainer:GetChildren() do
		if child:IsA("CanvasGroup") then
			child:Destroy()
		end
	end

	local tiersData = status.tiers or {}

	for _, tierData in tiersData do
		local tier = tierData.tier
		local config = MicroRewardConfig[tier]
		if not config then continue end

		local tile = tileTemplate:Clone()
		tile.Name = "MicroRewardTier" .. tostring(tier)

		local tileButton = tile.TileButton
		local iconLabel = tileButton.IconLabel
		local nameLabel = tileButton.NameLabel
		local priceLabel = tileButton.Price.PriceLabel
		local currencyImage = tileButton.Price.CurrencyImage

		iconLabel.Image = "rbxassetid://76179577512196"
		currencyImage.Image = ""

		if tierData.timeLeft < 0 then
			tile.GroupTransparency = 0.7
			tileButton.ImageColor3 = STATUS_COLORS.locked
			tileButton.Active = false
			tileButton.AutoButtonColor = false
			nameLabel.Text = "Locked"
			priceLabel.Text = ""
		elseif tierData.canClaim then
			tile.GroupTransparency = 0
			tileButton.ImageColor3 = STATUS_COLORS.available
			tileButton.Active = true
			tileButton.AutoButtonColor = true
			nameLabel.Text = tostring(config.minutes) .. " min"
			priceLabel.Text = "Claim"

			tileButton.Activated:Connect(function()
				Remotes.ClaimMicroReward:FireServer({ tier = tier })
			end)
		else
			tile.GroupTransparency = 0.3
			tileButton.ImageColor3 = STATUS_COLORS.cooldown
			tileButton.Active = false
			tileButton.AutoButtonColor = false
			nameLabel.Text = tostring(config.minutes) .. " min"
			priceLabel.Text = MicroRewardController._formatTime(tierData.timeLeft)
		end

		tile.Parent = microRewardContainer
	end
end

function MicroRewardController._requestStatus()
	Remotes.MicroRewardStatus:FireServer()
end

function MicroRewardController.Start()
	Remotes.MicroRewardStatus.OnClientEvent:Connect(MicroRewardController._renderTiles)
	MicroRewardController._requestStatus()

	if updateThread then task.cancel(updateThread) end
	updateThread = task.spawn(function()
		while true do
			task.wait(60)
			MicroRewardController._requestStatus()
		end
	end)
end

return MicroRewardController