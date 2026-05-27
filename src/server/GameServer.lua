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

local GameServer = {
	Services = {
		EconomyService = EconomyService,
		PlayerService = PlayerService,
		RollService = RollService,
		CombatService = CombatService,
		UpgradeService = UpgradeService,
		LocationService = LocationService,
	},
}

-- Start order: data system first, then listeners, then combat loop
PlayerService.Start()
RollService.StartListening()
UpgradeService.StartListening()
LocationService.StartListening()
CombatService.Start()

print("GameServer initialized")

return GameServer