-- Creed UI 1.8.3 to 1.11.0: the Talents page drawn by Creed UI from the stock 1.12 talent API.
-- Azeroth Survivors keeps its own talents (trees, milestones, specs) that this API doesn't give, so
-- from 1.12.0 the Talents tab opens the game's own Talents window instead. Kept for later.

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

