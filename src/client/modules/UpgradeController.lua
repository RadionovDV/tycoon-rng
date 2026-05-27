-- UpgradeController.lua
-- Client-side upgrade tree viewer. Shows available upgrades, handles purchase requests,
-- and manages the notification badge count on the upgrade icon.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local PlayerDataClient = require(ReplicatedStorage.PlayerData.PlayerDataClient)
local UpgradeConfig = require(ReplicatedStorage.UpgradeConfig)

local player = Players.LocalPlayer
local playerGui = player.PlayerGui
local mainGui = playerGui:WaitForChild("GameplayGui")

local Remotes = ReplicatedStorage.Remotes

local UpgradeController = {}

function UpgradeController.UpdateNotifications()
	local upgrades = PlayerDataClient.get("upgrades") or {}
	local coins = PlayerDataClient.get("coins") or 0
	local dice = PlayerDataClient.get("dice") or 0

	local upgradeUI = mainGui:FindFirstChild("UpgradeUI")
	if not upgradeUI then return end

	local badge = upgradeUI:FindFirstChild("NotificationBadge")
	if not badge then return end

	-- Count how many upgrades are purchasable right now
	local count = 0
	for upgradeId, config in UpgradeConfig do
		-- Skip already owned
		if upgrades[upgradeId] then continue end
		-- Skip if prerequisite not met
		if config.requires and not upgrades[config.requires] then continue end
		-- Check affordability
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
end

return UpgradeController