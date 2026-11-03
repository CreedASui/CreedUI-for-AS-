-- Creed UI: boss and mini-boss (guardian) health bars.
-- They sit under the boss timer, so they never cover its next-boss line, and show the real
-- health numbers, with the debuffs on each (your DoTs and the rest) in a row of icons just under
-- its bar, each with the time it has left. While this part is on, the game's own boss bars (the
-- "bosses" HUD part) are hidden; they come back when it's turned off.

local C = CreedUI
local DEFAULTS = { enabled = true, scale = 1, width = 380, guardians = true }
local MAX_ROWS = 6
local BAR_H = 12          -- the trough, as the timer's
local ROW_H = 38          -- name line + bar
local ROW_GAP = 2
local DATA_EVERY = 0.1
local DB_SIZE, DB_GAP, DB_MAX, DB_ROW = 18, 4, 10, 22 -- the debuff icons under a bar
-- A boss's row, and a guardian's: narrower, thinner and closer, so four guardians up at once
-- stay a small stack under the bosses' full bars.
local LOOKS = {
	boss = { w = 1, row = ROW_H, bar = BAR_H, font = 12, gem = 24, db = DB_SIZE, dbRow = DB_ROW, gap = ROW_GAP },
	guardian = { w = 0.7, row = 27, bar = 8, font = 11, gem = 18, db = 14, dbRow = 18, gap = 1 },
}
local DISPEL = { Magic = { 0.2, 0.6, 1 }, Curse = { 0.6, 0.2, 1 }, Disease = { 0.6, 0.4, 0 }, Poison = { 0, 0.6, 0 } }

local db
local root, rows, byKey = nil, {}, {}
local S = { alpha = 0, dataClock = 0, takeClock = 0, list = {}, n = 0, stamp = -1, shown = false, asleep = {} }

-- fills: every enemy bar is red. Bosses run crimson to scarlet, mini-bosses a deeper blood red
-- (their amber gem tells them apart), and an enraged boss burns hotter
local FILLS = {
	boss = { { 0.30, 0.02, 0.02 }, { 0.74, 0.06, 0.04 }, { 1.00, 0.32, 0.16 } },
	guardian = { { 0.24, 0.01, 0.03 }, { 0.62, 0.04, 0.07 }, { 0.96, 0.26, 0.22 } },
	enraged = { { 0.46, 0.04, 0.00 }, { 0.98, 0.16, 0.03 }, { 1.00, 0.56, 0.22 } },
}

local GEM_GUARD, GEM_BOSS = { 1.00, 0.70, 0.22 }, { 1.00, 0.24, 0.16 }

local function Mix(a, b, t, out)
	out[1] = a[1] + (b[1] - a[1]) * t
	out[2] = a[2] + (b[2] - a[2]) * t
	out[3] = a[3] + (b[3] - a[3]) * t
	return out
end

------------------------------------------------------------------------ a row
local function NewRow()
	local w = db.width
	local r = { key = nil, y = nil, yv = 0, alpha = 0, rage = 0, hp = 1, hpm = 1, frac = 1, gone = false,
		colA = { 0, 0, 0 }, colM = { 0, 0, 0 }, colB = { 0, 0, 0 } }
	local f = CreateFrame("Frame", nil, root)
	r.frame = f
	f:SetWidth(w)
	f:SetHeight(ROW_H)
	r.bar = C.NewBar(f, w, BAR_H, true)
	r.bar.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -(ROW_H - 6 - BAR_H))
	r.debuffs, r.dh = {}, 0
	r.name = C.Text(r.bar.top, C.FONT, 12, "OUTLINE", "LEFT", w - 130)
	r.name:SetPoint("BOTTOMLEFT", r.bar.frame, "TOPLEFT", 16, 4)
	r.value = C.Text(r.bar.top, C.FONT, 12, "OUTLINE", "RIGHT", 220)
	r.value:SetPoint("BOTTOMRIGHT", r.bar.frame, "TOPRIGHT", 0, 4)
	-- a gem on the bar's left end, in the timer's style
	r.mark = CreateFrame("Frame", nil, f)
	r.mark:SetWidth(24)
	r.mark:SetHeight(24)
	r.mark:SetPoint("CENTER", r.bar.frame, "LEFT", -2, 0)
	r.glow = C.Tex(r.mark, "BACKGROUND", C.ART .. "Glow", "ADD")
	r.glow:SetPoint("CENTER", r.mark, "CENTER", 0, 0)
	r.socket = C.Tex(r.mark, "BORDER", C.ART .. "Socket")
	r.socket:SetPoint("CENTER", r.mark, "CENTER", 0, 0)
	r.gem = C.Tex(r.mark, "ARTWORK", C.ART .. "Gem")
	r.gem:SetPoint("CENTER", r.mark, "CENTER", 0, 0)
	r.shine = C.Tex(r.mark, "OVERLAY", C.ART .. "GemShine", "ADD")
	r.shine:SetPoint("CENTER", r.mark, "CENTER", 0, 0)
	f:Hide()
	return r
