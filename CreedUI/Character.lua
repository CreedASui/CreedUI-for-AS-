-- Creed UI: the character window, dressed. The game's own stays (its tabs, the gear slots you drag
-- to, the model you turn): only its art goes, for Creed UI's dark glass in a gold rail, the portrait
-- in a ring, each gear slot in the skill bar's metal and lit in its item's rarity color. The run's
-- numbers, drawn by the game in its boxes and its Run Stats panel, are read off those and set out
-- again in a panel of their own beside the window: grouped, the ones at nothing dimmed, a change
-- since your last look flashing by its number. The Skills page becomes a Talents page: the hero's
-- talent trees side by side, to look back at what the run started with (the game's own talent
-- window is gone); the Honor tab goes, there being no PvP.
-- Turned off (or after an error) the window is the game's again, as it was.

local C = CreedUI
local DEFAULTS = { enabled = true }
local SLOTS = { "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist", "Hands", "Waist", "Legs",
	"Feet", "Finger0", "Finger1", "Trinket0", "Trinket1", "MainHand", "SecondaryHand", "Ranged", "Ammo" }
-- the run's stats by what they do; any the game adds later go under Other
local GROUPS = {
	{ name = "OFFENSE", stats = { "Damage", "Crit", "Crit Dmg", "Haste", "Execute", "Vs Afflicted" } },
	{ name = "SURVIVAL", stats = { "Health", "Armor", "Lifesteal", "Kill Heal", "Thorns", "Regen", "Lives" } },
	{ name = "AREA AND DOTS", stats = { "Area", "Targets", "Echo", "DoT Stacks", "DoT Haste" } },
	{ name = "RUN", stats = { "Speed", "Pickup", "Experience", "Gold", "Luck", "Buff Power" } },
}
local ROW, HEAD, TOP, PANEL_W = 13, 17, 32, 212
local FLASH = 5 -- seconds a change shows by its number
local ART_PATHS = { "PaperDollInfoFrame", "CharacterFrame\\", "UI%-Character" }

local db
local S = { dressed = false, hooked = false, broken = false, kept = {}, stats = {}, boxes = {}, nums = {}, flashAt = {},
	flashText = {}, readClock = 0, scanClock = 0, slotClock = 0, layoutKey = nil, statKey = nil }
local W = { bez = {}, rows = {}, heads = {}, tabs = {} }
local Call = C.Call

local KNOWN = {} -- a label as the game writes it, squeezed (no spaces, colons or capitals) -> our name
local GROUP_OF = {}
for gi = 1, table.getn(GROUPS) do
	for _, name in ipairs(GROUPS[gi].stats) do
		KNOWN[string.lower((string.gsub(name, "[%s:]+", "")))] = name
		GROUP_OF[name] = gi
	end
end
local function Squeeze(t)
	return string.lower((string.gsub(t or "", "[%s:]+", "")))
end

------------------------------------------------------------------------ the game's, kept to put back
-- a region or frame made see-through (and deaf to the mouse) while dressed; its own state kept
local function IsFrame(o)
	local kind = o.GetObjectType and o:GetObjectType()
	return kind ~= nil and kind ~= "Texture" and kind ~= "FontString"
end
local function Fade(o, keepMouse, page)
	if not o or S.kept[o] then return end
	local k = { alpha = o:GetAlpha() or 1, page = page }
	S.kept[o] = k
	o:SetAlpha(0)
	if not keepMouse and IsFrame(o) and o:IsMouseEnabled() then
		k.mouse = true
		o:EnableMouse(false)
	end
end
-- a frame's children too: deaf to the mouse (their tooltips would come up under ours)
local function Deafen(f, depth, page)
	if depth <= 0 or not f.GetChildren then return end
	local kids = { f:GetChildren() }
	for i = 1, table.getn(kids) do
		local k = kids[i]
		if not k.creed and not S.kept[k] and k.IsMouseEnabled and k:IsMouseEnabled() then
			S.kept[k] = { mouse = true, page = page }
			k:EnableMouse(false)
		end
		Deafen(k, depth - 1, page)
	end
end
local function PutBack(page)
	for o, k in pairs(S.kept) do
		if not page or k.page == page then
			if k.alpha then o:SetAlpha(k.alpha) end
			if k.mouse then o:EnableMouse(true) end
			S.kept[o] = nil
		end
	end
end

local function IsArt(r)
	if not (r.GetObjectType and r:GetObjectType() == "Texture" and r.GetTexture) then return false end
	local path = r:GetTexture()
	if type(path) ~= "string" then return false end
	for i = 1, table.getn(ART_PATHS) do
		if string.find(path, ART_PATHS[i]) then return true end
	end
	return false
end

local function FadeArt(f, page)
	if not f then return end
	local regions = { f:GetRegions() }
	for i = 1, table.getn(regions) do
		if IsArt(regions[i]) then Fade(regions[i], false, page) end
	end
end

------------------------------------------------------------------------ where the window's parts are
local function Slot(name) return getglobal("Character" .. name .. "Slot") end

-- the window's body in its own coordinates (left, top, right, bottom from its top left), from where
-- its slots are; the game's usual numbers when they can't be read
local function Body()
	local cf = CharacterFrame
	local fl, ft = cf:GetLeft(), cf:GetTop()
	local head, hands, main = Slot("Head"), Slot("Hands"), Slot("MainHand")
	if fl and ft and head and hands and main and head:GetLeft() and hands:GetRight() and main:GetBottom() then
		return head:GetLeft() - fl - 9, -12, hands:GetRight() - fl + 9, main:GetBottom() - ft - 12
	end
	return 12, -12, 350, -434
end

