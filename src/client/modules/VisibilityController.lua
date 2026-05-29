-- VisibilityController.lua
-- Shows/hides HUD elements based on PlayerData boolean flags set by upgrades.
-- Server-authoritative: flags are set by UpgradeService, client only reads and toggles UI.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local PlayerDataClient = require(ReplicatedStorage.PlayerData.PlayerDataClient)

local player = Players.LocalPlayer
local playerGui = player.PlayerGui
local gameplayGui = playerGui:WaitForChild("GameplayGui")

local VisibilityController = {}

-- Maps PlayerData boolean field → UI instance to toggle
local VISIBILITY_MAP = {
	rocksUnlocked = gameplayGui.LeftSide:FindFirstChild("Rocks"),
	shopUnlocked = gameplayGui.RightSide:FindFirstChild("Shop"),
	rebirthUnlocked = gameplayGui.RightSide:FindFirstChild("Rebirth"),
	indexUnlocked = gameplayGui.RightSide:FindFirstChild("Index"),
}

-- Reads each flag from PlayerData and sets UI visibility accordingly.
function VisibilityController.Refresh()
	for fieldName, uiElement in VISIBILITY_MAP do
		if not uiElement then
			continue
		end
		local isUnlocked = PlayerDataClient.get(fieldName) or false
		uiElement.Visible = isUnlocked
	end
end

return VisibilityController