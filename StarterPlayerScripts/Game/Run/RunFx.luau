--[[
	RunFx — the juice of a run, all pooled so a busy server never creates instances per hit:
	  RunFx.Hit(frame, hit, area, owner)   dust + wood chips (sparks + flash on ramps), tinted by the area; for the OWNER
	                                       also the thud/boost sounds and the "+N" GainFly into the Speed label
	  RunFx.Break(position, color)          splinters, chunks, dust and a flash
	  RunFx.Popup(position, text, kind)     a "+N" billboard rising off a point (pool of Feel.Popup.Max)
	Effects are VFXConfig recipes (HitDust / RampBurst / BreakSplinters) on pooled anchor parts, fired with VFXKit.Fire.
	Camera shake / FOV kick belong to RunCamera; the caller decides who feels them.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local NumberFormat = require(ReplicatedStorage.Shared.Modules.NumberFormat)
local UiPack = require(ReplicatedStorage.Shared.Modules.UiPack)
local VFXKit = require(ReplicatedStorage.Shared.Modules.VFXKit)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)
local GainFly = require(script.Parent.GainFly)

local RunFx = {}

local P = Config.Feel.Popup
local pools: { [string]: { any } } = {}
local popups: { any } = {}
local folder: Folder

local function anchors(recipe: string, count: number)
	local list = { Next = 1 }
	for _ = 1, count do
		local part = Instance.new("Part")
		part.Name, part.Size, part.Transparency = recipe, Vector3.one, 1
		part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow = true, false, false, false, false
		VFXKit.Recipe(part, recipe)
		part.Parent = folder
		table.insert(list, part)
	end
	pools[recipe] = list
end

local function init()
	if folder then
		return
	end
	folder = Instance.new("Folder")
	folder.Name = "RunFx"
	folder.Parent = workspace
	anchors("HitDust", 8)
	anchors("RampBurst", 4)
	anchors("SuperBurst", 3)
	anchors("HyperBurst", 3)
	anchors("BreakSplinters", 4)
	for _ = 1, P.Max do
		local gui = Instance.new("BillboardGui")
		gui.Size, gui.AlwaysOnTop, gui.MaxDistance, gui.Enabled = UDim2.fromOffset(190, 80), true, 600, false
		gui.LightInfluence, gui.Parent = 0, folder
		local label = UiPack.Get("StatText")
		label.Size, label.Position, label.AnchorPoint = UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5)
		label.Parent = gui
		table.insert(popups, { Gui = gui, Label = label, Busy = false })
	end
end

local function fire(recipe: string, cf: CFrame, tint: Color3?, layers: { string }?)
	init()
	local pool = pools[recipe]
	local part = pool[pool.Next]
	pool.Next = pool.Next % (#pool) + 1
	part.CFrame = cf
	if tint then
		for _, name in layers or { "Dust" } do
			local emitter = part:FindFirstChild(name)
			if emitter then
				emitter.Color = ColorSequence.new(tint)
			end
		end
	end
	VFXKit.Fire(part)
end

function RunFx.Popup(position: Vector3, text: string, kind: string)
	init()
	local slot
	for _, p in popups do
		if not p.Busy then
			slot = p
			break
		end
	end
	if not slot then
		return
	end
	slot.Busy = true
	UiPack.Text(slot.Label, text)
	UiPack.TextGradient(slot.Label, kind)
	slot.Gui.Adornee = nil
	local anchor = Instance.new("Part")
	anchor.Size, anchor.Transparency, anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = Vector3.one, 1, true, false, false, false
	anchor.Position = position
	anchor.Parent = folder
	slot.Gui.Adornee, slot.Gui.StudsOffsetWorldSpace, slot.Gui.Enabled = anchor, Vector3.zero, true
	TweenService:Create(slot.Gui, TweenInfo.new(P.Time, Enum.EasingStyle.Quad), { StudsOffsetWorldSpace = Vector3.new(0, P.Rise, 0) }):Play()
	task.delay(P.Time, function()
		slot.Gui.Enabled, slot.Busy = false, false
		anchor:Destroy()
	end)
end

function RunFx.Hit(frame: CFrame, hit, areaColor: Color3, owner: boolean)
	local ramp = hit.Kind ~= "Bump"
	fire(if hit.Kind == "Hyper" then "HyperBurst" elseif hit.Kind == "Super" then "SuperBurst" elseif ramp then "RampBurst" else "HitDust", frame, areaColor:Lerp(Color3.new(1, 1, 1), 0.35))
	if owner then
		SoundController.Play(Config.SoundNames[if hit.Kind == "Hyper" then "Hyper" elseif hit.Kind == "Super" then "Super" elseif ramp then "Ramp" else "Impact"])
		SoundController.Play(Config.SoundNames.Boost)
		GainFly.Play("+" .. NumberFormat.Abbreviate(hit.Gain))
	end
end

function RunFx.Break(position: Vector3, color: Color3)
	fire("BreakSplinters", CFrame.new(position), color, { "Splinters", "Chunks" })
end

return RunFx
