-- LocationController.lua
-- Client-side gate interaction handler.
-- Scans every Location folder in Workspace for Gate/Back parts,
-- connects their SurfaceGui or BillboardGui unlock buttons to the server.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local PlayerDataClient = require(ReplicatedStorage.PlayerData.PlayerDataClient)
local LocationConfig = require(ReplicatedStorage.LocationConfig)

local Remotes = ReplicatedStorage.Remotes
local player = Players.LocalPlayer
local playerGui = player.PlayerGui

local uiObjects = ReplicatedStorage.UI.Objects
local gateBillboardGuiTemplate = uiObjects:WaitForChild("GateBillboardGui")
local gateSurfaceGuiTemplate = uiObjects:WaitForChild("GateSurfaceGui")

local LocationController = {}

-- Creates or recreates a single gate's SurfaceGui/BillboardGui.
-- Detects BillboardAttachment on Back to pick template, fills price/label,
-- binds unlock button, parents to playerGui.
function LocationController._createGateGui(location)
	local gate = location:FindFirstChild("Gate")
	if not gate then
		return
	end

	local back = gate:WaitForChild("Back")
	local gui : SurfaceGuiBase
	local attachment = back:FindFirstChild("BillboardAttachment") :: Attachment?

	if attachment then
		gui = gateBillboardGuiTemplate:Clone()
		gui.Adornee = attachment
	else
		gui = gateSurfaceGuiTemplate:Clone()
		gui.Adornee = back
	end

	local config = LocationConfig[location.Name]
	if not config or not config.connectedLocationIds then
		return
	end

	local lockerInfo = gui.LockerInfo
	local titleLabel = lockerInfo.TitleLabel
	local unlockButton = lockerInfo.Unlock.UnlockButton
	local iconLabel = lockerInfo.PriceFrame.IconLabel
	local priceLabel = lockerInfo.PriceFrame.PriceLabel

	local nextLocationName = gate:GetAttribute("LeadTo")
	local nextLocationConfig = LocationConfig[nextLocationName]

	titleLabel.Text = nextLocationConfig.displayName
	priceLabel.Text = nextLocationConfig.unlockCost

	if unlockButton then
		unlockButton.Activated:Connect(function()
			for _, targetId in config.connectedLocationIds do
				if targetId == nextLocationName then
					Remotes.UnlockLocation:FireServer(targetId)
				end
			end
		end)
	end

	gui.Name = location.Name
	gui.Parent = playerGui
end

-- Scans all Locations for Gates and creates their GUIs once.
-- Also listens for new Locations added to Workspace.
function LocationController._connectGates()
	Workspace.ChildAdded:Connect(function(child)
		task.spawn(LocationController._createGateGui, child)
	end)

	for _, location in Workspace:GetChildren() do
		task.spawn(LocationController._createGateGui, location)
	end
end

function LocationController.UpdateGateStates()
	local unlockedIds = PlayerDataClient.get("unlockedLocations") or {}

	for _, unlockedId in unlockedIds do
		local curlocationId = LocationConfig[unlockedId].prerequisite
		if not curlocationId then
			continue
		end

		local location = Workspace:FindFirstChild(curlocationId)
		if not location then
			continue
		end

		local gate = location:FindFirstChild("Gate")
		if not gate then
			continue
		end

		local back = gate:FindFirstChild("Back")
		local depthFade = gate:FindFirstChild("DepthFade")
		for _, child in {back, depthFade} do
			if not child then
				continue
			end
			local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			local tween = TweenService:Create(child, tweenInfo, { Transparency = 1 })
			tween:Play()
		end

		task.wait(0.5)

		for _, targetGui in playerGui:GetChildren() do
			if targetGui.ClassName == "BillboardGui" or targetGui.ClassName == "SurfaceGui" then
				if targetGui.Name == location.Name then
					targetGui:Destroy()
				end
			end
		end

		local locker = gate:FindFirstChild("Locker")
		locker.CanCollide = false
	end
end

-- Restores all Gates to initial state (visible, lock solid).
-- Destroys stale GUIs and recreates fresh ones with new button connections.
-- Called after rebirth when unlockedLocations and currentLocation reset.
function LocationController.Refresh()
	for _, location in Workspace:GetChildren() do
		local gate = location:FindFirstChild("Gate")
		if not gate then
			continue
		end

		local back = gate:FindFirstChild("Back")
		local depthFade = gate:FindFirstChild("DepthFade")
		local locker = gate:FindFirstChild("Locker")

		if back then
			back.Transparency = 0
		end
		if depthFade then
			depthFade.Transparency = 0.05
		end
		if locker then
			locker.CanCollide = true
		end

		for _, targetGui in playerGui:GetChildren() do
			if targetGui.Name == location.Name then
				local isValid = targetGui.ClassName == "BillboardGui" or targetGui.ClassName == "SurfaceGui"
				if isValid then
					targetGui:Destroy()
				end
			end
		end

		task.spawn(LocationController._createGateGui, location)
	end
end

LocationController._connectGates()

return LocationController