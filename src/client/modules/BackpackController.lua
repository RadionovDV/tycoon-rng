-- BackpackController.lua
-- Client-side backpack viewer. Renders owned pets in a ScrollingFrame using ItemTile templates,
-- sorted by rarity (rarest first). Provides equip/unequip buttons per pet.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local PlayerDataClient = require(ReplicatedStorage.PlayerData.PlayerDataClient)
local PetConfig = require(ReplicatedStorage.PetConfig)

local player = Players.LocalPlayer
local playerGui = player.PlayerGui
local menuGui = playerGui:WaitForChild("MenuGui")
local Remotes = ReplicatedStorage.Remotes

local BackpackController = {}

local rarityOrder = {
    Divine = 1,
    Legendary = 2,
    Epic = 3,
    Rare = 4,
    Uncommon = 5,
    Common = 6,
}

function BackpackController._createPetTile(petId, petEntry, isEquipped)
    local template = ReplicatedStorage:FindFirstChild("UI")
        and ReplicatedStorage.UI:FindFirstChild("Objects")
        and ReplicatedStorage.UI.Objects:FindFirstChild("ItemTile")
    if not template then
        return nil
    end

    local tile = template:Clone()
    tile.Name = petId
    tile.LayoutOrder = rarityOrder[petEntry.rarity] or 99

    local iconLabel = tile:FindFirstChild("IconLabel", true)
    if iconLabel then
        iconLabel:Destroy()
    end

    local countLabel = tile:FindFirstChild("CountLabel", true)
    if countLabel then
        countLabel.Text = petEntry.rarity
    end

    local equipButton = tile:FindFirstChild("EquipButton", true)
    if equipButton then
        if isEquipped then
            equipButton.Text = "Unequip"
            equipButton.Activated:Connect(function()
                Remotes.UnequipPet:FireServer(petId)
            end)
        else
            equipButton.Text = "Equip"
            equipButton.Activated:Connect(function()
                Remotes.EquipPet:FireServer(petId)
            end)
        end
    end

    return tile
end

function BackpackController.Refresh()
    if not PlayerDataClient.hasLoaded() then
        return
    end

    local pets = PlayerDataClient.get("pets") or {}
    local equipped = PlayerDataClient.get("equippedPets") or {}
    local equippedSet = {}
    for _, pid in equipped do
        equippedSet[pid] = true
    end

    local scrollingFrame = menuGui:FindFirstChild("Body")
        and menuGui.Body:FindFirstChild("ScrollingFrame")
    if not scrollingFrame then
        return
    end

    for _, child in scrollingFrame:GetChildren() do
        if child:IsA("Frame") or child:IsA("ImageButton") or child:IsA("ImageLabel") then
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
        local tile = BackpackController._createPetTile(petId, pets[petId], equippedSet[petId])
        if tile then
            tile.Parent = scrollingFrame
        end
    end
end

return BackpackController