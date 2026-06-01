-- OfflineIncomeController.lua
-- Shows a popup with accumulated offline income when the player logs in.
-- Uses the existing ConfirmationMenu template from ReplicatedStorage.UI.Objects.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Remotes = ReplicatedStorage.Remotes

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local messageGui = playerGui:WaitForChild("MessageGui")
local background = messageGui:WaitForChild("Background")
local template = ReplicatedStorage.UI.Objects:WaitForChild("ConfirmationMenu")

local OfflineIncomeController = {}

function OfflineIncomeController._showPopup(data)
	local existing = background:FindFirstChild("OfflineIncomePopup")
	if existing then existing:Destroy() end

	local popup = template:Clone()
	popup.Name = "OfflineIncomePopup"

	local body = popup:WaitForChild("Body")
	local messageLabel = body:WaitForChild("MessageLabel")
	local confirmButton = body:WaitForChild("ConfirmButton")

	local message = ""
	if data.coins > 0 then
		message = message .. "Coins earned: " .. tostring(data.coins) .. "\n"
	end
	if data.rocks > 0 then
		message = message .. "Rocks earned: " .. tostring(data.rocks) .. "\n"
	end
	if data.showWarning then
		message = message .. "\nYour bucket was full! Some earnings were lost."
	end

	messageLabel.Text = message
	confirmButton.Activated:Connect(function()
		popup:Destroy()
	end)

	popup.Parent = background
end

function OfflineIncomeController.Start()
	Remotes.ShowOfflineIncome.OnClientEvent:Connect(OfflineIncomeController._showPopup)
end

return OfflineIncomeController