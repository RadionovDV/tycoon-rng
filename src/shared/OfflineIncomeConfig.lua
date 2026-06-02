-- OfflineIncomeConfig.lua
-- Defines parameters for the offline income system.
return {
	maxAccumulationHours = 12,
	minOfflineMinutes = 0.05,
	warnRepeatDays = 2,
	tiers = {
		capacity_coins = {
			multiplier = { 1, 2, 4, 8 },
		},
		rate_coins = {
			coinsPerHour = { 100, 250, 500, 1000 },
		},
		capacity_rocks = {
			rocksPerHour = { 0, 10, 25, 50 },
		},
		rate_rocks = {
			multiplier = { 1, 2, 3 },
		},
	},
}