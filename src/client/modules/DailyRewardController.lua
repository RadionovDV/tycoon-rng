-- DailyRewardController.lua
-- Renders 7 reward tiles inside MenuGui.Upgrade.DailyReward.
-- Shows current day tile as claimable, future tiles as "?", past claimed as dimmed.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local PlayerDataClient = require(ReplicatedStorage.PlayerData.PlayerDataClient)
local DailyRewardConfig = require(ReplicatedStorage.DailyRewardConfig)
local Remotes = ReplicatedStorage.Remotes

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local menuGui = playerGui:WaitForChild("MenuGui")
local upgradeWindow = menuGui:WaitForChild("Upgrade")
local dailyRewardContainer = upgradeWindow:WaitForChild("DailyReward")

local tileTemplate = ReplicatedStorage.UI.Objects:WaitForChild("UpgradeTileButton")

local DailyRewardController = {}

local STATUS_COLORS = {
	available = Color3.fromRGB(43, 43, 43),
	claimed = Color3.fromRGB(30, 30, 30),
	future = Color3.fromRGB(15, 15, 15),
	locked = Color3.fromRGB(81, 0, 1),
}

function DailyRewardController._renderTiles(status)
	for _, child in dailyRewardContainer:GetChildren() do
		if child:IsA("CanvasGroup") then
			child:Destroy()
		end
	end

	local day = status.day
	local claimed = status.claimed or {}
	local rewards = status.rewards or DailyRewardConfig.rewards

	for i = 1, 7 do
		local tile = tileTemplate:Clone()
		tile.Name = "Day" .. tostring(i)

		local tileButton = tile.TileButton
		local iconLabel = tileButton.IconLabel
		local nameLabel = tileButton.NameLabel
		local priceLabel = tileButton.Price.PriceLabel
		local currencyImage = tileButton.Price.CurrencyImage

		iconLabel.Image = "rbxassetid://122178881489757"
		nameLabel.Text = "Day " .. tostring(i)

		if claimed[i] then
			tileButton.ImageColor3 = STATUS_COLORS.claimed
			tile.GroupTransparency = 0.7
			tileButton.Active = false
			tileButton.AutoButtonColor = false
			priceLabel.Text = "Claimed"
			currencyImage.Image = ""
		elseif i == day then
			tileButton.ImageColor3 = STATUS_COLORS.available
			tile.GroupTransparency = 0
			tileButton.Active = true
			tileButton.AutoButtonColor = true

			local reward = rewards[i]
			local rewardText = ""
			if reward then
				if reward.coins then rewardText = rewardText .. tostring(reward.coins) .. "c " end
				if reward.dice then rewardText = rewardText .. tostring(reward.dice) .. "d " end
				if reward.rocks then rewardText = rewardText .. tostring(reward.rocks) .. "r " end
			end
			priceLabel.Text = rewardText
			currencyImage.Image = ""

			tileButton.Activated:Connect(function()
				Remotes.ClaimDailyReward:FireServer({ tileIndex = i })
			end)
		elseif i > day then
			tileButton.ImageColor3 = STATUS_COLORS.future
			tile.GroupTransparency = 0.7
			tileButton.Active = false
			tileButton.AutoButtonColor = false
			priceLabel.Text = "?"
			currencyImage.Image = ""
		else
			tileButton.ImageColor3 = STATUS_COLORS.locked
			tile.GroupTransparency = 0.7
			tileButton.Active = false
			tileButton.AutoButtonColor = false
			priceLabel.Text = "Missed"
			currencyImage.Image = ""
		end

		tile.Parent = dailyRewardContainer
	end
end

function DailyRewardController.Start()
	Remotes.DailyRewardStatus.OnClientEvent:Connect(DailyRewardController._renderTiles)
end

return DailyRewardController