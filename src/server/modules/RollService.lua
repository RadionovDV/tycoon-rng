-- RollService.lua
-- Server-authoritative rolling system. Anti-spam via lastRollTime table.
-- On each roll: RNG determines pet → added to inventory → +1 dice → auto-equip if slot open.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerService = require(script.Parent.PlayerService)
local EconomyService = require(script.Parent.EconomyService)
local RarityCalculator = require(ReplicatedStorage.RarityCalculator)
local TableUtils = require(ReplicatedStorage.TableUtils)

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
	local rebirthLuck = PlayerService.GetValue(player, "rebirthBonusLuck") or 0
	local effectiveLuck = luck + rebirthLuck
	local petType, petData = RarityCalculator.Roll(effectiveLuck)
	local petCountNum = TableUtils.objLength(PlayerService.GetValue(player, "pets") or {})

	local petId = string.format("%s_%d", petType, petCountNum + 1)

	PlayerService.UpdateValue(player, "pets", function(pets)
		pets[petId] = {
			petType = petType,
			rarity = petData.rarity,
			damage = petData.damage,
			maxHp = petData.hp or 20,
			displayName = petData.displayName,
		}
		return pets
	end)

	PlayerService.UpdateValue(player, "dice", function(old)
		return (old or 0) + 1
	end)

	-- Auto-equip if slot available
	local equipped = PlayerService.GetValue(player, "equippedPets") or {}
	local maxSlots = PlayerService.GetValue(player, "maxEquipSlots") or 1

	local autoEquipped = false
	if #equipped < maxSlots then
		autoEquipped = true
		PlayerService.UpdateValue(player, "equippedPets", function(list)
			table.insert(list, petId)
			return list
		end)
	end

	Remotes.RollPet:FireClient(player, {
		petType = petType,
		petId = petId,
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