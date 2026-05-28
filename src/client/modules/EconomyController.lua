-- EconomyController.lua
-- Client-side currency HUD updater. Listens for currency data changes and refreshes labels.
-- Also handles coin-fly animation on enemy defeat.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerDataClient = require(ReplicatedStorage.PlayerData.PlayerDataClient)
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player.PlayerGui
local gameplayGui = playerGui:WaitForChild("GameplayGui")
local coinsLabel = gameplayGui:WaitForChild("LeftSide") 
	and gameplayGui.LeftSide:WaitForChild("Coins") 
	and gameplayGui.LeftSide.Coins:WaitForChild("TextLabel")
local rocksLabel = gameplayGui:WaitForChild("LeftSide") 
	and gameplayGui.LeftSide:WaitForChild("Rocks") 
	and gameplayGui.LeftSide.Rocks:WaitForChild("TextLabel")

local FormatNumber = require(ReplicatedStorage.FormatNumber)
local Remotes = ReplicatedStorage.Remotes

local EconomyController = {}

function EconomyController.UpdateDisplay()
	if coinsLabel then
		coinsLabel.Text = FormatNumber.Format(PlayerDataClient.get("coins") or 0)
	end
	if rocksLabel then
		rocksLabel.Text = FormatNumber.Format(PlayerDataClient.get("rocks") or 0)
	end
end

function EconomyController.AnimateCoin(amount, screenPosition)
	local coin = Instance.new("ImageLabel")
	coin.Size = UDim2.new(0, 30, 0, 30)
	coin.Position = UDim2.new(0, screenPosition.X - 15, 0, screenPosition.Y - 15)
	coin.BackgroundTransparency = 1
	coin.Image = "rbxassetid://122995436726509"
	coin.ZIndex = 100
	coin.Parent = gameplayGui

	local targetPos = coinsLabel.AbsolutePosition
	local target = UDim2.new(0, targetPos.X, 0, targetPos.Y)

	local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local tween = TweenService:Create(coin, tweenInfo, { Position = target })
	tween:Play()
	tween.Completed:Connect(function()
		coin:Destroy()
		EconomyController.UpdateDisplay()
	end)
end

Remotes.EnemyDefeated.OnClientEvent:Connect(function(data)
	local camera = workspace.CurrentCamera
	local screenPos = camera:WorldToScreenPoint(data.position)
	if screenPos then
		EconomyController.AnimateCoin(data.coinsAmount or 0, Vector2.new(screenPos.X, screenPos.Y))
	end
end)

return EconomyController