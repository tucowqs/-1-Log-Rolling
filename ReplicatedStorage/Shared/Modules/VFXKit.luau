--[[
	VFXKit — builds effects from compact data specs, so an effect lives in a config table (the VFX Lab
	recipes, distilled in roblox-craft references/vfx.md; textures / fades / recipes in VFXConfig). One kit for the
	edit-time appliers and the game (the Lab's vfxkit.lua and Steal Treasure's port, merged).
		VFXKit.Emitter(parent, { Tex = "sparkle", Rate = 40, Life = { 2, 3 }, Size = { { 0, 0 }, { 0.5, 1.6 }, { 1, 0 } },
			Fade = "dip", Color = Color3.new(1, .8, .3), Speed = 0.5, Accel = Vector3.new(0, -1, 0) })
		VFXKit.Beam(a0, a1, { Tex = "beamSmoke", Width = { 30, 20 }, Speed = 0.1, ... })
		VFXKit.Ring(part, cframe, radius, beamSpec)   -- two mirrored curved beams = a flat circle
		VFXKit.Recipe(parent, "Sparkles", overrides?) -- every layer of a VFXConfig recipe
		VFXKit.Fire(root)                             -- Emit every burst emitter (EmitCount / EmitDelay attributes)
		VFXKit.InstantOn(root) / InstantOff(root)     -- show / hide a steady effect with no swell or hang
	Emitter spec keys: Name, Tex (a VFXConfig.Tex name or an asset id), Rate, Life, Size, Fade (a
	VFXConfig.Fades name or keys), Color (Color3 / { {t, Color3} } / { Color3, ... } spread evenly), LE
	(LightEmission, default 1), LI (LightInfluence, default 0), Bright, Speed, Spread (n or {x, y}), Rot,
	Spin, Drag, Accel, Orient, Dir, Squash, Z, Locked, Inherit, TimeScale, Enabled,
	Shape = { "Sphere", "Surface", "Inward", partial }, Flip / FlipMode / FlipRate / FlipRandom,
	Emit = { count, delay? } (a burst: Rate 0, attributes EmitCount / EmitDelay, fired by Fire).
	Beam spec keys: Name, Tex, Mode, Length, Speed, Width {w0, w1}, Curve {c0, c1}, Segments,
	FaceCamera, LE, LI, Bright, Color, Fade, Z, Parent.
]]
local Config = require(script.Parent.Parent.Config.VFXConfig)

local VFXKit = {}

VFXKit.Tex = Config.Tex

local FLIP = {}
for name, layout in Config.Flipbooks do
	FLIP[Config.Tex[name]] = layout
end

local WHITE = Color3.new(1, 1, 1)

local function tex(t): string
	return t and (Config.Tex[t] or t) or ""
end

local function range(v): NumberRange
	if typeof(v) == "table" then
		return NumberRange.new(v[1], v[2])
	end
	return NumberRange.new(v or 0)
end

-- number | { {t, v, envelope?}, ... } -> NumberSequence
function VFXKit.NSeq(v): NumberSequence
	if typeof(v) == "NumberSequence" then
		return v
	elseif typeof(v) ~= "table" then
		return NumberSequence.new(v or 0)
	end
	local keys = {}
	for _, k in v do
		table.insert(keys, NumberSequenceKeypoint.new(k[1], k[2], k[3] or 0))
	end
	return NumberSequence.new(keys)
end

