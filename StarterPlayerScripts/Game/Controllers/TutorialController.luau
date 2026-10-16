--[[
	TutorialController — the current tutorial step (the server decides it: "Tutorial" { Id } or { Done }):
	its Text is a sticky notification with the TutorialConfig.Header (no quest panel), a beam of scrolling arrows from the
	player's feet plus a bouncing marker point at its Target, and a step with Highlight = "Roll" dims the screen around the
	ROLL! button (Spotlight) while that button is on screen; Highlight = "Gifts" dims around the HUD Gifts button, then the
	step's gift CLAIM button once the Gifts window is open.
	Targets resolve every frame (things move and stream in), by name:
	  RollZone   the throw pad          LogPad     the pedestal of the log the server picked ("TutorialLog" attribute)
	  Treadmill  the first treadmill    else       the nearest instance tagged TutorialConfig.TargetTag whose "Target" is the name
	The beam and marker hide while you stand on the target. Text can change live inside a step (touch layout, Buy before the
	player can afford the log, Train's level counter).
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Balance = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local Config = require(ReplicatedStorage.Shared.Config.TutorialConfig)
local Curves = require(ReplicatedStorage.Shared.Modules.Curves)
local Emphasis = require(ReplicatedStorage.Shared.Modules.Emphasis)
local GuidePointer = require(ReplicatedStorage.Shared.Modules.GuidePointer)
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Spotlight = require(ReplicatedStorage.Shared.Modules.Spotlight)
local GiftsController = require(script.Parent.GiftsController)
local HudController = require(script.Parent.HudController)
local NotifyController = require(script.Parent.NotifyController)
local ClientState = require(script.Parent.Parent.State.ClientState)
local GiftsConfig = require(ReplicatedStorage.Shared.Config.GiftsConfig)
local NumberFormat = require(ReplicatedStorage.Shared.Modules.NumberFormat)

local TutorialController = {}

local player = Players.LocalPlayer
local resolvers: { [string]: () -> BasePart? } = {}
local pointer
local spotlight, rollButton: GuiObject?
local current = nil -- the TutorialConfig step
local stepToast, shownText = nil, ""

local function partOf(instance: Instance?): BasePart?
	if not instance then
		return nil
	end
	if instance:IsA("BasePart") then
		return instance
	end
	return instance:IsA("Model") and instance.PrimaryPart or nil
end

local function tagged(name: string): BasePart?
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local best, bestD = nil, math.huge
	for _, instance in CollectionService:GetTagged(Config.TargetTag) do
		local part = instance:GetAttribute("Target") == name and partOf(instance)
		if part and part:IsDescendantOf(workspace) then
			local d = root and (part.Position - root.Position).Magnitude or 0
			if d < bestD then
				best, bestD = part, d
			end
		end
	end
	return best
end

-- The Buy step needs Wins first: until the player can afford the log, the step points back at the roll (Config Poor).
local function poor(): boolean
	local log = Curves.LogById[player:GetAttribute("TutorialLog")]
	return current ~= nil and current.Poor ~= nil and log ~= nil and (player:GetAttribute("Wins") or 0) < log.Price
end

local function targetName(): string?
	return if poor() then current.Poor.Target else current and current.Target
end

local function resolve(name: string?): BasePart?
	if not name then
		return nil
	end
	return if resolvers[name] then resolvers[name]() else tagged(name)
end

local function textFor(): string
	if poor() then
		return current.Poor.Text
	end
	if current.GoalAttribute then
		local goal = player:GetAttribute("TutorialGoal") or current.Goal or 2
		return current.Text:format(math.min(math.floor(player:GetAttribute(current.GoalAttribute) or 0), goal), goal)
	end
	if current.Gift then
		local claimable, left = GiftsController.Status(current.Gift)
		if not claimable then
			return current.Wait:format(NumberFormat.Clock(left))
		end
		return if ClientState.MenuOpen() == GiftsConfig.Menu then current.Claim else current.Text
	end
	if current.Id == "Buy" then
		local log = Curves.LogById[player:GetAttribute("TutorialLog")]
		return current.Text:format(log and Emphasis.Em(log.Name, "Success") or "log")
	end
	local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	return if touchOnly and current.TextMobile then current.TextMobile else current.Text
end

local function build()
	pointer = GuidePointer.new("Tutorial")
	spotlight = Spotlight.new("TutorialDim", Config.Dim)
end

local function updatePointer()
	pointer:Update(current and resolve(targetName()), current and current.Marker, current and current.MarkerIcon)
end

-- The ROLL! button slides up from below the screen only while you stand on the pad: dim around it once it is mostly in view.
local function updateSpotlight()
	local button = rollButton
	local active = current and (if poor() then current.Poor else current)
	if active and active.Highlight == "Gifts" then
		local open = ClientState.MenuOpen() == GiftsConfig.Menu
		local target = if open then GiftsController.ClaimButton(current.Gift or 1) else HudController.Button("Gifts")
		local claimable = GiftsController.Status(current.Gift or 1)
		spotlight:Set(if claimable and target and target.Visible and target.AbsoluteSize.X > 0 then target else nil)
		return
	end
	local lit = active ~= nil and active.Highlight == "Roll" and button ~= nil and button.Visible
		and button.AbsolutePosition.Y < workspace.CurrentCamera.ViewportSize.Y - button.AbsoluteSize.Y * 0.5
	spotlight:Set(if lit then button else nil)
end

local function update()
	if not current then
		spotlight:Set(nil)
		pointer:Update(nil)
		return
	end
	local text = textFor()
	local label = stepToast and stepToast.Parent and stepToast:FindFirstChild("Text")
	if label and text ~= shownText then
		shownText, label.Text = text, text
	end
	updatePointer()
	updateSpotlight()
end

local function onStep(payload)
	local step = not payload.Done and Config.Steps[payload.Index]
	if not step then
		current = nil
		NotifyController.Dismiss(stepToast)
		stepToast = nil
		return
	end
	local fresh = not current or current.Id ~= step.Id
	current = step
	if fresh then
		NotifyController.Dismiss(stepToast)
		shownText = textFor()
		stepToast = NotifyController.Toast(shownText, "Info", true, Config.Header)
	end
end

function TutorialController.RegisterTarget(name: string, resolver: () -> BasePart?)
	resolvers[name] = resolver
end

-- The current step's Id (nil when there's none), for controllers that react to it.
function TutorialController.Current(): string?
	return current and current.Id
end

function TutorialController.Start()
	Net.Get("Tutorial"):Connect(onStep) -- (before anything that yields: the Ready resend must find it)
	build()
	TutorialController.RegisterTarget("RollZone", function()
		return workspace:FindFirstChild("RollZone")
	end)
	TutorialController.RegisterTarget("LogPad", function()
		local pads = workspace:FindFirstChild("LogPads")
		local model = pads and pads:FindFirstChild(player:GetAttribute("TutorialLog") or "")
		return partOf(model)
	end)
	TutorialController.RegisterTarget("Treadmill", function()
		local rows = workspace:FindFirstChild("Training")
		return partOf(rows and rows:FindFirstChild(Balance.Training.Treadmills[1].Id))
	end)
	task.spawn(function()
		rollButton = player:WaitForChild("PlayerGui"):WaitForChild("RunHud"):WaitForChild("Root"):WaitForChild("Roll")
	end)
	RunService.RenderStepped:Connect(update)
end

return TutorialController
