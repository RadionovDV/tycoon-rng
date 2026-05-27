-- RollController.lua
-- Client-side rolling UI handler. Connects the Roll button to the server RemoteEvent
-- and manages the rolling animation sequence (show → scroll → reveal → hide).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Remotes = ReplicatedStorage.Remotes

local player = Players.LocalPlayer
local playerGui = player.PlayerGui
local menuGui = playerGui:WaitForChild("MenuGui")
local rollUI = menuGui:FindFirstChild("Roll")
local gameplayGui = playerGui:WaitForChild("GameplayGui")
local bottomSide = gameplayGui:FindFirstChild("BottomSide")
local rollFrame = bottomSide:FindFirstChild("Roll")
local rollButton = rollFrame:FindFirstChild("RollButton")

local RollController = {}

-- Bind the roll button to the server
if rollButton then
	rollButton.Activated:Connect(function()
		Remotes.RollPet:FireServer()
	end)
end

-- Handle the roll result from the server
Remotes.RollPet.OnClientEvent:Connect(function(result)
	if rollUI then
		rollUI.Visible = true
	end

	-- Simple placeholder animation: show then hide
	-- In Day 3 this will be replaced with scrolling icon animation + sound
	task.wait(0.5)

	if rollUI then
		rollUI.Visible = false
	end
	
	print(result.petType)
end)

return RollController