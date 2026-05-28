-- BackpackController.lua
-- Client-side backpack viewer. Uses ItemTile component to render pets in ScrollingFrame,
-- sorted by rarity (rarest first).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local PlayerDataClient = require(ReplicatedStorage.PlayerData.PlayerDataClient)
local ItemTile = require(ReplicatedStorage.UI.Components.ItemTile)

local player = Players.LocalPlayer
local playerGui = player.PlayerGui
local menuGui = playerGui:WaitForChild("MenuGui")
local backpackFrame = menuGui:FindFirstChild("Backpack")
local scrollingFrame = backpackFrame and backpackFrame:FindFirstChild("Body")
	and backpackFrame.Body:FindFirstChild("ScrollingFrame")

local rarityOrder = {
	Divine = 1,
	Legendary = 2,
	Epic = 3,
	Rare = 4,
	Uncommon = 5,
	Common = 6,
}

local BackpackController = {}

function BackpackController.Refresh()
	if not PlayerDataClient.hasLoaded() or not scrollingFrame then
		return
	end

	local pets = PlayerDataClient.get("pets") or {}
	local equipped = PlayerDataClient.get("equippedPets") or {}
	local equippedSet = {}
	for _, pid in equipped do
		equippedSet[pid] = true
	end

	for _, child in scrollingFrame:GetChildren() do
		if child:IsA("ImageButton") then
			child:Destroy()
		end
	end

	local sortedPetIds = {}
	for petId in pets do
		table.insert(sortedPetIds, petId)
	end
	table.sort(sortedPetIds, function(a, b)
		local ra = rarityOrder[pets[a].rarity] or 99
		local rb = rarityOrder[pets[b].rarity] or 99
		if ra == rb then
			return a < b
		end
		return ra < rb
	end)

	for _, petId in sortedPetIds do
		local tile = ItemTile.Create(petId, pets[petId], equippedSet[petId])
		tile.Parent = scrollingFrame
	end
end

return BackpackController