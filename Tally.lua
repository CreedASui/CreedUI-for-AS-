-- Creed UI: your kills, your gold and what the next cache costs, each with a little glyph,
-- docked in the skill bar's panel, one above the other (the panel reaches round them). Dragged
-- away (/creed move), it keeps a slim glass strip of its own; /creed reset docks it again. The
-- cache lights up when you can afford it. While this part is on, the game's own kills-and-gold
-- box (the "tally" HUD part) is hidden; it comes back when the part is turned off.

local C = CreedUI
local DEFAULTS = { enabled = true, scale = 1 }
local H, ICON, PAD, GAP = 24, 16, 10, 14
local ROWV, PADV = 19, 5 -- docked: a row each, one above the other
local SHOWN = { playing = true, choosing = true, paused = true, dead = true, victory = true }
local CELLS = {
	{ key = "kills", art = "Skull", tint = { 0.93, 0.91, 0.86 }, text = { 1, 0.97, 0.9 } },
	{ key = "gold", art = "Coin", tint = { 1.00, 0.80, 0.26 }, text = { 1, 0.86, 0.36 } },
	{ key = "chest", art = "Chest", tint = { 1.00, 0.72, 0.40 }, text = { 0.86, 0.80, 0.70 } },
}
local SAMPLE = { kills = 188, gold = 143, chest = 31 }

local db, root
local cells = {}
C.tallyDock = { on = false, w = 0, shown = 0 } -- read by the skill bar's panel
local S = { alpha = 0, stamp = -1, takeClock = 0, gold = nil, run = nil, hovering = false }

local Call = C.Call -- no stray nil arguments (see Core)

local function Number(v)
	v = math.floor((tonumber(v) or 0) + 0.5)
	if v >= 10000 then return C.Commas(v) end
	return tostring(v)
end

------------------------------------------------------------------------ building
local function Build()
	root = CreateFrame("Frame", "CreedUITally", UIParent)
	root:SetFrameStrata("LOW")
	root:SetWidth(220)
	root:SetHeight(H)
	root:SetScale(db.scale)
	root:EnableMouse(true)
	root:Hide()
	-- dark glass with a thin metal line above and below, and a diamond on each end
	root.glass = C.Tex(root, "BACKGROUND", C.FLAT)
	root.glass:SetAllPoints(root)
	root.glass:SetGradientAlpha("VERTICAL", 0.02, 0.02, 0.03, 0.82, 0.08, 0.08, 0.10, 0.70)
	root.lineT = C.Tex(root, "BORDER", C.FLAT)
	root.lineT:SetPoint("TOPLEFT", root, "TOPLEFT", 6, 0)
	root.lineT:SetPoint("TOPRIGHT", root, "TOPRIGHT", -6, 0)
	root.lineT:SetHeight(1)
	root.lineB = C.Tex(root, "BORDER", C.FLAT)
	root.lineB:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 6, 0)
	root.lineB:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -6, 0)
	root.lineB:SetHeight(1)
	root.gemL = C.Tex(root, "ARTWORK", C.ART .. "Diamond")
	root.gemL:SetWidth(10)
	root.gemL:SetHeight(10)
	root.gemL:SetPoint("CENTER", root, "LEFT", 0, 0)
	root.gemR = C.Tex(root, "ARTWORK", C.ART .. "Diamond")
	root.gemR:SetWidth(10)
	root.gemR:SetHeight(10)
	root.gemR:SetPoint("CENTER", root, "RIGHT", 0, 0)
	for i = 1, table.getn(CELLS) do
		local info = CELLS[i]
		local c = { info = info, shown = 0, target = 0, flash = 0, glowA = 0, minW = 0, ready = 0 }
		c.glow = C.Tex(root, "BORDER", C.ART .. "Glow", "ADD")
		c.glow:SetWidth(30)
		c.glow:SetHeight(30)
		c.icon = C.Tex(root, "ARTWORK", C.ART .. info.art)
		c.icon:SetWidth(ICON)
		c.icon:SetHeight(ICON)
		c.icon:SetVertexColor(info.tint[1], info.tint[2], info.tint[3])
		c.text = C.Text(root, C.FONT, 12, "OUTLINE", "LEFT", 90)
		c.text:SetTextColor(info.text[1], info.text[2], info.text[3])
		cells[i] = c
	end
end

