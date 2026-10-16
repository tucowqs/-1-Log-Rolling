--[[
	LeaderboardController — fills each lobby board (Workspace.Leaderboards.<Id>.Board.Gui) from the "Entries" attribute
	LeaderboardService publishes, and slowly scrolls the list so all 50 get seen. A player's own scrolling (wheel / touch drag /
	hover on the board) pauses the auto scroll for Scroll.Idle seconds.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage.Shared.Config.LeaderboardConfig)
local View = require(ReplicatedStorage.Shared.Modules.LeaderboardView)

local LeaderboardController = {}

local Scroll = { Speed = 55, Pause = 2.5, Idle = 6 } -- canvas px per second, wait at each end, seconds after the player touches it

local function attach(def, station: Model)
	local gui = station:WaitForChild("Board"):WaitForChild("Gui")
	local list = gui.Panel.List
	local function fill()
		local json = station:GetAttribute("Entries")
		View.Fill(gui, if json then HttpService:JSONDecode(json) else {}, def)
	end
	station:GetAttributeChangedSignal("Entries"):Connect(fill)
	fill()

	local touched, direction, wait = 0, 1, Scroll.Pause
	local function touch()
		touched = os.clock()
	end
	list.MouseEnter:Connect(touch)
	list.MouseMoved:Connect(touch)
	list.InputChanged:Connect(touch)
	list.InputBegan:Connect(touch)
	RunService.Heartbeat:Connect(function(dt)
		local room = list.AbsoluteCanvasSize.Y - list.AbsoluteWindowSize.Y
		if room <= 0 or os.clock() - touched < Scroll.Idle then
			return
		end
		if wait > 0 then
			wait -= dt
			return
		end
		local y = math.clamp(list.CanvasPosition.Y + direction * Scroll.Speed * dt, 0, room)
		list.CanvasPosition = Vector2.new(0, y)
		if y <= 0 or y >= room then
			direction, wait = -direction, Scroll.Pause
		end
	end)
end

function LeaderboardController.Start()
	local root = workspace:WaitForChild("Leaderboards")
	for _, def in Config.Boards do
		task.spawn(attach, def, root:WaitForChild(def.Id))
	end
end

return LeaderboardController