-- Color3 | { {t, Color3}, ... } | { Color3, Color3, ... } (spread evenly) -> ColorSequence
function VFXKit.CSeq(v): ColorSequence
	if typeof(v) == "ColorSequence" then
		return v
	elseif typeof(v) == "Color3" then
		return ColorSequence.new(v)
	end
	local keys = {}
	for i, k in v do
		if typeof(k) == "Color3" then
			table.insert(keys, ColorSequenceKeypoint.new(#v == 1 and 0 or (i - 1) / (#v - 1), k))
		else
			table.insert(keys, ColorSequenceKeypoint.new(k[1], k[2]))
		end
	end
	if #keys == 1 then
		return ColorSequence.new(keys[1].Value)
	end
	return ColorSequence.new(keys)
end

function VFXKit.Fade(name)
	return VFXKit.NSeq(Config.Fades[name] or name or 0)
end

function VFXKit.Emitter(parent: Instance, s): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = s.Name or "Emitter"
	e.Texture = tex(s.Tex)
	e.LightEmission = s.LE or 1
	e.LightInfluence = s.LI or 0
	e.Brightness = s.Bright or 1
	e.Color = VFXKit.CSeq(s.Color or WHITE)
	e.Size = VFXKit.NSeq(s.Size or 1)
	e.Transparency = VFXKit.Fade(s.Fade)
	e.Squash = VFXKit.NSeq(s.Squash or 0)
	e.Lifetime = range(s.Life or 1)
	e.Rate = s.Emit and 0 or (s.Rate or 0)
	e.Speed = range(s.Speed or 0.001) -- 0.001: velocity-oriented particles still resolve a direction
	local spread = s.Spread or 0
	e.SpreadAngle = typeof(spread) == "table" and Vector2.new(spread[1], spread[2]) or Vector2.new(spread, spread)
	e.Rotation = range(s.Rot or { -360, 360 })
	e.RotSpeed = range(s.Spin or 0)
	e.Drag = s.Drag or 0
	e.Acceleration = s.Accel or Vector3.zero
	e.Orientation = Enum.ParticleOrientation[s.Orient or "FacingCamera"]
	e.EmissionDirection = Enum.NormalId[s.Dir or "Top"]
	e.ZOffset = s.Z or 0
	e.LockedToPart = s.Locked == true
	e.VelocityInheritance = s.Inherit or 0
	e.TimeScale = s.TimeScale or 1
	if s.Shape then
		e.Shape = Enum.ParticleEmitterShape[s.Shape[1]]
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle[s.Shape[2] or "Volume"]
		e.ShapeInOut = Enum.ParticleEmitterShapeInOut[s.Shape[3] or "Outward"]
		e.ShapePartial = s.Shape[4] or 1
	end
	local flip = s.Flip or FLIP[e.Texture]
	if flip then
		e.FlipbookLayout = Enum.ParticleFlipbookLayout[flip]
		e.FlipbookMode = Enum.ParticleFlipbookMode[s.FlipMode or "OneShot"]
		if s.FlipRate then
			e.FlipbookFramerate = range(s.FlipRate)
		end
		e.FlipbookStartRandom = s.FlipRandom == true
	end
	if s.Emit then
		e:SetAttribute("EmitCount", s.Emit[1])
		e:SetAttribute("EmitDelay", s.Emit[2] or 0)
	end
	e.Enabled = s.Enabled ~= false
	e.Parent = parent
	return e
end

function VFXKit.Attachment(parent: Instance, offset, name: string?): Attachment
	local a = Instance.new("Attachment")
	a.Name = name or "Attachment"
	a.CFrame = typeof(offset) == "CFrame" and offset or CFrame.new(offset or Vector3.zero)
	a.Parent = parent
	return a
end

function VFXKit.Beam(a0: Attachment, a1: Attachment, s): Beam
	local b = Instance.new("Beam")
	b.Name = s.Name or "Beam"
	b.Attachment0, b.Attachment1 = a0, a1
	b.Texture = tex(s.Tex)
	b.TextureMode = Enum.TextureMode[s.Mode or "Stretch"]
	b.TextureLength = s.Length or 1
	b.TextureSpeed = s.Speed or 0
	b.Width0 = s.Width and s.Width[1] or 1
	b.Width1 = s.Width and s.Width[2] or b.Width0
	b.CurveSize0, b.CurveSize1 = s.Curve and s.Curve[1] or 0, s.Curve and s.Curve[2] or 0
	b.Segments = s.Segments or 20
	b.FaceCamera = s.FaceCamera ~= false
	b.LightEmission = s.LE or 1
	b.LightInfluence = s.LI or 0
	b.Brightness = s.Bright or 1
	b.Color = VFXKit.CSeq(s.Color or WHITE)
	b.Transparency = VFXKit.Fade(s.Fade)
	b.ZOffset = s.Z or 0
	b.Parent = s.Parent or a0.Parent
	return b
end

-- A flat circle of `radius` (in the plane of cf's X/Z) made of two mirrored half-circle beams: a
-- half circle of radius r = two attachments 2r apart with CurveSize 4/3 r. The attachments' X axis
-- must be the tangent, so they point along cf's LookVector.
function VFXKit.Ring(part: BasePart, cf: CFrame, radius: number, s)
	local x = cf.RightVector * radius
	local tangent = CFrame.fromMatrix(Vector3.zero, cf.LookVector, cf.UpVector)
	local a = VFXKit.Attachment(part, CFrame.new(cf.Position + x) * tangent, "RingA")
	local b = VFXKit.Attachment(part, CFrame.new(cf.Position - x) * tangent, "RingB")
	local curve = radius * 4 / 3
	local spec = table.clone(s)
	spec.FaceCamera = false
	spec.Curve = { curve, -curve }
	local one = VFXKit.Beam(a, b, spec)
	spec.Curve = { -curve, curve }
	local two = VFXKit.Beam(a, b, spec)
	return one, two
end

-- Builds every layer of VFXConfig.Recipes[name] under parent, each with `overrides` merged in.
function VFXKit.Recipe(parent: Instance, name: string, overrides): { ParticleEmitter }
	local made = {}
	for _, layer in Config.Recipes[name] do
		local spec = table.clone(layer)
		for key, value in overrides or {} do
			spec[key] = value
		end
		table.insert(made, VFXKit.Emitter(parent, spec))
	end
	return made
end

local function emitters(root: Instance): { ParticleEmitter }
	local list = root:IsA("ParticleEmitter") and { root } or {}
	for _, e in root:GetDescendants() do
		if e:IsA("ParticleEmitter") then
			table.insert(list, e)
		end
	end
	return list
end

-- Fires every burst emitter under root (EmitCount after EmitDelay). slow (optional) = a TimeScale
-- for freeze-frame reviews; delays stretch with it.
function VFXKit.Fire(root: Instance, slow: number?)
	for _, e in emitters(root) do
		if slow then
			e.TimeScale = slow
		end
		local count = e:GetAttribute("EmitCount")
		if count then
			local delay = (e:GetAttribute("EmitDelay") or 0) / (slow or 1)
			if delay > 0 then
				task.delay(delay, e.Emit, e, count)
			else
				e:Emit(count)
			end
		end
	end
end

function VFXKit.SetTimeScale(root: Instance, timeScale: number)
	for _, e in emitters(root) do
		e.TimeScale = timeScale
	end
end

-- A steady emitter's look is Rate x Lifetime particles of mixed ages, so Enabled = true swells in
-- over one Lifetime. InstantOn runs each one at InstantOnTimeScale for Lifetime / that, then restores.
function VFXKit.InstantOn(root: Instance)
	local fast = Config.InstantOnTimeScale
	for _, e in emitters(root) do
		if e:GetAttribute("EmitCount") == nil then
			local normal = e.TimeScale
			e.Enabled = true
			e.TimeScale = fast
			task.delay(e.Lifetime.Max / fast, function()
				e.TimeScale = normal
			end)
		end
	end
end

-- Enabled = false alone leaves the live particles hanging for a Lifetime; Clear() drops them.
function VFXKit.InstantOff(root: Instance)
	for _, e in emitters(root) do
		e.Enabled = false
		e:Clear()
	end
end

return VFXKit
