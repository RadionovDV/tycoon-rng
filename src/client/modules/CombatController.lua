-- CombatController.lua
-- Client-side combat visual manager.
-- Spawns and orients 3D pet models orbiting the player, plus 3D enemy models
-- with HP bars. Handles pet death/revive transparency and enemy model cleanup.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local PlayerDataClient = require(ReplicatedStorage.PlayerData.PlayerDataClient)
local PetConfig = require(ReplicatedStorage.PetConfig)

local player = Players.LocalPlayer

local orbitRadius = 5
local orbitSpeed = 0.6

local CombatController = {}

local petModels = {}
local enemyModels = {}
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
	for _ in petModels do entryCount = entryCount + 1 end
	local verticalOffset = (entryCount % 3 - 1) * 2

	local hpBar = Instance.new("BillboardGui")
	hpBar.Size = UDim2.new(0, 100, 0, 20)
	hpBar.StudsOffset = Vector3.new(0, 3, 0)
	hpBar.AlwaysOnTop = true

	local hpLabel = Instance.new("TextLabel")
	hpLabel.Size = UDim2.new(1, 0, 1, 0)
	hpLabel.BackgroundTransparency = 1
	hpLabel.TextColor3 = Color3.new(1, 1, 1)
	hpLabel.TextScaled = true
	hpLabel.Text = "HP: ?/?"
	hpLabel.Parent = hpBar

	hpBar.Parent = model

	petModels[petId] = {
		model = model,
		angle = (entryCount * 2.1) % (math.pi * 2),
		verticalOffset = verticalOffset,
		hpBar = hpBar,
		hpLabel = hpLabel,
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
	for _ in petModels do count = count + 1 end
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

	local playerPos = rootPart.Position
	for enemyId, entry in enemyModels do
		if entry.targetPosition then
			local currentPos = entry.model:GetPivot().Position
			local newPos = currentPos:Lerp(entry.targetPosition, 0.2)
			local lookAt = CFrame.lookAt(newPos, playerPos)
			entry.model:PivotTo(lookAt)
		end
	end
end

function CombatController.SyncCombatState(data)
	if not data then return end

	for enemyId, eData in data.enemies do
		if not eData.isAlive then
			if enemyModels[enemyId] then
				enemyModels[enemyId].model:Destroy()
				enemyModels[enemyId] = nil
			end
		else
			if not enemyModels[enemyId] then
				local template = ReplicatedStorage:FindFirstChild("EnemyModels")
					and ReplicatedStorage.EnemyModels:FindFirstChild(eData.type)
				if template then
					local model = template:Clone() :: MeshPart
					model.Parent = Workspace

					local hpBar = Instance.new("BillboardGui")
					hpBar.Size = UDim2.new(0, 100, 0, 20)
					hpBar.StudsOffset = Vector3.new(0, 3, 0)
					hpBar.AlwaysOnTop = true

					local hpLabel = Instance.new("TextLabel")
					hpLabel.Size = UDim2.new(1, 0, 1, 0)
					hpLabel.BackgroundTransparency = 1
					hpLabel.TextColor3 = Color3.new(1, 0, 0)
					hpLabel.TextScaled = true
					hpLabel.Text = ""
					hpLabel.Parent = hpBar

					hpBar.Parent = model

					enemyModels[enemyId] = {
						model = model,
						hpBar = hpBar,
						hpLabel = hpLabel,
						targetPosition = Vector3.new(eData.position.X, eData.position.Y, eData.position.Z),
					}
					
					model:PivotTo(CFrame.new(enemyModels[enemyId].targetPosition))
				end
			else
				enemyModels[enemyId].targetPosition = Vector3.new(eData.position.X, eData.position.Y, eData.position.Z)
			end

			if enemyModels[enemyId] and enemyModels[enemyId].hpLabel then
				enemyModels[enemyId].hpLabel.Text = string.format("HP: %d/%d", eData.hp, eData.maxHp)
			end
		end
	end

	for petId, pData in data.pets do
		local entry = petModels[petId]
		if entry and entry.hpLabel then
			entry.hpLabel.Text = string.format("HP: %d/%d", pData.hp, pData.maxHp)
		end
	end
end

function CombatController.OnPetDefeated(petId)
	local entry = petModels[petId]
	if entry then
		local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Linear)
		local tween = TweenService:Create(entry.model:GetDescendants(), tweenInfo, { Transparency = 0.7 })
		tween:Play()
		for _, part in entry.model:GetDescendants() do
			if part:IsA("BasePart") then
				part.Transparency = 0.7
			end
		end
		if entry.hpLabel then
			entry.hpLabel.Text = "DEFEATED"
		end
	end
end

function CombatController.OnPetRevived(petId)
	local entry = petModels[petId]
	if entry then
		local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Linear)
		local tween = TweenService:Create(entry.model:GetDescendants(), tweenInfo, { Transparency = 0 })
		tween:Play()
		for _, part in entry.model:GetDescendants() do
			if part:IsA("BasePart") then
				part.Transparency = 0
			end
		end
		if entry.hpLabel then
			entry.hpLabel.Text = ""
		end
	end
end

function CombatController.OnEnemyDefeated(enemyId)
	local entry = enemyModels[enemyId]
	if entry then
		entry.model:Destroy()
		enemyModels[enemyId] = nil
	end
end

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