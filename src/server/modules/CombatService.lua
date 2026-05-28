-- CombatService.lua
-- Server-authoritative combat loop. Runs a heartbeat every 1s.
-- Enemies use PathfindingService to move toward the player, attack pets in range.
-- Pets have HP, can die and revive after 5s. Combat state is synced to client every tick.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")

local PlayerService = require(script.Parent.PlayerService)
local EconomyService = require(script.Parent.EconomyService)
local EnemyConfig = require(ReplicatedStorage.EnemyConfig)
local LocationConfig = require(ReplicatedStorage.LocationConfig)

local Remotes = ReplicatedStorage.Remotes

local CombatService = {}

local enemyState = {}
local petCombat = {}

function CombatService._initPetCombat(player)
	local equippedPets = PlayerService.GetValue(player, "equippedPets") or {}
	local allPets = PlayerService.GetValue(player, "pets") or {}
	local userId = player.UserId

	if not petCombat[userId] then
		petCombat[userId] = {}
	end

	for _, petId in equippedPets do
		if not petCombat[userId][petId] then
			local petEntry = allPets[petId]
			if petEntry then
				petCombat[userId][petId] = {
					hp = petEntry.maxHp or 20,
					maxHp = petEntry.maxHp or 20,
					isAlive = true,
					reviveTimer = 5,
					currentRevive = 0,
				}
			end
		end
	end

	for petId in petCombat[userId] do
		local stillEquipped = false
		for _, pid in equippedPets do
			if pid == petId then
				stillEquipped = true
				break
			end
		end
		if not stillEquipped then
			petCombat[userId][petId] = nil
		end
	end
end

function CombatService.SpawnEnemiesForPlayer(player)
	PlayerService.WaitForLoad(player)
	
	local currentLocation = PlayerService.GetValue(player, "currentLocation") or "Location1"
	local locationData = LocationConfig[currentLocation]
	if not locationData then return end

	local location = Workspace:FindFirstChild(currentLocation)
	if not location then return end

	local poi = location:FindFirstChild("POI")
	local enemySpawns = poi and poi:FindFirstChild("EnemySpawns")
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
				movementSpeed = config.movementSpeed or 8,
				attackRange = config.attackRange or 15,
				attackDamage = config.attackDamage or 5,
				attackRate = config.attackRate or 1,
				isAlive = true,
				zone = zone,
				respawnTimer = 3,
				currentRespawn = 0,
				position = zone.Position,
				path = nil,
				pathIndex = 1,
				pathTimer = 0,
				lastAttackTime = 0,
			}
		end
	end

	CombatService._initPetCombat(player)
end

