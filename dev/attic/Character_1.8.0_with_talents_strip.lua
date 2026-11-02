-- Kept for later: Character.lua as it was in 1.8.0, with the talents strip under the model
-- (Talents(), LayTalents, the strip in Build). Removed in 1.8.1 until the game says where it
-- keeps the run's talents. Not loaded by the addon.
-- Creed UI: the character window, dressed. The game's own stays (its tabs, the gear slots you drag
-- to, the model you turn): only its art goes, for Creed UI's dark glass in a gold rail, the portrait
-- in a ring, each gear slot in the skill bar's metal and lit in its item's rarity color. The run's
-- numbers, drawn by the game in its boxes and its Run Stats panel, are read off those and set out
-- again in a panel of their own beside the window: grouped, the ones at nothing dimmed, a change
-- since your last look flashing by its number. The talents you hold sit in a strip at its foot.
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
local ICON, ICON_GAP = 24, 5
local FLASH = 5 -- seconds a change shows by its number
local ART_PATHS = { "PaperDollInfoFrame", "CharacterFrame\\", "UI%-Character" }

local db
local S = { dressed = false, hooked = false, broken = false, kept = {}, stats = {}, boxes = {}, nums = {}, flashAt = {},
	flashText = {}, readClock = 0, scanClock = 0, talentClock = 0, slotClock = 0, layoutKey = nil, statKey = nil,
	talentKey = nil, opened = false }
local W = { bez = {}, rows = {}, heads = {}, icons = {}, tabs = {} }
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
local function PutBack(pageOnly)
	for o, k in pairs(S.kept) do
		if not pageOnly or k.page then
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
		return head:GetLeft() - fl - 9, -12, hands:GetRight() - fl + 9, main:GetBottom() - ft - 12,
			head:GetRight() - fl, hands:GetLeft() - fl, main:GetTop() - ft
	end
	return 12, -12, 350, -434, 58, 304, -386
end

------------------------------------------------------------------------ building
local function Build()
	if W.bg then return end
	local pd = PaperDollFrame
	-- the body: under the window's own (its portrait and texts, its slots and model)
	W.bg = CreateFrame("Frame", "CreedUICharacterBack", pd)
	W.bg.creed = true
	W.bg.deco = C.Panel(W.bg, false)
	W.header = C.Tex(W.bg, "ARTWORK", C.FLAT)
	W.header:SetPoint("TOPLEFT", W.bg, "TOPLEFT", 70, -8)
	W.header:SetPoint("TOPRIGHT", W.bg, "TOPRIGHT", -34, -8)
	W.header:SetHeight(36)
	W.header:SetGradientAlpha("VERTICAL", 0, 0, 0, 0.0, 0, 0, 0, 0.55)
	-- the portrait in the unit frames' ring, over the window's corner
	W.face = CreateFrame("Frame", "CreedUICharacterFace", pd)
	W.face.creed = true
	W.face:SetWidth(66)
	W.face:SetHeight(66)
	W.face:SetPoint("CENTER", W.bg, "TOPLEFT", 26, -22)
	W.faceBg = C.Tex(W.face, "BACKGROUND", C.ART .. "Badge")
	W.faceBg:SetWidth(60)
	W.faceBg:SetHeight(60)
	W.faceBg:SetPoint("CENTER", W.face, "CENTER", 0, 0)
	W.portrait = W.face:CreateTexture(nil, "BORDER")
	W.portrait:SetWidth(54)
	W.portrait:SetHeight(54)
	W.portrait:SetPoint("CENTER", W.face, "CENTER", 0, 0)
	W.ring = C.Tex(W.face, "ARTWORK", C.ART .. "Portrait")
	W.ring:SetAllPoints(W.face)
	-- the name in the timer's title face, the game's line under it in the game's own
	W.name = C.Text(W.face, C.TITLE_FONT, 17, nil, "CENTER", 220)
	W.name:SetPoint("TOP", W.bg, "TOP", 18, -10)
	W.level = W.face:CreateFontString(nil, "OVERLAY")
	W.level:SetFont(C.FONT, 11)
	W.level:SetPoint("TOP", W.name, "BOTTOM", 0, -2)
	W.level:SetWidth(240)
	W.level:SetJustifyH("CENTER")
	W.level:SetShadowOffset(1, -1)

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

	-- the talents, in a strip at the window's foot over the model's feet
	local t = CreateFrame("Frame", "CreedUICharacterTalents", pd)
	t.creed = true
	W.talents = t
	t.bg = C.Tex(t, "BACKGROUND", C.FLAT)
	t.bg:SetAllPoints(t)
	t.bg:SetGradientAlpha("VERTICAL", 0.02, 0.02, 0.03, 0.92, 0.05, 0.05, 0.07, 0.8)
	t.line = C.Tex(t, "BORDER", C.FLAT)
	t.line:SetPoint("TOPLEFT", t, "TOPLEFT", 0, 0)
	t.line:SetPoint("TOPRIGHT", t, "TOPRIGHT", 0, 0)
	t.line:SetHeight(1)
	t.head = C.Text(t, C.FONT, 10, nil, "LEFT", 200)
	t.head:SetPoint("TOPLEFT", t, "TOPLEFT", 6, -4)
	C.LText(t.head, "TALENTS")
	t.empty = C.Text(t, C.FONT, 10, nil, "LEFT", 210)
	t.empty:SetPoint("TOPLEFT", t, "TOPLEFT", 6, -20)
	t.empty:SetTextColor(0.6, 0.6, 0.62)
	C.LText(t.empty, "None yet: they show here as you pick them.")
	t:EnableMouse(false)
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
		Fade(run, false, true)
		Deafen(run, 3, true)
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