end

local function RowLevels(r, base)
	r.frame:SetFrameLevel(base)
	C.BarLevels(r.bar, base + 1)
	r.mark:SetFrameLevel(base + 5)
	r.level = base
	for i = 1, table.getn(r.debuffs) do r.debuffs[i].frame:SetFrameLevel(base + 5) end
end

------------------------------------------------------------------------ debuffs under a bar
local function DebuffTip()
	local d = this.data
	if not (d and GameTooltip) then return end
	GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
	GameTooltip:SetText(d.name or C.L("Debuff"), 0.98, 0.85, 0.52)
	if (tonumber(d.stacks) or 1) > 1 then GameTooltip:AddLine(C.F("{1} stacks", d.stacks), 1, 1, 1) end
	if d.permanent then
		GameTooltip:AddLine(C.L("Lasts while it lives"), 0.8, 0.8, 0.8)
	elseif tonumber(d.remaining) then
		GameTooltip:AddLine(C.F("{1} seconds left", string.format("%.1f", math.max(0, d.shownLeft or d.remaining))), 0.8, 0.8, 0.8)
	end
	if d.dispelType then GameTooltip:AddLine(d.dispelType, 0.6, 0.6, 0.6) end
	C.ShowTip()
end

local function NewDebuff(r)
	local d = {}
	local f = CreateFrame("Frame", nil, r.frame)
	d.frame = f
	f:SetWidth(DB_SIZE)
	f:SetHeight(DB_SIZE)
	f:SetFrameLevel((r.level or r.frame:GetFrameLevel()) + 5)
	f:EnableMouse(true)
	f:SetScript("OnEnter", DebuffTip)
	f:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	d.border = C.Tex(f, "BACKGROUND", C.FLAT)
	d.border:SetPoint("TOPLEFT", f, "TOPLEFT", -1, 1)
	d.border:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 1, -1)
	d.icon = f:CreateTexture(nil, "BORDER")
	d.icon:SetAllPoints(f)
	d.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	-- the time gone darkens it from the top, as a cooldown
	d.shade = C.Tex(f, "ARTWORK", C.FLAT)
	d.shade:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	d.shade:SetVertexColor(0, 0, 0, 0.6)
	d.time = C.Text(f, C.FONT, 10, "OUTLINE", "CENTER", 40)
	d.time:SetPoint("CENTER", f, "BOTTOM", 0, 2)
	d.stacks = C.Text(f, C.FONT, 9, "OUTLINE", "RIGHT", 20)
	d.stacks:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 2)
	C.Vis(f, false)
	table.insert(r.debuffs, d)
	return d
end

-- the row's debuffs, read with its unit; `since` seconds of run clock have passed since
local function StepDebuffs(r, list, since)
	local n = 0
	if type(list) == "table" then
		for i = 1, table.getn(list) do
			local data = list[i]
			if n < DB_MAX and type(data) == "table" and type(data.icon) == "string" then
				n = n + 1
				local d = r.debuffs[n] or NewDebuff(r)
				d.frame.data = data
				local size = r.look.db
				C.Size(d.frame, size, size)
				C.Place(d.frame, "TOPLEFT", r.bar.frame, "BOTTOMLEFT", 16 + (n - 1) * (size + DB_GAP), -5)
				if d.tex ~= data.icon then
					d.tex = data.icon
					d.icon:SetTexture(data.icon)
				end
				local c = DISPEL[data.dispelType or ""] or { 0, 0, 0 }
				C.Color(d.border, c[1], c[2], c[3], 0.9)
				local left = tonumber(data.remaining)
				local dur = tonumber(data.duration)
				local text, shade = "", 0
				if left and not data.permanent then
					left = math.max(0, left - since)
					data.shownLeft = left
					if left >= 60 then
						text = math.floor(left / 60 + 0.5) .. "m"
					elseif left > 3 then
						text = tostring(math.floor(left + 0.5))
					else
						text = string.format("%.1f", left)
					end
					if dur and dur > 0 then shade = C.Clamp(1 - left / dur, 0, 1) end
				end
				C.SetText(d.time, text)
				if left and left <= 3 and not data.permanent then C.TextColor(d.time, 1, 0.45, 0.25) else C.TextColor(d.time, 1, 0.95, 0.8) end
				local stacks = tonumber(data.stacks) or 1
				C.SetText(d.stacks, stacks > 1 and tostring(stacks) or "")
				local sh = math.floor(size * shade + 0.5)
				C.Size(d.shade, size, math.max(1, sh))
				C.Vis(d.shade, sh >= 1)
				C.Vis(d.frame, true)
			end
		end
	end
	for i = n + 1, table.getn(r.debuffs) do C.Vis(r.debuffs[i].frame, false) end
	return n