------------------------------------------------------------------------ building
-- a page's body (the glass in its rail, a shade under its title) and the portrait in the unit
-- frames' ring over its corner, the name in the timer's title face and a line under it
local function NewBody(parent, prefix)
	local b = {}
	b.bg = CreateFrame("Frame", prefix .. "Back", parent)
	b.bg.creed = true
	b.bg.deco = C.Panel(b.bg, false)
	b.header = C.Tex(b.bg, "ARTWORK", C.FLAT)
	b.header:SetPoint("TOPLEFT", b.bg, "TOPLEFT", 70, -8)
	b.header:SetPoint("TOPRIGHT", b.bg, "TOPRIGHT", -34, -8)
	b.header:SetHeight(36)
	b.header:SetGradientAlpha("VERTICAL", 0, 0, 0, 0.0, 0, 0, 0, 0.55)
	b.face = CreateFrame("Frame", prefix .. "Face", parent)
	b.face.creed = true
	b.face:SetWidth(66)
	b.face:SetHeight(66)
	b.face:SetPoint("CENTER", b.bg, "TOPLEFT", 26, -22)
	b.faceBg = C.Tex(b.face, "BACKGROUND", C.ART .. "Badge")
	b.faceBg:SetWidth(60)
	b.faceBg:SetHeight(60)
	b.faceBg:SetPoint("CENTER", b.face, "CENTER", 0, 0)
	b.portrait = b.face:CreateTexture(nil, "BORDER")
	b.portrait:SetWidth(54)
	b.portrait:SetHeight(54)
	b.portrait:SetPoint("CENTER", b.face, "CENTER", 0, 0)
	b.ring = C.Tex(b.face, "ARTWORK", C.ART .. "Portrait")
	b.ring:SetAllPoints(b.face)
	b.name = C.Text(b.face, C.TITLE_FONT, 17, nil, "CENTER", 220)
	b.name:SetPoint("TOP", b.bg, "TOP", 18, -10)
	b.level = b.face:CreateFontString(nil, "OVERLAY")
	b.level:SetFont(C.FONT, 11)
	b.level:SetPoint("TOP", b.name, "BOTTOM", 0, -2)
	b.level:SetWidth(240)
	b.level:SetJustifyH("CENTER")
	b.level:SetShadowOffset(1, -1)
	return b
end

local function Build()
	if W.bg then return end
	local pd = PaperDollFrame
	-- the body: under the window's own (its portrait and texts, its slots and model)
	local b = NewBody(pd, "CreedUICharacter")
	W.body = b
	W.bg, W.header, W.face, W.faceBg, W.portrait, W.ring, W.name, W.level = b.bg, b.header, b.face, b.faceBg, b.portrait, b.ring, b.name, b.level

	-- the run's stats, beside the window
	local p = CreateFrame("Frame", "CreedUICharacterStats", pd)
	p.creed = true
	W.stats = p
	p:SetWidth(PANEL_W)
	p:SetPoint("TOPLEFT", W.bg, "TOPRIGHT", 4, 0)
	p.deco = C.Panel(p, false)
	W.title = C.Text(p, C.TITLE_FONT, 15, nil, "CENTER", PANEL_W - 20)
	W.title:SetPoint("TOP", p, "TOP", 0, -11)
	C.LText(W.title, "Run stats")
	W.statsEmpty = C.Text(p, C.FONT, 10, nil, "CENTER", PANEL_W - 30)
	W.statsEmpty:SetPoint("TOP", p, "TOP", 0, -40)
	W.statsEmpty:SetTextColor(0.6, 0.6, 0.62)
	C.LText(W.statsEmpty, "The game hasn't shown its stats yet.")
end

------------------------------------------------------------------------ the talent page
-- Each tree as the game's talent window draws it, in Creed UI's dress: a panel of its own in the
-- gold rail, the tree's own painting behind it, its icon, name and points at its head; every
-- talent on the tree's grid of four columns and seven tiers, joined to the one that opens it by a
-- branch with an arrow. A talent with points is lit in the panel's gold with its rank; one that
-- could be taken is in its colors; one still locked is greyed.
local TREE_ICON, TREE_HEAD, TREE_PAD = 28, 44, 14
local ARROW = { down = { 0, 1, 1, 0 }, right = { 0, 1, 1, 1, 0, 0, 1, 0 }, left = { 1, 0, 0, 0, 1, 1, 0, 1 } }

local function TreeIcon(tree, n)
	local list = tree.icons
	local b = list[n]
	if b then return b end
	b = CreateFrame("Button", nil, tree)
	b.creed = true
	b:SetWidth(TREE_ICON)
	b:SetHeight(TREE_ICON)
	b:SetFrameLevel(tree:GetFrameLevel() + 3)
	b.icon = b:CreateTexture(nil, "BORDER")
	b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
	b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
	b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	b.shade = C.Tex(b, "ARTWORK", C.FLAT)
	b.shade:SetAllPoints(b.icon)
	b.bezel = C.Tex(b, "OVERLAY", C.ART .. "Slot")
	b.bezel:SetPoint("TOPLEFT", b, "TOPLEFT", -3, 3)
	b.bezel:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 3, -3)
	-- the rank in a little dark box at the corner, as the game's
	b.box = C.Tex(b, "OVERLAY", C.FLAT)
	b.box:SetHeight(12)
	b.box:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 7, -5)
	b.rank = C.Text(b, C.FONT, 10, "OUTLINE", "CENTER", 40)
	b.rank:SetPoint("CENTER", b.box, "CENTER", 0, 0)
	b:SetScript("OnEnter", function()
		if not (GameTooltip and this.tab) then return end
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
		if GameTooltip.SetTalent and pcall(GameTooltip.SetTalent, GameTooltip, this.tab, this.index) then
			GameTooltip:Show() -- the game's own lines, in its own face
		else
			GameTooltip:AddLine(this.talentName or "", 1, 0.82, 0.3)
			C.ShowTip()
		end
	end)
	b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	list[n] = b
	return b
end

-- a branch's piece: a dark edge and a core, lit or not; drawn under the icons
local function Piece(tree, n)
	local p = tree.pieces[n]
	if p then return p end
	p = { edge = C.Tex(tree.lines, "ARTWORK", C.FLAT), core = C.Tex(tree.lines, "OVERLAY", C.FLAT) }
	tree.pieces[n] = p
	return p
end
local function Arrow(tree, n)
	local a = tree.arrows[n]
	if a then return a end
	a = C.Tex(tree.lines, "OVERLAY", C.ART .. "Caret")
	a:SetWidth(13)
	a:SetHeight(13)
	tree.arrows[n] = a
	return a
end

