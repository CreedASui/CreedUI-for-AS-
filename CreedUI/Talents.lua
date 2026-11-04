-- Creed UI: the run's talents, in Creed UI's look.
-- A gold-railed window with your talent trees side by side: each tree's name and the points in it,
-- then every talent you learned as its icon with its rank in a small gold-rimmed box (point at one
-- for its name). The total sits at the foot. The game tells addons the talents you learned (not
-- the empty places of its grid), so that's what it shows. The character window's Talents tab
-- opens it, and /creed talents; its x or Escape closes it. Move frames moves it.

local C = CreedUI
local ICON, GAP, PER_ROW, PAD = 36, 8, 4, 12
local COL_W = PER_ROW * ICON + (PER_ROW - 1) * GAP + PAD * 2
local COL_GAP, HEAD_H, TREE_H, FOOT_H, SIDE = 12, 58, 50, 34, 16
local MAX_TREES = 4
local READ_EVERY = 1

local root
local cols = {}
local S = { readAt = -10, broken = false, key = nil }
local Call = C.Call

------------------------------------------------------------------------ the game's answer
-- a tree's key as its name: its last part, each word's first letter up ("warrior.arms" -> "Arms",
-- "beast_mastery" -> "Beast Mastery"), then in the language picked (the game's own tree names)
local function TreeName(key)
	local s = tostring(key or "")
	local _, _, last = string.find(s, "([^%.:/]+)$")
	last = string.gsub(last or s, "[_%-]", " ")
	last = string.gsub(last, "(%a)(%w*)", function(a, b) return string.upper(a) .. string.lower(b) end)
	return last
end

-- { trees = { { key, name, points, talents = { { name, icon, rank } } } }, total }; false out of
-- a run; nil while the game can't say yet
local function Read()
	if type(AZS_GetMeterLoadout) ~= "function" or type(AZS_GetMeterContext) ~= "function" then return false end
	local context = Call(AZS_GetMeterContext)
	if type(context) ~= "table" or not context.runId then return false end
	local l = Call(AZS_GetMeterLoadout, { apiVersion = 1, runId = context.runId })
	if type(l) ~= "table" or type(l.talents) ~= "table" then return nil end
	local sources = type(l.sources) == "table" and l.sources or {}
	local out, byKey, total = { trees = {} }, {}, 0
	for i = 1, table.getn(l.talents) do
		local t = l.talents[i]
		local rank = type(t) == "table" and tonumber(t.rank) or 0
		if rank and rank > 0 then
			local key = tostring(t.treeKey or "?")
			local tree = byKey[key]
			if not tree and table.getn(out.trees) < MAX_TREES then
				tree = { key = key, name = TreeName(key), points = 0, talents = {} }
				byKey[key] = tree
				table.insert(out.trees, tree)
			end
			if tree then
				local src = t.sourceKey and sources[t.sourceKey]
				local icon = type(src) == "table" and type(src.icon) == "table" and src.icon.status == "ready" and src.icon.path or nil
				table.insert(tree.talents, { name = type(src) == "table" and src.name or tostring(t.sourceKey or "?"),
					icon = icon, rank = rank })
				tree.points = tree.points + rank
				total = total + rank
			end
		end
	end
	out.total = total
	return out
end

------------------------------------------------------------------------ drawing
local function TalentTip()
	local d = this.data
	if not (d and GameTooltip) then return end
	GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
	GameTooltip:AddLine(d.name, 0.98, 0.85, 0.52)
	GameTooltip:AddLine(C.F("Rank {1}", d.rank), 1, 1, 1)
	C.ShowTip()
end

local function NewIcon(col)
	local b = CreateFrame("Frame", nil, col.frame)
	b:SetWidth(ICON)
	b:SetHeight(ICON)
	b:EnableMouse(true)
	b:SetScript("OnEnter", TalentTip)
	b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	b.edge = C.Tex(b, "BACKGROUND", C.FLAT)
	b.edge:SetPoint("TOPLEFT", b, "TOPLEFT", -1, 1)
	b.edge:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, -1)
	b.edge:SetVertexColor(0.95, 0.79, 0.44, 0.9)
	b.icon = b:CreateTexture(nil, "BORDER")
	b.icon:SetAllPoints(b)
	b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	-- the rank, as on the skill bar: a dark box in a gold rim on the bottom right corner
	b.rim = C.Tex(b, "ARTWORK", C.FLAT)
	b.rim:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 3, -3)
	b.rim:SetHeight(13)
	b.rim:SetVertexColor(0.91, 0.70, 0.30, 1)
	b.back = C.Tex(b, "OVERLAY", C.FLAT)
	b.back:SetPoint("TOPLEFT", b.rim, "TOPLEFT", 1, -1)
	b.back:SetPoint("BOTTOMRIGHT", b.rim, "BOTTOMRIGHT", -1, 1)
	b.back:SetVertexColor(0.05, 0.04, 0.03, 0.92)
	local top = CreateFrame("Frame", nil, b)
	top:SetAllPoints(b)
	top:SetFrameLevel(b:GetFrameLevel() + 2)
	b.rank = C.Text(top, C.FONT, 10, "OUTLINE", "CENTER", 24)
	b.rank:SetPoint("CENTER", b.rim, "CENTER", 1, 0)
	b.rank:SetTextColor(0.98, 0.85, 0.52)
	table.insert(col.icons, b)
	return b
