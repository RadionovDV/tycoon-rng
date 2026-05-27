-- PlayerService.lua
-- Server-side entry point for player data management.
-- Starts PlayerDataServer with the default data schema, then fires PlayerReady
-- via Signal for each player whose data has finished loading.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataServer = require(ReplicatedStorage.PlayerData.PlayerDataServer)
local Signal = require(ReplicatedStorage.Signal)

local PlayerService = {}

local DEFAULT_DATA = {
	coins = 0,
	rocks = 0,
	dice = 0,
	pets = {},
	equippedPets = {},
	maxEquipSlots = 1,
	upgrades = {},
	unlockedLocations = { "Location1" },
	currentLocation = "Location1",
	rollCooldown = 2,
	luck = 1,
	autoRollUnlocked = false,
	rocksUnlocked = false,
	rebirthCount = 0,
	rebirthBonusLuck = 0,
	enemyCount = 1,
}

PlayerService.DEFAULT_DATA = DEFAULT_DATA

-- Fires with (player) once the player's data is fully loaded and ready
PlayerService.PlayerReady = Signal.new()

function PlayerService.Start()
	PlayerDataServer.start(DEFAULT_DATA)

	-- Handle existing players already in the server
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			PlayerDataServer.waitForDataLoadAsync(player)
			PlayerService.PlayerReady:Fire(player)
		end)
	end

	-- Handle players who join later
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			PlayerDataServer.waitForDataLoadAsync(player)
			PlayerService.PlayerReady:Fire(player)
		end)
	end)
end

function PlayerService.GetValue(player, key)
	return PlayerDataServer.getValue(player, key)
end

function PlayerService.UpdateValue(player, key, transform)
	PlayerDataServer.updateValue(player, key, transform)
end

function PlayerService.WaitForLoad(player)
	if not PlayerDataServer.hasLoaded(player) then
		PlayerDataServer.waitForDataLoadAsync(player)
	end
end

return PlayerService