-- the cells side by side, or one above the other when docked; each only ever widens while a run
-- lasts, so rolling digits don't jiggle
local function Layout()
	if S.docked then
		local k, widest = 0, 0
		for i = 1, table.getn(cells) do
			local c = cells[i]
			if c.on then
				local y = -(PADV + ROWV * 0.5 + k * ROWV)
				C.Place(c.icon, "LEFT", root, "TOPLEFT", 4, y)
				C.Place(c.glow, "CENTER", root, "TOPLEFT", 4 + ICON * 0.5, y)
				C.Place(c.text, "LEFT", root, "TOPLEFT", 4 + ICON + 4, y)
				widest = math.max(widest, ICON + 4 + c.minW)
				k = k + 1
			end
		end
		C.Size(root, math.max(40, widest + 8), math.max(1, k) * ROWV + PADV * 2)
		return
	end
	local x = PAD
	for i = 1, table.getn(cells) do
		local c = cells[i]
		if c.on then
			C.Place(c.icon, "LEFT", root, "LEFT", x, 0)
			C.Place(c.glow, "CENTER", root, "LEFT", x + ICON * 0.5, 0)
			C.Place(c.text, "LEFT", root, "LEFT", x + ICON + 4, 0)
			x = x + ICON + 4 + c.minW + GAP
		end
	end
	C.Size(root, math.max(60, x - GAP + PAD), H)
end

-- docked in the skill bar's panel while the bar is up and the strip hasn't been dragged away. The
-- bar only stepping aside for the level-up cards still counts as up: undocking then would make the
-- panel shrink and stretch out again as the cards close.
local function Dockable()
	local bar = CreedUIBar
	if not (bar and C.barDockX) then return false end
	if not (bar:IsShown() or (C.barOn and C.cardsFade > 0)) then return false end
	local pos = C.Root().pos
	return not (type(pos) == "table" and pos.tally)
end

local function Theme(pal)
	local rim = pal.rim
	root.lineT:SetVertexColor(rim[1], rim[2], rim[3], 0.55)
	root.lineB:SetVertexColor(rim[1], rim[2], rim[3], 0.35)
	root.gemL:SetVertexColor(rim[1], rim[2], rim[3])
	root.gemR:SetVertexColor(rim[1], rim[2], rim[3])
end

------------------------------------------------------------------------ the tooltip
local function ShowTip()
	if not GameTooltip then return end
	local run = type(AZS_RUN) == "table" and AZS_RUN or {}
	GameTooltip:SetOwner(root, "ANCHOR_TOP")
	GameTooltip:AddLine(C.L("This run"), 0.98, 0.85, 0.52)
	GameTooltip:AddDoubleLine(C.L("Kills"), Number(run.kills), 0.85, 0.85, 0.85, 1, 1, 1)
	if tonumber(run.ek) or tonumber(run.gk) or tonumber(run.bk) then
		GameTooltip:AddDoubleLine(C.L("Elites / guardians / bosses"), Number(run.ek) .. " / " .. Number(run.gk) .. " / " .. Number(run.bk),
			0.85, 0.85, 0.85, 1, 1, 1)
	end
	GameTooltip:AddDoubleLine(C.L("Gold"), Number(run.gold), 0.85, 0.85, 0.85, 0.98, 0.85, 0.52)
	if tonumber(run.ge) then
		GameTooltip:AddDoubleLine(C.L("Gold earned"), Number(run.ge), 0.85, 0.85, 0.85, 0.98, 0.85, 0.52)
	end
	if tonumber(run.chest) and run.chest > 0 then
		GameTooltip:AddDoubleLine(C.L("Next cache"), C.F("{1} gold", Number(run.chest)), 0.85, 0.85, 0.85, 1, 0.72, 0.4)
		if (tonumber(run.gold) or 0) >= run.chest then
			GameTooltip:AddLine(C.L("You can buy one now."), 0.5, 1, 0.5)
		end
	end
	if tonumber(run.ck) then
		GameTooltip:AddDoubleLine(C.L("Caches opened"), Number(run.ck), 0.85, 0.85, 0.85, 1, 1, 1)
	end
	if tonumber(run.rr) then
		local more = tonumber(run.rrc) and ("  " .. C.F("(next {1} gold)", Number(run.rrc))) or ""
		GameTooltip:AddDoubleLine(C.L("Rerolls"), Number(run.rr) .. more, 0.85, 0.85, 0.85, 1, 1, 1)
	end
	C.ShowTip()
