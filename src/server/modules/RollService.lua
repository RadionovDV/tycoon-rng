-- RollService.lua
-- Server-authoritative rolling system. Anti-spam via lastRollTime table.
-- On each roll: RNG determines pet → added to inventory → +1 dice.
-- Equipping is done separately via PetEquipService (manual from Backpack).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerService = require(script.Parent.PlayerService)
local EconomyService = require(script.Parent.EconomyService)
local RarityCalculator = require(ReplicatedStorage.RarityCalculator)

local Remotes = ReplicatedStorage.Remotes

local RollService = {}

local lastRollTime = {}

function RollService.Roll(player)
	PlayerService.WaitForLoad(player)

	local now = os.clock()
	local cooldown = PlayerService.GetValue(player, "rollCooldown") or 2

	if lastRollTime[player.UserId] and (now - lastRollTime[player.UserId]) < cooldown then
		return
	end
	lastRollTime[player.UserId] = now

	local luck = PlayerService.GetValue(player, "luck") or 1
	local petType, petData = RarityCalculator.Roll(luck)

	local petCount = PlayerService.GetValue(player, "pets") or {}
	local petCountNum = 0
	for _ in petCount do petCountNum += 1 end

	local petId = string.format("%s_%d", petType, petCountNum + 1)

	PlayerService.UpdateValue(player, "pets", function(pets)
		pets[petId] = {
			petType = petType,
			rarity = petData.rarity,
			damage = petData.damage,
			displayName = petData.displayName,
		}
		return pets
	end)

	PlayerService.UpdateValue(player, "dice", function(old)
		return (old or 0) + 1
	end)

	Remotes.RollPet:FireClient(player, {
		petType = petType,
		petId = petId,
		rarity = petData.rarity,
		displayName = petData.displayName,
		damage = petData.damage,
	})
end

function RollService.StartListening()
	Remotes.RollPet.OnServerEvent:Connect(function(player)
		RollService.Roll(player)
	end)
end

return RollService