local function BuildTalents()
	if W.tp then return end
	-- over the game's Skills page, which goes see-through under it
	local tp = CreateFrame("Frame", "CreedUITalentPage", CharacterFrame)
	tp.creed = true
	W.tp = tp
	tp:SetAllPoints(CharacterFrame)
	tp:Hide()
	W.tb = NewBody(tp, "CreedUITalents")
	W.tb.face:SetFrameLevel(tp:GetFrameLevel() + 8)
	W.trees = {}
	for t = 1, 3 do
		local tree = CreateFrame("Frame", "CreedUITalentTree" .. t, tp)
		tree.creed = true
		tree:SetFrameLevel(tp:GetFrameLevel() + 2)
		tree.deco = C.Panel(tree, false)
		-- the tree's own painting, its middle kept to the panel's shape, dimmed under the talents
		tree.artTop = tree:CreateTexture(nil, "ARTWORK")
		tree.artTop:SetPoint("TOPLEFT", tree, "TOPLEFT", 6, -6)
		tree.artTop:SetPoint("TOPRIGHT", tree, "TOPRIGHT", -6, -6)
		tree.artBottom = tree:CreateTexture(nil, "ARTWORK")
		tree.artBottom:SetPoint("TOPLEFT", tree.artTop, "BOTTOMLEFT", 0, 0)
		tree.artBottom:SetPoint("TOPRIGHT", tree.artTop, "BOTTOMRIGHT", 0, 0)
		tree.head = C.Tex(tree, "OVERLAY", C.FLAT)
		tree.head:SetPoint("TOPLEFT", tree, "TOPLEFT", 6, -6)
		tree.head:SetPoint("TOPRIGHT", tree, "TOPRIGHT", -6, -6)
		tree.head:SetHeight(TREE_HEAD - 12)
		tree.head:SetGradientAlpha("VERTICAL", 0, 0, 0, 0.35, 0, 0, 0, 0.8)
		tree.top = CreateFrame("Frame", nil, tree)
		tree.top:SetAllPoints(tree)
		tree.top:SetFrameLevel(tree:GetFrameLevel() + 4)
		tree.icon = tree.top:CreateTexture(nil, "ARTWORK")
		tree.icon:SetWidth(20)
		tree.icon:SetHeight(20)
		tree.icon:SetPoint("TOPLEFT", tree, "TOPLEFT", 13, -12)
		tree.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		tree.iconRing = C.Tex(tree.top, "OVERLAY", C.ART .. "Slot")
		tree.iconRing:SetPoint("TOPLEFT", tree.icon, "TOPLEFT", -3, 3)
		tree.iconRing:SetPoint("BOTTOMRIGHT", tree.icon, "BOTTOMRIGHT", 3, -3)
		tree.title = C.Text(tree.top, C.FONT, 12, nil, "LEFT", 120)
		tree.title:SetPoint("LEFT", tree.icon, "RIGHT", 8, 0)
		tree.spent = C.Text(tree.top, C.FONT, 14, "OUTLINE", "RIGHT", 40)
		tree.spent:SetPoint("TOPRIGHT", tree, "TOPRIGHT", -14, -14)
		tree.line = C.Tex(tree.top, "OVERLAY", C.FLAT)
		tree.line:SetHeight(1)
		tree.line:SetPoint("TOPLEFT", tree, "TOPLEFT", 8, -TREE_HEAD + 6)
		tree.line:SetPoint("TOPRIGHT", tree, "TOPRIGHT", -8, -TREE_HEAD + 6)
		tree.lines = CreateFrame("Frame", nil, tree)
		tree.lines:SetAllPoints(tree)
		tree.lines:SetFrameLevel(tree:GetFrameLevel() + 2)
		tree.icons, tree.pieces, tree.arrows = {}, {}, {}
		W.trees[t] = tree
	end
	-- the page reaches over where the stats sit on the other: its own close button at its corner
	W.tclose = C.Button(tp, 22, 22, "x", function()
		if type(HideUIPanel) == "function" then HideUIPanel(CharacterFrame) else CharacterFrame:Hide() end
	end)
	W.tclose:SetPoint("TOPRIGHT", W.tb.bg, "TOPRIGHT", -10, -10)
	W.tclose:SetFrameLevel(tp:GetFrameLevel() + 8)
	W.treeEmpty = C.Text(tp, C.FONT, 11, nil, "CENTER", 260)
	W.treeEmpty:SetPoint("CENTER", W.tb.bg, "CENTER", 0, 0)
	W.treeEmpty:SetTextColor(0.6, 0.6, 0.62)
	C.LText(W.treeEmpty, "The game has no talent trees for this hero.")
end

-- a talent's prerequisites, as the game gives them: (tier, column) pairs
local function Prereqs(t, i)
	if type(GetTalentPrereqs) ~= "function" then return {} end
	local r = { pcall(GetTalentPrereqs, t, i) }
	local out = {}
	if not r[1] then return out end
	local k = 2
	while r[k] and r[k + 1] do
		table.insert(out, { tier = tonumber(r[k]), column = tonumber(r[k + 1]) })
		k = k + 3
	end
	return out
end

