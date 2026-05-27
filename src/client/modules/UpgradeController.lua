-- UpgradeController.lua
-- Client-side upgrade tree viewer. Renders upgrade nodes in UpgradeUI,
-- handles purchase requests, and manages the notification badge.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local PlayerDataClient = require(ReplicatedStorage.PlayerData.PlayerDataClient)
local UpgradeConfig = require(ReplicatedStorage.UpgradeConfig)

local player = Players.LocalPlayer
local playerGui = player.PlayerGui
local mainGui = playerGui:WaitForChild("GameplayGui")
local Remotes = ReplicatedStorage.Remotes

local UpgradeController = {}

function UpgradeController._renderUpgrades()
    local upgradeUI = mainGui:FindFirstChild("UpgradeUI")
    if not upgradeUI then
        return
    end

    local listContainer = upgradeUI:FindFirstChild("ListContainer")
    if not listContainer then
        return
    end

    for _, child in listContainer:GetChildren() do
        if child:IsA("Frame") or child:IsA("TextButton") then
            child:Destroy()
        end
    end

    local upgrades = PlayerDataClient.get("upgrades") or {}
    local coins = PlayerDataClient.get("coins") or 0
    local dice = PlayerDataClient.get("dice") or 0

    local upgradeIds = {}
    for id in UpgradeConfig do
        table.insert(upgradeIds, id)
    end

    local processed = {}
    local hasChanges = true
    while hasChanges do
        hasChanges = false
        for _, id in upgradeIds do
            if processed[id] then
                continue
            end
            local config = UpgradeConfig[id]
            if not config.requires or processed[config.requires] or upgrades[config.requires] then
                local frame = Instance.new("Frame")
                frame.Name = id
                frame.Size = UDim2.new(1, 0, 0, 60)
                frame.BackgroundTransparency = 1
                frame.Parent = listContainer

                local nameLabel = Instance.new("TextLabel")
                nameLabel.Size = UDim2.new(0.4, 0, 1, 0)
                nameLabel.BackgroundTransparency = 1
                nameLabel.Text = config.displayName
                nameLabel.TextXAlignment = Enum.TextXAlignment.Left
                nameLabel.Parent = frame

                local costLabel = Instance.new("TextLabel")
                costLabel.Size = UDim2.new(0.25, 0, 1, 0)
                costLabel.Position = UDim2.new(0.4, 0, 0, 0)
                costLabel.BackgroundTransparency = 1
                costLabel.Text = tostring(config.cost) .. " " .. config.currency
                costLabel.Parent = frame

                local owned = upgrades[id]
                local canAfford = (config.currency == "coins" and coins >= config.cost)
                    or (config.currency == "dice" and dice >= config.cost)
                local prereqMet = not config.requires or upgrades[config.requires]

                local buyButton = Instance.new("TextButton")
                buyButton.Size = UDim2.new(0.35, 0, 1, 0)
                buyButton.Position = UDim2.new(0.65, 0, 0, 0)

                if owned then
                    buyButton.Text = "Owned"
                    buyButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
                    buyButton.Active = false
                elseif not prereqMet then
                    buyButton.Text = "Locked"
                    buyButton.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
                    buyButton.Active = false
                elseif canAfford then
                    buyButton.Text = "Buy"
                    buyButton.BackgroundColor3 = Color3.fromRGB(40, 140, 40)
                    buyButton.Activated:Connect(function()
                        Remotes.PurchaseUpgrade:FireServer(id)
                    end)
                else
                    buyButton.Text = "Not enough"
                    buyButton.BackgroundColor3 = Color3.fromRGB(120, 80, 40)
                    buyButton.Active = false
                end

                buyButton.Parent = frame

                processed[id] = true
                hasChanges = true
            end
        end
    end
end

function UpgradeController.UpdateNotifications()
    local upgrades = PlayerDataClient.get("upgrades") or {}
    local coins = PlayerDataClient.get("coins") or 0
    local dice = PlayerDataClient.get("dice") or 0

    local upgradeUI = mainGui:FindFirstChild("UpgradeUI")
    if not upgradeUI then
        return
    end

    local badge = upgradeUI:FindFirstChild("NotificationBadge")
    if not badge then
        return
    end

    local count = 0
    for upgradeId, config in UpgradeConfig do
        if upgrades[upgradeId] then
            continue
        end
        if config.requires and not upgrades[config.requires] then
            continue
        end
        local balance = config.currency == "coins" and coins or dice
        if balance >= config.cost then
            count += 1
        end
    end

    if count > 0 then
        badge.Visible = true
        badge.Text = tostring(count)
    else
        badge.Visible = false
    end

    UpgradeController._renderUpgrades()
end

return UpgradeController