------------------------------------------------------------------------ talents
-- what the game tells of them: a list of its own where it keeps one, the talent tree's points,
-- and the damage meter's lines that are talents
local function Talents()
	local out, seen = {}, {}
	local function Add(name, icon, rank, max, tab, index)
		if type(name) ~= "string" or name == "" or seen[name] then return end
		seen[name] = true
		table.insert(out, { name = name, icon = icon, rank = rank, max = max, tab = tab, index = index })
	end
	local list = (type(AZS_RUN) == "table" and type(AZS_RUN.talents) == "table" and AZS_RUN.talents)
		or (type(AZS_TALENTS) == "table" and AZS_TALENTS) or nil
	if list then
		for _, t in pairs(list) do
			if type(t) == "string" then
				Add(t)
			elseif type(t) == "table" then
				Add(t.name, t.icon, tonumber(t.rank or t.stacks or t.count), tonumber(t.maxRank or t.max))
			end
		end
	end
	if type(GetNumTalentTabs) == "function" and type(GetNumTalents) == "function" and type(GetTalentInfo) == "function" then
		for tab = 1, (Call(GetNumTalentTabs) or 0) do
			for i = 1, (Call(GetNumTalents, tab) or 0) do
				local ok, name, icon, _, _, rank, max = pcall(GetTalentInfo, tab, i)
				if ok and name and tonumber(rank) and rank > 0 then Add(name, icon, rank, max, tab, i) end
			end
		end
	end
	if C.RefreshSources then C.RefreshSources() end
	local fromMeter = {}
	for _, t in pairs(C.sourceTalents or {}) do table.insert(fromMeter, t) end
	table.sort(fromMeter, function(a, b) return a.name < b.name end)
	for _, t in ipairs(fromMeter) do Add(t.name, t.icon) end
	return out
end

local function TalentTip()
	local t = this.talent
	if not (t and GameTooltip) then return end
	GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
	if t.tab and t.index and GameTooltip.SetTalent and pcall(GameTooltip.SetTalent, GameTooltip, t.tab, t.index) then
		GameTooltip:Show() -- the game's own, in its own face
		return
	end
	GameTooltip:AddLine(t.name, 1, 0.82, 0.3)
	if t.rank and t.max then
		GameTooltip:AddLine(C.F("Rank {1}/{2}", t.rank, t.max), 1, 1, 1)
	elseif t.rank and t.rank > 1 then
		GameTooltip:AddLine(C.F("Rank {1}", t.rank), 1, 1, 1)
	end
	C.ShowTip()
end

