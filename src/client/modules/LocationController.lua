-- LocationController.lua
-- Client-side gate interaction handler.
-- Scans every Location folder in Workspace for Gate/Back parts,
-- connects their SurfaceGui or BillboardGui unlock buttons to the server.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local PlayerDataClient = require(ReplicatedStorage.PlayerData.PlayerDataClient)
local LocationConfig = require(ReplicatedStorage.LocationConfig)

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage.Remotes

local LocationController = {}

function LocationController._connectGates()
    for _, location in Workspace:GetChildren() do
        local config = LocationConfig[location.Name]
        if not config or not config.connectedLocationIds then
            continue
        end

        local gate = location:FindFirstChild("Gate")
        if not gate then
            continue
        end

        local back = gate:FindFirstChild("Back")
        if not back then
            continue
        end

        local gui = back:FindFirstChildOfClass("SurfaceGui")
                or back:FindFirstChildOfClass("BillboardGui")
        if not gui then
            continue
        end

        local button = gui:FindFirstChild("UnlockButton", true)
        if button and not button:GetAttribute("GateConnected") then
            button:SetAttribute("GateConnected", true)
            button.Activated:Connect(function()
                for _, targetId in config.connectedLocationIds do
                    Remotes.UnlockLocation:FireServer(targetId)
                end
            end)
        end
    end
end

function LocationController.UpdateGateStates()
    local unlocked = PlayerDataClient.get("unlockedLocations") or {}

    for _, location in Workspace:GetChildren() do
        local config = LocationConfig[location.Name]
        if not config or not config.connectedLocationIds then
            continue
        end

        local gate = location:FindFirstChild("Gate")
        if not gate then
            continue
        end

        local back = gate:FindFirstChild("Back")
        if not back then
            continue
        end

        local gui = back:FindFirstChildOfClass("SurfaceGui")
                or back:FindFirstChildOfClass("BillboardGui")
        if not gui then
            continue
        end

        local button = gui:FindFirstChild("UnlockButton", true)
        local costLabel = gui:FindFirstChild("CostLabel", true)

        local allUnlocked = true
        for _, targetId in config.connectedLocationIds do
            local found = false
            for _, loc in unlocked do
                if loc == targetId then
                    found = true
                    break
                end
            end
            if not found then
                allUnlocked = false
                break
            end
        end

        if button then
            button.Visible = not allUnlocked
        end
        if costLabel then
            costLabel.Visible = not allUnlocked
        end
    end
end

LocationController._connectGates()

return LocationController