--[[
	PackViews/ShopCards — fills one of the pack's shop cards (UiPack.Card) from a resolved card view
	(ShopUiConfig.Cards entry + live data, see ShopController.CardView). No game logic: a preview can feed it.
	  ShopCards.new(parent, order, view, onBuy(key), group, fill?) -> entry   (fill = fill a shop row slot)
	      entry.Card, entry.Art (celebration source), entry.Buys = { [ShopMath key] = price button }, entry.Desc
	  ShopCards.SetOwned(entry, key, owned)   grey "OWNED" button (passes, one-time offers)
	  ShopCards.SetOdds(entry, odds)          Offer cards: { { Chance = "70%", Name, Art } } into the odds row
	  entry.Refresh()                         Pack cards: redraw the amount (view.Amount() -> text)
	  ShopCards.SetPrice(entry, key, robux)   re-labels a price button (the Mega pack after its first-time discount)
	  ShopCards.OnGift = fn(key)              set by the controller: every giftable key (ShopMath.GiftOf) gets a purple gift
	                                          button left of its price button that calls it
	  ShopCards.OnRedeem = fn(code)           set by the controller: the Codes card's Redeem
	Offer cards take any number of Buttons (the pack card has two slots; more are cloned from the first).
	view: Id, Card ("Starter" | "Offer" | "Wide" | "Half" | "Pack"), Key, Color (nil = the pack card's own), Art, Title, Name,
	      Tag, TagColor (UiPackConfig.Text), Desc, From, To (short: the Wide card's "x1 -> x2" row),
	      Price (Robux), Old (crossed-out price), Value, Lines = { { Amount, Name, Art } },
	      Buttons = { { Key, Text, Color, Price, Old? } } (Offer);
	      Pack (the Steal Treasure cash tile): Image, ImageScale?, ImageY?, Span?, Amount = () -> text
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.ShopUiConfig)
local PackConfig = require(ReplicatedStorage.Shared.Config.UiPackConfig)
local ShopMath = require(ReplicatedStorage.Shared.Modules.ShopMath)
local Ui = require(ReplicatedStorage.Shared.Modules.Ui)
local UiPack = require(ReplicatedStorage.Shared.Modules.UiPack)

local ShopCards = {}

local Art = UiPack.Art

local function art(card: Frame, spec, group)
	local holder = Art.Replace(card.Icon, spec, group)
	card.ImageBg.Visible = spec.Image ~= nil
	card.ImageBg.Image = spec.Image or ""
	return holder
end

-- The purple gift square, the price button's height, just left of it (inside the card).
local function gift(button: GuiButton, key: string)
	if not ShopMath.GiftOf(key) then
		return
	end
	local G = Config.Gift
	local square = UiPack.Square({ Color = G.Color, Icon = PackConfig.Icons.Gift, Text = "", Bare = true, OnClick = function()
		ShopCards.OnGift(key)
	end }, { Name = "Gift", SizeConstraint = Enum.SizeConstraint.RelativeYY, Size = UDim2.fromScale(G.Size, G.Size),
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.04, 0.02), ZIndex = button.ZIndex + 2, Parent = button })
	return square
end

-- The small red crossed-out price on a button's top-right corner: only the Starter card's button has one, so any other button
-- that shows a discount borrows a copy of it.
local function oldPriceLabel(face: Instance): Instance?
	local strike = face:FindFirstChild("OldPrice")
	if not strike then
		local template = UiPack.Get("Card.Starter")
		strike = template.Buy.Container.OldPrice:Clone()
		strike.Parent = face
		template:Destroy()
	end
	return strike
end

local function price(entry, button: GuiButton, key: string, robux: number, old: number?, onBuy)
	UiPack.SetText(button, UiPack.Robux(robux))
	local face = UiPack.Face(button)
	local strike = if old then oldPriceLabel(face) else face:FindFirstChild("OldPrice")
	if strike then
		strike.Visible = old ~= nil
		UiPack.Text(strike, UiPack.Robux(old or 0))
	end
	UiPack.Clickable(button, function()
		onBuy(key)
	end)
	gift(button, key)
	entry.Buys[key] = button
end

function ShopCards.SetPrice(entry, key: string, robux: number)
	UiPack.SetText(entry.Buys[key], UiPack.Robux(robux))
	local strike = UiPack.Face(entry.Buys[key]):FindFirstChild("OldPrice")
	if strike then
		strike.Visible = false
	end
end

local function half(entry, card, view, onBuy)
	card.Title.Text = view.Title
	card.Desc.Text = view.Desc or ""
	entry.Desc = card.Desc
	price(entry, card.Button.Buy, view.Key, view.Price, nil, onBuy)
end

local rainbows = setmetatable({}, { __mode = "k" }) -- UIGradient -> true, hue-shifted every frame by ONE Heartbeat connection
local function rainbowText(label: TextLabel)
	local gradient = Instance.new("UIGradient")
	label.TextColor3, gradient.Parent = Color3.new(1, 1, 1), label
	rainbows[gradient] = true
	if not ShopCards.Spin then
		ShopCards.Spin = game:GetService("RunService").Heartbeat:Connect(function()
			local shift, keys = os.clock() * 0.4 % 1, {}
			for i = 0, 6 do
				table.insert(keys, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV((shift + i / 6) % 1, 0.75, 1)))
			end
			local sequence = ColorSequence.new(keys)
			for g in rainbows do
				g.Color = sequence
			end
		end)
	end
end

-- Wide card zones (share of the card): art left (x .02-.30), title across the top, the multiplier row centred in the band right of
-- the art (y .22-.60), the description under it beside the price button (x .31-.72, y .62-.95), price button bottom-right.
local function layoutWide(card)
	local row, desc = card.Multiplier, card.Desc
	row.Position, row.Size = UDim2.fromScale(0.31, 0.22), UDim2.fromScale(0.66, 0.38)
	row:FindFirstChildOfClass("UIListLayout").HorizontalAlignment = Enum.HorizontalAlignment.Center
	desc.AnchorPoint, desc.Position, desc.Size = Vector2.zero, UDim2.fromScale(0.31, 0.63), UDim2.fromScale(0.41, 0.32)
	desc.TextXAlignment, desc.TextYAlignment = Enum.TextXAlignment.Center, Enum.TextYAlignment.Center
end

local function wide(entry, card, view, onBuy)
	card.Title.Text = view.Title
	card.Desc.Text = view.Desc or ""
	entry.Desc = if view.Rainbow then nil else card.Desc -- a rainbow card keeps its own description (no live "+1M Wins" note over it)
	layoutWide(card)
	local row, line = card.Multiplier, card.Multiplier["1"]
	if view.Rainbow or view.Row then -- no arrow: one small rainbow line ("50x SPEED") or a row of icon + amount
		row["-"].Visible, row["2"].Visible = false, false
		if view.Rainbow then
			line.Size, line.Text = UDim2.fromScale(1, 1), view.From .. " " .. view.To
			rainbowText(line)
			rainbowText(card.Desc)
		else
			line.Visible = false
			for i, item in view.Row do
				local amount = line:Clone()
				amount.Visible, amount.Text, amount.Size, amount.LayoutOrder = true, item.Text, UDim2.fromScale(0.2, 0.7), i * 2
				amount.Parent = row
				Ui.Make("ImageLabel", { Image = item.Image, BackgroundTransparency = 1, SizeConstraint = Enum.SizeConstraint.RelativeYY,
					Size = UDim2.fromScale(0.95, 0.95), ScaleType = Enum.ScaleType.Fit, LayoutOrder = i * 2 - 1, ZIndex = 26, Parent = row })
			end
		end
		price(entry, card.Buttons.Buy, view.Key, view.Price, view.Old, onBuy)
		return
	end
	card.Multiplier["1"].Text, card.Multiplier["2"].Text = view.From, view.To
	price(entry, card.Buttons.Buy, view.Key, view.Price, view.Old, onBuy)
end

local function starter(entry, card, view, onBuy)
	card.Title.Text, card.CrateName.Text, card.Type.Text, card.Value.Text = view.Title, view.Name, view.Tag, view.Value
	UiPack.TextGradient(card.Type, view.TagColor)
	card.Value.Position -= UDim2.fromScale(0, 0.04) -- the "N% OFF!" line sits a touch higher
	local frames = {}
	for _, child in card.Show:GetChildren() do
		if child:IsA("Frame") then
			table.insert(frames, child)
		end
	end
	for i, frame in frames do
		local line = view.Lines[i]
		frame.Visible, frame.LayoutOrder = line ~= nil, i
		if line then
			frame.Amount.Text, frame["Time/Name"].Text = line.Amount, line.Name
			Art.Replace(frame.Icon, line.Art, entry.Group)
		end
	end
	price(entry, card.Buy, view.Key, view.Price, view.Old, onBuy)
end

local function offer(entry, card, view, onBuy)
	card.Title.Text, card.CrateName.Text, card.Type.Text = view.Title, view.Name, view.Tag
	local slots = { card.Buttons["3"], card.Buttons["1"] }
	for i = #slots + 1, #view.Buttons do
		slots[i] = slots[1]:Clone()
		slots[i].Name, slots[i].Parent = tostring(i), card.Buttons
	end
	local layout = card.Buttons:FindFirstChildOfClass("UIListLayout")
	if layout and #slots > 2 then
		for _, button in slots do
			button.Size = UDim2.fromScale(button.Size.X.Scale * 2 / #slots, button.Size.Y.Scale)
		end
	end
	for i, button in slots do
		local def = view.Buttons[i]
		UiPack.Paint(button, def.Color)
		button.LayoutOrder = i
		UiPack.Face(button).Text.Text = def.Text
		price(entry, button, def.Key, def.Price, def.Old, onBuy)
	end
	entry.Odds = {}
	for _, child in card.Chances:GetChildren() do
		if child:IsA("Frame") then
			table.insert(entry.Odds, child)
		end
	end
end

-- The Steal Treasure cash tile: the X2Money card's starburst with big pack art up top, the amount under it, and
-- its price button stretched along the bottom (no icon / description).
local function pack(entry, card, view, onBuy)
	for _, name in { "Icon", "ImageBg", "Desc" } do
		local child = card:FindFirstChild(name)
		if child then
			child.Visible = false
		end
	end
	for _, sparkle in card:GetChildren() do
		if sparkle.Name == "Effect" and sparkle:IsA("ImageLabel") then
			sparkle.AnchorPoint, sparkle.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.33)
			sparkle.SizeConstraint, sparkle.Size = Enum.SizeConstraint.RelativeYY, UDim2.fromScale(0.85, 0.85)
		end
	end
	local scale = view.ImageScale or 1
	local image = Instance.new("ImageLabel")
	image.Name, image.Image, image.BackgroundTransparency, image.ScaleType = "PackArt", view.Image, 1, Enum.ScaleType.Fit
	image.AnchorPoint, image.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, view.ImageY or 0.34)
	image.Size, image.ZIndex = UDim2.fromScale(scale, 0.74 * scale), 20
	image.Parent = card
	entry.Art = image
	card.Title.RichText, card.Title.TextXAlignment = true, Enum.TextXAlignment.Center
	card.Title.AnchorPoint, card.Title.Position, card.Title.Size = Vector2.zero, UDim2.fromScale(0.04, 0.6), UDim2.fromScale(0.92, 0.17)
	local buttons = card.Button
	buttons.AnchorPoint, buttons.Position, buttons.Size = Vector2.zero, UDim2.fromScale(0.04, 0.79), UDim2.fromScale(0.92, 0.18)
	price(entry, buttons.Buy, view.Key, view.Price, nil, onBuy)
	entry.Refresh = function()
		card.Title.Text = view.Amount()
	end
	entry.Refresh()
