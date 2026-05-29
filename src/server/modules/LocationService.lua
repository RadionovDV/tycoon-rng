-- LocationService.lua
-- Server-authoritative location unlocking and tracking system.
-- Unlock: validates prerequisites, checks affordability, adds to unlockedLocations.
-- Baseplate tracking: scans Workspace for Location/POI/Baseplate parts,
-- connects Touched to update currentLocation when the player physically enters an area.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local PlayerService = require(script.Parent.PlayerService)
local EconomyService = require(script.Parent.EconomyService)
local LocationConfig = require(ReplicatedStorage.LocationConfig)

local Remotes = ReplicatedStorage.Remotes

local LocationService = {}

-- Guards against rapid re-triggers from Touched (fires multiple times per frame)
local touchCooldowns = {}
local TOUCH_COOLDOWN = 1

-- Scans every Location folder in Workspace, finds POI.Baseplate, and connects
-- a Touched handler that updates currentLocation when a player steps on it.
function LocationService._initBaseplateTriggers()
	for _, location in Workspace:GetChildren() do
		local config = LocationConfig[location.Name]
		if not config then
			continue
		end

		local poi = location:FindFirstChild("POI")
		local baseplate = poi and poi:FindFirstChild("Baseplate")
		if not baseplate or not baseplate:IsA("BasePart") then
			continue
		end

		baseplate.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if not player then
				return
			end
			PlayerService.WaitForLoad(player)
			local userId = player.UserId

			-- Debounce: prevent rapid re-triggering
			local now = tick()
			local lastTouch = touchCooldowns[userId]
			if lastTouch and (now - lastTouch) < TOUCH_COOLDOWN then
				return
			end
			touchCooldowns[userId] = now

			-- Only change location if it's already unlocked
			local unlocked = PlayerService.GetValue(player, "unlockedLocations") or {}
			local isUnlocked = false
			for _, loc in unlocked do
				if loc == location.Name then
					isUnlocked = true
					break
				end
			end
			if not isUnlocked then
				return
			end

			-- Skip if already in this location
			local currentLoc = PlayerService.GetValue(player, "currentLocation")

			if currentLoc == location.Name then
				return
			end

			-- Update location and respawn enemies for the new area
			PlayerService.UpdateValue(player, "currentLocation", function()
				return location.Name
			end)

			local CombatService = require(script.Parent.CombatService)
			CombatService.SpawnEnemiesForPlayer(player)
		end)
	end
end

-- Validates prerequisite, checks affordability, unlocks the location (adds to player's list).
-- Does NOT change currentLocation — that happens via Baseplate touch.
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

	-- Add to unlocked list only (currentLocation set by Baseplate touch)
	PlayerService.UpdateValue(player, "unlockedLocations", function(list)
		table.insert(list, locationId)
		return list
	end)
end

function LocationService.StartListening()
	LocationService._initBaseplateTriggers()

	Remotes.UnlockLocation.OnServerEvent:Connect(function(player, locationId)
		LocationService.Unlock(player, locationId)
	end)
end

return LocationService