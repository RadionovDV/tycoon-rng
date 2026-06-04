-- CombatService.lua
-- Server-authoritative combat loop. Runs on Heartbeat (real dt).
-- Enemy positions are server-side for attack range logic only.
-- SyncCombatState fires per-tick only for HP deltas and new spawns (no position).
-- Client handles visual movement and attack animation independently.
-- Attack cycle uses unified state machine for both pets and enemies:
--   ready → jumpTo(0.25s, dealDamage) → jumpBack(0.25s) → cooldown → ready
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PlayerService = require(script.Parent.PlayerService)
local EconomyService = require(script.Parent.EconomyService)
local EnemyConfig = require(ReplicatedStorage.EnemyConfig)
local PetConfig = require(ReplicatedStorage.PetConfig)
local CombatConfig = require(ReplicatedStorage.CombatConfig)
local LocationConfig = require(ReplicatedStorage.LocationConfig)

local Remotes = ReplicatedStorage.Remotes

local JUMP_TO_DURATION = 0.25
local JUMP_BACK_DURATION = 0.25

local CombatService = {}

local enemyState = {}
local petCombat = {}
local respawnQueue = {}
local enemyIdCounter = {}

-- Dirty-state tracking for per-tick SyncCombatState deltas
local syncDirty = {}

-- Marks enemy HP/state change for sync
local function _markEnemyDirty(userId, enemyId, data)
	if not syncDirty[userId] then
		syncDirty[userId] = { enemies = {}, pets = {}, newSpawns = {} }
	end
	syncDirty[userId].enemies[enemyId] = data
end

-- Marks pet HP/state change for sync
local function _markPetDirty(userId, petId, data)
	if not syncDirty[userId] then
		syncDirty[userId] = { enemies = {}, pets = {}, newSpawns = {} }
	end
	syncDirty[userId].pets[petId] = data
end

-- Marks new enemy spawn with its initial position for client-side placement
local function _markNewEnemySpawn(userId, enemyId, eType, spawnPos)
	if not syncDirty[userId] then
		syncDirty[userId] = { enemies = {}, pets = {}, newSpawns = {} }
	end
	syncDirty[userId].newSpawns[enemyId] = {
		type = eType,
		spawnPosition = { X = spawnPos.X, Y = spawnPos.Y, Z = spawnPos.Z },
	}
end

-- Flushes accumulated dirty state to client
local function _flushSync(player)
	local userId = player.UserId
	local dirty = syncDirty[userId]
	if not dirty then return end
	syncDirty[userId] = nil

	local syncData = {}
	if next(dirty.newSpawns) then syncData.newSpawns = dirty.newSpawns end
	if next(dirty.enemies) then syncData.enemies = dirty.enemies end
	if next(dirty.pets) then syncData.pets = dirty.pets end
	if next(syncData) then
		Remotes.SyncCombatState:FireClient(player, syncData)
	end
end

-- Generates unique sequential enemy ID per player
function CombatService._nextEnemyId(userId)
	local counter = (enemyIdCounter[userId] or 0) + 1
	enemyIdCounter[userId] = counter
	return counter
end

-- Syncs petCombat in-memory table to the player's equippedPets
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
				local petConfig = PetConfig.Map[petEntry.petType]
				petCombat[userId][petId] = {
					hp = petEntry.maxHp or 20,
					maxHp = petEntry.maxHp or 20,
					isAlive = true,
					reviveTimer = 5,
					currentRevive = 0,
					attackState = {
						phase = "ready",
						timer = 0,
						targetId = "",
						damage = petEntry.damage or 0,
						cooldownTime = petConfig and petConfig.attackRate or 1.0,
					},
				}
				_markPetDirty(userId, petId, {
					hp = petEntry.maxHp or 20,
					maxHp = petEntry.maxHp or 20,
					isAlive = true,
				})
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

-- Creates a fresh enemy state entry from config and a spawn zone
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
		attackState = {
			phase = "ready",
			timer = 0,
			targetId = "",
			damage = config.attackDamage or 5,
			cooldownTime = config.attackRate or 1,
		},
	}
end

