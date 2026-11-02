-- Creed UI: the skill bar. Your six run abilities and your racial, each with a cooldown that
-- drains off its icon; the jewelry you picked from the cards (neck, two rings, two trinkets) in sockets
-- rimmed with their rarity; your run's experience; and docked beside them your kills, gold and
-- the next cache's price (Tally.lua), all on a gold-framed panel with a dragon on each end, wrapped in its wing. Hover anything for the game's own tooltip: an ability's, or what a piece of
-- jewelry gives you. While it's on, the game's bar and build rows are tucked away; turning it
-- off brings them back.

local C = CreedUI
local DEFAULTS = { enabled = true, scale = 1 }
local SLOT, GAP, RACIAL, JEWEL, SEP = 36, 4, 40, 32, 12
local INSET, FOOT = 14, 10 -- room for the panel's rail: at the sides, under the slots
local ROW_Y = FOOT + RACIAL * 0.5 -- the slots' middle, from the bottom
local DOCK_GAP = 14 -- between the jewelry and the kills, gold and cache docked in the panel
local ABILITY_SLOTS = { 1, 2, 3, 4, 5, 6 }
local RACIAL_SLOT = 12
local JEWEL_SLOTS = {
	{ name = "NeckSlot", id = 2 }, { name = "Finger0Slot", id = 11 }, { name = "Finger1Slot", id = 12 },
	{ name = "Trinket0Slot", id = 13 }, { name = "Trinket1Slot", id = 14 },
}
local QUALITY = {
	[0] = { 0.62, 0.62, 0.62 }, [1] = { 0.92, 0.92, 0.92 }, [2] = { 0.12, 1.00, 0.00 },
	[3] = { 0.00, 0.44, 0.87 }, [4] = { 0.64, 0.21, 0.93 }, [5] = { 1.00, 0.50, 0.00 },
}
local XP_COLORS = { { 0.34, 0.22, 0.02 }, { 0.86, 0.64, 0.10 }, { 1.00, 0.92, 0.46 } } -- gold

local db
local root, slots, jewels, xp = nil, {}, {}, nil
local S = { dataClock = 0, takeClock = 0, width = 0, lvl = nil, wrap = false, flashLevel = 0 }

local Call = C.Call -- no stray nil arguments (see Core)

------------------------------------------------------------------------ a slot
local function ShowTip(s)
	if not GameTooltip or C.unlocked then return end
	GameTooltip:SetOwner(s.button, "ANCHOR_NONE")
	GameTooltip:ClearAllPoints()
	GameTooltip:SetPoint("BOTTOM", s.button, "TOP", 0, 10)
	local shown = false
	if s.kind == "jewel" then
		if s.has and type(GameTooltip.SetInventoryItem) == "function" then
			shown = pcall(GameTooltip.SetInventoryItem, GameTooltip, "player", s.inv)
		end
		if not s.has then
			GameTooltip:AddLine(C.L(s.label), 1, 0.82, 0.3)
			GameTooltip:AddLine(C.L("Empty: pick one from the cards."), 0.8, 0.8, 0.8)
			shown = true
		end
	elseif s.has and type(GameTooltip.SetAction) == "function" then
		shown = pcall(GameTooltip.SetAction, GameTooltip, s.action)
	elseif not s.has then
		GameTooltip:AddLine(C.L(s.kind == "racial" and "Racial ability" or "Empty ability slot"), 1, 0.82, 0.3)
		GameTooltip:AddLine(C.L("A new ability from the cards goes here."), 0.8, 0.8, 0.8)
		shown = true
	end
	if shown then if s.has then GameTooltip:Show() else C.ShowTip() end end -- the game's own lines in its own face
end

