-- CombatController.lua
-- Client-side pet 3D model manager.
-- Maintains an orbiting ring of pet models around the player via RunService.Heartbeat.
-- SpawnPet/RemovePet are called internally from SyncEquippedPets.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local PlayerDataClient = require(ReplicatedStorage.PlayerData.PlayerDataClient)
local PetConfig = require(ReplicatedStorage.PetConfig)

local player = Players.LocalPlayer

local orbitRadius = 5
local orbitSpeed = 0.6

local CombatController = {}

local petModels = {}
local heartbeatConn = nil

local rarityColors = {
    Common = Color3.fromRGB(180, 180, 180),
    Uncommon = Color3.fromRGB(100, 200, 100),
    Rare = Color3.fromRGB(80, 150, 255),
    Epic = Color3.fromRGB(180, 80, 255),
    Legendary = Color3.fromRGB(255, 180, 50),
    Divine = Color3.fromRGB(255, 80, 80),
}

function CombatController.SpawnPet(petType, petId)
    local modelTemplate = ReplicatedStorage:FindFirstChild("PetModels")
        and ReplicatedStorage.PetModels:FindFirstChild(petType)
    if not modelTemplate then
        return
    end

    local model = modelTemplate:Clone()
    model.Parent = Workspace

    local entryCount = 0
    for _ in petModels do entryCount += 1 end
    local verticalOffset = (entryCount % 3 - 1) * 2

    petModels[petId] = {
        model = model,
        angle = (entryCount * 2.1) % (math.pi * 2),
        verticalOffset = verticalOffset,
    }

    if not heartbeatConn then
        heartbeatConn = RunService.Heartbeat:Connect(function(dt)
            CombatController._updateOrbit(dt)
        end)
    end
end

function CombatController.RemovePet(petId)
    local entry = petModels[petId]
    if entry then
        entry.model:Destroy()
        petModels[petId] = nil
    end

    local count = 0
    for _ in petModels do count += 1 end
    if count == 0 and heartbeatConn then
        heartbeatConn:Disconnect()
        heartbeatConn = nil
    end
end

function CombatController.SyncEquippedPets()
    if not PlayerDataClient.hasLoaded() then
        return
    end

    local equipped = PlayerDataClient.get("equippedPets") or {}
    local allPets = PlayerDataClient.get("pets") or {}

    local newSet = {}
    for _, petId in equipped do
        newSet[petId] = true
    end

    for petId in petModels do
        if not newSet[petId] then
            CombatController.RemovePet(petId)
        end
    end

    for _, petId in equipped do
        if not petModels[petId] and allPets[petId] then
            CombatController.SpawnPet(allPets[petId].petType, petId)
        end
    end
end

function CombatController._updateOrbit(dt)
    local character = player.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        return
    end

    local centerPos = rootPart.Position

    for petId, entry in petModels do
        entry.angle = (entry.angle + orbitSpeed * dt) % (math.pi * 2)
        local offset = Vector3.new(
            math.cos(entry.angle) * orbitRadius,
            entry.verticalOffset + 1,
            math.sin(entry.angle) * orbitRadius
        )
        local targetCF = CFrame.new(centerPos + offset) * CFrame.Angles(0, -entry.angle, 0)
        entry.model:PivotTo(targetCF)
    end
end

-- Cleanup when character respawns
player.CharacterAdded:Connect(function()
    for petId in petModels do
        local entry = petModels[petId]
        if entry then
            entry.model:Destroy()
        end
    end
    local toRemove = {}
    for petId in petModels do toRemove[#toRemove + 1] = petId end
    for _, petId in toRemove do
        petModels[petId] = nil
    end
    CombatController.SyncEquippedPets()
end)

return CombatController