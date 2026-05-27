-- RollService.lua
-- Server-authoritative rolling system. Anti-spam via lastRollTime table.
-- On each roll: RNG determines pet → added to inventory → auto-equipped if slot open → +1 dice.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerService = require(script.Parent.PlayerService)
local EconomyService = require(script.Parent.EconomyService)
local RarityCalculator = require(ReplicatedStorage.RarityCalculator)

local Remotes = ReplicatedStorage.Remotes

local RollService = {}

-- Tracks last roll time per player to enforce cooldown (stored in-memory, not in player data)
local lastRollTime = {}

function RollService.Roll(player)
	PlayerService.WaitForLoad(player)

	local now = os.clock()
	local cooldown = PlayerService.GetValue(player, "rollCooldown") or 2

	-- Anti-spam: reject rolls faster than the player's current cooldown
	if lastRollTime[player.UserId] and (now - lastRollTime[player.UserId]) < cooldown then
		return
	end
	lastRollTime[player.UserId] = now

	local luck = PlayerService.GetValue(player, "luck") or 1
	local petType, petData = RarityCalculator.Roll(luck)

	local equippedPets = PlayerService.GetValue(player, "equippedPets") or {}
	local maxSlots = PlayerService.GetValue(player, "maxEquipSlots") or 1
	local petCount = PlayerService.GetValue(player, "pets") or {}
	local petCountNum = 0
	for _ in petCount do petCountNum += 1 end

	local petId = string.format("%s_%d", petType, petCountNum + 1)

	-- Add pet to inventory
	PlayerService.UpdateValue(player, "pets", function(pets)
		pets[petId] = {
			petType = petType,
			rarity = petData.rarity,
			damage = petData.damage,
			displayName = petData.displayName,
		}
		return pets
	end)

	-- Grant one dice per roll
	PlayerService.UpdateValue(player, "dice", function(old)
		return (old or 0) + 1
	end)

	-- Auto-equip if there is an open slot
	local autoEquipped = false
	if #equippedPets < maxSlots then
		autoEquipped = true
		PlayerService.UpdateValue(player, "equippedPets", function(list)
			table.insert(list, petId)
			return list
		end)
	end

	Remotes.RollPet:FireClient(player, {
		petType = petType,
		rarity = petData.rarity,
		displayName = petData.displayName,
		damage = petData.damage,
		autoEquipped = autoEquipped,
	})
end

function RollService.StartListening()
	Remotes.RollPet.OnServerEvent:Connect(function(player)
		RollService.Roll(player)
	end)
end

return RollService