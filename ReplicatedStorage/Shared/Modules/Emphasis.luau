--[[
	Emphasis — rich-text highlight for the important words of a notification (colour from
	NotifyConfig.Emphasis by kind, bold). The same markup on server and client, so a toast sent by a
	service looks exactly like a local one.
	  Emphasis.Em("Gold Chest", "Success") -> '<font color="#78ff82"><b>Gold Chest</b></font>'
	  Emphasis.Paint(text, color)          -> bold, in any colour (a rarity's, a tier's)
	  Emphasis.Gradient(text, from, to)    -> each letter blended from `from` to `to` (rich text can't
	                                          take a UIGradient on one word, so it's coloured per letter)
	  Emphasis.Colors(text, { c1, c2, ... }) -> the same across any number of colours
	  Emphasis.Escape(text)                -> & < > escaped for rich text
]]
local Config = require(script.Parent.Parent.Config.NotifyConfig)

local Emphasis = {}

local function escape(text: string): string
	return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

Emphasis.Escape = escape

local function letters(text: string): { string }
	local out = {}
	for _, code in utf8.codes(text) do
		table.insert(out, utf8.char(code))
	end
	return out
end

function Emphasis.Paint(text: string, color: Color3): string
	return ('<font color="#%s"><b>%s</b></font>'):format(color:ToHex(), escape(text))
end

function Emphasis.Em(text: string, kind: string?): string
	local colors = Config.Emphasis
	return Emphasis.Paint(text, colors[kind or "Info"] or colors.Info)
end

function Emphasis.Gradient(text: string, from: Color3, to: Color3): string
	return Emphasis.Colors(text, { from, to })
end

function Emphasis.Colors(text: string, colors: { Color3 }): string
	local chars = letters(text)
	local out = {}
	for i, letter in chars do
		local x = (#chars > 1 and (i - 1) / (#chars - 1) or 0) * (#colors - 1)
		local k = math.min(math.floor(x) + 1, #colors)
		local color = colors[k]:Lerp(colors[math.min(k + 1, #colors)], x - (k - 1))
		table.insert(out, ('<font color="#%s">%s</font>'):format(color:ToHex(), escape(letter)))
	end
	return "<b>" .. table.concat(out) .. "</b>"
end

return Emphasis
