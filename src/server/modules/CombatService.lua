-- CombatService.lua
-- Server-authoritative combat loop. Runs a heartbeat every 1s.
-- Enemies move directly toward the player, attack pets in range.
-- Pets have HP, can die and revive after 5s. Combat state is synced to client every tick.
-- Enemies are fully removed on death and respawned after cooldown via respawnQueue.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local PlayerService = require(script.Parent.PlayerService)
local EconomyService = require(script.Parent.EconomyService)
local EnemyConfig = require(ReplicatedStorage.EnemyConfig)
local LocationConfig = require(ReplicatedStorage.LocationConfig)

local Remotes = ReplicatedStorage.Remotes

local CombatService = {}

local enemyState = {}
local petCombat = {}
local respawnQueue = {}
local enemyIdCounter = {}

function CombatService._nextEnemyId(userId)
	local counter = (enemyIdCounter[userId] or 0) + 1
	enemyIdCounter[userId] = counter
	return counter
end

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

function CombatService._newEnemyEntry(userId, enemyType, zone)
	local config = EnemyConfig.Map[enemyType]
	if not config then return nil end

	return {
		type = enemyType,
		hp = config.hp,
		maxHp = config.hp,
		reward = config.reward,
		movementSpeed = config.movementSpeed or 8,
		attackRange = config.attackRange or 15,
		attackDamage = config.attackDamage or 5,
		attackRate = config.attackRate or 1,
		zone = zone,
		position = zone.Position,
		lastAttackTime = 0,
	}
end

function CombatService.SpawnEnemiesForPlayer(player)
	PlayerService.WaitForLoad(player)

	local userId = player.UserId
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

	enemyState[userId] = {}
	respawnQueue[userId] = {}
	enemyIdCounter[userId] = 0

	for i = 1, math.min(enemyCount, #zones) do
		local zone = zones[math.random(1, #zones)]
		local enemyType = enemyTypes[(i - 1) % #enemyTypes + 1]
		local config = EnemyConfig.Map[enemyType]
		if config then
			local counter = CombatService._nextEnemyId(userId)
			local enemyId = string.format("%s_%d", enemyType, counter)
			enemyState[userId][enemyId] = CombatService._newEnemyEntry(userId, enemyType, zone)
		end
	end

	CombatService._initPetCombat(player)
end

function CombatService.ClearPlayer(player)
	local userId = player.UserId
	enemyState[userId] = nil
	respawnQueue[userId] = nil
	petCombat[userId] = nil
	enemyIdCounter[userId] = nil
end

function CombatService._getPlayerRootPos(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return root and root.Position or nil
end

function CombatService._moveEnemies(player, dt)
	local userId = player.UserId
	local enemies = enemyState[userId]
	if not enemies then return end

	local playerPos = CombatService._getPlayerRootPos(player)
	if not playerPos then return end

	for enemyId, state in enemies do
		local dist = (state.position - playerPos).Magnitude
		if dist > state.attackRange then
			local direction = (playerPos - state.position).Unit
			local moveAmount = math.min(state.movementSpeed * dt, dist - state.attackRange + 1)
			state.position = state.position + direction * moveAmount
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

function CombatService._processEnemyDamage(player, dt)
	local userId = player.UserId
	local enemies = enemyState[userId]
	if not enemies then return end

	local equippedPets = PlayerService.GetValue(player, "equippedPets") or {}
	local allPets = PlayerService.GetValue(player, "pets") or {}
	local rocksUnlocked = PlayerService.GetValue(player, "rocksUnlocked") or false
	local playerPos = CombatService._getPlayerRootPos(player)

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

	if totalDamage <= 0 or not playerPos then return end

	local deadEnemies = {}
	for enemyId, state in enemies do
		local dist = (state.position - playerPos).Magnitude
		if dist <= state.attackRange then
			state.hp = state.hp - totalDamage
			if state.hp <= 0 then
				table.insert(deadEnemies, { id = enemyId, state = state })
			end
		end
	end

	for _, entry in deadEnemies do
		local enemyId = entry.id
		local state = entry.state

		enemyState[userId][enemyId] = nil

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

		if not respawnQueue[userId] then
			respawnQueue[userId] = {}
		end
		table.insert(respawnQueue[userId], {
			timer = 3,
			enemyType = state.type,
			zone = state.zone,
		})
	end
end

function CombatService._processRespawns(dt)
	for userId, queue in respawnQueue do
		local player = Players:GetPlayerByUserId(userId)
		if not player then
			respawnQueue[userId] = nil
			continue
		end

		local i = #queue
		while i >= 1 do
			local entry = queue[i]
			entry.timer = entry.timer - dt
			if entry.timer <= 0 then
				if not enemyState[userId] then
					enemyState[userId] = {}
				end

				local zone = entry.zone
				local zones = zone.Parent and zone.Parent:GetChildren() or {}
				if #zones > 0 then
					zone = zones[math.random(1, #zones)]
				end

				local counter = CombatService._nextEnemyId(userId)
				local enemyId = string.format("%s_%d", entry.enemyType, counter)
				enemyState[userId][enemyId] = CombatService._newEnemyEntry(userId, entry.enemyType, zone)

				table.remove(queue, i)
			end
			i = i - 1
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
	local userId = player.UserId

	if not enemyState[userId] then return end

	CombatService._initPetCombat(player)

	CombatService._moveEnemies(player, dt)
	CombatService._processEnemyAttacks(player, dt)
	CombatService._processEnemyDamage(player, dt)
	CombatService._processRespawns(dt)
	CombatService._processPetRevives(dt)

	local syncData = {
		enemies = {},
		pets = {},
	}
	local enemies = enemyState[userId]
	if enemies then
		for enemyId, state in enemies do
			syncData.enemies[enemyId] = {
				hp = state.hp,
				maxHp = state.maxHp,
				isAlive = true,
				type = state.type,
				position = { X = state.position.X, Y = state.position.Y, Z = state.position.Z },
			}
		end
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
		CombatService.ClearPlayer(player)
	end)

	task.spawn(CombatService.TickLoop)
end

return CombatService