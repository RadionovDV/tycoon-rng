-- CombatController.lua
-- Client-side combat visuals. Manages 3D pet models orbiting the player
-- and handles coin-to-HUD animation when enemies are defeated.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local Remotes = ReplicatedStorage.Remotes

local CombatController = {}

local petModels = {}

-- Called when a new pet is equipped (spawns its 3D model near the player)
function CombatController.SpawnPet(petType, rarity)
	-- Stub: will be implemented in Day 2 with RunService.Heartbeat orbital movement
end

-- Called when a pet is unequipped (removes its 3D model)
function CombatController.RemovePet(petId)
	-- Stub: will be implemented in Day 2
end

-- Sync equipped pets list with server state
function CombatController.SyncEquippedPets()
	-- Stub: will be implemented in Day 2
end

-- Server fires this when an enemy is defeated, triggering coin-fly animation
Remotes.EnemyDefeated.OnClientEvent:Connect(function(data)
	-- Stub: coin animation in Day 3
end)

return CombatController