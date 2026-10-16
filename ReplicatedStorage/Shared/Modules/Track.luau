--[[
	Track — the hill's geometry, shared by server, clients and the Studio builder (one source of truth).
	The hill is a polyline of straight slopes (one per area, BalanceConfig.Areas) heading +Z and falling in Y.
	s = distance along the slope from the start line; lane = lateral studs (+X). The log's centre line is exact
	on the built slabs; only its TILT eases across joints (Blend) so it never snaps.
	  Track.Length            total slope length
	  Track.AreaIndex(s)      1..#Areas   Track.AreaStart(i) / Track.AreaEnd(i)
	  Track.Pos(s, lane?)     point on the slope surface
	  Track.Basis(s)          forward (down the slope), up, right  (smoothed tilt)
	  Track.Pitch(s)          radians (smoothed)
	  Track.SFromZ(z)         distance along the slope for a world Z (the hill heads +Z), clamped
	  Track.Offset            added to every Pos: the client sets it to the local player's world (Worlds.Offset; worlds sit
	                          side by side on X, so SFromZ is the same in every world). The server leaves it at zero.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.BalanceConfig)

local Track = { Offset = Vector3.zero }

local segments = {}
local length = 0
local origin = Config.Track.Origin
for index, area in Config.Areas do
	local pitch = math.rad(area.Pitch)
	local dir = Vector3.new(0, -math.sin(pitch), math.cos(pitch))
	table.insert(segments, { S0 = length, S1 = length + area.Length, Start = origin, Dir = dir, Pitch = pitch, Index = index })
	origin += dir * area.Length
	length += area.Length
end
Track.Length = length
Track.Segments = segments

function Track.AreaIndex(s: number): number
	for _, segment in segments do
		if s < segment.S1 then
			return segment.Index
		end
	end
	return #segments
end

function Track.AreaStart(index: number): number
	return segments[index].S0
end

function Track.AreaEnd(index: number): number
	return segments[index].S1
end

function Track.Pos(s: number, lane: number?): Vector3
	local segment = segments[Track.AreaIndex(math.clamp(s, 0, length - 1e-3))]
	return segment.Start + segment.Dir * (s - segment.S0) + Vector3.new(lane or 0, 0, 0) + Track.Offset
end

function Track.SFromZ(z: number): number
	for _, segment in segments do
		local endZ = segment.Start.Z + segment.Dir.Z * (segment.S1 - segment.S0)
		if z < endZ then
			return math.max(0, segment.S0 + (z - segment.Start.Z) / segment.Dir.Z)
		end
	end
	return length
end

-- Smoothed pitch: eases between neighbouring areas inside Blend studs of a joint.
function Track.Pitch(s: number): number
	local blend = Config.Track.Blend
	local segment = segments[Track.AreaIndex(math.clamp(s, 0, length - 1e-3))]
	local nextSeg, prevSeg = segments[segment.Index + 1], segments[segment.Index - 1]
	if nextSeg and segment.S1 - s < blend then
		local t = 0.5 - (segment.S1 - s) / (2 * blend)
		t = t * t * (3 - 2 * t)
		return segment.Pitch + (nextSeg.Pitch - segment.Pitch) * t
	elseif prevSeg and s - segment.S0 < blend then
		local t = 0.5 + (s - segment.S0) / (2 * blend)
		t = t * t * (3 - 2 * t)
		return prevSeg.Pitch + (segment.Pitch - prevSeg.Pitch) * t
	end
	return segment.Pitch
end

function Track.Basis(s: number): (Vector3, Vector3, Vector3)
	local pitch = Track.Pitch(s)
	local forward = Vector3.new(0, -math.sin(pitch), math.cos(pitch))
	local up = Vector3.new(0, math.cos(pitch), math.sin(pitch))
	return forward, up, Vector3.xAxis
end

return Track
