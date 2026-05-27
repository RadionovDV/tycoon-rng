-- LocationController.lua
-- Client-side gate interaction handler. Connects SurfaceGui unlock buttons on
-- LocationGates BaseParts to the server unlock event.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local PlayerDataClient = require(ReplicatedStorage.PlayerData.PlayerDataClient)
local player = Players.LocalPlayer

local Remotes = ReplicatedStorage.Remotes

local LocationController = {}

local gates = Workspace:FindFirstChild("LocationGates")

-- Connect all gate buttons to the server unlock event
if gates then
	for _, gate in gates:GetChildren() do
		local surfaceGui = gate:FindFirstChildOfClass("SurfaceGui")
		if surfaceGui then
			local button = surfaceGui:FindFirstChild("UnlockButton", true)
			if button then
				button.Activated:Connect(function()
					Remotes.UnlockLocation:FireServer(gate.Name)
				end)
			end
		end
	end
end

-- Update gate visual states (locked/unlocked) based on player data
function LocationController.UpdateGateStates()
	local unlocked = PlayerDataClient.get("unlockedLocations") or {}

	if gates then
		for _, gate in gates:GetChildren() do
			local surfaceGui = gate:FindFirstChildOfClass("SurfaceGui")
			if surfaceGui then
				local button = surfaceGui:FindFirstChild("UnlockButton", true)
				local costLabel = surfaceGui:FindFirstChild("CostLabel", true)
				if button then
					-- In MVP this will toggle button visibility based on unlock state
					if not button:FindFirstChild("GateConnection") then
						-- Already connected above
					end
				end
			end
		end
	end
end

return LocationController