--[[
	HudExtrasController — the small HUD pieces around the pack components (HudConfig):
	  * the "N%" tag over the Rebirth button: level progress toward the rebirth level cap (100% = ready)
	  * the "Friend Boost +N%" row under the stats (BoostConfig.Friends; attribute FriendBoost) with a "+" that opens the
	    Roblox invite prompt
	  * the hand-built bottom bar's level products (StarterGui.Main.Bottom.Products.<5|10|25> -> ShopConfig Levels<N>): a click
	    buys (refused at the level cap: ShopConfig.Ui.MaxLevel) and each gets a small Robux price tag
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local BoostConfig = require(ReplicatedStorage.Shared.Config.BoostConfig)
local Config = require(ReplicatedStorage.Shared.Config.HudConfig)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local IconPick = require(ReplicatedStorage.Shared.Modules.IconPick)
local RebirthMath = require(ReplicatedStorage.Shared.Modules.RebirthMath)
local ShopMath = require(ReplicatedStorage.Shared.Modules.ShopMath)
local Ui = require(ReplicatedStorage.Shared.Modules.Ui)
local UiPack = require(ReplicatedStorage.Shared.Modules.UiPack)
local HudController = require(script.Parent.HudController)
local NotifyController = require(script.Parent.NotifyController)
local ShopController = require(script.Parent.ShopController)

local HudExtrasController = {}

local player = Players.LocalPlayer
local PRODUCTS = { ["5"] = "Levels5", ["10"] = "Levels10", ["25"] = "Levels25" }
local ORDER = { ["5"] = 1, ["10"] = 2, ["25"] = 3 }

local function label(parent: Instance, text: string, gradient: string, props): TextLabel
	local item = UiPack.Get("StatText")
	for key, value in props do
		item[key] = value
	end
	local top = item:FindFirstChild("Color") -- the pack label's gradient layer must share the alignment, or it drifts off its shadow
	if top and props.TextXAlignment then
		top.TextXAlignment = props.TextXAlignment
	end
	item.Parent = parent
	UiPack.Text(item, text)
	UiPack.TextGradient(item, gradient)
	return item
end

local function maxed(): boolean
	return (player:GetAttribute("Level") or 1) >= RebirthMath.MaxLevel(player:GetAttribute("Rebirths") or 0)
end

local function rebirthTag()
	while not HudController.Button("Rebirth") do
		task.wait() -- HudController builds it in its own Start
	end
	local button = HudController.Button("Rebirth")
	local tag = label(button, "0%", "White", { Name = "Percent", TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(0.7, 0.26), Position = UDim2.fromScale(0.5, -0.04),
		AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 20 })
	local function refresh()
		local share = (player:GetAttribute("Level") or 1) / RebirthMath.MaxLevel(player:GetAttribute("Rebirths") or 0)
		UiPack.Text(tag, math.floor(math.clamp(share, 0, 1) * 100) .. "%")
		UiPack.TextGradient(tag, if share >= 1 then "Green" else "White")
	end
	player:GetAttributeChangedSignal("Level"):Connect(refresh)
	player:GetAttributeChangedSignal("Rebirths"):Connect(refresh)
	refresh()
end

-- "Friend Boost +N%" with a bare "+" icon beside it (no box) that opens the Roblox invite prompt.
local function friendRow()
	local F = Config.Friend
	local group = HudController.Group("Stats")
	local props = table.clone(F.Box)
	props.Name, props.TextXAlignment, props.AnchorPoint = "FriendBoost", Enum.TextXAlignment.Left, Vector2.zero
	local text = label(group, "", "White", props)
	local plus = UiPack.Square({ Icon = IconPick.Image("Plus"), Text = "", Bare = true, OnClick = function()
		pcall(SocialService.PromptGameInvite, SocialService, player)
	end }, { Parent = group, Name = "Invite", Size = F.Plus.Size, Position = F.Plus.Position })
	Ui.Make("UIAspectRatioConstraint", { AspectRatio = 1, Parent = plus })
	local function refresh()
		UiPack.Text(text, BoostConfig.Text.Friend:format(math.floor((player:GetAttribute(BoostConfig.Friends.Attribute) or 0) * 100 + 0.5)))
	end
	player:GetAttributeChangedSignal(BoostConfig.Friends.Attribute):Connect(refresh)
	refresh()
end

local function levelProducts()
	local products = player:WaitForChild("PlayerGui"):WaitForChild("Main"):WaitForChild("Bottom"):WaitForChild("Products")
	local layout = products:FindFirstChildOfClass("UIListLayout")
	if layout then
		layout.SortOrder = Enum.SortOrder.LayoutOrder
	end
	for name, key in PRODUCTS do
		local button = products:WaitForChild(name) :: TextButton
		label(button, UiPack.Robux(ShopMath.Items[key].Def.Price), "Green", { Name = "Price", Size = UDim2.fromScale(0.36, 0.34),
			Position = UDim2.fromScale(0.97, 1.02), AnchorPoint = Vector2.new(1, 0.5), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 20 })
		UiPack.Clickable(button, function()
			if maxed() then
				NotifyController.Toast(ShopConfig.Ui.MaxLevel, "Error")
			else
				ShopController.Buy(key)
			end
		end)
		button.Parent.LayoutOrder = ORDER[name] -- Clickable wraps a list item in a slot frame: keep 5 / 10 / 25 in order
	end
end

function HudExtrasController.Start()
	task.spawn(rebirthTag)
	task.spawn(friendRow)
	task.spawn(levelProducts)
end

return HudExtrasController
