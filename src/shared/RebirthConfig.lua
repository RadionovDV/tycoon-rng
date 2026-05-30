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
		luckBonus = 1,
		requirements = {
			--unlockedLocations = "Location2",
			rocks = 100,
			--coins = 10,
		},
	},
	Rebirth2 = {
		displayName = "Rebirth II",
		luckBonus = 1.5,
		requirements = {
			unlockedLocations = "Location2",
			rocks = 200,
			enemyKills = 100,
		}
	},
	Rebirth3 = {
		displayName = "Rebirth III",
		luckBonus = 2.4,
		requirements = {
			unlockedLocations = "Location3",
			coins = 1000,
			rocks = 500,
			enemyKills = 500,
			pets = 500,
		}
	},
}