local function NewSlot(kind, size, label)
	local s = { kind = kind, size = size, label = label, hot = 0, flash = 0, wasCooling = false, cdStart = 0, cdDur = 0 }
	local b = CreateFrame("Button", nil, root)
	s.button = b
	b:SetWidth(size)
	b:SetHeight(size)
	b:EnableMouse(true)
	local inset = kind == "jewel" and size * 0.16 or 3
	s.inner = size - inset * 2
	s.bg = C.Tex(b, "BACKGROUND", C.FLAT)
	s.bg:SetPoint("TOPLEFT", b, "TOPLEFT", inset, -inset)
	s.bg:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -inset, inset)
	s.bg:SetVertexColor(0.03, 0.03, 0.04, 0.92)
	s.icon = b:CreateTexture(nil, "BORDER")
	s.icon:SetPoint("TOPLEFT", b, "TOPLEFT", inset, -inset)
	s.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -inset, inset)
	s.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	-- the cooldown: a dark veil that drains up off the icon, with a lit edge
	s.shade = C.Tex(b, "ARTWORK", C.FLAT)
	s.shade:SetPoint("TOP", b, "TOP", 0, -inset)
	s.shade:SetWidth(s.inner)
	s.shade:SetVertexColor(0, 0, 0, 0.66)
	s.edge = C.Tex(b, "ARTWORK", C.FLAT, "ADD")
	s.edge:SetWidth(s.inner)
	s.edge:SetHeight(1.5)
	s.bezel = C.Tex(b, "OVERLAY", C.ART .. (kind == "jewel" and "Jewel" or "Slot"))
	s.bezel:SetAllPoints(b)
	s.text = C.Text(b, C.FONT, kind == "jewel" and 11 or 14, "OUTLINE", "CENTER", size + 20)
	s.text:SetPoint("CENTER", b, "CENTER", 0, 0)
	s.top = CreateFrame("Frame", nil, b)
	s.top:SetAllPoints(b)
	s.glow = C.Tex(s.top, "OVERLAY", C.ART .. "Glow", "ADD")
	s.glow:SetPoint("CENTER", b, "CENTER", 0, 0)
	C.Vis(s.glow, false)
	C.Vis(s.shade, false)
	C.Vis(s.edge, false)
	b:SetScript("OnEnter", function()
		s.hovering = true
		ShowTip(s)
	end)
	b:SetScript("OnLeave", function()
		s.hovering = false
		if GameTooltip then GameTooltip:Hide() end
	end)
	return s
end