local function Icon(i)
	local b = W.icons[i]
	if b then return b end
	b = CreateFrame("Button", nil, W.talents)
	b.creed = true
	b:SetWidth(ICON)
	b:SetHeight(ICON)
	b.icon = b:CreateTexture(nil, "BORDER")
	b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
	b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
	b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	b.bezel = C.Tex(b, "OVERLAY", C.ART .. "Slot")
	b.bezel:SetAllPoints(b)
	b.rank = C.Text(b, C.FONT, 10, "OUTLINE", "RIGHT", 30)
	b.rank:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, 0)
	b:SetScript("OnEnter", TalentTip)
	b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	W.icons[i] = b
	return b
end

local function LayTalents(list, width)
	local key = width .. "|"
	for _, t in ipairs(list) do key = key .. t.name .. (t.rank or "") .. ";" end
	if key == S.talentKey then return end
	S.talentKey = key
	local per = math.max(1, math.floor((width - 10 + ICON_GAP) / (ICON + ICON_GAP)))
	local n = table.getn(list)
	for i = 1, n do
		local t = list[i]
		local b = Icon(i)
		b.talent = t
		b.icon:SetTexture(t.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
		C.SetText(b.rank, (t.rank and t.rank > 1) and tostring(t.rank) or "")
		local col, row = math.mod(i - 1, per), math.floor((i - 1) / per)
		C.Place(b, "TOPLEFT", W.talents, "TOPLEFT", 6 + col * (ICON + ICON_GAP), -18 - row * (ICON + ICON_GAP))
		b:Show()
	end
	for i = n + 1, table.getn(W.icons) do W.icons[i]:Hide() end
	C.Vis(W.talents.empty, n == 0)
	local rows = math.max(1, math.ceil(n / per))
	W.talents:SetHeight(n == 0 and 46 or (22 + rows * (ICON + ICON_GAP)))
end

------------------------------------------------------------------------ dressing and undressing
local function Layout()
	local l, t, r, b, colL, colR, weaponTop = Body()
	local key = string.format("%.1f,%.1f,%.1f,%.1f", l, t, r, b)
	if key == S.layoutKey then return end
	S.layoutKey = key
	W.bg:ClearAllPoints()
	W.bg:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", l, t)
	W.bg:SetPoint("BOTTOMRIGHT", CharacterFrame, "TOPLEFT", r, b)
	-- the stats as tall as the window (taller only if the game shows more than fit)
	S.bodyH = t - b
	W.stats:SetHeight(math.max(S.bodyH, S.statsH or 120))
	local w = colR - colL - 12
	W.talents:ClearAllPoints()
	W.talents:SetPoint("BOTTOMLEFT", CharacterFrame, "TOPLEFT", colL + 6, weaponTop + 8)
	W.talents:SetWidth(w)
	W.talents.empty:SetWidth(w - 12)
	W.talents.empty.mtw = nil
	S.talentKey = nil
	W.talentWidth = w
end

local function Theme(pal)
	C.PanelTheme(W.bg.deco, pal)
	C.PanelTheme(W.stats.deco, pal)
	local mr, mg, mb = C.PanelMetal(pal)
	W.ring:SetVertexColor(mr, mg, mb)
	W.name:SetTextColor(1, 0.84, 0.4)
	W.title:SetTextColor(1, 0.84, 0.4)
	W.talents.line:SetVertexColor(mr, mg, mb, 0.8)
	W.talents.head:SetTextColor(mr * 0.85, mg * 0.85, mb * 0.85)
	for _, h in ipairs(W.heads) do
		h.text:SetTextColor(mr * 0.9, mg * 0.9, mb * 0.9)
		h.line:SetVertexColor(mr, mg, mb, 0.35)
	end
	for _, b in ipairs(W.icons) do b.bezel:SetVertexColor(mr, mg, mb) end
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
	FadeArt(CharacterFrame, true)
	Fade(CharacterFramePortrait, true, true)
	Fade(CharacterNameText, true, true)
	Fade(CharacterLevelText, true, true)
end

local function Dress()
	if S.dressed or S.broken then return end
	Build()
	S.dressed = true
	FadeWindow()
	FadeArt(PaperDollFrame)
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
	W.talents:SetFrameLevel((CharacterModelFrame and CharacterModelFrame:GetFrameLevel() or PaperDollFrame:GetFrameLevel()) + 4)
	W.bg:Show()
	W.face:Show()
	W.stats:Show()
	W.talents:Show()
	if type(SetPortraitTexture) == "function" then pcall(SetPortraitTexture, W.portrait, "player") end
	if CharacterLevelText and CharacterLevelText.GetFont then
		local face, size, flags = CharacterLevelText:GetFont()
		if face then W.level:SetFont(face, size or 11, flags) end
	end
	S.layoutKey, S.stamp, S.statKey, S.talentKey = nil, -1, nil, nil
	S.scanClock, S.readClock, S.talentClock, S.slotClock = 0, 0, 0, 0
	S.nums = {} -- a new look: changes count from the last one's numbers
end

local function Undress()
	if not S.dressed then return end
	S.dressed = false
	PutBack()
	if W.bg then
		W.bg:Hide()
		W.face:Hide()
		W.stats:Hide()
		W.talents:Hide()
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
		StepTabs()
	end
	S.talentClock = S.talentClock - dt
	if S.talentClock <= 0 then
		S.talentClock = 2
		LayTalents(Talents(), W.talentWidth or 200)
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

-- another page (Skills, Honor) or the window shut: what's ours goes with this page, the window's
-- own pieces and the game's Run Stats come back; the tabs stay dressed
local function Hidden()
	if not S.dressed then return end
	local ok, err = pcall(PutBack, true)
	if not ok then Fail(err) end
end

local function Hook()
	if S.hooked or type(PaperDollFrame) ~= "table" or type(CharacterFrame) ~= "table" then return end
	S.hooked = true
	local onShow, onHide = PaperDollFrame:GetScript("OnShow"), PaperDollFrame:GetScript("OnHide")
	PaperDollFrame:SetScript("OnShow", function()
		if onShow then onShow() end
		Shown()
		if S.dressed and W.bg then
			FadeWindow()
			S.nums, S.scanClock, S.readClock = {}, 0, 0
			if type(SetPortraitTexture) == "function" then pcall(SetPortraitTexture, W.portrait, "player") end
		end
	end)
	PaperDollFrame:SetScript("OnHide", function()
		if onHide then onHide() end
		Hidden()
	end)
	-- the driver: only while the page is open (its OnUpdate stops when it's hidden)
	local driver = CreateFrame("Frame", "CreedUICharacterDriver", PaperDollFrame)
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
	ev:SetScript("OnEvent", function()
		if not S.dressed or arg1 ~= "player" then return end
		if event == "UNIT_PORTRAIT_UPDATE" then
			if type(SetPortraitTexture) == "function" then pcall(SetPortraitTexture, W.portrait, "player") end
		else
			S.slotClock = 0
		end
	end)
end

local function Apply()
	if type(CharacterFrame) ~= "table" or type(PaperDollFrame) ~= "table" then return end
	Hook()
	if db.enabled and not S.broken then
		if PaperDollFrame:IsVisible() then Shown() end
	else
		Undress()
	end
end

------------------------------------------------------------------------ what the game tells addons
-- /creed probe: the game's run tables and what Creed UI found of them, for adding what's missing
function C.Probe()
	C.Print(C.L("what the game tells addons:"))
	for _, name in ipairs({ "AZS_STATS", "AZS_RUN", "AZS_TALENTS" }) do
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
	local tal = {}
	for _, t in ipairs(Talents()) do table.insert(tal, t.name) end
	C.Print("talents: " .. (table.getn(tal) > 0 and table.concat(tal, ", ") or "-"))
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
	note = "The game's character window in Creed UI's panel: each gear slot in metal, lit in its item's rarity color; your run's stats grouped beside it (the ones at nothing dimmed, a change since your last look flashing by its number); the talents you hold at its foot.",
	get = function() return db and db.enabled end,
	set = function(on)
		if db then
			db.enabled = on and true or false
			if on then S.broken = false end
			Apply()
		end
	end,
})
