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
local rollFrame = menuGui:WaitForChild("Roll")
local background = rollFrame:WaitForChild("Background")
local viewingFrame = background:WaitForChild("Viewing")
local petIcon = viewingFrame:WaitForChild("PetIcon")
local petNameLabel = viewingFrame:WaitForChild("NameLabel")
local rarityLabel = petIcon:WaitForChild("RarityLabel")
local autoRoll = background:WaitForChild("AutoRoll")

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
	if not rollFrame then
		return
	end

	local nameLabel = rollFrame:FindFirstChild("NameLabel", true)
	local rarityLabel = rollFrame:FindFirstChild("RarityLabel", true)

	petNameLabel.Text = result.displayName
	rarityLabel.Text = result.rarity
	rarityLabel.TextColor3 = rarityColors[result.rarity] or Color3.new(1, 1, 1)

	rollFrame.Visible = true
	task.wait(1.5)
	rollFrame.Visible = false
end)

return RollController