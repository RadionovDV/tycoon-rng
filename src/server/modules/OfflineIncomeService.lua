-- OfflineIncomeService.lua
-- Server-authoritative offline income system.
-- On player join, calculates accumulated coins/rocks based on owned offline upgrades
-- and elapsed time since last seen. Sends a popup to the client.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerService = require(script.Parent.PlayerService)
local EconomyService = require(script.Parent.EconomyService)
local OfflineIncomeConfig = require(ReplicatedStorage.OfflineIncomeConfig)

local Remotes = ReplicatedStorage.Remotes

local OfflineIncomeService = {}

-- Determines the level of an offline-income upgrade tier (0 = not owned)
function OfflineIncomeService._getTierLevel(owned, upgradeIds)
	local level = 0
	for _, id in upgradeIds do
		if owned[id] then
			level += 1
		end
	end
	return level
end

-- Calculates accumulated offline coins and rocks for a player.
-- Returns (coins, rocks, isFull) or nil if not enough time has passed.
function OfflineIncomeService._calculateIncome(player)
	local upgrades = PlayerService.GetValue(player, "upgrades") or {}
	local permanentUpgrades = PlayerService.GetValue(player, "permanentUpgrades") or {}

	local owned = {}
	for id, _ in upgrades do owned[id] = true end
	for id, _ in permanentUpgrades do owned[id] = true end

	local capacityLevel = OfflineIncomeService._getTierLevel(owned, {
		"offline_income_1", "offline_income_2", "offline_income_3", "offline_income_4"
	})
	if capacityLevel == 0 then
		return nil
	end

	local lastSeen = PlayerService.GetValue(player, "offlineIncomeLastSeen") or 0
	local elapsed = os.time() - lastSeen
	if elapsed < OfflineIncomeConfig.minOfflineMinutes * 60 then
		return nil
	end

	local cappedElapsed = math.min(elapsed, OfflineIncomeConfig.maxAccumulationHours * 3600)
	local hours = cappedElapsed / 3600

	local cfg = OfflineIncomeConfig.tiers
	local rateLevel = math.max(0, capacityLevel - 1)
	local coinsPerHour = cfg.rate_coins.coinsPerHour[rateLevel + 1] or 0
	local coinsMult = cfg.capacity_coins.multiplier[capacityLevel] or 1
	local coins = math.floor(coinsPerHour * hours * coinsMult)

	local rocks = 0
	if capacityLevel >= 2 then
		local rockCapLevel = capacityLevel - 1
		local rocksPerHour = cfg.capacity_rocks.rocksPerHour[rockCapLevel] or 0
		local rockRateLevel = math.max(0, capacityLevel - 2)
		local rockMult = cfg.rate_rocks.multiplier[rockRateLevel + 1] or 1
		rocks = math.floor(rocksPerHour * hours * rockMult)
	end

	local isFull = elapsed >= OfflineIncomeConfig.maxAccumulationHours * 3600

	return coins, rocks, isFull
end

function OfflineIncomeService._onPlayerReady(player)
	task.wait(1)

	local coins, rocks, isFull = OfflineIncomeService._calculateIncome(player)
	if not coins then
		PlayerService.UpdateValue(player, "offlineIncomeLastSeen", function() return os.time() end)
		return
	end

	local warned = PlayerService.GetValue(player, "offlineIncomeWarned") or 0
	local showWarning = false
	if isFull then
		if warned >= OfflineIncomeConfig.warnRepeatDays - 1 then
			showWarning = true
			PlayerService.UpdateValue(player, "offlineIncomeWarned", function() return 0 end)
		else
			PlayerService.UpdateValue(player, "offlineIncomeWarned", function(old) return (old or 0) + 1 end)
		end
	else
		PlayerService.UpdateValue(player, "offlineIncomeWarned", function() return 0 end)
	end

	if coins > 0 then EconomyService.AddCoins(player, coins) end
	if rocks > 0 then EconomyService.AddRocks(player, rocks) end

	Remotes.ShowOfflineIncome:FireClient(player, {
		coins = coins,
		rocks = rocks,
		isFull = isFull,
		showWarning = showWarning,
	})

	PlayerService.UpdateValue(player, "offlineIncomeLastSeen", function() return os.time() end)
end

function OfflineIncomeService.StartListening()
	PlayerService.PlayerReady:Connect(OfflineIncomeService._onPlayerReady)
end

return OfflineIncomeService