-- Spawns initial enemies for a player based on their location and upgrades
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

			_markNewEnemySpawn(userId, enemyId, enemyType, zone.Position)
			_markEnemyDirty(userId, enemyId, {
				hp = config.hp, maxHp = config.hp, isAlive = true, type = enemyType,
			})
		end
	end

	CombatService._initPetCombat(player)
	_flushSync(player)
end

-- Wipes all combat state for a player (on leave or location change)
function CombatService.ClearPlayer(player)
	local userId = player.UserId
	Remotes.SyncCombatState:FireClient(player, { clearAll = true })
	enemyState[userId] = nil
	respawnQueue[userId] = nil
	petCombat[userId] = nil
	enemyIdCounter[userId] = nil
	syncDirty[userId] = nil
end

-- Returns player's HumanoidRootPart position or nil
function CombatService._getPlayerRootPos(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return root and root.Position or nil
end

-- Moves enemies toward the player if outside attack range (server-side logic)
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

-- Finds the nearest enemy to player position within attackRange
function CombatService._findNearestEnemy(enemies, playerPos, attackRange)
	local nearestId, nearestDist = nil, math.huge
	for enemyId, state in enemies do
		local dist = (state.position - playerPos).Magnitude
		if dist <= attackRange and dist < nearestDist then
			nearestDist = dist
			nearestId = enemyId
		end
	end
	return nearestId
end

-- Handles enemy death: rewards, respawn queue, remotes, stats
function CombatService._handleEnemyKill(player, userId, enemyId, state, rocksUnlocked)
	_markEnemyDirty(userId, enemyId, { isAlive = false })
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

	PlayerService.UpdateValue(player, "enemyKills", function(old)
		return (old or 0) + 1
	end)

	if not respawnQueue[userId] then
		respawnQueue[userId] = {}
	end
	table.insert(respawnQueue[userId], {
		timer = 3,
		enemyType = state.type,
		zone = state.zone,
	})
end

-- Unified attack state machine: processes attack cycle for all pets and enemies
function CombatService._processAllAttacks(player, dt)
	local userId = player.UserId
	local enemies = enemyState[userId]
	if not enemies then return end

	local equippedPets = PlayerService.GetValue(player, "equippedPets") or {}
	local allPets = PlayerService.GetValue(player, "pets") or {}
	local rocksUnlocked = PlayerService.GetValue(player, "rocksUnlocked") or false
	local playerPos = CombatService._getPlayerRootPos(player)
	if not playerPos then return end

	-- Process pet attacks
	for _, petId in equippedPets do
		local pState = petCombat[userId] and petCombat[userId][petId]
		if not pState or not pState.isAlive then continue end

		local petEntry = allPets[petId]
		if not petEntry then continue end

		local as = pState.attackState

		as.timer = as.timer + dt

		if as.phase == "ready" then
			local targetId = CombatService._findNearestEnemy(enemies, playerPos, CombatConfig.PET_ATTACK_RANGE)
			if targetId then
				as.targetId = targetId
				as.phase = "jumpTo"
				as.timer = 0
				Remotes.PetAttack:FireClient(player, { petId = petId, enemyId = targetId })
			end
		elseif as.phase == "jumpTo" and as.timer >= JUMP_TO_DURATION then
			local targetState = enemies[as.targetId]
			if targetState then
				targetState.hp = targetState.hp - as.damage
				_markEnemyDirty(userId, as.targetId, {
					hp = targetState.hp, maxHp = targetState.maxHp, isAlive = true, type = targetState.type,
				})
				if targetState.hp <= 0 then
					CombatService._handleEnemyKill(player, userId, as.targetId, targetState, rocksUnlocked)
				end
			end
			as.phase = "jumpBack"
			as.timer = 0
		elseif as.phase == "jumpBack" and as.timer >= JUMP_BACK_DURATION then
			as.phase = "cooldown"
			as.timer = 0
		elseif as.phase == "cooldown" and as.timer >= as.cooldownTime then
			as.phase = "ready"
			as.timer = 0
		end
	end

	-- Process enemy attacks
	for enemyId, state in enemies do
		local as = state.attackState
		local distToPlayer = (state.position - playerPos).Magnitude

		as.timer = as.timer + dt

		if as.phase ~= "ready" and as.targetId then
			local pState = petCombat[userId] and petCombat[userId][as.targetId]
			if not pState or not pState.isAlive then
				as.phase = "ready"
				as.timer = 0
			end
		end

		if as.phase == "ready" then
			if distToPlayer <= state.attackRange then
				local targetPetId = as.targetId
				local targetState = petCombat[userId] and petCombat[userId][targetPetId]
				if not targetPetId or not targetState or not targetState.isAlive then
					targetPetId = nil
					for _, petId in equippedPets do
						local pState = petCombat[userId] and petCombat[userId][petId]
						if pState and pState.isAlive then
							targetPetId = petId
							break
						end
					end
				end
				if targetPetId then
					as.targetId = targetPetId
					as.phase = "jumpTo"
					as.timer = 0
					Remotes.EnemyAttack:FireClient(player, {
						enemyId = enemyId,
						petId = targetPetId,
						targetPosition = { X = playerPos.X, Y = playerPos.Y, Z = playerPos.Z },
					})
				end
			end
		elseif as.phase == "jumpTo" and as.timer >= JUMP_TO_DURATION then
			local pState = petCombat[userId] and petCombat[userId][as.targetId]
			if pState and pState.isAlive then
				pState.hp = pState.hp - as.damage
				_markPetDirty(userId, as.targetId, {
					hp = pState.hp, maxHp = pState.maxHp, isAlive = pState.isAlive,
				})
				if pState.hp <= 0 then
					pState.isAlive = false
					pState.hp = 0
					pState.currentRevive = 0
					pState.attackState.phase = "ready"
					pState.attackState.timer = 0
					_markPetDirty(userId, as.targetId, {
						hp = 0, maxHp = pState.maxHp, isAlive = false,
					})
					Remotes.PetDefeated:FireClient(player, { petId = as.targetId })
				end
			end
			as.phase = "jumpBack"
			as.timer = 0
		elseif as.phase == "jumpBack" and as.timer >= JUMP_BACK_DURATION then
			as.phase = "cooldown"
			as.timer = 0
		elseif as.phase == "cooldown" and as.timer >= as.cooldownTime then
			as.phase = "ready"
			as.timer = 0
		end
	end
end

-- Respawns killed enemies after cooldown
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
				local newState = CombatService._newEnemyEntry(userId, entry.enemyType, zone)
				enemyState[userId][enemyId] = newState

				_markNewEnemySpawn(userId, enemyId, entry.enemyType, zone.Position)
				_markEnemyDirty(userId, enemyId, {
					hp = newState.hp,
					maxHp = newState.maxHp,
					isAlive = true,
					type = newState.type,
				})

				table.remove(queue, i)
			end
			i = i - 1
		end
	end
end

-- Revives dead pets after 5-second timer
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
						state.attackState.phase = "ready"
						state.attackState.timer = 0
						_markPetDirty(userId, petId, {
							hp = state.maxHp, maxHp = state.maxHp, isAlive = true,
						})
						Remotes.PetRevived:FireClient(player, { petId = petId })
					end
				end
			end
		end
	end
end

-- Runs one combat tick for a player with real dt
function CombatService.CombatTick(player, dt)
	local userId = player.UserId

	if not enemyState[userId] then return end

	CombatService._initPetCombat(player)
	CombatService._moveEnemies(player, dt)
	CombatService._processAllAttacks(player, dt)
	CombatService._processRespawns(dt)
	CombatService._processPetRevives(dt)

	_flushSync(player)
end

-- Heartbeat loop driving combat for all players
function CombatService.TickLoop()
	local lastTime = tick()
	local conn = RunService.Heartbeat:Connect(function()
		local now = tick()
		local dt = math.min(now - lastTime, 0.1)
		lastTime = now

		for _, player in Players:GetPlayers() do
			local success, err = pcall(function()
				CombatService.CombatTick(player, dt)
			end)
			if not success then
				warn(string.format("Combat tick error for %s: %s", player.Name, tostring(err)))
			end
		end
	end)
	return conn
end

-- Entry point: hook player lifecycle and start Heartbeat loop
function CombatService.Start()
	local conn = CombatService.TickLoop()

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
end

return CombatService