end

------------------------------------------------------------------------ every frame
local function Values(phase)
	if C.unlocked and not (phase and SHOWN[phase]) then return SAMPLE, true end
	if not (phase and SHOWN[phase]) then return nil end
	local run = type(AZS_RUN) == "table" and AZS_RUN or nil
	if not run or tonumber(run.kills) == nil then return nil end
	return run, false
end

local function StepCell(c, v, dt, now, gold)
	local target = tonumber(v) or 0
	-- the number rolls to its new value
	if target ~= c.target then
		if c.info.key == "gold" and target > c.target and c.seen then c.flash = 1 end
		c.target = target
	end
	if not c.seen then
		c.shown, c.seen = target, true
	else
		c.shown = c.shown + (target - c.shown) * (1 - math.exp(-dt * 12))
		if math.abs(target - c.shown) < 0.5 then c.shown = target end
	end
	local text = (c.numNow ~= c.shown) and Number(c.shown) or c.textNow
	c.numNow = c.shown
	if c.textNow ~= text then
		c.textNow = text
		C.SetText(c.text, text)
		local w = C.TextWidth(c.text)
		if w <= 0 then w = string.len(text) * 7 end
		if w > c.minW then
			c.minW = w
			S.relayout = true
		end
	end
	-- the cache glows while it's affordable; gold glints as it comes in
	local want = 0
	if c.info.key == "chest" then
		local ready = target > 0 and gold >= target
		c.ready = C.Toward(c.ready, ready and 1 or 0, 5, dt)
		want = c.ready * (0.35 + 0.2 * math.sin(now * 3.2))
		local t = c.info.text
		local r = c.ready
		C.TextColor(c.text, t[1] + (1 - t[1]) * r, t[2] + (0.9 - t[2]) * r, t[3] + (0.42 - t[3]) * r)
	elseif c.flash > 0 then
		c.flash = math.max(0, c.flash - dt * 2.2)
		want = 0.5 * C.Smooth(c.flash)
	end
	if want > 0.01 then
		local g = c.info.tint
		C.Color(c.glow, g[1], g[2], g[3], want)
		C.Vis(c.glow, true)
	else
		C.Vis(c.glow, false)
	end
end

local function Step(dt)
	local now = GetTime()
	local phase = Call(AZS_GetPhase)
	local vals, sample = nil, false
	if db.enabled then vals, sample = Values(phase) end

	-- a new run starts the strip afresh
	local runId = type(AZS_ZONE) == "table" and AZS_ZONE.run or nil
	if runId ~= S.run then
		S.run = runId
		for i = 1, table.getn(cells) do
			cells[i].seen, cells[i].minW = false, 0
		end
		S.relayout = true
	end

	local want = vals and 1 or 0
	S.alpha = C.Toward(S.alpha, want, want > S.alpha and 6 or 4, dt)
	if want == 1 and S.alpha > 0.997 then S.alpha = 1 end
	if S.alpha < 0.005 and want == 0 then
		C.Vis(root, false)
		return
	end
	-- away while the cards are up (the panel keeps its room for it all the same)
	local a = C.Smooth(S.alpha) * (1 - C.cardsFade)
	C.Vis(root, a > 0.005)
	C.Alpha(root, a)
	if not vals then return end -- fading out: keep the last picture

	local pal = C.Pal()
	if S.stamp ~= C.palStamp then
		S.stamp = C.palStamp
		Theme(pal)
	end
	local gold = tonumber(vals.gold) or 0
	for i = 1, table.getn(cells) do
		local c = cells[i]
		local v = vals[c.info.key]
		local on = (v ~= nil) and (c.info.key ~= "chest" or (tonumber(v) or 0) > 0)
		if c.on ~= on then
			c.on = on
			C.Vis(c.icon, on)
			C.Vis(c.text, on)
			if not on then C.Vis(c.glow, false) end
			S.relayout = true
		end
		if on then StepCell(c, v, dt, now, gold) end
	end
	if S.relayout then
		S.relayout = false
		Layout()
	end
	if S.hovering then
		S.tipClock = (S.tipClock or 0) - dt
		if S.tipClock <= 0 then
			S.tipClock = 0.25
			ShowTip()
		end
	end