end

local function NewCol(i)
	local col = { icons = {} }
	local f = CreateFrame("Frame", nil, root)
	col.frame = f
	f:SetWidth(COL_W)
	f:SetFrameLevel(root:GetFrameLevel() + 1)
	col.back = C.Tex(f, "BACKGROUND", C.FLAT)
	col.back:SetAllPoints(f)
	col.back:SetVertexColor(0, 0, 0, 0.32)
	col.line = C.Tex(f, "BORDER", C.FLAT)
	col.line:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -TREE_H + 6)
	col.line:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -TREE_H + 6)
	col.line:SetHeight(1)
	col.line:SetVertexColor(0.95, 0.79, 0.44, 0.35)
	-- the tree's name across the column, its points under it
	col.name = C.Text(f, C.TITLE_FONT, 14, "OUTLINE", "LEFT", COL_W - PAD * 2)
	col.name:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -8)
	col.name:SetTextColor(0.98, 0.85, 0.52)
	col.points = C.Text(f, C.FONT, 11, "OUTLINE", "LEFT", COL_W - PAD * 2)
	col.points:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -27)
	col.points:SetTextColor(0.92, 0.9, 0.85)
	cols[i] = col
	return col
end

local function Fill(data)
	local trees = data and data.trees or {}
	local n = table.getn(trees)
	local rows = 1
	for i = 1, n do rows = math.max(rows, math.ceil(table.getn(trees[i].talents) / PER_ROW)) end
	local colH = TREE_H + rows * (ICON + GAP + 4) + PAD
	local w = math.max(1, n) * COL_W + (math.max(1, n) - 1) * COL_GAP + SIDE * 2
	C.Size(root, math.max(w, 320), HEAD_H + (n > 0 and colH or 40) + FOOT_H)
	for i = 1, MAX_TREES do
		local tree, col = trees[i], cols[i]
		if tree then
			col = col or NewCol(i)
			C.Place(col.frame, "TOPLEFT", root, "TOPLEFT", SIDE + (i - 1) * (COL_W + COL_GAP), -HEAD_H)
			C.Size(col.frame, COL_W, colH)
			C.SetText(col.name, C.L(tree.name))
			C.SetText(col.points, C.F("{1} points", tree.points))
			for j = 1, table.getn(tree.talents) do
				local t = tree.talents[j]
				local b = col.icons[j] or NewIcon(col)
				b.data = t
				local r, c = math.floor((j - 1) / PER_ROW), math.mod(j - 1, PER_ROW)
				C.Place(b, "TOPLEFT", col.frame, "TOPLEFT", PAD + c * (ICON + GAP), -TREE_H - 4 - r * (ICON + GAP + 4))
				if b.iconPath ~= t.icon then
					b.iconPath = t.icon
					b.icon:SetTexture(t.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
				end
				local text = tostring(t.rank)
				C.SetText(b.rank, text)
				C.Width(b.rim, 8 + 6 * string.len(text))
				C.Vis(b, true)
			end
			for j = table.getn(tree.talents) + 1, table.getn(col.icons) do C.Vis(col.icons[j], false) end
			C.Vis(col.frame, true)
		elseif col then
			C.Vis(col.frame, false)
		end
	end
	-- the empty states, and the total at the foot
	local empty = nil
	if data == false then empty = C.L("Your talents show here during a run.")
	elseif n == 0 then empty = C.L("No talents learned yet.") end
	C.SetText(root.empty, empty or "")
	C.Vis(root.empty, empty ~= nil)
	C.SetText(root.total, (data and n > 0) and C.F("{1} points spent", data.total) or "")
end

local function Refresh()
	local data = Read()
	if data == nil and S.shown ~= nil then return end -- not in yet: keep what shows
	S.shown = data
	Fill(data)
end

------------------------------------------------------------------------ the window
local function Build()
	root = CreateFrame("Frame", "CreedUITalents", UIParent)
	root:SetWidth(640)
	root:SetHeight(320)
	if C.AboveHub then C.AboveHub(root) else root:SetFrameStrata("DIALOG") end
	root:EnableMouse(true)
	root:Hide()
	root.deco = C.Panel(root, false)
	C.PanelTheme(root.deco, C.Pal())
	root.title = C.Text(root, C.TITLE_FONT, 22, "OUTLINE", "LEFT", 300)
	root.title:SetPoint("TOPLEFT", root, "TOPLEFT", SIDE + 2, -12)
	root.title:SetTextColor(0.98, 0.85, 0.52)
	C.LText(root.title, "Talents")
	root.sub = C.Text(root, C.FONT, 11, "OUTLINE", "LEFT", 400)
	root.sub:SetPoint("TOPLEFT", root.title, "BOTTOMLEFT", 0, -2)
	root.sub:SetTextColor(0.75, 0.75, 0.8)
	C.LText(root.sub, "What this run plays with")
	root.empty = C.Text(root, C.FONT, 12, "OUTLINE", "CENTER", 300)
	root.empty:SetPoint("TOP", root, "TOP", 0, -HEAD_H - 12)
	root.empty:SetTextColor(0.8, 0.8, 0.8)
	root.total = C.Text(root, C.FONT, 12, "OUTLINE", "RIGHT", 300)
	root.total:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -SIDE - 2, 12)
	root.total:SetTextColor(0.98, 0.85, 0.52)
	local close = C.Button(root, 20, 20, "x", function() root:Hide() end)
	close:SetPoint("TOPRIGHT", root, "TOPRIGHT", -10, -10)
	if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "CreedUITalents") end
	C.Movable(root, "talents", "Talents", function(f)
		f:ClearAllPoints()
		f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
	end)
	root:SetScript("OnShow", function() S.readAt = -10 end)
	root:SetScript("OnUpdate", function()
		if S.broken then return end
		local now = GetTime()
		if now - S.readAt < READ_EVERY then return end
		S.readAt = now
		local ok, err = pcall(Refresh)
		if not ok then
			S.broken = true
			root:Hide()
			C.Print(C.L("the talent window stopped after an error: ") .. tostring(err))
		end
	end)
end

-- a new language: the open window's words at once
C.OnLanguage(function()
	if root and root:IsShown() and not S.broken then pcall(Fill, S.shown) end
end)

-- open or close it (the Talents tab, /creed talents)
function C.ToggleTalents()
	if not root then Build() end
	if root:IsShown() then
		root:Hide()
	else
		S.broken = false
		root:Show()
		local ok = pcall(Refresh)
		if not ok then S.broken = true end
	end
end