end

-- The code box on the Wide shell: a title line, a TextBox in a dark well and a green Redeem button.
local function codes(entry, card, _, _)
	for _, child in card:GetChildren() do
		if child:IsA("GuiObject") and child.Name ~= "Title" then
			child.Visible = false
		end
	end
	local T = Config.Texts.Codes
	card.Title.Text, card.Title.TextXAlignment = T.Title, Enum.TextXAlignment.Center
	card.Title.AnchorPoint, card.Title.Position, card.Title.Size = Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0.08), UDim2.fromScale(0.92, 0.32)
	local well = UiPack.Get("Bar")
	well.Progress:Destroy()
	well.Name, well.AnchorPoint, well.Position, well.Size, well.Parent = "Box", Vector2.new(0, 0.5), UDim2.fromScale(0.04, 0.68), UDim2.fromScale(0.6, 0.34), card
	local box = Ui.Make("TextBox", { Name = "Input", PlaceholderText = T.Hint, Text = "", ClearTextOnFocus = false, BackgroundTransparency = 1,
		TextScaled = true, TextColor3 = Color3.new(1, 1, 1), PlaceholderColor3 = Color3.fromRGB(190, 200, 220), FontFace = PackConfig.Font,
		TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromScale(0.92, 0.7), Position = UDim2.fromScale(0.04, 0.15), ZIndex = 8, Parent = well })
	UiPack.Button("Green", T.Button, function()
		ShopCards.OnRedeem(box.Text)
		box.Text = ""
	end, { Name = "Redeem", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(0.96, 0.68), Size = UDim2.fromScale(0.3, 0.38), Parent = card })
	entry.Box = box
