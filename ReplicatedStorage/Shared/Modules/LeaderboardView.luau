--[[
	LeaderboardView — fills one board's pre-built rows (Workspace.Leaderboards.<Id>.Board.Gui) from the entries the
	server publishes as the model's "Entries" attribute (JSON { { Id, Name, Value }, ... } best first).
	  LeaderboardView.Fill(gui, entries, config)   rows 1..#entries show, the rest hide; the empty hint shows with none
	Rows are built by tools/build_boards.lua (Rank, Head, PlayerName, Value, all pack 3D labels).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.LeaderboardConfig)
local NumberFormat = require(ReplicatedStorage.Shared.Modules.NumberFormat)

local LeaderboardView = {}

local function set(label: Instance, text: string)
	(label :: TextLabel).Text = text
	local top = label:FindFirstChild("Color")
	if top then
		(top :: TextLabel).Text = text
	end
end

-- Seconds as "3h 05m" / "42m" (the Time Played board).
function LeaderboardView.Time(seconds: number): string
	local minutes = math.floor(seconds / 60)
	return if minutes >= 60 then ("%dh %02dm"):format(minutes // 60, minutes % 60) else ("%dm"):format(minutes)
end

function LeaderboardView.Fill(gui: SurfaceGui, entries, board)
	local list = gui.Panel.List
	list.Empty.Visible = #entries == 0
	for index = 1, Config.Top do
		local row = list:FindFirstChild("Row" .. index)
		local entry = entries[index]
		if row then
			row.Visible = entry ~= nil
			if entry then
				set(row.PlayerName, entry.Name)
				set(row.Value, board.Value:format(if board.Time then LeaderboardView.Time(entry.Value) else NumberFormat.Abbreviate(entry.Value)))
				row.Head.Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(entry.Id)
				local accent = Config.Colors[index]
				row.Stroke.Color = accent or Color3.new(1, 1, 1)
				row.Stroke.Transparency = if accent then 0.1 else 0.65
			end
		end
	end
end

return LeaderboardView