end

-- a row takes a boss's look or a guardian's (rows are reused, so this runs when its unit's kind changes)
local function Look(r, guardian)
	local L = guardian and LOOKS.guardian or LOOKS.boss
	if r.look == L then return end
	r.look = L
	local w = math.floor(db.width * L.w + 0.5)
	r.frame:SetWidth(w)
	r.frame:SetHeight(L.row)
	C.BarLayout(r.bar, w, L.bar)
	r.bar.frame:ClearAllPoints()
	r.bar.frame:SetPoint("TOPLEFT", r.frame, "TOPLEFT", 0, -(L.row - 6 - L.bar))
	r.name:SetWidth(math.max(80, w - 130))
	C.SetFace(r.name, C.FONT, L.font, "OUTLINE")
	C.SetFace(r.value, C.FONT, L.font, "OUTLINE")
	r.mark:SetWidth(L.gem)
	r.mark:SetHeight(L.gem)
	r.valueText = nil
end

------------------------------------------------------------------------ reading the run
local SHOWN = { playing = true, choosing = true, paused = true }

local Call = C.Call -- no stray nil arguments (see Core)

-- A new run starts with the last run's units still in the game's tables, until it sends fresh
-- ones: after a run begins, nothing is read until the units have changed since.
local function WatchRuns(phase)
	local fresh, byZone = false, false
	local zone = AZS_ZONE_UPDATED -- the zone is sent once at each run's start
	if S.zoneSeen and zone ~= S.zoneStamp then fresh, byZone = true, true end
	S.zoneStamp, S.zoneSeen = zone, true
	local t = Call(AZS_GetRunTime)
	if type(t) == "number" then
		if S.lastT and t + 1 < S.lastT then fresh = true end -- the clock went back
		S.lastT = t
	end
	if phase == "playing" and (S.lastPhase == "ready" or S.lastPhase == "victory") then fresh = true end
	if phase then S.lastPhase = phase end
	if fresh and (AZS_UNITS_UPDATED ~= nil or S.heard) then
		local units, since = tonumber(AZS_UNITS_UPDATED), tonumber(zone)
		-- units that came in with the new zone (or after it) are already the new run's
		if not (byZone and units and since and units >= since) then
			S.staleUnits, S.staleHeard, S.waiting = AZS_UNITS_UPDATED, S.heard or 0, true
		end
	end
	-- fresh units: a new publication since (counted as it arrives, in case it bears the same time)
	if S.waiting and (AZS_UNITS_UPDATED ~= S.staleUnits or (S.heard or 0) ~= S.staleHeard) then S.waiting = false end
end

-- the units to show, in order: bosses (the final one first), then awake guardians
local function Read(list)
	local n = 0
	for key in pairs(S.asleep) do S.asleep[key] = nil end
	local bosses = Call(AZS_GetBosses)
	if type(bosses) == "table" then
		for pass = 1, 2 do
			for i = 1, table.getn(bosses) do
				local b = bosses[i]
				if type(b) == "table" and ((pass == 1) == (b.final and true or false)) and n < MAX_ROWS then
					n = n + 1
					local e = list[n] or {}
					list[n] = e
					e.key = "b" .. tostring(b.id or b.name)
					e.name = b.name or C.L("Boss")
					e.hp, e.hpm = tonumber(b.hp) or 0, tonumber(b.hpm) or 0
					e.kind = b.final and "final" or "boss"
					e.enraged = b.enraged and true or false
					e.debuffs = b.debuffs
				end
			end
		end
	end
	if db.guardians then
		local guards = Call(AZS_GetGuardians)
		if type(guards) == "table" then
			for i = 1, table.getn(guards) do
				local g = guards[i]
				if type(g) == "table" and not g.awake then
					S.asleep["g" .. tostring(g.id or g.name)] = true -- back home asleep: not dead
				elseif type(g) == "table" and n < MAX_ROWS then
					n = n + 1
					local e = list[n] or {}
					list[n] = e
					e.key = "g" .. tostring(g.id or g.name)
					e.name = g.name or C.L("Guardian")
					e.hp, e.hpm = tonumber(g.hp) or 0, tonumber(g.hpm) or 0
					e.kind = "guardian"
					e.enraged = false
					e.debuffs = g.debuffs
				end
			end
		end
	end
	return n
end

-- placing the bars while unlocked shows two made-up ones
local SAMPLE = {
	{ key = "sample1", name = "Edwin VanCleef", hp = 41250, hpm = 88000, kind = "final", enraged = false,
		debuffs = { { name = "Corruption", icon = "Interface\\Icons\\Spell_Shadow_AbominationExplosion", remaining = 11, duration = 18, stacks = 1, dispelType = "Magic" },
			{ name = "Rupture", icon = "Interface\\Icons\\Ability_Rogue_Rupture", remaining = 2.4, duration = 16, stacks = 3 } } },
	{ key = "sample2", name = "Sir Zeliek", hp = 9400, hpm = 36000, kind = "guardian", enraged = false },
}

------------------------------------------------------------------------ drawing
local function StepRow(r, e, slotY, dt, now, pal, since)
	Look(r, r.kind == "guardian")
	-- gliding into its place in the stack
	if not r.y then r.y = slotY - 10 end
	r.y, r.yv = C.Spring(r.y, r.yv, slotY, 13, dt)
	if math.abs(r.y - slotY) < 0.05 and math.abs(r.yv) < 0.05 then r.y, r.yv = slotY, 0 end
	C.Place(r.frame, "TOP", root, "TOP", 0, -r.y)

	local want = r.gone and 0 or 1
	r.alpha = C.Toward(r.alpha, want, want > r.alpha and 7 or 5, dt)
	if want == 1 and r.alpha > 0.997 then r.alpha = 1 end
	C.Alpha(r.frame, C.Smooth(r.alpha))
	C.Vis(r.frame, true)

	local frac = (r.hpm > 0) and C.Clamp(r.hp / r.hpm, 0, 1) or 0
	if r.gone and r.drain then frac = 0 end
	C.BarStep(r.bar, frac, dt, now)
	-- its debuffs, just under the bar; the row makes room for them
	local nd = StepDebuffs(r, (not r.gone) and e.debuffs or nil, since or 0)
	r.dh = C.Toward(r.dh or 0, nd > 0 and r.look.dbRow or 0, 10, dt)

	-- colors: an enraged boss shifts toward orange and pulses
	r.rage = C.Toward(r.rage, r.enraged and 1 or 0, 4, dt)
	local base = FILLS[r.kind == "guardian" and "guardian" or "boss"]
	local hot = FILLS.enraged
	local t = r.rage * (0.85 + 0.15 * math.sin(now * 6))
	if r.rage > 0.002 or r.colorsFor ~= r.kind then
		r.colorsFor = r.kind
		C.BarColors(r.bar, Mix(base[1], hot[1], t, r.colA), Mix(base[2], hot[2], t, r.colM), Mix(base[3], hot[3], t, r.colB))
	end
	if r.palStamp ~= C.palStamp then
		r.palStamp = C.palStamp
		C.BarTheme(r.bar, pal)
		local rim = pal.rim
		r.socket:SetVertexColor(rim[1], rim[2], rim[3])
		r.socketFinal = nil
	end

	-- the gem: the final boss gets the star socket; a guardian's gem is amber
	local final = r.kind == "final"
	if r.socketFinal ~= final then
		r.socketFinal = final
		r.socket:SetTexture(C.ART .. (final and "SocketFinal" or "Socket"))
	end
	local s = final and 30 or r.look.gem
	C.Size(r.socket, s, s)
	C.Size(r.gem, s * 0.92, s * 0.92)
	C.Size(r.shine, s * 0.92, s * 0.92)
	local gem = r.kind == "guardian" and GEM_GUARD or GEM_BOSS
	local pulse = 0.5 + 0.5 * math.sin(now * (r.enraged and 9 or 2.4))
	C.Color(r.gem, gem[1], gem[2] + 0.12 * r.rage * pulse, gem[3], 1)
	local glowA = (final and 0.28 or 0.16) + 0.1 * pulse + r.rage * (0.25 + 0.25 * pulse)
	C.Size(r.glow, s * 2.4, s * 2.4)
	C.Color(r.glow, 1, 0.3 + 0.25 * r.rage, 0.12, glowA)

	-- text: the name (and ENRAGED), then current / max and the percent
	local nameWant = (r.enraged and (e.name .. "  |cffff7a2aENRAGED|r")) or e.name
	C.SetText(r.name, nameWant)
	if r.kind == "guardian" then
		C.TextColor(r.name, 1, 0.80, 0.42)
	else
		C.TextColor(r.name, 1, 0.92, 0.82)
	end
	local pct = math.floor(frac * 100 + 0.5)
	if frac > 0 and pct == 0 then pct = 1 end
	local v = C.Short(r.hp) .. " / " .. C.Short(r.hpm) .. "   |cffffd27a" .. pct .. "%|r"
	if r.gone and r.drain then v = "|cffffd27a0%|r" end
	if r.valueText ~= v then
		r.valueText = v
		C.SetText(r.value, v)
	end
end

local function SetLevels()
	local base = root:GetFrameLevel()
	for i = 1, table.getn(rows) do RowLevels(rows[i], base + 1 + (i - 1) * 6) end
end

local function Step(dt)
	local now = GetTime()
	local phase = type(AZS_GetPhase) == "function" and Call(AZS_GetPhase) or nil
	local inRun = phase and SHOWN[phase]
	WatchRuns(phase)

	-- read the bosses ten times a second
	S.dataClock = S.dataClock - dt
	if S.dataClock <= 0 then
		S.dataClock = DATA_EVERY
		if inRun and db.enabled and not S.waiting then
			S.n = Read(S.list)
			S.readAt = now
		else
			S.n = 0
			for key in pairs(S.asleep) do S.asleep[key] = nil end
		end
	end
	local list, n = S.list, S.n
	local sample = false
	if n == 0 and C.unlocked and db.enabled then
		list, n, sample = SAMPLE, 2, true
	end

	-- match units to rows: a row keeps its unit; one that died drains and fades out
	for key, r in pairs(byKey) do r.seen = false end
	for i = 1, n do
		local e = list[i]
		local r = byKey[e.key]
		if not r then
			for j = 1, table.getn(rows) do
				if not rows[j].key then
					r = rows[j]
					break
				end
			end
			if not r and table.getn(rows) < MAX_ROWS + 3 then
				r = NewRow()
				table.insert(rows, r)
				SetLevels()
			end
			if r then
				r.key, r.y, r.yv, r.alpha, r.gone, r.drain, r.dh = e.key, nil, 0, 0, false, false, 0
				r.bar.snap = true
				r.rage, r.colorsFor, r.palStamp, r.valueText = 0, nil, nil, nil
				byKey[e.key] = r
			end
		end
		if r then
			r.seen, r.gone, r.order = true, false, i
			r.hp, r.hpm, r.kind, r.enraged = e.hp, e.hpm, e.kind, e.enraged
			r.entry = e
			if sample then r.hp = e.hp * (0.98 + 0.02 * math.sin(now)) end
		end
	end
	for key, r in pairs(byKey) do
		if not r.seen and not r.gone then
			r.gone, r.goneAt = true, now
			-- one that died drains to empty; one gone back to sleep, or a run that ended, just fades
			r.drain = (inRun and not S.waiting and not S.asleep[key] and not sample) and true or false
			if r.order then r.order = r.order + 0.5 end
		end
	end

	-- the stack: live rows in order, a fading one keeps its slot until it's gone
	local order = {}
	for key, r in pairs(byKey) do table.insert(order, r) end
	table.sort(order, function(a, b) return (a.order or 99) < (b.order or 99) end)
	local y, any = 0, false
	local pal = C.Pal()
	-- the run's clock (and the debuffs' with it) runs only while playing
	local since = (phase == "playing" and S.readAt) and (now - S.readAt) or 0
	for i = 1, table.getn(order) do
		local r = order[i]
		StepRow(r, r.entry or SAMPLE[1], y, dt, now, pal, since)
		if r.gone and r.alpha < 0.01 and now - (r.goneAt or now) > 0.4 then
			byKey[r.key] = nil
			r.key = nil
			C.Vis(r.frame, false)
		else
			local weight = r.gone and C.Smooth(r.alpha) or 1
			local L = r.look or LOOKS.boss
			y = y + (L.row + (r.dh or 0) + L.gap) * weight
			any = true
		end
	end

	local want = (any and db.enabled and not C.cardsUp) and 1 or 0 -- away while the cards are up
	S.alpha = C.Toward(S.alpha, want, want > S.alpha and 6 or 4, dt)
	if want == 1 and S.alpha > 0.997 then S.alpha = 1 end
	if S.alpha < 0.005 and want == 0 then
		C.Vis(root, false)
	else
		C.Vis(root, true)
		C.Alpha(root, C.Smooth(S.alpha))
	end

	-- keep the game's own boss bars hidden while these replace them
	S.takeClock = S.takeClock - dt
	if S.takeClock <= 0 then
		S.takeClock = 2
		if db.enabled then C.TakeHud("bosses") end
	end
