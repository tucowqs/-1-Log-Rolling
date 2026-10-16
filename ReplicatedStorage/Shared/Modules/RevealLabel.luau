--[[
	RevealLabel — the floating multi-line label over an item being revealed (a chest pull, a hatch, a
	craft result). Every line is its own TextScaled row in the kit font with a black stroke:
	  { Text = "Siren's Harp" }                              plain white
	  { Text = "LEGENDARY  NEW!", Rarity = "Legendary" }     the rarity gradient (RarityText, may shimmer)
	  { Text = "", Paint = function(label) ... end }         anything else (a modifier's own gradient)
	Height = the line's share of UIConfig.RevealLabel.Size.Y (default: UIConfig.RevealLabel.Lines by
	line number, the last repeating), so the box grows a little for each extra line.
		RevealLabel.Make(anchorPart, lines) -> BillboardGui (parented to the anchor)
]]
local UIConfig = require(script.Parent.Parent.Config.UIConfig)
local RarityText = require(script.Parent.RarityText)

local RevealLabel = {}

local Config = UIConfig.RevealLabel

function RevealLabel.Make(anchor: BasePart, lines): BillboardGui
	local total = 0
	for index, line in lines do
		line.Height = line.Height or Config.Lines[math.min(index, #Config.Lines)]
		total += line.Height
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(Config.Size.X, Config.Size.Y * total)
	gui.StudsOffsetWorldSpace = Vector3.new(0, Config.Lift, 0)
	gui.LightInfluence, gui.AlwaysOnTop, gui.MaxDistance = 0, true, Config.MaxDistance
	local y = 0
	for _, line in lines do
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, line.Height / total)
		text.Position = UDim2.fromScale(0, y / total)
		text.FontFace, text.TextScaled, text.Text = UIConfig.Fonts.Title, true, line.Text
		text.TextColor3 = line.Color or Color3.new(1, 1, 1)
		local stroke = Instance.new("UIStroke")
		stroke.Color, stroke.Thickness = UIConfig.TextStrokeColor, UIConfig.TextStroke
		stroke.Parent = text
		if line.Rarity then
			RarityText.Apply(text, line.Rarity)
		elseif line.Paint then
			line.Paint(text)
		end
		text.Parent = gui
		y += line.Height
	end
	gui.Adornee = anchor
	gui.Parent = anchor
	return gui
end

return RevealLabel
