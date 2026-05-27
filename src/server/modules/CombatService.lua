-- CombatService.lua
-- Server-authoritative combat loop. Runs a heartbeat every 1s.
-- Each tick: equipped pets deal combined damage to alive enemies in the current location.
-- Defeated enemies grant coins (and rocks if unlocked), then respawn after 3 seconds.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local PlayerService = require(script.Parent.PlayerService)
local EconomyService = require(script.Parent.EconomyService)
local EnemyConfig = require(ReplicatedStorage.EnemyConfig)
local LocationConfig = require(ReplicatedStorage.LocationConfig)

local Remotes = ReplicatedStorage.Remotes

local CombatService = {}

-- In-memory enemy state per player. Respawns when the player leaves or changes location.
local enemyState = {}

function CombatService.SpawnEnemiesForPlayer(player)
	PlayerService.WaitForLoad(player)

	local currentLocation = PlayerService.GetValue(player, "currentLocation") or "Location1"
	local locationData = LocationConfig[currentLocation]
	if not locationData then return end

	local location = Workspace:FindFirstChild(currentLocation)
	if not location then return end

	local poi = location:FindFirstChild("POI")
	local enemySpawns = poi:FindFirstChild("EnemySpawns")
	if not enemySpawns then return end

	local zones = enemySpawns:GetChildren()
	if #zones == 0 then return end

	local enemyCount = PlayerService.GetValue(player, "enemyCount") or 1
	local enemyTypes = locationData.defaultEnemyTypes

	enemyState[player.UserId] = {}

	for i = 1, math.min(enemyCount, #zones) do
		local zone = zones[(player.UserId + i - 1) % #zones + 1]
		local enemyType = enemyTypes[(i - 1) % #enemyTypes + 1]
		local config = EnemyConfig.Map[enemyType]
		if config then
			local enemyId = string.format("%s_%d", enemyType, i)
			enemyState[player.UserId][enemyId] = {
				type = enemyType,
				hp = config.hp,
				maxHp = config.hp,
				reward = config.reward,
				isAlive = true,
				zone = zone,
				respawnTimer = 3,
				currentRespawn = 0,
			}
		end
	end
end

function CombatService.CombatTick(player, dt)
	local enemies = enemyState[player.UserId]
	if not enemies then return end

	-- Retrieve equipped pet data for damage calculation
	local equippedPets = PlayerService.GetValue(player, "equippedPets") or {}
	local allPets = PlayerService.GetValue(player, "pets") or {}
	if #equippedPets == 0 then return end

	local totalDamage = 0
	for _, petId in equippedPets do
		local petEntry = allPets[petId]
		if petEntry then
			totalDamage += petEntry.damage or 0
		end
	end

	if totalDamage <= 0 then return end

	local rocksUnlocked = PlayerService.GetValue(player, "rocksUnlocked") or false

	for enemyId, state in enemies do
		if state.isAlive then
			state.hp -= totalDamage
			if state.hp <= 0 then
				state.isAlive = false
				state.currentRespawn = 0

				-- Award coins on enemy defeat
				EconomyService.AddCoins(player, state.reward)

				-- Award rocks if the player has unlocked that currency
				if rocksUnlocked then
					local rockReward = math.max(1, math.floor(state.reward / 5))
					EconomyService.AddRocks(player, rockReward)
				end

				-- Tell the client where to play the coin animation
				if state.zone then
					Remotes.EnemyDefeated:FireClient(player, {
						position = state.zone.Position,
						coinsAmount = state.reward,
					})
				end
			end
		else
			state.currentRespawn += dt
			if state.currentRespawn >= state.respawnTimer then
				state.hp = state.maxHp
				state.isAlive = true
				state.currentRespawn = 0
			end
		end
	end
end

function CombatService.TickLoop()
	while task.wait(1) do
		for _, player in Players:GetPlayers() do
			local success, err = pcall(function()
				CombatService.CombatTick(player, 1)
			end)
			if not success then
				warn(string.format("Combat tick error for %s: %s", player.Name, tostring(err)))
			end
		end
	end
end

function CombatService.Start()
	-- Handle all players (existing + new) by waiting for their data, then spawning enemies
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			PlayerService.WaitForLoad(player)
			CombatService.SpawnEnemiesForPlayer(player)
		end)
	end

	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			PlayerService.WaitForLoad(player)
			CombatService.SpawnEnemiesForPlayer(player)
		end)
	end)

	task.spawn(CombatService.TickLoop)
end

return CombatService