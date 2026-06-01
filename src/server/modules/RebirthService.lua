-- RebirthService.lua
-- Server-authoritative rebirth system.
-- Validates requirements against RebirthConfig, resets progress to defaults,
-- awards additive luck bonus, teleports player to Location1 spawn.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Workspace = game:GetService("Workspace")

local PlayerService = require(script.Parent.PlayerService)
local RebirthConfig = require(ReplicatedStorage.RebirthConfig)
local UpgradeConfig = require(ReplicatedFirst.UpgradeConfig)
local TableUtils = require(ReplicatedStorage.TableUtils) 

local Remotes = ReplicatedStorage.Remotes

local RebirthService = {}

-- Fields to preserve across rebirth (permanent progress)
local SKIP_FIELDS = {
	rebirthCount = true,
	rebirthBonusLuck = true,
	enemyKills = true,
	permanentUpgrades = true,
	dailyRewardProgress = true,
	dailyRewardLastClaim = true,
	microRewardLastClaim = true,
	offlineIncomeLastSeen = true,
	offlineIncomeWarned = true,
	questProgress = true,
}

-- Validates all requirements for the next rebirth tier and performs the reset.
function RebirthService.PerformRebirth(player)
	PlayerService.WaitForLoad(player)

	local rebirthCount = PlayerService.GetValue(player, "rebirthCount") or 0
	local tyreConfig = RebirthConfig["Rebirth" .. tostring(rebirthCount + 1)]
	if not tyreConfig then return end

	local reqSource = tyreConfig.requirements
	if not reqSource then return end

	-- Validate all requirements (AND logic)
	local unlocked = PlayerService.GetValue(player, "unlockedLocations") or {}
	local reqLocation = reqSource.unlockedLocations
	if reqLocation then
		local found = false
		for _, targetLocation in unlocked do
			if targetLocation == reqLocation then
				found = true
				break
			end
		end

		if not found then return end
	end

	local coins = PlayerService.GetValue(player, "coins") or 0
	local dice = PlayerService.GetValue(player, "dice") or 0
	local rocks = PlayerService.GetValue(player, "rocks") or 0
	local enemyKills = PlayerService.GetValue(player, "enemyKills") or 0
	local petCount = TableUtils.objLength(PlayerService.GetValue(player, "pets") or {})

	if reqSource.coins and coins < reqSource.coins then return end
	if reqSource.dices and dice < reqSource.dices then return end
	if reqSource.rocks and rocks < reqSource.rocks then return end
	if reqSource.enemyKills and enemyKills < reqSource.enemyKills then return end
	if reqSource.pets and petCount < reqSource.pets then return end

	-- Save progress before reset
	local currentUpgrades = PlayerService.GetValue(player, "upgrades") or {}
	local dailyRewardProgress = PlayerService.GetValue(player, "dailyRewardProgress") or 0
	local existingPerm = PlayerService.GetValue(player, "permanentUpgrades") or {}

	-- Reset all fields to defaults (preserve skip fields)
	for key, defaultValue in PlayerService.DEFAULT_DATA do
		if not SKIP_FIELDS[key] then
			local copy = typeof(defaultValue) == "table" and table.clone(defaultValue) or defaultValue
			PlayerService.UpdateValue(player, key, function() return copy end)
		end
	end

	-- Compute new permanent upgrades from isPermanent config flag
	local newPermanent = {}
	for id, _ in currentUpgrades do
		if UpgradeConfig[id] and UpgradeConfig[id].isPermanent then
			newPermanent[id] = true
		end
	end

	-- Check special branches tracked outside upgrades dict
	if dailyRewardProgress >= 7 then
		newPermanent["daily_reward_unlock"] = true
	end

	-- Merge into existing permanentUpgrades
	local merged = table.clone(existingPerm)
	for id, _ in newPermanent do
		merged[id] = true
	end

	PlayerService.UpdateValue(player, "permanentUpgrades", function()
		return merged
	end)

	-- Restore owned permanent upgrades back into the upgrades dict
	PlayerService.UpdateValue(player, "upgrades", function(currentUpgrades)
		local result = table.clone(currentUpgrades or {})
		for id, _ in merged do
			result[id] = true
		end
		return result
	end)

	-- Apply rebirth rewards
	PlayerService.UpdateValue(player, "rebirthCount", function(old)
		return (old or 0) + 1
	end)
	PlayerService.UpdateValue(player, "rebirthBonusLuck", function(old)
		return (old or 0) + tyreConfig.luckBonus
	end)

	-- Clean up combat state and spawn enemies for Location1
	local CombatService = require(script.Parent.CombatService)
	CombatService.ClearPlayer(player)
	CombatService.SpawnEnemiesForPlayer(player)

	-- Teleport player to Location1 spawn point
	local location1 = Workspace:FindFirstChild("Location1")
	local poi = location1 and location1:FindFirstChild("POI")
	local spawnPart = poi and poi:FindFirstChild("PlayerSpawn")
	if spawnPart and spawnPart:IsA("BasePart") and player.Character then
		local root = player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = spawnPart.CFrame + Vector3.new(0, 3, 0)
		end
	end
end

function RebirthService.StartListening()
	Remotes.PerformRebirth.OnServerEvent:Connect(RebirthService.PerformRebirth)
end

return RebirthService