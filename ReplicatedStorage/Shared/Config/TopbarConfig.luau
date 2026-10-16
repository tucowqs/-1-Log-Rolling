--[[
	TopbarConfig — utility and inventory buttons as TopbarPlus icons in Roblox's top bar (TopbarController),
	NEVER HUD squares (standing rule: Settings, inventory toggles and the like always live in the topbar).
	TopbarPlus v3 is vendored at ReplicatedStorage.Packages.Icon (kit packages, Wally 1foreverhd/topbarplus).
	Icons keep TopbarPlus's DEFAULT grey/white look (never recoloured). Each icon toggles its ClientState menu
	and follows it: closing the menu any other way (its X, another menu) deselects the icon.
	Icons appear in list order; Right = true puts an icon on the right side of the bar.
]]
return {
	Module = { "Packages", "Icon" }, -- path under ReplicatedStorage
	Wait = 10, -- seconds to wait for it before giving up (warns once)
	Icons = {
		{ Menu = "Settings", Label = "Settings", Image = "rbxassetid://95985042841987", Right = true }, -- plain white gear
	},
}