-- one tree: its painting, head, talents and branches, in a panel w x h
local function LayTree(tree, t, w, h, mr, mg, mb)
	local ok, name, icon, spent, background = pcall(GetTalentTabInfo, t)
	if not ok then name, icon, spent, background = nil, nil, 0, nil end
	spent = tonumber(spent) or 0
	-- the painting: the game's top left and bottom left quarters (its middle), kept to the panel's shape
	local aw, ah = w - 12, h - 12
	if type(background) == "string" and background ~= "" then
		local base = string.find(background, "\\", 1, true) and background or ("Interface\\TalentFrame\\" .. background)
		local keep = math.min(1, (aw / ah) / (256 / 384))
		local l = (1 - keep) / 2
		tree.artTop:SetTexture(base .. "-TopLeft")
		tree.artBottom:SetTexture(base .. "-BottomLeft")
		tree.artTop:SetTexCoord(l, 1 - l, 0, 1)
		tree.artBottom:SetTexCoord(l, 1 - l, 0, 1)
		tree.artTop:SetHeight(ah * 256 / 384)
		tree.artBottom:SetHeight(ah * 128 / 384)
		tree.artTop:SetVertexColor(0.62, 0.6, 0.58)
		tree.artBottom:SetVertexColor(0.62, 0.6, 0.58)
		tree.artTop:Show()
		tree.artBottom:Show()
	else
		tree.artTop:Hide()
		tree.artBottom:Hide()
	end
	tree.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
	tree.iconRing:SetVertexColor(mr, mg, mb)
	C.SetText(tree.title, name or "")
	tree.title:SetTextColor(1, 0.84, 0.4)
	C.SetText(tree.spent, tostring(spent))
	if spent > 0 then tree.spent:SetTextColor(1, 1, 1) else tree.spent:SetTextColor(0.5, 0.5, 0.53) end
	tree.line:SetVertexColor(mr, mg, mb, 0.5)
	C.PanelTheme(tree.deco, C.Pal())

	-- the grid: four columns across, seven tiers down the panel
	local colStep = (w - TREE_PAD * 2 - TREE_ICON) / 3
	local rowStep = (h - TREE_HEAD - 14 - TREE_ICON) / 6
	local function X(col) return TREE_PAD + (col - 1) * colStep end
	local function Y(tier) return -TREE_HEAD - 4 - (tier - 1) * rowStep end
	local talents, at = {}, {}
	local n = (Call(GetNumTalents, t)) or 0
	for i = 1, n do
		local ok2, tname, ticon, tier, column, rank, max, _, meets = pcall(GetTalentInfo, t, i)
		tier, column = tonumber(tier), tonumber(column)
		if ok2 and tname and tier and column then
			local d = { i = i, name = tname, icon = ticon, tier = tier, column = column, rank = tonumber(rank) or 0,
				max = tonumber(max) or 0, meets = meets }
			table.insert(talents, d)
			at[tier .. ":" .. column] = d
		end
	end
	-- the branches first, under the icons: from the talent that opens one to it
	local pi, ai = 0, 0
	local function Seg(x1, y1, x2, y2, lit)
		pi = pi + 1
		local p = Piece(tree, pi)
		local lx, rx, ty, by = math.min(x1, x2), math.max(x1, x2), math.max(y1, y2), math.min(y1, y2)
		local horizontal = math.abs(y1 - y2) < 0.5
		C.Place(p.edge, "TOPLEFT", tree, "TOPLEFT", lx - 3, ty + 3)
		C.Size(p.edge, horizontal and (rx - lx + 6) or 6, horizontal and 6 or (ty - by + 6))
		C.Place(p.core, "TOPLEFT", tree, "TOPLEFT", lx - 1, ty + 1)
		C.Size(p.core, horizontal and (rx - lx + 2) or 2, horizontal and 2 or (ty - by + 2))
		C.Color(p.edge, 0, 0, 0, 0.75)
		if lit then C.Color(p.core, mr, mg, mb, 1) else C.Color(p.core, 0.42, 0.42, 0.45, 1) end
		C.Vis(p.edge, true)
		C.Vis(p.core, true)
	end
	local function Head(x, y, dir, lit)
		ai = ai + 1
		local a = Arrow(tree, ai)
		C.Place(a, "CENTER", tree, "TOPLEFT", x, y)
		local c = ARROW[dir]
		if c[5] then a:SetTexCoord(c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8]) else a:SetTexCoord(c[1], c[2], c[3], c[4]) end
		if lit then a:SetVertexColor(mr, mg, mb) else a:SetVertexColor(0.55, 0.55, 0.58) end
		C.Vis(a, true)
	end
	local half = TREE_ICON / 2
	for _, d in ipairs(talents) do
		for _, pre in ipairs(Prereqs(t, d.i)) do
			local from = at[(pre.tier or 0) .. ":" .. (pre.column or 0)]
			if from then
				local lit = from.rank > 0 and from.rank >= from.max
				local fx, fy = X(from.column) + half, Y(from.tier) - half
				local tx, ty = X(d.column) + half, Y(d.tier) - half
				if from.tier == d.tier then
					-- side by side: across, into its side
					local dir = tx > fx and 1 or -1
					Seg(fx + dir * half, fy, tx - dir * (half + 5), ty, lit)
					Head(tx - dir * (half + 4), ty, dir > 0 and "right" or "left", lit)
				else
					-- down (across first if it's in another column), into its top
					if from.column ~= d.column then
						local dir = tx > fx and 1 or -1
						Seg(fx + dir * half, fy, tx, fy, lit)
						Seg(tx, fy, tx, ty + half + 5, lit)
					else
						Seg(fx, fy - half, tx, ty + half + 5, lit)
					end
					Head(tx, ty + half + 4, "down", lit)
				end
			end
		end
	end
	for k = pi + 1, table.getn(tree.pieces) do
		C.Vis(tree.pieces[k].edge, false)
		C.Vis(tree.pieces[k].core, false)
	end
	for k = ai + 1, table.getn(tree.arrows) do C.Vis(tree.arrows[k], false) end

	-- the talents: lit with points; in their colors when they could be taken; greyed while locked
	for k, d in ipairs(talents) do
		local b = TreeIcon(tree, k)
		b.tab, b.index, b.talentName = t, d.i, d.name
		b.icon:SetTexture(d.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
		local has = d.rank > 0
		local open = spent >= (d.tier - 1) * 5 and d.meets ~= false and d.meets ~= 0
		for _, pre in ipairs(Prereqs(t, d.i)) do
			local from = at[(pre.tier or 0) .. ":" .. (pre.column or 0)]
			if from and from.rank < from.max then open = false end
		end
		if b.icon.SetDesaturated then b.icon:SetDesaturated(not (has or open)) end
		C.Color(b.shade, 0, 0, 0, has and 0 or (open and 0.15 or 0.5))
		if has then
			b.bezel:SetVertexColor(mr, mg, mb)
		elseif open then
			b.bezel:SetVertexColor(0.78, 0.78, 0.8)
		else
			b.bezel:SetVertexColor(0.38, 0.38, 0.4)
		end
		local text = (has or open) and (d.rank .. "/" .. d.max) or ""
		C.SetText(b.rank, text)
		C.Width(b.box, math.max(18, C.TextWidth(b.rank) + 6))
		C.Color(b.box, 0, 0, 0, text ~= "" and 0.8 or 0)
		if has and d.rank >= d.max then
			b.rank:SetTextColor(1, 0.84, 0.4)
		elseif has then
			b.rank:SetTextColor(0.4, 1, 0.45)
		else
			b.rank:SetTextColor(0.7, 0.7, 0.72)
		end
		C.Place(b, "TOPLEFT", tree, "TOPLEFT", X(d.column), Y(d.tier))
		b:Show()
	end
	for k = table.getn(talents) + 1, table.getn(tree.icons) do tree.icons[k]:Hide() end
	return spent
end

-- the three trees side by side, each in its own panel
local function LayTrees()
	local tabs = (type(GetNumTalentTabs) == "function" and Call(GetNumTalentTabs)) or 0
	local body = W.tb.bg
	local bw = body:GetWidth() or 554
	if bw < 100 then bw = 554 end
	local bh = body:GetHeight() or 420
	if bh < 100 then bh = 420 end
	local gap, top = 8, 64
	local tw = math.floor((bw - 20 - gap * 2) / 3)
	local th = math.floor(bh - top - 12)
	local mr, mg, mb = C.PanelMetal(C.Pal())
	local total = 0
	for t = 1, 3 do
		local tree = W.trees[t]
		if t <= tabs then
			tree:ClearAllPoints()
			tree:SetPoint("TOPLEFT", body, "TOPLEFT", 10 + (t - 1) * (tw + gap), -top)
			tree:SetWidth(tw)
			tree:SetHeight(th)
			total = total + LayTree(tree, t, tw, th, mr, mg, mb)
			tree:Show()
		else
			tree:Hide()
		end
	end
	C.Vis(W.treeEmpty, tabs == 0)
	S.talentTotal = total
end

-- a gear slot in the skill bar's metal; lit in its item's rarity color
local function DressSlot(name)
	local b = Slot(name)
	if not b or W.bez[name] then return end
	local top = CreateFrame("Frame", nil, b)
	top.creed = true
	top:SetPoint("TOPLEFT", b, "TOPLEFT", -3, 3)
	top:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 3, -3)
	top:SetFrameLevel(b:GetFrameLevel() + 2)
	top.glow = C.Tex(top, "BACKGROUND", C.ART .. "Ring", "ADD")
	top.glow:SetPoint("TOPLEFT", top, "TOPLEFT", -9, 9)
	top.glow:SetPoint("BOTTOMRIGHT", top, "BOTTOMRIGHT", 9, -9)
	top.bezel = C.Tex(top, "OVERLAY", C.ART .. "Slot")
	top.bezel:SetAllPoints(top)
	top:EnableMouse(false)
	W.bez[name] = top
end

-- a tab under the window: its art gone, our glass and a gold line, the chosen one lit
local function DressTab(i)
	local tab = getglobal("CharacterFrameTab" .. i)
	if not tab or W.tabs[i] then return end
	local regions = { tab:GetRegions() }
	for j = 1, table.getn(regions) do
		if regions[j]:GetObjectType() == "Texture" then Fade(regions[j]) end
	end
	local k = {}
	k.fill = C.Tex(tab, "BACKGROUND", C.FLAT)
	k.fill:SetPoint("TOPLEFT", tab, "TOPLEFT", 6, -3)
	k.fill:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -6, 6)
	k.line = C.Tex(tab, "BACKGROUND", C.FLAT)
	k.line:SetPoint("TOPLEFT", k.fill, "TOPLEFT", 0, 0)
	k.line:SetPoint("TOPRIGHT", k.fill, "TOPRIGHT", 0, 0)
	k.line:SetHeight(2)
	W.tabs[i] = k
