-- GameClient.lua (LocalScript)
-- Client-side entry point. Waits for PlayerDataClient to load, then requires all controllers.
-- Subscribes to PlayerDataClient.updated Signal to keep UI in sync with server data.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local module = script.Parent.Modules

local PlayerDataClient = require(ReplicatedStorage.PlayerData.PlayerDataClient)
local EconomyController = require(module.EconomyController)
local RollController = require(module.RollController)
local CombatController = require(module.CombatController)
local UpgradeController = require(module.UpgradeController)
local LocationController = require(module.LocationController)
local BackpackController = require(module.BackpackController)

PlayerDataClient.start()

if not PlayerDataClient.hasLoaded() then
	PlayerDataClient.loaded:Wait()
end

local GameClient = {
	Controllers = {
		EconomyController = EconomyController,
		RollController = RollController,
		CombatController = CombatController,
		UpgradeController = UpgradeController,
		LocationController = LocationController,
		BackpackController = BackpackController,
	},
}

-- React to any server-side data change and update relevant UI
PlayerDataClient.updated:Connect(function(valueName, value)
	if valueName == "coins" or valueName == "rocks" or valueName == "dice" then
		EconomyController.UpdateDisplay()
	elseif valueName == "upgrades" then
		UpgradeController.UpdateNotifications()
	elseif valueName == "pets" then
		BackpackController.Refresh()
	elseif valueName == "equippedPets" then
		CombatController.SyncEquippedPets()
	elseif valueName == "currentLocation" or valueName == "unlockedLocations" then
		LocationController.UpdateGateStates()
	end
end)

-- Initial render after load
local data = PlayerDataClient.get("coins")
EconomyController.UpdateDisplay()
UpgradeController.UpdateNotifications()
BackpackController.Refresh()
LocationController.UpdateGateStates()

print("GameClient initialized", data)

return GameClient