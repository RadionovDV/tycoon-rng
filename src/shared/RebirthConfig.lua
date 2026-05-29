-- RebirthConfig.lua
-- Defines rebirth tiers. Each tier has minimum requirements and a luck bonus.
-- Lookup: RebirthConfig["Rebirth" .. tostring(player.rebirthCount + 1)]
-- If nil — player has reached the maximum available rebirths.

--[[
	Possible requirements
	requirements = {
		unlockedLocations = { "Location1" },
		coins = 0,
		dices = 0,
		rocks = 0,
		enemyKills = 0,
		pets = 0,
	},
]]

return {
	Rebirth1 = {
		displayName = "Rebirth I",
		luckBonus = 0.07,
		requirements = {
			unlockedLocations = "Location2",
			pets = 1,
		},
	},
	Rebirth2 = {
		displayName = "Rebirth II",
		luckBonus = 0.10,
		requirements = {
			unlockedLocations = "Location2",
			coins = 5000,
			dices = 5,
			enemyKills = 30,
			pets = 10,
		}
	},
	Rebirth3 = {
		displayName = "Rebirth III",
		luckBonus = 0.15,
		requirements = {
			unlockedLocations = "Location3",
			coins = 20000,
			dices = 15,
			rocks = 100,
			enemyKills = 100,
			pets = 20,
		}
	},
}