end

-- a tab's words, and which page it opens by them (the game's words for Skills and Honor)
local function TabText(tab)
	local fs = getglobal(tab:GetName() .. "Text")
	if not fs and tab.GetFontString then fs = tab:GetFontString() end
	return fs, fs and fs:GetText()
end
local function Retab()
	local skills = getglobal("SKILLS") or "Skills"
	local honor = getglobal("HONOR") or "Honor"
	for i = 1, 8 do
		local tab = getglobal("CharacterFrameTab" .. i)
		if tab then
			local fs, text = TabText(tab)
			if fs and (text == skills or fs == W.skillsText) and SkillFrame then
				if not W.skillsText then
					W.skillsText, W.skillsWas = fs, text
					local face, size, flags = fs:GetFont()
					W.skillsFont = { face, size, flags }
				end
				local size = W.skillsFont[2] or 10
				if fs.cface ~= C.FONT or fs.csize ~= size then C.SetFace(fs, C.FONT, size, W.skillsFont[3]) end
				C.SetText(fs, C.L("Talents"))
			elseif text == honor or tab == W.honorTab then
				W.honorTab = tab
				if tab:IsShown() then tab:Hide() end
			end
		end
	end
end
local function Untab()
	if W.skillsText then
		local f = W.skillsFont
		W.skillsText.cface = nil
		if f[1] then W.skillsText:SetFont(f[1], f[2] or 10, f[3]) end
		C.SetText(W.skillsText, W.skillsWas)
		for i = table.getn(C.faced), 1, -1 do
			if C.faced[i] == W.skillsText then table.remove(C.faced, i) end
		end
		W.skillsText = nil
	end
	if W.honorTab then
		W.honorTab:Show()
		W.honorTab = nil
	end
end

------------------------------------------------------------------------ reading the game's numbers
-- a label's number: the font string on its row, right of it, in its own frame
local function ValueOf(label, owner)
	local _, ly = label:GetCenter()
	local lx = label:GetLeft()
	if not (ly and lx) then return nil end
	local best, bestX
	local regions = { owner:GetRegions() }
	for i = 1, table.getn(regions) do
		local r = regions[i]
		if r ~= label and r:GetObjectType() == "FontString" then
			local _, ry = r:GetCenter()
			local rx = r:GetLeft()
			if ry and rx and math.abs(ry - ly) < 4 and rx > lx + 2 and (not bestX or rx < bestX) then
				best, bestX = r, rx
			end
		end
	end
	return best
end

-- the frame a stat sits in that can go see-through whole: the highest one under the window (or
-- under the screen, for a panel of its own) that holds none of the slots or the model
local function Holds(f, o)
	while o and o ~= UIParent do
		if o == f then return true end
		o = o:GetParent()
	end
	return false
end
local function Box(owner)
	local c = owner
	local roots = { [CharacterFrame] = true, [PaperDollFrame] = true, [UIParent] = true }
	if roots[c] then return nil end
	while c:GetParent() and not roots[c:GetParent()] do c = c:GetParent() end
	if Holds(c, CharacterModelFrame) then return nil end
	for i = 1, table.getn(SLOTS) do
		if Holds(c, Slot(SLOTS[i])) then return nil end
	end
	return c
end

-- every font string a few frames down from one, ours left out
local function Walk(f, depth, fn)
	if f.creed or (f.IsVisible and not f:IsVisible()) then return end
	local regions = { f:GetRegions() }
	for i = 1, table.getn(regions) do
		if regions[i]:GetObjectType() == "FontString" then fn(regions[i], f) end
	end
	if depth > 0 then
		local kids = { f:GetChildren() }
		for i = 1, table.getn(kids) do Walk(kids[i], depth - 1, fn) end
	end
end

-- the game's Run Stats panel: a frame on the screen with that title
local function RunStatsPanel()
	if S.runPanel then return S.runPanel end
	local kids = { UIParent:GetChildren() }
	for i = 1, table.getn(kids) do
		local f = kids[i]
		if not f.creed and f ~= CharacterFrame then
			local regions = { f:GetRegions() }
			for j = 1, table.getn(regions) do
				local r = regions[j]
				if r:GetObjectType() == "FontString" and Squeeze(r:GetText()) == "runstats" then
					S.runPanel = f
					return f
				end
			end
		end
	end
	-- or one of the window's own
	local found
	Walk(CharacterFrame, 3, function(r, owner)
		if not found and Squeeze(r:GetText()) == "runstats" then found = owner end
	end)
	S.runPanel = found
	return found
end

local function Take(label, owner, faded)
	local text = label:GetText()
	if type(text) ~= "string" or not string.find(text, ":%s*$") then return end
	local key = Squeeze(text)
	if key == "" then return end
	local value = ValueOf(label, owner)
	if not value then return end
	local name = KNOWN[key] or (string.gsub(text, "%s*:%s*$", ""))
	S.stats[name] = value
	local box = Box(owner)
	if box then
		if not faded[box] then
			faded[box] = true
			Fade(box)
			Deafen(box, 3)
		end
	else
		Fade(label, true)
		Fade(value, true)
	end
end

local function Scan()
	local faded = {}
	Walk(CharacterFrame, 5, function(r, owner) Take(r, owner, faded) end)
	local run = RunStatsPanel()
	if run then
		Fade(run, false, "window")
		Deafen(run, 3, "window")
		faded[run] = true
		Walk(run, 3, function(r, owner) Take(r, owner, faded) end)
	end