end

------------------------------------------------------------------------ setup
local function Anchor(f)
	f:ClearAllPoints()
	if Dockable() then
		-- in the panel, past the jewelry (offsets in the strip's own scale)
		local k = CreedUIBar:GetEffectiveScale() / f:GetEffectiveScale()
		f:SetPoint("LEFT", CreedUIBar, "RIGHT", C.barDockX * k, 0)
	elseif CreedUIBar then
		f:SetPoint("LEFT", CreedUIBar, "BOTTOMRIGHT", 6, 28) -- beside the spells and jewelry
	else
		f:SetPoint("BOTTOM", UIParent, "BOTTOM", 330, 28)
	end
end

-- docked or not: its own glass only when on its own; tell the bar how much room it takes
local function Dock(mover, dt)
	local d = C.tallyDock
	S.dockClock = (S.dockClock or 0) - dt
	if S.dockClock <= 0 then
		S.dockClock = 0.25 -- docking and the room it takes, looked at four times a second
		local docked = Dockable()
		if docked ~= S.docked then
			S.docked = docked
			root.creedDocked = docked or nil
			for _, t in ipairs({ root.glass, root.lineT, root.lineB, root.gemL, root.gemR }) do C.Vis(t, not docked) end
			if docked then root:SetFrameLevel(CreedUIBar:GetFrameLevel() + 3) end
			C.ApplyPos(mover)
			Layout() -- its new shape now, so the panel never reaches for the old one
			S.relayout = false
		end
		d.on = docked
		if docked then S.dockK = root:GetEffectiveScale() / CreedUIBar:GetEffectiveScale() end
	end
	-- the room it takes in the panel: its width as laid out this frame, and only its own fade (not
	-- the cards': the panel keeps its shape while they're up)
	if d.on then d.w = (root.mw or root:GetWidth()) * (S.dockK or 1) end
	d.shown = d.on and C.Smooth(S.alpha) or 0
end

local function SetEnabled(on)
	db.enabled = on and true or false
	if db.enabled then C.TakeHud("tally") else C.ReleaseHud("tally") end
end

C.OnInit(function()
	db = C.DB("tally", DEFAULTS)
	Build()
	root:SetScript("OnEnter", function()
		S.hovering = true
		ShowTip()
	end)
	root:SetScript("OnLeave", function()
		S.hovering = false
		if GameTooltip then GameTooltip:Hide() end
	end)
	-- 1.5.2 docks it in the skill bar's panel: a place it was dragged to before goes, once
	local saved = C.Root()
	if not saved.tallyDocks then
		saved.tallyDocks = true
		if type(saved.pos) == "table" then saved.pos.tally = nil end
	end
	S.mover = C.Movable(root, "tally", "Kills, gold and cache", Anchor)
	C.OverCards(root) -- lit over the level-up cards' veil when clear of them, or docked (Core)
	local driver = CreateFrame("Frame", "CreedUITallyDriver")
	local broken = false
	driver:SetScript("OnUpdate", function()
		if broken then return end
		local dt = arg1 or 0
		if dt > 0.1 then dt = 0.1 end
		local ok, err = pcall(Dock, S.mover, dt)
		if ok then ok, err = pcall(Step, dt) end
		if not ok then
			broken = true
			C.ReleaseHud("tally")
			root:Hide()
			C.Print(C.L("the kills and gold strip stopped after an error, so the game's own is back: ") .. tostring(err))
			return
		end
		S.takeClock = S.takeClock - dt
		if S.takeClock <= 0 then
			S.takeClock = 2
			if db.enabled then C.TakeHud("tally") end
		end
	end)
end)

C.OnWorld(function()
	if not db then return end
	if db.enabled then C.TakeHud("tally") end
	for i = 1, table.getn(C.movers) do
		if C.movers[i].frame == root then C.ApplyPos(C.movers[i]) end
	end
end)

C.OnLogout(function()
	if db then C.ReleaseHud("tally") end
end)

C.RegisterPart({
	key = "tally", name = "Kills, gold and cache",
	note = "Kills, gold and the next cache's price with little icons, docked in the skill bar's panel (drag it away with /creed move). The cache lights up when you can afford it. Replaces the game's kills and gold box.",
	get = function() return db and db.enabled end,
	set = function(on) if db then SetEnabled(on) end end,
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
