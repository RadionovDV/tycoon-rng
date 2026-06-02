-- DailyRewardService.lua
-- Server-authoritative daily reward system.
-- On player entry: computes elapsed days, advances or resets the 7-day cycle.
-- ClaimDailyReward: validates day matches current cycle day, issues reward.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerService = require(script.Parent.PlayerService)
local EconomyService = require(script.Parent.EconomyService)
local DailyRewardConfig = require(ReplicatedStorage.DailyRewardConfig)

local Remotes = ReplicatedStorage.Remotes

local DailyRewardService = {}

local ONE_DAY = 86400
local CYCLE_LENGTH = 7

function DailyRewardService._maxCombo(upgrades, permanentUpgrades)
	local combined = {}
	for id, _ in upgrades do combined[id] = true end
	for id, _ in permanentUpgrades do combined[id] = true end

	local level = 2
	if combined["daily_reward_level_1"] then level = math.max(level, 3) end
	if combined["daily_reward_level_2"] then level = math.max(level, 4) end
	if combined["daily_reward_level_3"] then level = math.max(level, 5) end
	if combined["daily_reward_level_4"] then level = math.max(level, 6) end
	if combined["daily_reward_level_5"] then level = math.max(level, 7) end
	return level
end

-- Called on player entry to advance/reset the day cycle.
function DailyRewardService._advanceCycle(player)
	local day = PlayerService.GetValue(player, "dailyRewardDay") or 1
	local lastSeen = PlayerService.GetValue(player, "dailyRewardLastSeen") or 0
	local upgrades = PlayerService.GetValue(player, "upgrades") or {}
	local permanentUpgrades = PlayerService.GetValue(player, "permanentUpgrades") or {}
	local maxCombo = DailyRewardService._maxCombo(upgrades, permanentUpgrades)

	local elapsed = os.time() - lastSeen
	local elapsedDays = math.floor(elapsed / ONE_DAY)

	if elapsedDays >= 2 then
		day = 1
		PlayerService.UpdateValue(player, "dailyRewardClaimed", function() return {} end)
	elseif elapsedDays == 1 then
		day = day + 1
		if day > CYCLE_LENGTH then
			day = 1
			PlayerService.UpdateValue(player, "dailyRewardClaimed", function() return {} end)
		end
	end

	if day > maxCombo then
		day = 1
	end

	PlayerService.UpdateValue(player, "dailyRewardDay", function() return day end)
	PlayerService.UpdateValue(player, "dailyRewardLastSeen", function() return os.time() end)
end

function DailyRewardService._sendStatus(player)
	local day = PlayerService.GetValue(player, "dailyRewardDay") or 1
	local claimed = PlayerService.GetValue(player, "dailyRewardClaimed") or {}
	local upgrades = PlayerService.GetValue(player, "upgrades") or {}
	local permanentUpgrades = PlayerService.GetValue(player, "permanentUpgrades") or {}
	local maxCombo = DailyRewardService._maxCombo(upgrades, permanentUpgrades)

	Remotes.DailyRewardStatus:FireClient(player, {
		day = day,
		claimed = claimed,
		maxCombo = maxCombo,
		rewards = DailyRewardConfig.rewards,
	})
end

function DailyRewardService._onClaim(player, tileIndex)
	PlayerService.WaitForLoad(player)

	local day = PlayerService.GetValue(player, "dailyRewardDay") or 1
	if tileIndex ~= day then return end

	local claimed = PlayerService.GetValue(player, "dailyRewardClaimed") or {}
	if claimed[tileIndex] then return end

	local reward = DailyRewardConfig.rewards[tileIndex]
	if not reward then return end

	if reward.coins then EconomyService.AddCoins(player, reward.coins) end
	if reward.dice then EconomyService.AddDice(player, reward.dice) end
	if reward.rocks then EconomyService.AddRocks(player, reward.rocks) end

	PlayerService.UpdateValue(player, "dailyRewardClaimed", function(list)
		list[tileIndex] = true
		return list
	end)

	DailyRewardService._sendStatus(player)
end

function DailyRewardService._onPlayerReady(player)
	task.wait(1)
	DailyRewardService._advanceCycle(player)
	DailyRewardService._sendStatus(player)
end

function DailyRewardService.StartListening()
	Remotes.ClaimDailyReward.OnServerEvent:Connect(function(player, data)
		DailyRewardService._onClaim(player, data.tileIndex)
	end)
	Remotes.DailyRewardStatus.OnServerEvent:Connect(function(player)
		DailyRewardService._sendStatus(player)
	end)

	PlayerService.PlayerReady:Connect(DailyRewardService._onPlayerReady)
end

return DailyRewardService