end

local BUILD = { Half = half, Wide = wide, Starter = starter, Offer = offer, Pack = pack, Codes = codes }
local BASE = { Codes = "Wide" } -- game cards built on a pack card's shell

function ShopCards.new(parent: Instance, order: number, view, onBuy, group: any, fill: boolean?)
	local card = UiPack.Card(BASE[view.Card] or view.Card, { Parent = parent, Name = view.Id, LayoutOrder = order })
	if fill then -- fills its slot: the shop row decides the shape
		card.Size, card.Position, card.AnchorPoint = UDim2.fromScale(1, 1), UDim2.new(), Vector2.zero
		local aspect = card:FindFirstChildOfClass("UIAspectRatioConstraint")
		if aspect then
			aspect:Destroy()
		end
	end
	if view.Color then
		UiPack.Paint(card, view.Color)
	end
	local entry = { Card = card, Buys = {}, Group = group }
	if view.Art then
		entry.Art = art(card, view.Art, group)
	end
	BUILD[view.Card](entry, card, view, onBuy)
	return entry
end

function ShopCards.SetOwned(entry, key: string, owned: boolean)
	local button = entry.Buys[key]
	if owned then
		UiPack.Paint(button, "Gray")
		UiPack.SetText(button, Config.Texts.Owned)
	end
	button.Active = not owned
end

function ShopCards.SetOdds(entry, odds)
	for i, cell in entry.Odds do
		local row = odds[i]
		cell.Visible, cell.LayoutOrder = row ~= nil, i
		if row then
			cell.Chance.Text, cell.ItemName.Text = row.Chance, row.Name
			local old = cell:FindFirstChild("IconArt")
			if old then
				old:Destroy()
			end
			Art.Replace(cell.Icon, row.Art, entry.Group)
		end
	end
end

return ShopCards