end

------------------------------------------------------------------------ the stats panel
local function Num(text)
	if type(text) ~= "string" then return nil end
	local _, _, n = string.find(text, "(%-?%d+%.?%d*)")
	return tonumber(n)
end

local function Signed(d, text)
	local a = math.abs(d)
	local s = (math.abs(a - math.floor(a + 0.5)) < 0.05) and string.format("%d", math.floor(a + 0.5)) or string.format("%.1f", a)
	local unit = ""
	if string.find(text, "%%") then unit = "%" elseif string.find(text, "yd") then unit = " yd" end
	return (d > 0 and "+" or "-") .. s .. unit
end

local function Row(i)
	local r = W.rows[i]
	if r then return r end
	r = {}
	r.label = C.Text(W.stats, C.FONT, 11, nil, "LEFT", PANEL_W - 30) -- one line, however long its words
	r.value = C.Text(W.stats, C.FONT, 11, nil, "RIGHT", 70)
	r.delta = C.Text(W.stats, C.FONT, 10, "OUTLINE", "RIGHT", 60)
	r.value:SetTextColor(1, 1, 1)
	W.rows[i] = r
	return r
end

local function Head(i)
	local h = W.heads[i]
	if h then return h end
	h = {}
	h.text = C.Text(W.stats, C.FONT, 10, nil, "LEFT", PANEL_W - 24)
	h.line = C.Tex(W.stats, "ARTWORK", C.FLAT)
	h.line:SetHeight(1)
	W.heads[i] = h
	return h
end

-- the rows, laid out again when the stats the game shows change
local function Lay()
	local lists, other = {}, {}
	for gi = 1, table.getn(GROUPS) do lists[gi] = {} end
	for name in pairs(S.stats) do
		if GROUP_OF[name] then table.insert(lists[GROUP_OF[name]], name) else table.insert(other, name) end
	end
	for gi = 1, table.getn(GROUPS) do
		local order = {}
		for k, n in ipairs(GROUPS[gi].stats) do order[n] = k end
		table.sort(lists[gi], function(a, b) return order[a] < order[b] end)
	end
	table.sort(other)
	local sections = {}
	for gi = 1, table.getn(GROUPS) do
		if table.getn(lists[gi]) > 0 then table.insert(sections, { name = GROUPS[gi].name, stats = lists[gi] }) end
	end
	if table.getn(other) > 0 then table.insert(sections, { name = "OTHER", stats = other }) end
	local key = ""
	for _, sec in ipairs(sections) do key = key .. sec.name .. ":" .. table.concat(sec.stats, ",") .. ";" end
	if key == S.statKey then return end
	S.statKey = key
	local y, ri, hi = -TOP, 0, 0
	for _, sec in ipairs(sections) do
		hi = hi + 1
		local h = Head(hi)
		C.LText(h.text, sec.name)
		C.Place(h.text, "TOPLEFT", W.stats, "TOPLEFT", 12, y - 3)
		h.line:ClearAllPoints()
		h.line:SetPoint("TOPLEFT", W.stats, "TOPLEFT", 12, y - 14)
		h.line:SetPoint("TOPRIGHT", W.stats, "TOPRIGHT", -12, y - 14)
		C.Vis(h.text, true)
		C.Vis(h.line, true)
		y = y - HEAD
		for _, name in ipairs(sec.stats) do
			ri = ri + 1
			local r = Row(ri)
			r.name, r.y = name, y
			C.LText(r.label, name)
			C.Place(r.label, "TOPLEFT", W.stats, "TOPLEFT", 14, y)
			C.Place(r.value, "TOPRIGHT", W.stats, "TOPRIGHT", -12, y)
			C.Place(r.delta, "TOPRIGHT", W.stats, "TOPRIGHT", -64, y)
			for _, fs in ipairs({ r.label, r.value, r.delta }) do C.Vis(fs, true) end
			y = y - ROW
		end
		y = y - 3
	end
	for i = ri + 1, table.getn(W.rows) do
		local r = W.rows[i]
		r.name = nil
		for _, fs in ipairs({ r.label, r.value, r.delta }) do C.Vis(fs, false) end
	end
	for i = hi + 1, table.getn(W.heads) do
		C.Vis(W.heads[i].text, false)
		C.Vis(W.heads[i].line, false)
	end
	C.Vis(W.statsEmpty, ri == 0)
	S.statsH = -y + 8
	W.stats:SetHeight(math.max(S.bodyH or 120, S.statsH))
	S.rowCount = ri
end

-- this run's id, so a new run's numbers don't flash as changes from the last one's
local function RunId()
	local ctx = Call(AZS_GetMeterContext)
	if type(ctx) == "table" and ctx.runId then return tostring(ctx.runId) end
	return nil
end

local function Read(now)
	local run = RunId()
	if type(db.seen) ~= "table" or (run and db.seen.run ~= run) then db.seen = { run = run, vals = {} } end
	local seen = db.seen.vals
	for i = 1, S.rowCount or 0 do
		local r = W.rows[i]
		local fs = S.stats[r.name]
		local text = fs and fs:GetText()
		if type(text) == "string" then
			C.SetText(r.value, text)
			local n = Num(text)
			-- what it was the last time it was read (this look, or the last one)
			local before = S.nums[r.name]
			if before == nil then before = seen[r.name] end
			if n and before and math.abs(n - before) > 0.001 then
				S.flashAt[r.name] = now
				C.SetText(r.delta, Signed(n - before, text))
				C.Place(r.delta, "TOPRIGHT", W.stats, "TOPRIGHT", -12 - math.ceil(C.TextWidth(r.value)) - 5, r.y)
				if n > before then r.delta:SetTextColor(0.35, 1, 0.45) else r.delta:SetTextColor(1, 0.4, 0.32) end
			end
			if n then
				S.nums[r.name] = n
				seen[r.name] = n
			end
			-- at nothing: dimmed, so the build stands out
			local zero = n ~= nil and math.abs(n) < 0.0001
			C.Alpha(r.label, zero and 0.42 or 1)
			C.Alpha(r.value, zero and 0.42 or 1)
			if zero then r.label:SetTextColor(0.7, 0.7, 0.72) else r.label:SetTextColor(0.86, 0.84, 0.78) end
		end
	end
end

local function StepFlash(now)
	for i = 1, S.rowCount or 0 do
		local r = W.rows[i]
		local at = S.flashAt[r.name]
		local a = at and (1 - (now - at) / FLASH) or 0
		if a <= 0 then
			C.Alpha(r.delta, 0)
		else
			C.Alpha(r.delta, math.min(1, a * 1.6))
		end
	end
end

