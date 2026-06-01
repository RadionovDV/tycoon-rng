-- RollController.lua
-- Client-side rolling UI handler. Fires server on button click, receives pet result,
-- and displays it in either the Roll window or the HUD auto-roll frame.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local PlayerDataClient = require(ReplicatedStorage.PlayerData.PlayerDataClient)

local Remotes = ReplicatedStorage.Remotes

local player = Players.LocalPlayer
local playerGui = player.PlayerGui
local menuGui = playerGui:WaitForChild("MenuGui")
local rollFrame = menuGui:WaitForChild("Roll")
local background = rollFrame:WaitForChild("Background")
local hideRoll = background:WaitForChild("HideRoll")
local autoRoll = background:WaitForChild("AutoRoll")

-- ViewingRoll is now a template in ReplicatedStorage — clone it for this player
local viewingRollTemplate = ReplicatedStorage.UI.Objects:WaitForChild("ViewingRoll")
local viewingRollInstance = viewingRollTemplate:Clone()
viewingRollInstance.Parent = background

local petIcon = viewingRollInstance:WaitForChild("PetIcon")
local petNameLabel = viewingRollInstance:WaitForChild("NameLabel")
local rarityLabel = petIcon:WaitForChild("RarityLabel")

local gameplayGui = playerGui:WaitForChild("GameplayGui")
local autorollFrame = gameplayGui:WaitForChild("Autoroll")
local bottomSide = gameplayGui:WaitForChild("BottomSide")
local rollHudFrame = bottomSide:WaitForChild("Roll")
local rollButton = rollHudFrame:WaitForChild("RollButton")

-- Auto-roll state
local autoRollActive = false
local autoRollThread = nil

local rarityColors = {
	Common = Color3.fromRGB(180, 180, 180),
	Uncommon = Color3.fromRGB(100, 200, 100),
	Rare = Color3.fromRGB(80, 150, 255),
	Epic = Color3.fromRGB(180, 80, 255),
	Legendary = Color3.fromRGB(255, 180, 50),
	Divine = Color3.fromRGB(255, 80, 80),
}

local RollController = {}

-- Shows/hides the AutoRoll and HideRoll buttons based on whether the player
-- owns the autoll upgrade. Reads from upgrades dict for reliable post-rebirth sync.
-- Also checks permanentUpgrades so autoll survives rebirth.
-- Called on init and whenever upgrades or autoRollUnlocked changes.
function RollController.UpdateAutoRollVisibility(rebirth)
	local upgrades = PlayerDataClient.get("upgrades") or {}
	local permanentUpgrades = PlayerDataClient.get("permanentUpgrades") or {}
	local unlocked = upgrades.autoll == true or permanentUpgrades.autoll == true
	autoRoll.Visible = unlocked
	hideRoll.Visible = unlocked
	if rebirth then
		autoRollActive = false
		viewingRollInstance.Parent = background
	end
end

-- Activates auto-roll: closes Roll window, moves ViewingRoll into the HUD autoroll
-- frame, and starts a background loop that fires RollPet every rollCooldown seconds.
function RollController._startAutoRoll()
	autoRollActive = true
	rollFrame.Visible = false
	viewingRollInstance.Parent = autorollFrame

	autoRollThread = task.spawn(function()
		while autoRollActive do
			Remotes.RollPet:FireServer()
			task.wait(PlayerDataClient.get("rollCooldown") or 2)
		end
	end)
end

-- Deactivates auto-roll: stops the loop, lets the last result stay visible for 1.5s,
-- then closes the Roll window and returns ViewingRoll to its default parent.
function RollController._stopAutoRoll()
	autoRollActive = false
	if autoRollThread then
		task.cancel(autoRollThread)
		autoRollThread = nil
	end

	task.wait(1.5)

	rollFrame.Visible = false
	viewingRollInstance.Parent = background
end

-- Manual roll button in the HUD.
-- During auto-roll it toggles the Roll window instead of firing a roll.
rollButton.Activated:Connect(function()
	if autoRollActive then
		rollFrame.Visible = not rollFrame.Visible
	else
		Remotes.RollPet:FireServer()
	end
end)

-- Closes the Roll window (manual roll dismissal)
hideRoll.Activated:Connect(function()
	rollFrame.Visible = false
end)

-- Toggles auto-roll on/off
autoRoll.Activated:Connect(function()
	if autoRollActive then
		RollController._stopAutoRoll()
	else
		RollController._startAutoRoll()
	end
end)

-- While auto-rolling, keep ViewingRoll in whichever container is open
rollFrame:GetPropertyChangedSignal("Visible"):Connect(function()
	if not autoRollActive then
		return
	end
	viewingRollInstance.Parent = rollFrame.Visible and background or autorollFrame
end)

-- Receives roll results from the server and updates the display
Remotes.RollPet.OnClientEvent:Connect(function(result)
	petNameLabel.Text = result.displayName
	rarityLabel.Text = result.rarity
	rarityLabel.TextColor3 = rarityColors[result.rarity] or Color3.new(1, 1, 1)

	if autoRollActive then
		viewingRollInstance.Visible = true
	else
		viewingRollInstance.Parent = background
		rollFrame.Visible = true
		task.wait(1.5)
		rollFrame.Visible = false
	end
end)

return RollController