-- UpgradeConfig.lua
-- Defines the upgrade tree. Each upgrade has a cost, currency type, prerequisite,
-- effect type, and value. The tree branches from the first upgrades outward.
-- Effects: luck (multiplier), rollCooldown (reduction), maxEquipSlots (+), unlockAutoRoll, unlockRocks, enemyCount (+)
-- isPermanent: true => upgrade survives rebirth and becomes dimmed in the tree.
return {
	luck_1 = {
		cost = 10, 
		currency = "coins", 
		requires = nil,
		effect = "luck", 
		value = 1.1,
		displayName = "Luck I", 
		description = "Increases luck multiplier to 1.2x",
		icon = "rbxassetid://83955876596707",
		nodePosition = { x = 1000, y = 1000 },
	},
	luck_2 = {
		cost = 50, currency = "coins", requires = "luck_1",
		effect = "luck", value = 1.3,
		displayName = "Luck II", description = "Increases luck multiplier to 1.5x",
		icon = "rbxassetid://83955876596707",
		nodePosition = { x = 1120, y = 1070 },
	},
	shop = {
		cost = 200, currency = "coins", requires = "luck_2",
		effect = "unlockShop", value = true,
		displayName = "Shop", description = "Unlock shop for more benefits",
		icon = "rbxassetid://118554800883386",
		nodePosition = { x = 1240, y = 1000 },
		isPermanent = true,
	},
	rollspeed_1 = {
		cost = 30, currency = "dice", requires = "luck_2",
		effect = "rollCooldown", value = -0.5,
		displayName = "Roll Speed I", description = "Reduces roll cooldown by 0.5s",
		icon = "rbxassetid://122184010309818",
		nodePosition = { x = 1120, y = 1210 },
	},
	rollspeed_2 = {
		cost = 100, currency = "dice", requires = "rollspeed_1",
		effect = "rollCooldown", value = -0.3,
		displayName = "Roll Speed II", description = "Reduces roll cooldown by 0.3s",
		icon = "rbxassetid://122184010309818",
		nodePosition = { x = 1240, y = 1280 },
	},
	index = {
		cost = 1000, currency = "coins", requires = "rollspeed_2",
		effect = "unlockIndex", value = true,
		displayName = "Index", description = "Find out how much is left",
		icon = "rbxassetid://118367980795800",
		nodePosition = { x = 1240, y = 1420 },
		isPermanent = true,
	},
	
	extraslot_1 = {
		cost = 80, currency = "coins", requires = "luck_1",
		effect = "maxEquipSlots", value = 1,
		displayName = "Extra Slot I", description = "+1 pet equip slot",
		icon = "rbxassetid://77560258643186",
		nodePosition = { x = 880, y = 1070 },
	},
	extraslot_2 = {
		cost = 250, currency = "coins", requires = "extraslot_1",
		effect = "maxEquipSlots", value = 1,
		displayName = "Extra Slot II", description = "+1 pet equip slot",
		icon = "rbxassetid://77560258643186",
		nodePosition = { x = 760, y =  1000},
	},
	rebirth = {
		cost = 400, currency = "coins", requires = "extraslot_2",
		effect = "unlockRebirth", value = true,
		displayName = "Rebirth", description = "Unlock rebirth for more benefits",
		icon = "rbxassetid://98256223082322",
		nodePosition = { x = 640, y = 1070 },
		isPermanent = true,
	},
	
	moreenemies_1 = {
		cost = 20, currency = "coins", requires = "luck_1",
		effect = "enemyCount", value = 1,
		displayName = "More Enemies I", description = "+1 active enemy",
		icon = "rbxassetid://88395994860267",
		nodePosition = { x = 1000, y = 860 },
	},
	moreenemies_2 = {
		cost = 150, currency = "coins", requires = "moreenemies_1",
		effect = "enemyCount", value = 1,
		displayName = "More Enemies II", description = "+1 active enemy",
		icon = "rbxassetid://88395994860267",
		nodePosition = { x = 1120, y = 790 },
	},
	moreenemies_3 = {
		cost = 500, currency = "coins", requires = "moreenemies_2",
		effect = "enemyCount", value = 1,
		displayName = "More Enemies III", description = "+1 active enemy",
		icon = "rbxassetid://88395994860267",
		nodePosition = { x = 1120, y = 650 },
	},
	
	autoll = {
		cost = 100, currency = "coins", requires = "moreenemies_1",
		effect = "unlockAutoRoll", value = true,
		displayName = "Auto Roll", description = "Automatically rolls pets",
		icon = "rbxassetid://108780071692774",
		nodePosition = { x = 880, y = 790 },
		isPermanent = true,
	},
	rocks_unlock = {
		cost = 500, currency = "coins", requires = "moreenemies_2",
		effect = "unlockRocks", value = true,
		displayName = "Rocks Unlock", description = "Unlocks Rocks currency from enemies",
		icon = "rbxassetid://110971351869251",
		nodePosition = { x = 1240, y = 720 },
	},

	-- Offline Income branch (4 tiers)
	offline_income_1 = {
		cost = 500, currency = "coins", requires = "rocks_unlock",
		effect = "offlineIncome", value = true,
		displayName = "Bucket I", description = "Offline coin bucket unlocked",
		icon = "rbxassetid://83955876596707",
		nodePosition = { x = 1380, y = 720 },
		isPermanent = true,
	},
	offline_income_2 = {
		cost = 1000, currency = "coins", requires = "offline_income_1",
		effect = "offlineIncome", value = true,
		displayName = "Rate I", description = "Faster coin accumulation",
		icon = "rbxassetid://83955876596707",
		nodePosition = { x = 1380, y = 640 },
		isPermanent = true,
	},
	offline_income_3 = {
		cost = 2000, currency = "coins", requires = "offline_income_2",
		effect = "unlockRocks", value = true,
		displayName = "Bucket II", description = "Unlocks rock accumulation",
		icon = "rbxassetid://83955876596707",
		nodePosition = { x = 1380, y = 560 },
		isPermanent = true,
	},
	offline_income_4 = {
		cost = 4000, currency = "coins", requires = "offline_income_3",
		effect = "offlineIncome", value = true,
		displayName = "Rate II", description = "Faster rock accumulation",
		icon = "rbxassetid://83955876596707",
		nodePosition = { x = 1380, y = 480 },
		isPermanent = true,
	},

	-- Daily Rewards unlock node
	daily_reward_unlock = {
		cost = 2000, currency = "coins", requires = "shop",
		effect = "unlockDailyReward", value = true,
		displayName = "Daily Rewards", description = "Unlock daily reward system",
		icon = "rbxassetid://83955876596707",
		nodePosition = { x = 1400, y = 1000 },
		isPermanent = true,
	},

	-- Micro Rewards unlock node
	micro_reward_unlock = {
		cost = 1500, currency = "coins", requires = "rollspeed_2",
		effect = "unlockMicroReward", value = true,
		displayName = "Micro Rewards", description = "Unlock time-gated micro rewards",
		icon = "rbxassetid://83955876596707",
		nodePosition = { x = 1400, y = 1280 },
		isPermanent = true,
	},

	-- Quest System unlock node
	quest_system = {
		cost = 10000, currency = "coins", requires = "index",
		effect = "unlockQuestSystem", value = true,
		displayName = "Quests", description = "Unlock quest system",
		icon = "rbxassetid://83955876596707",
		nodePosition = { x = 1400, y = 1420 },
		isPermanent = true,
	},
}