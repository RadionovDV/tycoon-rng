-- LocationConfig.lua
-- Defines available locations. Location1 is the starting area (free).
-- Each location has a list of enemy types that spawn there.
return {
	Location1 = {
		displayName = "Rocky Plains",
		unlockCost = 0,                -- Free, always unlocked
		prerequisite = nil,
		defaultEnemyTypes = { "AngryRock_Weak" },
	},
	Location2 = {
		displayName = "Crystal Cave",
		unlockCost = 5000,             -- Must be purchased via LocationGates SurfaceGui
		prerequisite = "Location1",
		defaultEnemyTypes = { "AngryRock_Medium", "AngryRock_Strong" },
	},
}