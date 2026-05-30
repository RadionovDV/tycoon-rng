-- EnemyConfig.lua
-- Defines enemy types with HP, coin reward, and which locations they appear in.
-- Each player instance runs independent enemies in their current location's EnemyZones.
local ENEMY_LIST = {
	{ id = "AngryRock_Weak",   hp = 30,  reward = 10,  movementSpeed = 8,  attackRange = 15, attackDamage = 5,  attackRate = 1,  displayName = "Angry Rock",   locations = { "Location1" } },
	{ id = "AngryRock_Medium", hp = 80,  reward = 30,  movementSpeed = 10, attackRange = 18, attackDamage = 12, attackRate = 1,  displayName = "Hardened Rock", locations = { "Location1", "Location2" } },
	{ id = "AngryRock_Strong", hp = 600, reward = 80, movementSpeed = 7,  attackRange = 22, attackDamage = 25, attackRate = 1.5, displayName = "Obsidian Rock", locations = { "Location2" } },
}

local ENEMY_MAP = {}
for _, enemy in ENEMY_LIST do
	ENEMY_MAP[enemy.id] = enemy
end

return {
	List = ENEMY_LIST,
	Map = ENEMY_MAP,
}