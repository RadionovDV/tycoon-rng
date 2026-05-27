-- UpgradeConfig.lua
-- Defines the upgrade tree. Each upgrade has a cost, currency type, prerequisite,
-- effect type, and value. The tree branches from the first upgrades outward.
-- Effects: luck (multiplier), rollCooldown (reduction), maxEquipSlots (+), unlockAutoRoll, unlockRocks, enemyCount (+)
return {
	luck_1 = {
		cost = 50, currency = "coins", requires = nil,
		effect = "luck", value = 1.2,
		displayName = "Luck I", description = "Increases luck multiplier to 1.2x",
	},
	rollspeed_1 = {
		cost = 5, currency = "dice", requires = nil,
		effect = "rollCooldown", value = -0.5,
		displayName = "Roll Speed I", description = "Reduces roll cooldown by 0.5s",
	},
	extraslot_1 = {
		cost = 200, currency = "coins", requires = "luck_1",
		effect = "maxEquipSlots", value = 1,
		displayName = "Extra Slot I", description = "+1 pet equip slot",
	},
	luck_2 = {
		cost = 500, currency = "coins", requires = "extraslot_1",
		effect = "luck", value = 1.5,
		displayName = "Luck II", description = "Increases luck multiplier to 1.5x",
	},
	rollspeed_2 = {
		cost = 20, currency = "dice", requires = "rollspeed_1",
		effect = "rollCooldown", value = -0.3,
		displayName = "Roll Speed II", description = "Reduces roll cooldown by 0.3s",
	},
	autoll = {
		cost = 1000, currency = "coins", requires = "luck_2",
		effect = "unlockAutoRoll", value = true,
		displayName = "Auto Roll", description = "Automatically rolls pets",
	},
	moreenemies_1 = {
		cost = 300, currency = "coins", requires = "luck_1",
		effect = "enemyCount", value = 1,
		displayName = "More Enemies I", description = "+1 active enemy",
	},
	rocks_unlock = {
		cost = 2000, currency = "coins", requires = "autoll",
		effect = "unlockRocks", value = true,
		displayName = "Rocks Unlock", description = "Unlocks Rocks currency from enemies",
	},
	extraslot_2 = {
		cost = 800, currency = "coins", requires = "extraslot_1",
		effect = "maxEquipSlots", value = 1,
		displayName = "Extra Slot II", description = "+1 pet equip slot",
	},
}