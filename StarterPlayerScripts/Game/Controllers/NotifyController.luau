--[[
	NotifyController — every notification, in one look (NotifyConfig): big white bold rich text with a
	scaled black stroke, no background, stacked from the top of the screen, newest on top, each growing in
	and shrinking away. Never build a one-off banner or toast panel: call this.
	  NotifyController.Toast(text, kind?, sticky?, header?) -> toast   kind picks the sound (and Em colour)
	      sticky = stays until Dismiss (e.g. the tutorial's current task), pinned at the top of the stack;
	      header = a big title over it ("TUTORIAL:"). The message label is toast.Text (update it live).
	  NotifyController.Dismiss(toast)
	  NotifyController.Em(word, kind)   rich-text emphasis (Shared.Modules.Emphasis)
	The server's "Notify" { Text, Kind } and server-wide "Announcement" { Text } bridges become toasts too.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local N = require(ReplicatedStorage.Shared.Config.NotifyConfig)
local Emphasis = require(ReplicatedStorage.Shared.Modules.Emphasis)
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Ui = require(ReplicatedStorage.Shared.Modules.Ui)
local LoadingController = require(script.Parent.LoadingController)
local SoundController = require(script.Parent.SoundController)

local NotifyController = {}

NotifyController.Em = Emphasis.Em

local template: TextLabel
local scale = 1 -- template size -> design px
local stack: Frame
local count = 0

-- The hand-designed template if NotifyConfig.Template names one, else the same look built in code.
local function makeTemplate(): TextLabel
	if N.Template then
		local node: Instance = Players.LocalPlayer:WaitForChild("PlayerGui")
		for _, name in N.Template do
			node = node:WaitForChild(name)
		end
		local parent = node.Parent :: GuiObject
		if parent:IsA("GuiObject") then
			parent.Visible = false -- it only holds the template
		end
		scale = N.TemplateScale
		return node :: TextLabel
	end
	local L = N.Label
	local label = Ui.Make("TextLabel", {
		Name = "Template", Size = UDim2.fromOffset(L.Size.X, L.Size.Y), BackgroundTransparency = 1, TextScaled = true,
		RichText = true, FontFace = L.Font, TextColor3 = L.Color, Visible = false,
	})
	Ui.Make("UIStroke", { Thickness = L.Stroke, StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize, Parent = label })
	return label
end

-- Shrink it away (and close its slot so the ones below slide up), then remove it.
local function dismiss(toast: Frame)
	if toast:GetAttribute("Leaving") then
		return
	end
	toast:SetAttribute("Leaving", true)
	Ui.Tween(toast:FindFirstChild("Grow"), N.Shrink, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	Ui.Tween(toast, N.Shrink, { Size = UDim2.fromOffset(toast.Size.X.Offset, 0) }).Completed:Wait()
	toast:Destroy()
end

local function label(text: string, size: UDim2, color: Color3?): TextLabel
	local copy = template:Clone()
	copy.Text, copy.RichText, copy.Visible, copy.Size = text, true, true, size
	copy.TextColor3 = color or copy.TextColor3
	return copy
end

-- Keeps at most N.Max timed toasts: the oldest beyond that shrink away.
local function trim()
	local live = {}
	for _, child in stack:GetChildren() do
		if child:IsA("Frame") and not child:GetAttribute("Leaving") and not child:GetAttribute("Sticky") then
			table.insert(live, child)
		end
	end
	table.sort(live, function(a, b)
		return a.LayoutOrder > b.LayoutOrder -- oldest first
	end)
	for i = 1, #live - N.Max do
		task.spawn(dismiss, live[i])
	end
end

function NotifyController.Toast(text: string, kind: string?, sticky: boolean?, header: string?)
	if not stack then
		return nil
	end
	count += 1
	local width, height = template.Size.X.Offset * scale, template.Size.Y.Offset * scale
	local H = N.Header
	local top = header and height * H.Height or 0
	-- A slot in the list holds the labels, so they scale about the centre while the slot keeps its place.
	local toast = Ui.Make("Frame", { Name = "Toast", Size = UDim2.fromOffset(width, height + top), BackgroundTransparency = 1,
		LayoutOrder = sticky and -1e6 or -count, Parent = stack })
	if header then
		local title = label(header, UDim2.fromScale(H.Width, top / (height + top)), H.Color)
		title.Name, title.Position, title.AnchorPoint = "Header", UDim2.fromScale(0.5, 0), Vector2.new(0.5, 0)
		title.Parent = toast
	end
	local body = label(text, UDim2.fromScale(1, height / (height + top)))
	body.Name, body.Position, body.AnchorPoint = "Text", UDim2.fromScale(0.5, 1), Vector2.new(0.5, 1)
	body.Parent = toast
	local grow = Ui.Make("UIScale", { Name = "Grow", Scale = 0, Parent = toast })
	if sticky then
		toast:SetAttribute("Sticky", true) -- never timed out, never pushed off by newer toasts
	end
	-- Held back (hidden at scale 0) until the loading screen is gone, then it grows in with its sound and timer.
	LoadingController.WhenDone(function()
		if not toast.Parent or toast:GetAttribute("Leaving") then
			return
		end
		Ui.Tween(grow, N.Grow, { Scale = 1 }, Enum.EasingStyle.Back)
		SoundController.Play(N.Sounds[kind or "Info"] or N.Sounds.Info)
		trim()
		if not sticky then
			task.delay(N.Duration, function()
				if toast.Parent then
					dismiss(toast)
				end
			end)
		end
	end)
	return toast
end

function NotifyController.Dismiss(toast: Frame?)
	if toast and toast.Parent then
		task.spawn(dismiss, toast)
	end
end

function NotifyController.Start()
	Net.Get("Notify"):Connect(function(payload)
		NotifyController.Toast(payload.Text, payload.Kind)
	end)
	Net.Get("Announcement"):Connect(function(payload)
		NotifyController.Toast(payload.Text, "Announcement")
	end)
	template = makeTemplate()
	local screen = Ui.Screen("Notify", N.DisplayOrder)
	-- Holder (top-centre of the stack at N.At, a share of the screen) in design pixels (Fit scales it to the device).
	local holder = Ui.Make("Frame", { Size = UDim2.fromOffset(N.Holder.X, N.Holder.Y), Position = UDim2.fromScale(N.At.X, N.At.Y),
		AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Parent = screen })
	Ui.Fit(holder)
	stack = Ui.Make("Frame", { Size = UDim2.new(1, 0, 1, -N.Top), Position = UDim2.fromOffset(0, N.Top), BackgroundTransparency = 1, Parent = holder })
	Ui.List(stack, { Padding = UDim.new(0, N.Gap), HorizontalAlignment = Enum.HorizontalAlignment.Center })
end

return NotifyController