function CombatService._getPlayerRootPos(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return root and root.Position or nil
end

function CombatService._updateEnemyPaths(player, dt)
	local userId = player.UserId
	local enemies = enemyState[userId]
	if not enemies then return end

	local playerPos = CombatService._getPlayerRootPos(player)
	if not playerPos then return end

	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	for enemyId, state in enemies do
		if not state.isAlive then continue end

		state.pathTimer = state.pathTimer + dt

		if state.pathTimer >= 2 or not state.path then
			state.pathTimer = 0
			task.spawn(function()
				local pathObject = PathfindingService:CreatePath({
					AgentRadius = 2,
					AgentHeight = 5,
				})
				pathObject:ComputeAsync(state.position, playerPos)
				if pathObject.Status == Enum.PathStatus.Success then
					state.path = pathObject:GetWaypoints()
					state.pathIndex = 1
				end
			end)
		end
	end
end

function CombatService._moveEnemies(player, dt)
	local userId = player.UserId
	local enemies = enemyState[userId]
	if not enemies then return end

	for enemyId, state in enemies do
		if not state.isAlive or not state.path then continue end

		if state.pathIndex <= #state.path then
			local waypoint = state.path[state.pathIndex]
			local direction = (waypoint.Position - state.position).Unit
			local distance = (waypoint.Position - state.position).Magnitude

			if distance < 2 then
				state.pathIndex = state.pathIndex + 1
			else
				local moveAmount = math.min(state.movementSpeed * dt, distance)
				state.position = state.position + direction * moveAmount
			end
		end
	end
end

function CombatService._processEnemyAttacks(player, dt)
	local userId = player.UserId
	local enemies = enemyState[userId]
	if not enemies then return end

	local playerPos = CombatService._getPlayerRootPos(player)
	if not playerPos then return end

	local equippedPets = PlayerService.GetValue(player, "equippedPets") or {}
	local alivePetIds = {}
	for _, petId in equippedPets do
		local pState = petCombat[userId] and petCombat[userId][petId]
		if pState and pState.isAlive then
			table.insert(alivePetIds, petId)
		end
	end

	if #alivePetIds == 0 then return end

	for enemyId, state in enemies do
		if not state.isAlive then continue end

		local dist = (state.position - playerPos).Magnitude
		if dist <= state.attackRange then
			state.lastAttackTime = state.lastAttackTime + dt
			if state.lastAttackTime >= state.attackRate then
				state.lastAttackTime = 0

				local targetPetId = alivePetIds[math.random(1, #alivePetIds)]
				local pState = petCombat[userId][targetPetId]
				if pState then
					pState.hp = pState.hp - state.attackDamage
					if pState.hp <= 0 then
						pState.isAlive = false
						pState.currentRevive = 0
						pState.hp = 0
						Remotes.PetDefeated:FireClient(player, { petId = targetPetId })

						for idx, pid in ipairs(alivePetIds) do
							if pid == targetPetId then
								table.remove(alivePetIds, idx)
								break
							end
						end
					end
				end
			end
		end
	end
end

function CombatService._processPetRevives(dt)
	for userId, pTable in petCombat do
		for petId, state in pTable do
			if not state.isAlive then
				state.currentRevive = state.currentRevive + dt
				if state.currentRevive >= state.reviveTimer then
					local player = Players:GetPlayerByUserId(userId)
					if player then
						state.isAlive = true
						state.hp = state.maxHp
						state.currentRevive = 0
						Remotes.PetRevived:FireClient(player, { petId = petId })
					end
				end
			end
		end
	end
end

function CombatService.CombatTick(player, dt)
	local enemies = enemyState[player.UserId]
	if not enemies then return end

	CombatService._initPetCombat(player)

	local equippedPets = PlayerService.GetValue(player, "equippedPets") or {}
	local allPets = PlayerService.GetValue(player, "pets") or {}
	local userId = player.UserId

	local totalDamage = 0
	for _, petId in equippedPets do
		local pState = petCombat[userId] and petCombat[userId][petId]
		if pState and pState.isAlive then
			local petEntry = allPets[petId]
			if petEntry then
				totalDamage = totalDamage + (petEntry.damage or 0)
			end
		end
	end

	local rocksUnlocked = PlayerService.GetValue(player, "rocksUnlocked") or false

	CombatService._updateEnemyPaths(player, dt)
	CombatService._moveEnemies(player, dt)
	CombatService._processEnemyAttacks(player, dt)
	CombatService._processPetRevives(dt)

	for enemyId, state in enemies do
		if state.isAlive then
			if totalDamage > 0 then
				state.hp = state.hp - totalDamage
				if state.hp <= 0 then
					state.isAlive = false
					state.currentRespawn = 0

					EconomyService.AddCoins(player, state.reward)

					if rocksUnlocked then
						local rockReward = math.max(1, math.floor(state.reward / 5))
						EconomyService.AddRocks(player, rockReward)
					end

					if state.zone then
						Remotes.EnemyDefeated:FireClient(player, {
							enemyId = enemyId,
							position = state.position,
							coinsAmount = state.reward,
						})
					end
				end
			end
		else
			state.currentRespawn = state.currentRespawn + dt
			if state.currentRespawn >= state.respawnTimer then
				state.hp = state.maxHp
				state.isAlive = true
				state.currentRespawn = 0
				state.position = state.zone and state.zone.Position or state.position
				state.path = nil
				state.pathIndex = 1
			end
		end
	end

	local syncData = {
		enemies = {},
		pets = {},
	}
	for enemyId, state in enemies do
		syncData.enemies[enemyId] = {
			hp = state.hp,
			maxHp = state.maxHp,
			isAlive = state.isAlive,
			type = state.type,
			position = { X = state.position.X, Y = state.position.Y, Z = state.position.Z },
		}
	end
	if petCombat[userId] then
		for petId, state in petCombat[userId] do
			syncData.pets[petId] = {
				hp = state.hp,
				maxHp = state.maxHp,
				isAlive = state.isAlive,
			}
		end
	end
	Remotes.SyncCombatState:FireClient(player, syncData)
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

	Players.PlayerRemoving:Connect(function(player)
		local userId = player.UserId
		enemyState[userId] = nil
		petCombat[userId] = nil
	end)

	task.spawn(CombatService.TickLoop)
end

return CombatService