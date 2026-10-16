--[[
	UiPack/Celebrate — the "you got it!" moment after a purchase or a reward claim, drawn over everything in
	a window's root: a spinning sunburst flash at the item, a confetti blast, and the item's icons bursting
	out and arcing into a HUD gui (its stat), popping it on arrival. Numbers: UiPackConfig.Celebrate.
	  Celebrate.Play(root, { From = gui?, Images = { image }, Target = gui?, OnArrive = fn?, Confetti = bool? })
	      From nil = screen centre; Target nil = the icons float up and fade instead.
]]
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.UiPackConfig)
local Ui = require(ReplicatedStorage.Shared.Modules.Ui)

local Celebrate = {}

local C = Config.Celebrate
local Z = 300

local function inset(gui: GuiBase2d): Vector2
	local screen = gui:FindFirstAncestorWhichIsA("ScreenGui") or gui
	return if screen:IsA("ScreenGui") and not screen.IgnoreGuiInset then GuiService:GetGuiInset() else Vector2.zero
end

-- gui's centre in root's pixel space (the two may sit in ScreenGuis with different inset rules).
local function centre(root: GuiBase2d, gui: GuiBase2d): Vector2
	return gui.AbsolutePosition + gui.AbsoluteSize / 2 + inset(gui) - root.AbsolutePosition - inset(root)
end

local function over(time: number, fn)
	local t = 0
	while t < time do
		fn(t / time)
		t += RunService.Heartbeat:Wait()
	end
	fn(1)
end

local function flash(layer: Frame, at: Vector2, k: number)
	local rays = Ui.Make("ImageLabel", { Image = Config.Icons.Rays, ImageColor3 = Color3.fromRGB(255, 240, 150), BackgroundTransparency = 1,
		ImageTransparency = 0.05, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(0, 0), Position = UDim2.fromOffset(at.X, at.Y), ZIndex = Z, Parent = layer })
	Ui.Tween(rays, C.BurstTime, { Rotation = 90 })
	Ui.Tween(rays, C.BurstTime * 0.35, { Size = UDim2.fromOffset(C.BurstSize * k, C.BurstSize * k) }, Enum.EasingStyle.Back)
	Ui.Tween(rays, C.BurstTime, { ImageTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
end

local function confetti(layer: Frame, at: Vector2, k: number)
	local bits = {}
	for i = 1, C.Confetti do
		local angle = math.rad(math.random(-150, -30))
		local speed = math.random(C.Speed[1], C.Speed[2]) * k
		bits[i] = { Gui = Ui.Make("Frame", { Size = UDim2.fromOffset(math.random(8, 14) * k, math.random(14, 22) * k), AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = C.Colors[math.random(#C.Colors)], BorderSizePixel = 0, ZIndex = Z + 1, Parent = layer }),
			P = at, V = Vector2.new(math.cos(angle), math.sin(angle)) * speed, R = math.random(-600, 600), Phase = math.random() * 6 }
	end
	local last = 0
	over(C.ConfettiTime, function(a)
		local dt = a * C.ConfettiTime - last
		last = a * C.ConfettiTime
		for _, bit in bits do
			bit.V = Vector2.new(bit.V.X * (1 - 1.6 * dt), bit.V.Y + C.Gravity * k * dt)
			bit.P += bit.V * dt + Vector2.new(math.sin(last * 7 + bit.Phase) * 40 * k * dt, 0)
			bit.Gui.Position = UDim2.fromOffset(bit.P.X, bit.P.Y)
			bit.Gui.Rotation += bit.R * dt
			bit.Gui.BackgroundTransparency = math.max(0, (a - 0.7) / 0.3)
		end
	end)
end

local function flyer(layer: Frame, root: GuiBase2d, image: string, at: Vector2, i: number, opts, k: number)
	local size = C.FlyerSize * k
	local icon = Ui.Make("ImageLabel", { Image = image, BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size), Position = UDim2.fromOffset(at.X, at.Y), Rotation = math.random(-25, 25), ZIndex = Z + 2, Parent = layer })
	Ui.Pop(icon, 0.2)
	local spot = at + Vector2.new(math.random(-100, 100), math.random(-100, 60)).Unit * C.Spread * k * (0.5 + math.random() * 0.5)
	Ui.Tween(icon, 0.3, { Position = UDim2.fromOffset(spot.X, spot.Y) }, Enum.EasingStyle.Back)
	task.wait(C.Hold + i * 0.05)
	if opts.Target and opts.Target.Parent then
		local arc = (spot + centre(root, opts.Target)) / 2 + Vector2.new(0, -180 * k)
		over(C.FlyTime, function(a)
			local goal = centre(root, opts.Target)
			local e = a * a
			local p = spot:Lerp(arc, e):Lerp(arc:Lerp(goal, e), e)
			icon.Position = UDim2.fromOffset(p.X, p.Y)
			icon.Size = UDim2.fromOffset(size * (1 - 0.5 * a), size * (1 - 0.5 * a))
		end)
		if opts.OnArrive then
			opts.OnArrive(i)
		end
		Ui.Pop(opts.Target, 0.82)
	else
		Ui.Tween(icon, C.FlyTime, { Position = UDim2.fromOffset(spot.X, spot.Y - 160 * k), ImageTransparency = 1 })
		task.wait(C.FlyTime)
	end
	icon:Destroy()
end

function Celebrate.Play(root: GuiBase2d, opts)
	local layer = Ui.Make("Frame", { Name = "Celebrate", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = Z, Parent = root })
	local k = math.clamp(root.AbsoluteSize.Y / 720, 0.6, 1.6)
	local at = if opts.From and opts.From.Parent then centre(root, opts.From) else root.AbsoluteSize / 2
	flash(layer, at, k)
	if opts.Confetti ~= false then
		task.spawn(confetti, layer, at, k)
	end
	local images = opts.Images or {}
	for i = 1, if #images > 0 then C.Flyers else 0 do
		task.spawn(flyer, layer, root, images[(i - 1) % #images + 1], at, i, opts, k)
	end
	task.delay(math.max(C.ConfettiTime, C.Hold + C.Flyers * 0.05 + C.FlyTime) + 0.3, layer.Destroy, layer)
end

return Celebrate