------------------------------------------------------------------------ dressing and undressing
local function Layout()
	local l, t, r, b = Body()
	local key = string.format("%.1f,%.1f,%.1f,%.1f", l, t, r, b)
	if key == S.layoutKey then return end
	S.layoutKey = key
	W.bg:ClearAllPoints()
	W.bg:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", l, t)
	W.bg:SetPoint("BOTTOMRIGHT", CharacterFrame, "TOPLEFT", r, b)
	if W.tb then
		W.tb.bg:ClearAllPoints()
		W.tb.bg:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", l, t)
		W.tb.bg:SetPoint("BOTTOMRIGHT", CharacterFrame, "TOPLEFT", r + 4 + PANEL_W, b)
	end
	-- the stats as tall as the window (taller only if the game shows more than fit)
	S.bodyH = t - b
	W.stats:SetHeight(math.max(S.bodyH, S.statsH or 120))
end

local function Theme(pal)
	C.PanelTheme(W.bg.deco, pal)
	if W.tb then
		C.PanelTheme(W.tb.bg.deco, pal)
		W.tb.ring:SetVertexColor(C.PanelMetal(pal))
		W.tb.name:SetTextColor(1, 0.84, 0.4)
	end
	C.PanelTheme(W.stats.deco, pal)
	local mr, mg, mb = C.PanelMetal(pal)
	W.ring:SetVertexColor(mr, mg, mb)
	W.name:SetTextColor(1, 0.84, 0.4)
	W.title:SetTextColor(1, 0.84, 0.4)
	for _, h in ipairs(W.heads) do
		h.text:SetTextColor(mr * 0.9, mg * 0.9, mb * 0.9)
		h.line:SetVertexColor(mr, mg, mb, 0.35)
	end
	S.stamp = C.palStamp
	S.slotClock = 0
end

-- a slot's rarity, from its item's link color (the game's own words for it)
local function RarityColor(id)
	local link = id and Call(GetInventoryItemLink, "player", id)
	if type(link) ~= "string" then return nil end
	local _, _, hex = string.find(link, "|c%x%x(%x%x%x%x%x%x)")
	if not hex then return nil end
	local r, g, b = tonumber(string.sub(hex, 1, 2), 16) / 255, tonumber(string.sub(hex, 3, 4), 16) / 255, tonumber(string.sub(hex, 5, 6), 16) / 255
	-- plain white and grey (common, poor) keep the panel's metal
	if math.abs(r - g) < 0.06 and math.abs(g - b) < 0.06 then return nil end
	return r, g, b
end

local function StepSlots(pal)
	local mr, mg, mb = C.PanelMetal(pal)
	for name, top in pairs(W.bez) do
		local b = Slot(name)
		local r, g, bl = RarityColor(b and b:GetID())
		if r then
			top.bezel:SetVertexColor(r, g, bl)
			C.Color(top.glow, r, g, bl, 0.45)
		else
			top.bezel:SetVertexColor(mr, mg, mb)
			C.Color(top.glow, 0, 0, 0, 0)
		end
	end
end

local function StepTabs()
	local mr, mg, mb = 1, 0.8, 0.42
	for i, k in pairs(W.tabs) do
		local tab = getglobal("CharacterFrameTab" .. i)
		local chosen = tab and not tab:IsEnabled()
		k.fill:SetGradientAlpha("VERTICAL", 0.02, 0.02, 0.03, 0.92, chosen and 0.12 or 0.06, chosen and 0.11 or 0.06, chosen and 0.09 or 0.08, 0.92)
		k.line:SetVertexColor(mr, mg, mb, chosen and 1 or 0.4)
	end
end

-- the window's own pieces, shared by its pages: gone while this page shows, back on the others
local function FadeWindow()
	FadeArt(CharacterFrame, "window")
	Fade(CharacterFramePortrait, true, "window")
	Fade(CharacterNameText, true, "window")
	Fade(CharacterLevelText, true, "window")
	local run = RunStatsPanel()
	if run then
		Fade(run, false, "window")
		Deafen(run, 3, "window")
	end
end

local function OnTalents() return W.tp and W.tp:IsShown() and SkillFrame and SkillFrame:IsVisible() end

-- one of our pages open: the window's own pieces (and the game's Run Stats) away; none: back
local function SyncWindow()
	if not S.dressed then return end
	S.tabClock = 0 -- the chosen tab's line moves at once
	if PaperDollFrame:IsVisible() or OnTalents() then FadeWindow() else PutBack("window") end
end

local function Portraits()
	if type(SetPortraitTexture) ~= "function" then return end
	pcall(SetPortraitTexture, W.portrait, "player")
	if W.tb then pcall(SetPortraitTexture, W.tb.portrait, "player") end
end

local function Dress()
	if S.dressed or S.broken then return end
	Build()
	BuildTalents()
	S.dressed = true
	FadeArt(PaperDollFrame)
	if SkillFrame then
		Fade(SkillFrame)
		Deafen(SkillFrame, 6)
	end
	Retab()
	for i = 1, table.getn(SLOTS) do
		local b = Slot(SLOTS[i])
		if b then
			if b.GetNormalTexture and b:GetNormalTexture() then Fade(b:GetNormalTexture(), true) end
			DressSlot(SLOTS[i])
			W.bez[SLOTS[i]]:Show()
		end
	end
	for i = 1, 5 do DressTab(i) end
	for _, k in pairs(W.tabs) do C.Vis(k.fill, true) C.Vis(k.line, true) end
	W.bg:SetFrameLevel(math.max(0, CharacterFrame:GetFrameLevel() - 1))
	W.face:SetFrameLevel(PaperDollFrame:GetFrameLevel() + 6)
	W.bg:Show()
	W.face:Show()
	W.stats:Show()
	Portraits()
	if CharacterLevelText and CharacterLevelText.GetFont then
		local face, size, flags = CharacterLevelText:GetFont()
		if face then
			W.level:SetFont(face, size or 11, flags)
			W.tb.level:SetFont(face, size or 11, flags)
		end
	end
	S.layoutKey, S.stamp, S.statKey = nil, -1, nil
	S.scanClock, S.readClock, S.slotClock = 0, 0, 0
	S.nums = {} -- a new look: changes count from the last one's numbers
end

local function Undress()
	if not S.dressed then return end
	S.dressed = false
	PutBack()
	Untab()
	if W.tp then W.tp:Hide() end
	if W.bg then
		W.bg:Hide()
		W.face:Hide()
		W.stats:Hide()
		for _, top in pairs(W.bez) do top:Hide() end
		for _, k in pairs(W.tabs) do C.Vis(k.fill, false) C.Vis(k.line, false) end
	end
	S.stats, S.statKey = {}, nil
end
C.CharacterUndress = Undress

