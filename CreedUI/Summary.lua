-- Creed UI: the run's summary.
-- When a run ends (won, fallen or left), a gold-railed panel fades in at the left of the screen
-- with what the run came to: its time, your level, the kills, elites, guardians and bosses slain,
-- the damage you dealt (and a second) and took, the gold earned and the caches opened. The
-- numbers count up as it opens. It stays clear of the game's own end screen and its buttons, and
-- goes when you close it, keep fighting in endless or start the next run. Move frames moves it.

local C = CreedUI
local DEFAULTS = { enabled = true, scale = 1 }
local W, ROW_H, HEAD_H = 270, 20, 64
local COUNT_UP = 1.2
-- each line: its label, and how the game's end line gives it
local ROWS = {
	{ label = "Survived", field = "t", clock = true },
	{ label = "Level", field = "lvl" },
	{ label = "Kills", field = "kills" },
	{ label = "Elites slain", field = "elites" },
	{ label = "Guardians slain", field = "guardians" },
	{ label = "Bosses slain", field = "bosses" },
	{ label = "Damage dealt", field = "dmg" },
	{ label = "Damage a second", field = "dps" },
	{ label = "Damage taken", field = "taken" },
	{ label = "Gold earned", field = "gold" },
	{ label = "Caches opened", field = "chests" },
}
local RESULTS = {
	victory = { text = "Victory!", color = { 1, 0.84, 0.3 } },
	defeat = { text = "You have fallen", color = { 1, 0.36, 0.26 } },
	left = { text = "You left the run", color = { 0.8, 0.8, 0.85 } },
}

local db
local root
local S = { stamp = nil, openedAt = nil, alpha = 0, values = {}, closed = false, broken = false }

local function Value(row, v, k)
	if type(v) ~= "number" then return "-" end
	if row.clock then return C.Clock(v * k) end
	local n = math.floor(v * k + 0.5)
	if n >= 100000 then return C.Short(n) end
	return C.Commas(n)
end

-- the game's end line as numbers (and damage a second from the damage and the time)
local function Read(e)
	local out = {}
	for i = 1, table.getn(ROWS) do out[ROWS[i].field] = tonumber(e[ROWS[i].field]) end
	if out.dmg and out.t and out.t > 0 then out.dps = out.dmg / out.t end
	return out
end

local function Fill(e)
	local res = RESULTS[tostring(e.result)] or { text = "Run over", color = { 0.9, 0.9, 0.9 } }
	C.LText(root.title, res.text)
	root.title:SetTextColor(res.color[1], res.color[2], res.color[3])
	C.SetText(root.hero, type(e.hero) == "string" and e.hero or "")
	S.values = Read(e)
end

local function Show(e, now)
	Fill(e)
	S.openedAt = now
	S.closed = false
	C.Vis(root, true)
end

local function Close()
	S.closed = true
end

local function Step(dt, now)
	local e = nil
	if type(AZS_GetRunSummary) == "function" then e = C.Call(AZS_GetRunSummary) end
	if type(e) ~= "table" then e = nil end
	local stamp = e and (tostring(e.result) .. "|" .. tostring(e.t) .. "|" .. tostring(e.kills)) or nil
	if stamp ~= S.stamp then
		S.stamp = stamp
		if e then Show(e, now) else S.closed = true end
	end
	-- still fighting past the end (endless): the summary steps aside
	if e and not S.closed and tonumber(e.t) then
		local t = tonumber(C.Call(AZS_GetRunTime))
		if t and t > e.t + 3 then S.closed = true end
	end
	local want = (e and not S.closed) and 1 or 0
	S.alpha = C.Toward(S.alpha, want, want > 0 and 6 or 9, dt)
	if S.alpha < 0.01 then
		C.Vis(root, false)
		return
	end
	C.Vis(root, true)
	C.Alpha(root, S.alpha)
	local k = C.Smooth(((now - (S.openedAt or now)) / COUNT_UP))
	for i = 1, table.getn(ROWS) do
		local row = ROWS[i]
		C.SetText(root.rows[i].value, Value(row, S.values[row.field], k))
	end
	C.PanelStep(root.deco, now)
