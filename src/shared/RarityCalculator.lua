-- RarityCalculator.lua
-- Server-authoritative RNG system. Calculates effective weights by dividing
-- non-Common pet weights by the player's luck multiplier, then rolls within the total.
local PetConfig = require(script.Parent.PetConfig)

local RarityCalculator = {}

function RarityCalculator.Roll(luckMultiplier)
	local effectiveWeights = {}
	local totalWeight = 0

	for _, petData in PetConfig.List do
		local weight = petData.weight
		if petData.rarity ~= "Common" then
			weight = weight * luckMultiplier
		end
		effectiveWeights[petData.id] = weight
		totalWeight += weight
	end

	local roll = math.random() * totalWeight
	local cumulative = 0

	for _, petData in PetConfig.List do
		cumulative += effectiveWeights[petData.id]
		if roll <= cumulative then
			return petData.id, petData
		end
	end

	-- Fallback safety: first pet in list
	local fallback = PetConfig.List[1]
	return fallback.id, fallback
end

return RarityCalculator