end

------------------------------------------------------------------------ setup
local function Anchor(f)
	f:ClearAllPoints()
	if C.timerRoot then
		f:SetPoint("TOP", C.timerRoot, "BOTTOM", 0, -6)
	else
		f:SetPoint("TOP", UIParent, "TOP", 0, -88)
	end
end

local function ApplyScale()
	root:SetScale(db.scale)
	for i = 1, table.getn(C.movers) do
		if C.movers[i].frame == root then C.ApplyPos(C.movers[i]) end
	end
end

local function SetEnabled(on)
	db.enabled = on and true or false
	if db.enabled then
		C.TakeHud("bosses")
	else
		C.ReleaseHud("bosses")
	end
end

C.OnInit(function()
	db = C.DB("bosses", DEFAULTS)
	db.width = C.Clamp(tonumber(db.width) or 380, 240, 700)
	root = CreateFrame("Frame", "CreedUIBosses", UIParent)
	root:SetFrameStrata("MEDIUM")
	root:SetWidth(db.width + 40)
	root:SetHeight(2 * (ROW_H + ROW_GAP))
	root:SetScale(db.scale)
	root:Hide()
	C.Movable(root, "bosses", "Boss and mini-boss bars", Anchor)
	if type(AZS_SetOnTopOfScreens) == "function" then pcall(AZS_SetOnTopOfScreens, root, true) end
	local driver = CreateFrame("Frame", "CreedUIBossesDriver")
	driver:RegisterEvent("CHAT_MSG_ADDON")
	driver:SetScript("OnEvent", function()
		if arg1 == "AZSUNITS" then S.heard = (S.heard or 0) + 1 end
	end)
	local broken = false
	driver:SetScript("OnUpdate", function()
		if broken then return end
		local dt = arg1 or 0
		if dt > 0.1 then dt = 0.1 end
		local ok, err = pcall(Step, dt)
		if not ok then
			broken = true
			C.ReleaseHud("bosses")
			if root then root:Hide() end
			C.Print(C.L("boss bars stopped after an error, so the game's own are back: ") .. tostring(err))
		end
	end)
end)

C.OnWorld(function()
	if not db then return end
	if db.enabled then C.TakeHud("bosses") end
	-- the timer is built now, so the bars can sit under it
	for i = 1, table.getn(C.movers) do
		if C.movers[i].frame == root then C.ApplyPos(C.movers[i]) end
	end
	if type(AZS_SetOnTopOfScreens) == "function" then pcall(AZS_SetOnTopOfScreens, root, true) end
	if root:IsShown() then SetLevels() end
end)

C.OnLogout(function()
	if db then C.ReleaseHud("bosses") end
end)

C.RegisterPart({
	key = "bosses", name = "Boss and mini-boss bars",
	note = "Health bars under the boss timer with the real numbers. Replaces the game's boss bars.",
	get = function() return db and db.enabled end,
	set = function(on) if db then SetEnabled(on) end end,
	getScale = function() return db and db.scale or 1 end,
	setScale = function(v)
		if db then
			db.scale = v
			ApplyScale()
		end
	end,
})