end

local function Build()
	root = CreateFrame("Frame", "CreedUISummary", UIParent)
	root:SetWidth(W)
	root:SetHeight(HEAD_H + table.getn(ROWS) * ROW_H + 16)
	root:SetFrameStrata("DIALOG")
	root:SetScale(db.scale)
	root:EnableMouse(true)
	root.deco = C.Panel(root, false)
	C.PanelTheme(root.deco, C.Pal())
	root.title = C.Text(root, C.TITLE_FONT, 22, "OUTLINE", "CENTER", W - 40)
	root.title:SetPoint("TOP", root, "TOP", 0, -12)
	root.hero = C.Text(root, C.FONT, 11, "OUTLINE", "CENTER", W - 40)
	root.hero:SetPoint("TOP", root.title, "BOTTOM", 0, -4)
	root.hero:SetTextColor(0.75, 0.75, 0.8)
	root.rows = {}
	for i = 1, table.getn(ROWS) do
		local y = -HEAD_H - (i - 1) * ROW_H
		local r = {}
		if math.mod(i, 2) == 0 then
			r.band = C.Tex(root, "BORDER", C.FLAT)
			r.band:SetPoint("TOPLEFT", root, "TOPLEFT", 12, y + 2)
			r.band:SetPoint("TOPRIGHT", root, "TOPRIGHT", -12, y + 2)
			r.band:SetHeight(ROW_H)
			r.band:SetVertexColor(1, 1, 1, 0.04)
		end
		r.label = C.Text(root, C.FONT, 12, "OUTLINE", "LEFT", 150)
		r.label:SetPoint("TOPLEFT", root, "TOPLEFT", 18, y)
		r.label:SetTextColor(0.85, 0.82, 0.74)
		C.LText(r.label, ROWS[i].label)
		r.value = C.Text(root, C.FONT, 12, "OUTLINE", "RIGHT", 100)
		r.value:SetPoint("TOPRIGHT", root, "TOPRIGHT", -18, y)
		r.value:SetTextColor(1, 1, 1)
		root.rows[i] = r
	end
	local close = C.Button(root, 20, 20, "x", Close)
	close:SetPoint("TOPRIGHT", root, "TOPRIGHT", -8, -8)
	root.close = close
	C.Vis(root, false)
	-- at the left, below the party frames, clear of the game's end screen in the middle
	C.Movable(root, "summary", "Run summary", function(f)
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 40, -300)
	end)
	if type(AZS_SetOnTopOfScreens) == "function" then pcall(AZS_SetOnTopOfScreens, root, true) end
end

local function Apply()
	if not db.enabled then
		S.alpha = 0
		C.Vis(root, false)
	end
end

C.OnInit(function()
	db = C.DB("summary", DEFAULTS)
	Build()
	local driver = CreateFrame("Frame", "CreedUISummaryDriver")
	driver:SetScript("OnUpdate", function()
		if S.broken or not db.enabled then return end
		local dt = arg1 or 0
		if dt > 0.1 then dt = 0.1 end
		local ok, err = pcall(Step, dt, GetTime())
		if not ok then
			S.broken = true
			C.Vis(root, false)
			C.Print(C.L("the run summary stopped after an error: ") .. tostring(err))
		end
	end)
	Apply()
end)

C.OnWorld(function()
	if root and type(AZS_SetOnTopOfScreens) == "function" then pcall(AZS_SetOnTopOfScreens, root, true) end
end)

C.RegisterPart({
	key = "summary", name = "Run summary",
	note = "When a run ends: your time, level, kills, elites, guardians and bosses slain, damage dealt and taken, gold and caches on one panel beside the game's end screen.",
	get = function() return db and db.enabled end,
	set = function(on)
		if db then
			db.enabled = on and true or false
			S.broken = false
			Apply()
		end
	end,
	getScale = function() return db and db.scale or 1 end,
	setScale = function(v)
		if db then
			db.scale = v
			root:SetScale(v)
		end
	end,
})
