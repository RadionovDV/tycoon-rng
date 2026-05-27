-- PetConfig.lua
-- Defines all obtainable pet types with their rarity weights, damage values, and display metadata.
-- Weight sum = 1040. Higher weight = more common. Luck multiplier divides non-Common weights.
local PET_LIST = {
	{ id = "Common_Pebble",  weight = 500, rarity = "Common",    damage = 5,   displayName = "Pebble"  },
	{ id = "Common_Rock",    weight = 300, rarity = "Common",    damage = 8,   displayName = "Rock"    },
	{ id = "Uncommon_Cobble",weight = 150, rarity = "Uncommon",  damage = 20,  displayName = "Cobble"  },
	{ id = "Rare_Boulder",   weight = 40,  rarity = "Rare",      damage = 60,  displayName = "Boulder" },
	{ id = "Rare_Geode",     weight = 30,  rarity = "Rare",      damage = 80,  displayName = "Geode"   },
	{ id = "Epic_Crystal",   weight = 15,  rarity = "Epic",      damage = 200, displayName = "Crystal" },
	{ id = "Legendary_Gem",  weight = 4,   rarity = "Legendary", damage = 600, displayName = "Gem"     },
	{ id = "Divine_Opal",    weight = 1,   rarity = "Divine",    damage = 2000,displayName = "Opal"    },
}

local PET_MAP = {}
for _, pet in PET_LIST do
	PET_MAP[pet.id] = pet
end

return {
	List = PET_LIST, -- Ordered list for deterministic RNG iteration
	Map = PET_MAP,   -- Lookup by pet id
}