--[[
	NumberFormat — shared number text: 1234 -> "1.23K", money -> "$1.23K", seconds -> "4:05" / "1:02:03".
]]
local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local NumberFormat = {}

function NumberFormat.Abbreviate(value: number): string
	local tier = 1
	-- 999.995 rounds to "1000.00" at 2 decimals, so step up a suffix before that happens.
	while math.abs(value) >= 999.995 and tier < #SUFFIXES do
		value /= 1000
		tier += 1
	end
	if tier == 1 then
		-- Small incomes like 1.5 keep their decimal.
		local text = string.format("%.1f", value):gsub("%.0$", "")
		return text
	end
	local text = string.format("%.2f", value):gsub("%.?0+$", "")
	return text .. SUFFIXES[tier]
end

function NumberFormat.Money(value: number): string
	return "$" .. NumberFormat.Abbreviate(value)
end

function NumberFormat.Rate(value: number): string
	return "$" .. NumberFormat.Abbreviate(value) .. "/s"
end

-- Whole-number with thousands separators for exact costs: 7500000 -> "7,500,000".
function NumberFormat.Commas(value: number): string
	local text = tostring(math.floor(value))
	return (text:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

-- A countdown / elapsed clock: 245 -> "4:05", 3723 -> "1:02:03" (negative = 0).
function NumberFormat.Clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h, m, s = seconds // 3600, seconds // 60 % 60, seconds % 60
	if h > 0 then
		return ("%d:%02d:%02d"):format(h, m, s)
	end
	return ("%d:%02d"):format(m, s)
end

return NumberFormat
