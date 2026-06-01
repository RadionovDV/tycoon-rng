-- GameServer.lua (Script)
-- Server-side entry point. Requires all service modules and initializes them.
-- Order matters: PlayerService.Start() must run first since it starts PlayerDataServer.
local module = script.Parent.Modules

local EconomyService = require(module.EconomyService)
local PlayerService = require(module.PlayerService)
local RollService = require(module.RollService)
local CombatService = require(module.CombatService)
local UpgradeService = require(module.UpgradeService)
local LocationService = require(module.LocationService)
local PetEquipService = require(module.PetEquipService)
local RebirthService = require(module.RebirthService)
local OfflineIncomeService = require(module.OfflineIncomeService)

local GameServer = {
	Services = {
		EconomyService = EconomyService,
		PlayerService = PlayerService,
		RollService = RollService,
		CombatService = CombatService,
		UpgradeService = UpgradeService,
		LocationService = LocationService,
		PetEquipService = PetEquipService,
		OfflineIncomeService = OfflineIncomeService,
	},
}

-- Start order: data system first, then listeners, then combat loop
PlayerService.Start()
RollService.StartListening()
PetEquipService.StartListening()
UpgradeService.StartListening()
LocationService.StartListening()
RebirthService.StartListening()
OfflineIncomeService.StartListening()
CombatService.Start()

return GameServer