local function Step(dt)
	if not S.dressed then return end
	local now = GetTime()
	local pal = C.Pal()
	Layout()
	if S.stamp ~= C.palStamp then Theme(pal) end
	-- the tabs, whatever page shows: Skills called Talents in the language picked, no Honor
	S.tabClock = (S.tabClock or 0) - dt
	if S.tabClock <= 0 then
		S.tabClock = 1
		Retab()
		StepTabs()
	end
	if OnTalents() then
		S.treeClock = (S.treeClock or 0) - dt
		if S.treeClock <= 0 then
			S.treeClock = 2
			LayTrees()
			C.SetText(W.tb.name, C.L("Talents"))
			C.SetText(W.tb.level, (CharacterLevelText and CharacterLevelText:GetText()) or "")
			W.tb.level:SetTextColor(1, 0.82, 0.3)
		end
	end
	if not PaperDollFrame:IsVisible() then return end
	-- the game's numbers: found again now and then (its boxes may come late), read four times a second
	S.scanClock = S.scanClock - dt
	if S.scanClock <= 0 then
		S.scanClock = (S.rowCount or 0) >= 6 and 5 or 1
		Scan()
		Lay()
		Theme(pal)
		S.readClock = 0
	end
	S.readClock = S.readClock - dt
	if S.readClock <= 0 then
		S.readClock = 0.25
		Read(now)
		local text = (CharacterNameText and CharacterNameText:GetText()) or Call(UnitName, "player") or ""
		C.SetText(W.name, text)
		C.SetText(W.level, (CharacterLevelText and CharacterLevelText:GetText()) or "")
		W.level:SetTextColor(1, 0.82, 0.3)
	end
	StepFlash(now)
	S.slotClock = S.slotClock - dt
	if S.slotClock <= 0 then
		S.slotClock = 1
		StepSlots(pal)
	end
end

------------------------------------------------------------------------ the window's comings and goings
local function Fail(err)
	S.broken = true
	pcall(Undress)
	C.Print(C.L("the character panel stopped after an error, so the game's own is back: ") .. tostring(err))
end

local function Shown()
	if not (db and db.enabled) or S.broken then return end
	local ok, err = pcall(Dress)
	if not ok then Fail(err) end
end

local function Safe(fn)
	local ok, err = pcall(fn)
	if not ok then Fail(err) end
end

local function Chain(frame, script, fn)
	local old = frame:GetScript(script)
	frame:SetScript(script, function()
		if old then old() end
		if not S.broken then Safe(fn) end
	end)
end

local function Hook()
	if S.hooked or type(PaperDollFrame) ~= "table" or type(CharacterFrame) ~= "table" then return end
	S.hooked = true
	Chain(PaperDollFrame, "OnShow", function()
		Shown()
		if S.dressed then
			S.nums, S.scanClock, S.readClock = {}, 0, 0
			Portraits()
			SyncWindow()
		end
	end)
	Chain(PaperDollFrame, "OnHide", SyncWindow)
	if type(SkillFrame) == "table" then
		Chain(SkillFrame, "OnShow", function()
			Shown()
			if S.dressed then
				W.tp:Show()
				S.treeClock = 0
				Portraits()
				SyncWindow()
				Fade(CharacterFrameCloseButton, false, "talents")
			end
		end)
		Chain(SkillFrame, "OnHide", function()
			if W.tp then W.tp:Hide() end
			PutBack("talents")
			SyncWindow()
		end)
	end
	-- the driver: while the window's open, on any page
	local driver = CreateFrame("Frame", "CreedUICharacterDriver", CharacterFrame)
	driver.creed = true
	driver:SetScript("OnUpdate", function()
		if S.broken or not S.dressed then return end
		local dt = arg1 or 0
		if dt > 0.1 then dt = 0.1 end
		local ok, err = pcall(Step, dt)
		if not ok then Fail(err) end
	end)
	local ev = CreateFrame("Frame", "CreedUICharacterEvents")
	ev:RegisterEvent("UNIT_INVENTORY_CHANGED")
	ev:RegisterEvent("UNIT_PORTRAIT_UPDATE")
	ev:RegisterEvent("CHARACTER_POINTS_CHANGED")
	ev:SetScript("OnEvent", function()
		if not S.dressed then return end
		if event == "CHARACTER_POINTS_CHANGED" then
			S.treeClock = 0
		elseif arg1 ~= "player" then
			return
		elseif event == "UNIT_PORTRAIT_UPDATE" then
			Portraits()
		else
			S.slotClock = 0
		end
	end)
end

local function Apply()
	if type(CharacterFrame) ~= "table" or type(PaperDollFrame) ~= "table" then return end
	Hook()
	if db.enabled and not S.broken then
		local onSkills = type(SkillFrame) == "table" and SkillFrame:IsVisible()
		if PaperDollFrame:IsVisible() or onSkills then
			Shown()
			if S.dressed and onSkills then
				W.tp:Show()
				Fade(CharacterFrameCloseButton, false, "talents")
			end
			SyncWindow()
		end
	else
		Undress()
	end
end

------------------------------------------------------------------------ what the game tells addons
-- /creed probe: the game's run tables and what Creed UI found of them, for adding what's missing
function C.Probe()
	C.Print(C.L("what the game tells addons:"))
	for _, name in ipairs({ "AZS_STATS", "AZS_RUN" }) do
		local t = getglobal(name)
		if type(t) == "table" then
			local keys = {}
			for k, v in pairs(t) do
				if type(v) == "table" then
					local n = 0
					for _ in pairs(v) do n = n + 1 end
					table.insert(keys, tostring(k) .. "={" .. n .. "}")
				else
					table.insert(keys, tostring(k) .. "=" .. tostring(v))
				end
			end
			table.sort(keys)
			C.Print(name .. ": " .. table.concat(keys, ", "))
		else
			C.Print(name .. ": -")
		end
	end
	local found = {}
	for name, fs in pairs(S.stats) do table.insert(found, name .. "=" .. tostring(fs:GetText())) end
	table.sort(found)
	C.Print("stats: " .. (table.getn(found) > 0 and table.concat(found, ", ") or "-"))
end

C.OnInit(function()
	db = C.DB("character", DEFAULTS)
end)

C.OnWorld(function()
	if not db then return end
	local ok, err = pcall(Apply)
	if not ok then Fail(err) end
end)

C.RegisterPart({
	key = "character", name = "Character panel",
	note = "The game's character window in Creed UI's panel: each gear slot in metal, lit in its item's rarity color; your run's stats grouped beside it (the ones at nothing dimmed, a change since your last look flashing by its number).",
	get = function() return db and db.enabled end,
	set = function(on)
		if db then
			db.enabled = on and true or false
			if on then S.broken = false end
			Apply()
		end
	end,
})
