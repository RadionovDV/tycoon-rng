-- RollController.lua
-- Client-side rolling UI handler.
-- Fires server on button click, receives pet result, and displays it in the roll popup.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local PlayerDataClient = require(ReplicatedStorage.PlayerData.PlayerDataClient)

local Remotes = ReplicatedStorage.Remotes

local player = Players.LocalPlayer
local playerGui = player.PlayerGui
local menuGui = playerGui:WaitForChild("MenuGui")
local rollUI = menuGui:WaitForChild("Roll")
local gameplayGui = playerGui:WaitForChild("GameplayGui")
local bottomSide = gameplayGui:WaitForChild("BottomSide")
local rollFrame = bottomSide:WaitForChild("Roll")
local rollButton = rollFrame:WaitForChild("RollButton")

local rarityColors = {
	Common = Color3.fromRGB(180, 180, 180),
	Uncommon = Color3.fromRGB(100, 200, 100),
	Rare = Color3.fromRGB(80, 150, 255),
	Epic = Color3.fromRGB(180, 80, 255),
	Legendary = Color3.fromRGB(255, 180, 50),
	Divine = Color3.fromRGB(255, 80, 80),
}

local RollController = {}

rollButton.Activated:Connect(function()
	Remotes.RollPet:FireServer()
end)

Remotes.RollPet.OnClientEvent:Connect(function(result)
	if not rollUI then
		return
	end

	local nameLabel = rollUI:FindFirstChild("NameLabel", true)
	local rarityLabel = rollUI:FindFirstChild("RarityLabel", true)
	local iconLabel = rollUI:FindFirstChild("IconLabel", true)

	if nameLabel then
		nameLabel.Text = result.displayName
	end
	if rarityLabel then
		rarityLabel.Text = result.rarity
		rarityLabel.TextColor3 = rarityColors[result.rarity] or Color3.new(1, 1, 1)
	end

	rollUI.Visible = true
	task.wait(1.5)
	rollUI.Visible = false
end)

return RollController