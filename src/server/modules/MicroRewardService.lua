-- MicroRewardService.lua
-- Server-authoritative time-gated micro reward system.
-- Three independent tiers (30/60/120 min). Each tier requires a corresponding upgrade.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerService = require(script.Parent.PlayerService)
local EconomyService = require(script.Parent.EconomyService)
local MicroRewardConfig = require(ReplicatedStorage.MicroRewardConfig)

local Remotes = ReplicatedStorage.Remotes

local MicroRewardService = {}

local TIER_UPGRADES = {
	[1] = "micro_reward_unlock",
	[2] = "micro_reward_level_1",
	[3] = "micro_reward_level_2",
}

function MicroRewardService._isTierUnlocked(player, tier)
	local upgrades = PlayerService.GetValue(player, "upgrades") or {}
	local permanentUpgrades = PlayerService.GetValue(player, "permanentUpgrades") or {}
	local upgradeId = TIER_UPGRADES[tier]
	return upgrades[upgradeId] == true or permanentUpgrades[upgradeId] == true
end

function MicroRewardService._sendStatus(player)
	local lastClaim = PlayerService.GetValue(player, "microRewardLastClaim") or {}
	local now = os.time()
	local tiers = {}

	for i = 1, 3 do
		local config = MicroRewardConfig[i]
		if not config then break end

		local tierData = { tier = i, reward = config, canClaim = false, timeLeft = config.minutes * 60 }

		if MicroRewardService._isTierUnlocked(player, i) then
			local last = lastClaim["tier" .. tostring(i)] or 0
			local elapsed = now - last
			local interval = config.minutes * 60
			tierData.canClaim = elapsed >= interval
			tierData.timeLeft = math.max(0, interval - elapsed)
		else
			tierData.canClaim = false
			tierData.timeLeft = -1
		end

		table.insert(tiers, tierData)
	end

	Remotes.MicroRewardStatus:FireClient(player, { tiers = tiers })
end

function MicroRewardService._onClaim(player, data)
	PlayerService.WaitForLoad(player)

	local tier = data.tier
	if tier < 1 or tier > 3 then return end
	if not MicroRewardService._isTierUnlocked(player, tier) then return end

	local lastClaim = PlayerService.GetValue(player, "microRewardLastClaim") or {}
	local last = lastClaim["tier" .. tostring(tier)] or 0
	local config = MicroRewardConfig[tier]
	if not config then return end

	local now = os.time()
	if now - last < config.minutes * 60 then return end

	local reward = config
	if reward.coins then EconomyService.AddCoins(player, reward.coins) end
	if reward.dice then EconomyService.AddDice(player, reward.dice) end
	if reward.rocks then EconomyService.AddRocks(player, reward.rocks) end

	PlayerService.UpdateValue(player, "microRewardLastClaim", function(list)
		list["tier" .. tostring(tier)] = now
		return list
	end)

	MicroRewardService._sendStatus(player)
end

function MicroRewardService._onPlayerReady(player)
	task.wait(1)
	MicroRewardService._sendStatus(player)
end

function MicroRewardService.StartListening()
	Remotes.ClaimMicroReward.OnServerEvent:Connect(MicroRewardService._onClaim)
	Remotes.MicroRewardStatus.OnServerEvent:Connect(function(player)
		MicroRewardService._sendStatus(player)
	end)

	PlayerService.PlayerReady:Connect(MicroRewardService._onPlayerReady)
end

return MicroRewardService