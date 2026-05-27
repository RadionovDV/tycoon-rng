-- LocationService.lua
-- Server-authoritative location unlocking system. Validates prerequisite locations,
-- checks affordability, then unlocks and sets the new location as active.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerService = require(script.Parent.PlayerService)
local EconomyService = require(script.Parent.EconomyService)
local LocationConfig = require(ReplicatedStorage.LocationConfig)

local Remotes = ReplicatedStorage.Remotes

local LocationService = {}

function LocationService.Unlock(player, locationId)
	PlayerService.WaitForLoad(player)

	local config = LocationConfig[locationId]
	if not config then
		warn(string.format("Unknown location: %s", locationId))
		return
	end

	-- Check if already unlocked
	local unlocked = PlayerService.GetValue(player, "unlockedLocations") or {}
	for _, loc in unlocked do
		if loc == locationId then
			return
		end
	end

	-- Check prerequisite location
	if config.prerequisite then
		local hasPrereq = false
		for _, loc in unlocked do
			if loc == config.prerequisite then
				hasPrereq = true
				break
			end
		end
		if not hasPrereq then
			warn(string.format("Player %s missing prerequisite %s for %s", player.Name, config.prerequisite, locationId))
			return
		end
	end

	-- Validate affordability
	if not EconomyService.CanAfford(player, config.unlockCost, "coins") then
		return
	end

	EconomyService.SubtractCoins(player, config.unlockCost)

	-- Add to unlocked list and set as current location
	PlayerService.UpdateValue(player, "unlockedLocations", function(list)
		table.insert(list, locationId)
		return list
	end)
	PlayerService.UpdateValue(player, "currentLocation", function()
		return locationId
	end)

	-- Re-spawn enemies for the new location
	local CombatService = require(script.Parent.CombatService)
	CombatService.SpawnEnemiesForPlayer(player)
end

function LocationService.StartListening()
	Remotes.UnlockLocation.OnServerEvent:Connect(function(player, locationId)
		LocationService.Unlock(player, locationId)
	end)
end

return LocationService