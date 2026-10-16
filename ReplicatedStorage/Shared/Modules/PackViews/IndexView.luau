--[[
	PackViews/IndexView — a collection index: the pack's Index window (UiPackConfig menu "Index") whose rarity
	tab column holds the game's rarity bands. A band's page is the pack's item grid with one pack cell per entry:
	its model in a ViewportFrame on rarity-tinted rays (Gold = a gold name gradient), a black silhouette and "???"
	until discovered. The pack's hidden percentage bar under the window shows the overall progress. Cells are
	PRE-built ahead of time by view:Prebuild(UiPackConfig.Preload.PerFrame) (a few per frame, from the game's
	controller once the save has loaded), so opening only toggles visibility; Open finishes any not built yet.
	A tab change bounces its grid back to the top. No game logic.
	  IndexView.new({ Menu = "Index"?, Window = { OnClose, Parent? }, OnCell = (cell, view) -> ()?, Bands = { { Key, Title, Color, Cells = { cellView } } } }) -> view
	      OnCell runs on each fresh pack cell BEFORE its art is placed (a game re-lays-out the cell / adds buttons)
	      cellView = { Id, Name, Gold, Rays (Color3), Model = () -> Model }
	  view:SetKnown(id, known)   view:SetProgress(found, total, text)   view:Open(band?)   view:Close()
	  view:Prebuild(perFrame)    build every cell, perFrame cells a frame (yields)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ui = require(ReplicatedStorage.Shared.Modules.Ui)
local UiPack = require(ReplicatedStorage.Shared.Modules.UiPack)

local IndexView = {}
IndexView.__index = IndexView

local UNKNOWN = "???"

function IndexView.new(spec)
	local self = setmetatable({ Spec = spec, Pages = {}, Cells = {}, Known = {} }, IndexView)
	local window = UiPack.Window(spec.Menu or "Index", spec.Window)
	self.Window = window
	local panel = window.Panel
	local template = panel.Scrolling
	for _, child in template:GetChildren() do
		if child:IsA("GuiObject") and child.Name ~= "_" then
			child:Destroy()
		end
	end
	template.Visible = false
	local tabs = {}
	for _, band in spec.Bands do
		local page = template:Clone()
		page.Name, page.Parent = band.Key, panel
		self.Pages[band.Key] = page
		table.insert(tabs, { Key = band.Key, Title = band.Title, Color = band.Color })
	end
	template:Destroy()
	self.Progress = panel.Percentage
	self.Progress.Visible = true
	window:SetTabs(tabs, function(key)
		for name, page in self.Pages do
			page.Visible = name == key
		end
		local page = self.Pages[key]
		page.CanvasPosition = Vector2.new(0, math.min(page.CanvasPosition.Y, 24))
		Ui.Tween(page, 0.25, { CanvasPosition = Vector2.zero }, Enum.EasingStyle.Back) -- quick bounce to the top
	end)
	return self
end

-- Builds the cells not built yet; with perFrame, yields a frame after every perFrame cells.
function IndexView:Prebuild(perFrame: number?)
	local made = 0
	for _, band in self.Spec.Bands do
		for order, view in band.Cells do
			if not self.Cells[view.Id] then
				local cell = UiPack.Cell({ Parent = self.Pages[band.Key], Name = view.Id, LayoutOrder = order })
				if self.Spec.OnCell then
					self.Spec.OnCell(cell, view)
				end
				local art = UiPack.Art.Replace(cell.Icon, { Model = view.Model(), Rays = view.Rays }, nil)
				if view.Gold then
					UiPack.TextGradient(cell:FindFirstChild("Name"), "Gold")
				end
				self.Cells[view.Id] = { Cell = cell, Art = art, View = view }
				self:Paint(view.Id)
				made += 1
				if perFrame and made % perFrame == 0 then
					task.wait()
				end
			end
		end
	end
end

function IndexView:Paint(id: string)
	local entry = self.Cells[id]
	if entry then
		local known = self.Known[id] == true
		UiPack.Art.Silhouette(entry.Art, not known)
		UiPack.Text(entry.Cell:FindFirstChild("Name"), if known then entry.View.Name else UNKNOWN)
		local rays = entry.Art:FindFirstChild("Rays")
		if rays then
			rays.Visible = known
		end
	end
end

function IndexView:SetKnown(id: string, known: boolean)
	if self.Known[id] ~= known then
		self.Known[id] = known
		self:Paint(id)
	end
end

function IndexView:SetProgress(found: number, total: number, text: string)
	self.Progress.Container.Size = UDim2.fromScale(math.clamp(found / total, 0, 1), 1)
	UiPack.Text(self.Progress.Text, text)
end

function IndexView:Open(band: string?)
	self:Prebuild() -- normally already done (the game's controller prebuilds once the save has loaded)
	self.Window:Open()
	self.Window:Select(if band and self.Pages[band] then band else self.Window.Tab or self.Spec.Bands[1].Key)
end

function IndexView:Close()
	self.Window:Close()
end

return IndexView
