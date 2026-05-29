-- ItemTile.lua (ModuleScript — ReplicatedStorage.UI.Components.ItemTile)
-- Creates configured ItemTileButton instances for the backpack.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local template = ReplicatedStorage.UI.Objects:WaitForChild("BackpackPetTileButton")
local Remotes = ReplicatedStorage.Remotes

local rarityOrder = {
	Divine = 1,
	Legendary = 2,
	Epic = 3,
	Rare = 4,
	Uncommon = 5,
	Common = 6,
}

local ItemTile = {}

function ItemTile.Create(petId, petEntry, isEquipped)
	local tile = template:Clone()
	tile.Name = petId
	tile.LayoutOrder = rarityOrder[petEntry.rarity] or 99
	tile.Body.IconLabel.Image = "rbxassetid://6774884752"

	local iconLabel = tile:FindFirstChild("IconLabel", true)
	local countLabel = tile:FindFirstChild("CountLabel", true)

	if countLabel then
		countLabel.Text = petEntry.rarity
	end

	if isEquipped then
		tile.Activated:Connect(function()
			Remotes.UnequipPet:FireServer(petId)
		end)
	else
		tile.Activated:Connect(function()
			Remotes.EquipPet:FireServer(petId)
		end)
	end

	return tile
end

return ItemTile