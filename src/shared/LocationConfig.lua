-- LocationConfig.lua
-- Defines available locations. Location1 is the starting area (free).
-- Each location has enemy types and optional gate connections to next locations.
-- connectedLocationIds: array of location IDs that this location's gate unlocks.
return {
	Location1 = {
		displayName = "Rocky Plains",
		unlockCost = 0,
		prerequisite = nil,
		defaultEnemyTypes = { "AngryRock_Weak" },
		connectedLocationIds = { "Location2" },
	},
	Location2 = {
		displayName = "Stone Cave",
		unlockCost = 100,
		prerequisite = "Location1",
		defaultEnemyTypes = { "AngryRock_Medium", "AngryRock_Weak" },
		connectedLocationIds = { "Location3" },
		clearLocations = { "Location1" }
	},
	Location3 = {
		displayName = "Level 2",
		unlockCost = 1000,
		prerequisite = "Location2",
		defaultEnemyTypes = { "AngryRock_Medium", "AngryRock_Strong" },
	},
}