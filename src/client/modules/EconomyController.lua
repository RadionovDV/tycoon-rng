-- EconomyController.lua
-- Client-side currency HUD updater. Listens for currency data changes and refreshes labels.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerDataClient = require(ReplicatedStorage.PlayerData.PlayerDataClient)
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player.PlayerGui
local mainGui = playerGui:WaitForChild("GameplayGui")

local FormatNumber = require(ReplicatedStorage.FormatNumber)

local EconomyController = {}

function EconomyController.UpdateDisplay()
	local coinsLabel = mainGui:FindFirstChild("HUD") and mainGui.HUD:FindFirstChild("CoinsLabel")
	local rocksLabel = mainGui:FindFirstChild("HUD") and mainGui.HUD:FindFirstChild("RocksLabel")
	local diceLabel = mainGui:FindFirstChild("HUD") and mainGui.HUD:FindFirstChild("DiceLabel")

	if coinsLabel then
		coinsLabel.Text = FormatNumber.Format(PlayerDataClient.get("coins") or 0)
	end
	if rocksLabel then
		rocksLabel.Text = FormatNumber.Format(PlayerDataClient.get("rocks") or 0)
	end
	if diceLabel then
		diceLabel.Text = FormatNumber.Format(PlayerDataClient.get("dice") or 0)
	end
end

return EconomyController