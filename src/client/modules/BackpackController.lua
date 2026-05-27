-- BackpackController.lua
-- Client-side backpack viewer. Displays owned pets for inspection and manual equip/unequip.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local PlayerDataClient = require(ReplicatedStorage.PlayerData.PlayerDataClient)

local player = Players.LocalPlayer
local playerGui = player.PlayerGui
local menuGui = playerGui:WaitForChild("MenuGui")

local Remotes = ReplicatedStorage.Remotes

local BackpackController = {}

local backpackUI = menuGui:FindFirstChild("Backpack")

function BackpackController.Refresh()
	-- Stub: render the list of owned pets from PlayerDataClient.get("pets") in Day 2
	local pets = PlayerDataClient.get("pets") or {}
	-- In Day 2 this will populate a ScrollingFrame with pet entries
end

return BackpackController