------------------------------------------------------------------------ layout
local function Layout()
	local x = 0
	for i = 1, table.getn(ABILITY_SLOTS) do
		slots[i].x = x + SLOT * 0.5
		x = x + SLOT + GAP
	end
	x = x - GAP + SEP
	slots[7].x = x + RACIAL * 0.5
	x = x + RACIAL + SEP
	for i = 1, table.getn(jewels) do
		local j = jewels[i]
		if j.visible then
			j.x = x + JEWEL * 0.5
			x = x + JEWEL + GAP
		end
	end
	x = x - GAP
	S.width = x
	root:SetWidth(x + INSET * 2)
	local left = INSET
	for i = 1, 7 do
		local s = slots[i]
		C.Place(s.button, "CENTER", root, "BOTTOMLEFT", left + s.x, ROW_Y)
	end
	for i = 1, table.getn(jewels) do
		local j = jewels[i]
		if j.visible then C.Place(j.button, "CENTER", root, "BOTTOMLEFT", left + j.x, ROW_Y) end
		C.Vis(j.button, j.visible)
	end
	C.BarLayout(xp, x - 20, 8)
	xp.frame:ClearAllPoints()
	xp.frame:SetPoint("BOTTOM", root, "BOTTOMLEFT", left + x * 0.5, FOOT + RACIAL + 13)
	xp.text:SetWidth(x)
	-- thin metal bars between the spells, the racial and the jewelry
	local a = left + slots[6].x + SLOT * 0.5 + SEP * 0.5
	local b = left + slots[7].x + RACIAL * 0.5 + SEP * 0.5
	C.Place(root.dividers[1], "CENTER", root, "BOTTOMLEFT", a, ROW_Y)
	C.Place(root.dividers[2], "CENTER", root, "BOTTOMLEFT", b, ROW_Y)
	-- where the kills, gold and cache dock (from the bar's right edge, at its middle), a bar before them
	C.barDockX = DOCK_GAP - INSET
	C.Place(root.dividers[3], "CENTER", root, "RIGHT", DOCK_GAP * 0.5 - INSET, 0)
end

-- the panel spans the bar and, docked in it, the kills, gold and cache; it glides as they come
local function StepDock(dt)
	local d = C.tallyDock
	local target = 0
	if d and d.on and d.shown > 0.01 then target = (d.w + DOCK_GAP) * d.shown end
	local w = C.Toward(S.dock or 0, target, 10, dt)
	if math.abs(w - target) < 0.3 then w = target end
	if w ~= S.dock then
		S.dock = w
		root.panel:ClearAllPoints()
		root.panel:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
		root.panel:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", w, 0)
	end
	C.Vis(root.dividers[3], w > 20)
end

------------------------------------------------------------------------ reading
local function ReadAbilities(cds)
	for i = 1, 7 do
		local s = slots[i]
		local tex = Call(GetActionTexture, s.action)
		local has = (Call(HasAction, s.action) and tex) and true or false
		if s.has ~= has or s.tex ~= tex then
			s.has, s.tex = has, tex
			if has then
				s.icon:SetTexture(tex)
				s.iconA, s.iconMax = 0, 1
				C.Alpha(s.icon, 0)
			end
			C.Vis(s.icon, has)
			if s.hovering then ShowTip(s) end
		end
		if cds then
			local start, duration, enable = Call(GetActionCooldown, s.action)
			if has and start and duration and duration > 0 and enable ~= 0 then
				s.cdStart, s.cdDur = start, duration
			else
				s.cdStart, s.cdDur = 0, 0
			end
		end
	end
end

local function ReadJewelry(cds)
	local changed = false
	for i = 1, table.getn(jewels) do
		local j = jewels[i]
		local tex = Call(GetInventoryItemTexture, "player", j.inv)
		local has = (type(tex) == "string" and tex ~= "") and true or false
		local q = has and Call(GetInventoryItemQuality, "player", j.inv) or nil
		if j.has ~= has or j.tex ~= tex or j.q ~= q then
			j.has, j.tex, j.q = has, tex, q
			if has then
				j.icon:SetTexture(tex)
				j.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
				j.iconA, j.iconMax = 0, 1
				C.Alpha(j.icon, 0)
				if j.seenOnce then j.flashAge = 0 end -- a new pick from the cards
			elseif j.empty then
				j.icon:SetTexture(j.empty)
				j.icon:SetTexCoord(0, 1, 0, 1)
				j.iconA, j.iconMax = 0, 0.35
				C.Alpha(j.icon, 0)
			end
			j.seenOnce = true
			C.Vis(j.icon, has or j.empty ~= nil)
			j.palStamp = nil -- recolor the rim
			if j.hovering then ShowTip(j) end
		end
		local visible = has or not j.optional
		if j.visible ~= visible then
			j.visible = visible
			changed = true
		end
		if cds then
			local start, duration, enable = nil, nil, nil
			if has then start, duration, enable = Call(GetInventoryItemCooldown, "player", j.inv) end
			if start and duration and duration > 0 and enable ~= 0 then
				j.cdStart, j.cdDur = start, duration
			else
				j.cdStart, j.cdDur = 0, 0
			end
		end
	end
	if changed then Layout() end
end

------------------------------------------------------------------------ drawing
local function StepSlot(s, now, dt, pal)
	-- cooldown: the veil drains upward; a lit edge rides on it; the seconds count down
	local left = s.cdStart + s.cdDur - now
	local cooling = s.cdDur > 0 and left > 0
	if cooling then
		local frac = C.Clamp(left / s.cdDur, 0, 1)
		local h = s.inner * frac
		if h < 0.5 then
			C.Vis(s.shade, false)
			C.Vis(s.edge, false)
		else
			s.shade:SetHeight(h)
			C.Vis(s.shade, true)
			C.Place(s.edge, "CENTER", s.button, "TOP", 0, -(s.size - s.inner) * 0.5 - h)
			local g = pal.glow
			C.Color(s.edge, g[1], g[2], g[3], 0.45)
			C.Vis(s.edge, true)
		end
		-- every cooldown counts: whole seconds, then tenths for the last three (so the fast
		-- skills show theirs too)
		if s.cdDur >= 0.5 then
			if left > 3 then
				C.SetText(s.text, tostring(math.ceil(left - 0.01)))
				C.TextColor(s.text, 1, 1, 1)
			else
				C.SetText(s.text, string.format("%.1f", math.max(0.1, math.ceil(left * 10 - 0.01) / 10)))
				C.TextColor(s.text, 1, 0.86, 0.3)
			end
			C.Vis(s.text, true)
		else
			C.Vis(s.text, false)
		end
	else
		C.Vis(s.shade, false)
		C.Vis(s.edge, false)
		C.Vis(s.text, false)
		if s.wasCooling and s.lastDur and s.lastDur > 1.6 then
			s.flashAge = 0 -- ready again: a quick bloom
		end
	end
	s.wasCooling = cooling
	if cooling then s.lastDur = s.cdDur end

	-- the bloom when it comes back (or a new item lands), and a gentle lift while hovered
	local bloom = 0
	if s.flashAge then
		s.flashAge = s.flashAge + dt
		local age = s.flashAge
		bloom = C.Smooth(age / 0.08) * (1 - C.Smooth((age - 0.08) / 0.4))
		if age > 0.5 then s.flashAge = nil end
	end
	s.hot = C.Toward(s.hot, s.hovering and 1 or 0, 12, dt)
	if s.hot < 0.002 then s.hot = 0 elseif s.hot > 0.998 then s.hot = 1 end
	-- a new icon fades in
	if s.iconA and s.iconA < 1 then
		s.iconA = C.Toward(s.iconA, 1, 9, dt)
		if s.iconA > 0.995 then s.iconA = 1 end
		C.Alpha(s.icon, s.iconA * (s.iconMax or 1))
	end
	local a = 0.75 * bloom + 0.3 * s.hot
	if a > 0.01 then
		local g = pal.glow
		local size = s.size * (1.5 + 0.5 * C.Clamp((s.flashAge or 0.5) / 0.5, 0, 1))
		C.Size(s.glow, size, size)
		C.Color(s.glow, g[1], g[2], g[3], a)
		C.Vis(s.glow, true)
	else
		C.Vis(s.glow, false)
	end
end

local function Theme(pal)
	local rim = pal.rim
	C.PanelTheme(root.deco, pal)
	local mr, mg, mb = C.PanelMetal(pal)
	for i = 1, 3 do root.dividers[i]:SetVertexColor(mr, mg, mb) end
	for i = 1, 7 do
		local s = slots[i]
		if s.kind == "racial" then
			s.bezel:SetVertexColor(1, 0.82, 0.38)
		else
			s.bezel:SetVertexColor(rim[1], rim[2], rim[3])
		end
	end
	C.BarTheme(xp, pal)
end

local function JewelRim(j)
	local c = j.has and QUALITY[j.q or 1] or nil
	if c then
		j.bezel:SetVertexColor(0.45 + c[1] * 0.55, 0.45 + c[2] * 0.55, 0.45 + c[3] * 0.55)
	else
		local rim = C.Pal().rim
		j.bezel:SetVertexColor(rim[1] * 0.7, rim[2] * 0.7, rim[3] * 0.7)
	end
end

-- XP a second: what the run gained over the last half minute of its clock (which stops for the
-- cards and pauses, so picking doesn't drag it down), a sample a second; nil until 5 s of it
local PACE_WINDOW = 30
local pace = { banked = 0, samples = {} }
local function Pace(cur, need, lvl)
	local t = Call(AZS_GetRunTime)
	local runId = type(AZS_ZONE) == "table" and AZS_ZONE.run or nil
	if not t then return nil end
	if runId ~= pace.run or (pace.lvl and lvl < pace.lvl) or (pace.t and t < pace.t - 1) then
		pace.run, pace.banked, pace.samples, pace.lvl, pace.need = runId, 0, {}, nil, nil -- a new run
	end
	-- a level up banks the level just filled
	if pace.lvl and lvl > pace.lvl and pace.need then pace.banked = pace.banked + pace.need * (lvl - pace.lvl) end
	pace.lvl, pace.need, pace.t = lvl, need, t
	local total = pace.banked + cur
	local s = pace.samples
	local n = table.getn(s)
	if n == 0 or t - s[n].t >= 1 then
		table.insert(s, { t = t, xp = total })
		while t - s[1].t > PACE_WINDOW + 0.5 do table.remove(s, 1) end
	end
	local span = t - s[1].t
	if span < 5 then return nil end
	return math.max(0, (total - s[1].xp) / span)
end

local function Rate(r)
	if r >= 1000 then return string.format("%.1fk", r / 1000) end
	if r >= 10 then return tostring(math.floor(r + 0.5)) end
	return string.format("%.1f", r)
end

local function StepXP(dt, now)
	local run = type(AZS_RUN) == "table" and AZS_RUN or {}
	local phase = Call(AZS_GetPhase)
	local inRun = phase and phase ~= "ready"
	local cur, need, lvl
	if inRun and tonumber(run.xpn) and run.xpn > 0 then
		cur, need, lvl = tonumber(run.xp) or 0, run.xpn, tonumber(run.lvl) or 1
		S.lastXP, S.lastNeed, S.lastLvl = cur, need, lvl
	elseif inRun and S.lastNeed then
		cur, need, lvl = S.lastXP, S.lastNeed, S.lastLvl -- a moment without the run's numbers: hold
	else
		cur, need, lvl = Call(UnitXP, "player") or 0, Call(UnitXPMax, "player") or 0, Call(UnitLevel, "player") or 1
	end
	if need <= 0 then
		C.Vis(xp.frame, false)
		return
	end
	C.Vis(xp.frame, true)
	local frac = C.Clamp(cur / need, 0, 1)
	-- a level up runs the bar to the end, flashes, and starts the next level from empty
	if S.lvl and lvl > S.lvl then
		S.wrap = true
		S.flashLevel = 1
	elseif S.lvl and lvl < S.lvl then
		xp.snap = true -- a new run
	end
	S.lvl = lvl
	if S.wrap then
		C.BarStep(xp, 1, dt, now)
		if xp.value > 0.995 then
			-- the full bar stays as a pale echo that drains into the new level's start
			S.wrap = false
			xp.value, xp.vel, xp.echo, xp.echoHold = 0, 0, 1, 0.3
		end
	else
		C.BarStep(xp, frac, dt, now)
	end
	S.flashLevel = math.max(0, S.flashLevel - dt * 1.4)
	-- the level and its XP, then the pace: XP a second
	local text = C.F("Level {1}", lvl) .. "  -  " .. math.floor(cur + 0.5) .. " / " .. math.floor(need + 0.5)
	local rate = inRun and run.xpn and Pace(cur, need, lvl) or nil
	if rate then text = text .. "  -  " .. C.F("{1} xp/s", Rate(rate)) end
	C.SetText(xp.text, text)
	local f = C.Smooth(S.flashLevel) -- cream on the gold bar, white as it levels
	C.TextColor(xp.text, 1, 0.95 + 0.05 * f, 0.84 + 0.16 * f)
end

local stamp = -1
-- While the cards are up (or the game is paused) the run stands still, and so do the cooldowns:
-- they hold where they were (the game's own numbers jump about then) and go on from there after.
local FROZEN = { choosing = true, paused = true }

local function Thaw(list, held)
	for i = 1, table.getn(list) do
		local s = list[i]
		if s.cdStart and s.cdStart > 0 then s.cdStart = s.cdStart + held end
	end
end

local function Step(dt)
	local real = GetTime()
	-- away while the cards are up: the panel would lie over their buttons
	local k = 1 - C.cardsFade
	if k ~= S.cardsK then
		S.cardsK = k
		root:SetAlpha(k)
		if k < 0.01 then root:Hide() else root:Show() end
	end
	local phase = Call(AZS_GetPhase)
	local frozen = phase and FROZEN[phase] and true or false
	if frozen then
		if not S.freezeAt then S.freezeAt = real end
	elseif S.freezeAt then
		local held = real - S.freezeAt
		Thaw(slots, held)
		Thaw(jewels, held)
		S.freezeAt = nil
	end
	local now = S.freezeAt or real
	S.dataClock = S.dataClock - dt
	if S.dataClock <= 0 then
		S.dataClock = 0.1
		ReadAbilities(not frozen)
		S.jewelClock = (S.jewelClock or 0) - 1
		if S.jewelClock <= 0 then
			S.jewelClock = 5 -- jewelry twice a second
			ReadJewelry(not frozen)
		end
	end
	local pal = C.Pal()
	if stamp ~= C.palStamp then
		stamp = C.palStamp
		Theme(pal)
		for i = 1, table.getn(jewels) do jewels[i].palStamp = nil end
	end
	for i = 1, 7 do StepSlot(slots[i], now, dt, pal) end
	for i = 1, table.getn(jewels) do
		local j = jewels[i]
		if j.visible then
			if j.palStamp ~= C.palStamp then
				j.palStamp = C.palStamp
				JewelRim(j)
			end
			StepSlot(j, now, dt, pal)
		end
	end
	StepXP(dt, now)
	StepDock(dt)
	C.PanelStep(root.deco, real)

	S.takeClock = S.takeClock - dt
	if S.takeClock <= 0 then
		S.takeClock = 2
		C.TakeHud("build")
		C.HideStock("MainMenuBar")
	end
end

------------------------------------------------------------------------ setup
local function Levels()
	local base = root:GetFrameLevel()
	for i = 1, 7 do
		slots[i].button:SetFrameLevel(base + 2)
		slots[i].top:SetFrameLevel(base + 3)
	end
	for i = 1, table.getn(jewels) do
		jewels[i].button:SetFrameLevel(base + 2)
		jewels[i].top:SetFrameLevel(base + 3)
	end
	C.BarLevels(xp, base + 1)
	-- the panel under everything: the root's own level, the dragons' eyes over it
	root.panel:SetFrameLevel(base)
	if root.deco.eyeLayer then root.deco.eyeLayer:SetFrameLevel(base + 1) end
end

local function Apply()
	C.barOn = db.enabled and true or false -- on, even while it steps aside for the cards (Tally)
	if db.enabled then
		C.TakeHud("build")
		C.HideStock("MainMenuBar")
		root:Show()
		S.cardsK = nil -- the next step puts it where the cards want it (away, if they're up)
	else
		C.ReleaseHud("build")
		C.RestoreStock("MainMenuBar")
		root:Hide()
		if GameTooltip then GameTooltip:Hide() end
	end
end

C.OnInit(function()
	db = C.DB("bar", DEFAULTS)
	root = CreateFrame("Frame", "CreedUIBar", UIParent)
	root:SetFrameStrata("LOW")
	root:SetHeight(FOOT + RACIAL + 34)
	root:SetScale(db.scale)
	for i = 1, table.getn(ABILITY_SLOTS) do
		local s = NewSlot("spell", SLOT)
		s.action = ABILITY_SLOTS[i]
		slots[i] = s
	end
	slots[7] = NewSlot("racial", RACIAL)
	slots[7].action = RACIAL_SLOT
	for i = 1, table.getn(JEWEL_SLOTS) do
		local info = JEWEL_SLOTS[i]
		local id, empty = Call(GetInventorySlotInfo, info.name)
		local labels = { NeckSlot = "Neck", Finger0Slot = "Ring", Finger1Slot = "Ring", Trinket0Slot = "Trinket", Trinket1Slot = "Trinket" }
		local j = NewSlot("jewel", JEWEL, labels[info.name])
		j.inv = tonumber(id) or info.id
		j.empty = type(empty) == "string" and empty or nil
		j.optional = info.optional
		j.visible = not info.optional
		jewels[i] = j
	end
	-- the panel: brushed glass in the timer's gold, a dragon on each end (Core)
	root.panel = CreateFrame("Frame", nil, root)
	root.panel:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
	root.panel:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", 0, 0)
	root.deco = C.Panel(root.panel, true)
	root.dividers = {}
	for i = 1, 3 do
		local d = C.Tex(root.panel, "ARTWORK", C.ART .. "PanelDivider")
		d:SetWidth(8)
		d:SetHeight(i == 3 and 62 or 44)
		root.dividers[i] = d
	end
	C.Vis(root.dividers[3], false)
	xp = C.NewBar(root, 400, 8, true)
	C.BarColors(xp, XP_COLORS[1], XP_COLORS[2], XP_COLORS[3])
	xp.text = C.Text(xp.top, C.FONT, 10, "OUTLINE", "CENTER", 400)
	xp.text:SetPoint("CENTER", xp.frame, "CENTER", 0, 0)
	Layout()
	Levels()
	C.Movable(root, "bar", "Skill bar", function(f)
		f:ClearAllPoints()
		f:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 12)
	end)
	if type(AZS_SetOnTopOfScreens) == "function" then pcall(AZS_SetOnTopOfScreens, root, true) end
	local driver = CreateFrame("Frame", "CreedUIBarDriver")
	local broken = false
	driver:SetScript("OnUpdate", function()
		if broken or not db.enabled then return end
		local dt = arg1 or 0
		if dt > 0.1 then dt = 0.1 end
		local ok, err = pcall(Step, dt)
		if not ok then
			broken = true
			db.enabled = false
			Apply()
			db.enabled = true
			C.Print(C.L("the skill bar stopped after an error, so the game's own is back: ") .. tostring(err))
		end
	end)
	Apply()
end)

C.OnWorld(function()
	if not db then return end
	if db.enabled then
		C.TakeHud("build")
		C.HideStock("MainMenuBar")
	end
	if type(AZS_SetOnTopOfScreens) == "function" then pcall(AZS_SetOnTopOfScreens, root, true) end
	S.lvl, S.wrap = nil, false
	xp.snap = true
	Levels()
end)

C.OnLogout(function()
	if db then C.ReleaseHud("build") end
end)

C.RegisterPart({
	key = "bar", name = "Skill bar",
	note = "Your abilities with their cooldowns, your neck, rings and trinkets (hover for what they give), and your XP. Replaces the game's bar.",
	get = function() return db and db.enabled end,
	set = function(on)
		if db then
			db.enabled = on and true or false
			Apply()
		end
	end,
	getScale = function() return db and db.scale or 1 end,
	setScale = function(v)
		if db then
			db.scale = v
			root:SetScale(v)
			for i = 1, table.getn(C.movers) do
				if C.movers[i].frame == root then C.ApplyPos(C.movers[i]) end
			end
		end
	end,
})
