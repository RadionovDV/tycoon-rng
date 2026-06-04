-- PetConfig.lua
-- Defines all obtainable pet types with their rarity weights, damage values, and display metadata.
-- Weight sum = 1040. Higher weight = more common. Luck multiplier divides non-Common weights.
local PET_LIST = {
	{ id = "Common_Pebble",  weight = 500, rarity = "Common",    damage = 5,   hp = 20,  attackRate = 1.2, attackRange = 25, displayName = "Pebble"  },
	{ id = "Common_Rock",    weight = 300, rarity = "Common",    damage = 8,   hp = 30,  attackRate = 1.1, attackRange = 25, displayName = "Rock"    },
	{ id = "Uncommon_Cobble",weight = 200, rarity = "Uncommon",  damage = 20,  hp = 50,  attackRate = 1.0, attackRange = 26, displayName = "Cobble"  },
	{ id = "Rare_Boulder",   weight = 50,  rarity = "Rare",      damage = 60,  hp = 100, attackRate = 0.9, attackRange = 27, displayName = "Boulder" },
	{ id = "Rare_Geode",     weight = 10,  rarity = "Rare",      damage = 80,  hp = 120, attackRate = 0.8, attackRange = 28, displayName = "Geode"   },
	{ id = "Epic_Crystal",   weight = 2,   rarity = "Epic",      damage = 200, hp = 250, attackRate = 0.7, attackRange = 29, displayName = "Crystal" },
	{ id = "Legendary_Gem",  weight = 0.5, rarity = "Legendary", damage = 600, hp = 500, attackRate = 0.6, attackRange = 30, displayName = "Gem"     },
	{ id = "Divine_Opal",    weight = 0.01,rarity = "Divine",    damage = 2000,hp = 2000,attackRate = 0.5, attackRange = 32, displayName = "Opal"    },
}

local PET_MAP = {}
for _, pet in PET_LIST do
	PET_MAP[pet.id] = pet
end

return {
	List = PET_LIST, -- Ordered list for deterministic RNG iteration
	Map = PET_MAP,   -- Lookup by pet id
}