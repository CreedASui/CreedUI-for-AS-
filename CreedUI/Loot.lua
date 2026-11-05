-- Creed UI: the run's loot.
-- A small gold-railed window of what the run has given you: the marks you earned at its head (on
-- an Argent Dawn token), then every piece of gear that dropped for you, the newest first, each with
-- its icon and its name in its rarity's color, and the moment of the run it came (point at one for
-- the item's own tooltip). It starts empty with each run and keeps the last one's after it ends.
-- Both are read from the game's own lines in the chat ("You receive loot: ...", "You earn 5 marks
-- (120 in all)."), in whichever of its languages it speaks.

local C = CreedUI
local DEFAULTS = { enabled = true, scale = 1, shown = true }
local K = { w = 210, head = 24, sum = 18, row = 20, rows = 5, pad = 8 }
local QUALITY = {
	[0] = { 0.62, 0.62, 0.62 }, [1] = { 0.92, 0.92, 0.92 }, [2] = { 0.12, 1.00, 0.00 },
	[3] = { 0.00, 0.44, 0.87 }, [4] = { 0.64, 0.21, 0.93 }, [5] = { 1.00, 0.50, 0.00 },
}

-- the game's two lines, in all its languages (from its own words)
local LOOT_LINES = { "Du erhältst Beute:", "Ganimet aldın:", "Otrzymujesz łup:", "Primești pradă:", "Recibes botín:", "Você recebe saque:", "Vous recevez du butin :", "You receive loot:", "Získáváš kořist:", "Ви отримуєте здобич:", "Вы получаете добычу:", "你获得了战利品：", "戦利品を入手：", "전리품을 받았습니다:" }
local MARK_LINES = { "Câștigi {n} însemne ({total} în total).", "Du erhältst {n} Marken (insgesamt {total}).", "Ganas {n} marcas ({total} en total).", "Você ganha {n} marcas ({total} no total).", "Vous gagnez {n} marques ({total} au total).", "You earn {n} marks ({total} in all).", "Zdobywasz znaki: {n} (łącznie {total}).", "Získáváš známky: {n} (celkem {total}).", "{n} nişan kazandın (toplam {total}).", "{n}マークを獲得（合計{total}）。", "Ви отримуєте знаки: {n} (усього {total}).", "Вы получаете знаки: {n} (всего {total}).", "你获得了{n}枚印记（共{total}枚）。", "징표 {n}개를 얻었습니다 (총 {total}개)." }
local MARK_ICON = "Interface\\Icons\\INV_Misc_Token_ArgentDawn"

local db
local root
local S = { items = {}, marks = 0, markTotal = nil, runTime = 0, broken = false, rows = {}, dirty = true,
	patterns = nil, heard = {} }

------------------------------------------------------------------------ what came
-- an item from a loot line: its link, id, name, count; nil for a line without one
local function ParseLoot(msg)
	if type(msg) ~= "string" then return nil end
	local _, _, link, id, name = string.find(msg, "(|c%x+|Hitem:(%d+)[^|]*|h%[([^%]]+)%]|h|r)")
	if not link then return nil end
	local _, _, count = string.find(msg, "|rx(%d+)")
	return { link = link, id = tonumber(id), name = name, count = tonumber(count) or 1 }
end

local function RunTime()
	if type(AZS_GetRunTime) ~= "function" then return 0 end
	local ok, t = pcall(AZS_GetRunTime)
	return ok and tonumber(t) or 0
end

local function Clock(t)
	t = math.floor(t or 0)
	return string.format("%d:%02d", math.floor(t / 60), math.mod(t, 60))
end

-- each marks line as a pattern: its two numbers caught, which comes first remembered
local function MarkPatterns()
	local out = {}
	for i = 1, table.getn(MARK_LINES) do
		local t = MARK_LINES[i]
		local nAt, totalAt = string.find(t, "{n}", 1, true), string.find(t, "{total}", 1, true)
		local pat = string.gsub(t, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
		pat = string.gsub(pat, "{n}", "([%%d,]+)")
		pat = string.gsub(pat, "{total}", "([%%d,]+)")
		table.insert(out, { pat = "^" .. pat, nFirst = (nAt or 0) < (totalAt or 0) })
	end
	return out
end

local function Number(s) return tonumber((string.gsub(s or "", ",", ""))) end

local function Plain(msg) return string.gsub(string.gsub(msg, "|c%x%x%x%x%x%x%x%x", ""), "|r", "") end

local function Rarity(hex)
	if not hex then return nil end
	for q, c in pairs(QUALITY) do
		local h = string.format("%02x%02x%02x", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
		if string.lower(hex) == h then return q end
	end
	return nil
end

-- a line of the chat: a drop, or marks earned
local function Hear(msg)
	if type(msg) ~= "string" then return end
	local plain = Plain(msg)
	S.patterns = S.patterns or MarkPatterns()
	for i = 1, table.getn(S.patterns) do
		local p = S.patterns[i]
		local _, _, a, b = string.find(plain, p.pat)
		if a then
			local n, total = Number(a), Number(b)
			if not p.nFirst then n, total = total, n end
			S.marks = S.marks + (n or 0)
			S.markTotal = total
			S.dirty = true
			return
		end
	end
	for i = 1, table.getn(LOOT_LINES) do
		local start, stop = string.find(plain, LOOT_LINES[i], 1, true)
		if start == 1 then -- the game's own line, not someone saying it
			local item = ParseLoot(msg)
			if not item then
				-- a name with no link: the words after the line's start, its color its rarity
				local rest = string.gsub(string.gsub(string.sub(plain, stop + 1), "^%s+", ""), "[%.。]%s*$", "")
				local _, _, name, count = string.find(rest, "^(.-)%s*x(%d+)$")
				item = { name = name or rest, count = tonumber(count) or 1 }
				local _, _, hex = string.find(msg, "|c%x%x(%x%x%x%x%x%x)")
				item.quality = Rarity(hex)
			end
			if item.name == "" then return end
			item.at = RunTime()
			if type(GetItemInfo) == "function" and item.id then
				local _, _, quality, _, _, _, _, _, icon = GetItemInfo(item.id)
				item.quality, item.icon = quality or item.quality, icon
			end
			if not item.quality then
				local _, _, hex = string.find(item.link or "", "^|c%x%x(%x%x%x%x%x%x)")
				item.quality = Rarity(hex)
			end
			table.insert(S.items, 1, item)
			S.dirty = true
			return
		end
	end
end

-- every chat window's lines pass by here (a line shown in two windows counts once)
local function Listen()
	for i = 1, (tonumber(NUM_CHAT_WINDOWS) or 7) do
		local f = getglobal("ChatFrame" .. i)
		if type(f) == "table" and f.AddMessage and not f.creedLoot then
			local own = f.AddMessage
			f.creedLoot = own
			f.AddMessage = function(self, ...)
				local msg = arg[1]
				if db and db.enabled and not S.broken and type(msg) == "string" then
					local now = GetTime()
					if S.heard[msg] ~= now then
						S.heard[msg] = now
						pcall(Hear, msg)
					end
				end
				return own(self, unpack(arg))
			end
		end
	end
end

------------------------------------------------------------------------ the window
local function Row(i)
	local r = S.rows[i]
	if r then return r end
	r = {}
	local f = CreateFrame("Button", nil, root)
	r.frame = f
	f:SetHeight(K.row)
	f:SetPoint("TOPLEFT", root, "TOPLEFT", K.pad, -(K.head + K.sum + 4 + (i - 1) * K.row))
	f:SetPoint("RIGHT", root, "RIGHT", -K.pad, 0)
	f:EnableMouse(true)
	r.icon = f:CreateTexture(nil, "ARTWORK")
	r.icon:SetWidth(K.row - 4)
	r.icon:SetHeight(K.row - 4)
	r.icon:SetPoint("LEFT", f, "LEFT", 0, 0)
	r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	r.time = C.Text(f, C.FONT, 9, nil, "RIGHT", 40)
	r.time:SetPoint("RIGHT", f, "RIGHT", 0, 0)
	r.time:SetTextColor(0.65, 0.62, 0.55)
	r.name = C.Text(f, C.FONT, 11, "OUTLINE", "LEFT", K.w - 2 * K.pad - K.row - 44)
	r.name:SetPoint("LEFT", r.icon, "RIGHT", 5, 0)
	f:SetScript("OnEnter", function()
		if not r.item or not GameTooltip or C.unlocked then return end
		GameTooltip:SetOwner(f, "ANCHOR_LEFT")
		if GameTooltip.SetHyperlink and r.item.id then
			local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. r.item.id .. ":0:0:0")
			if ok then
				GameTooltip:Show()
				return
			end
		end
		GameTooltip:AddLine(r.item.name, 0.98, 0.85, 0.52)
		C.ShowTip()
	end)
	f:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	S.rows[i] = r
	return r
end

local function Redraw()
	S.dirty = false
	local n = table.getn(S.items)
	local shown = math.min(n, K.rows)
	for i = 1, shown do
		local r, item = Row(i), S.items[i]
		r.item = item
		r.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
		local c = QUALITY[item.quality or 1] or QUALITY[1]
		C.TextColor(r.name, c[1], c[2], c[3])
		C.SetText(r.name, item.name .. ((item.count or 1) > 1 and (" x" .. item.count) or ""))
		C.SetText(r.time, Clock(item.at))
		C.Vis(r.frame, true)
	end
	for i = shown + 1, table.getn(S.rows) do C.Vis(S.rows[i].frame, false) end
	if n > K.rows then
		C.SetText(root.more, C.F("and {1} more", n - K.rows))
	elseif n == 0 then
		C.SetText(root.more, C.L("Nothing yet this run."))
	else
		C.SetText(root.more, "")
	end
	local rowsH = math.max(shown, 1) * K.row
	C.Size(root, K.w, K.head + K.sum + 4 + rowsH + ((n > K.rows or n == 0) and 14 or 0) + K.pad)
	C.Place(root.more, "TOPLEFT", root, "TOPLEFT", K.pad + 2, -(K.head + K.sum + 4 + (n == 0 and 0 or rowsH)))
end

local function Step(dt)
	-- a new run: the clock went back to the start
	local t = RunTime()
	if t + 2 < S.runTime then
		S.items, S.marks, S.markTotal, S.dirty = {}, 0, nil, true
		S.heard = {}
	end
	S.runTime = t
	C.SetText(root.marks, "+" .. C.Commas(S.marks))
	C.SetText(root.markTotal, S.markTotal and C.F("{1} in all", C.Commas(S.markTotal)) or "")
	if S.dirty then Redraw() end
	local want = (db.shown and 1 or 0) * (1 - C.cardsFade)
	C.Alpha(root, want)
	C.Vis(root, want > 0.01)
end

local function Apply()
	if not db.enabled then C.Vis(root, false) end
end

C.OnInit(function()
	db = C.DB("loot", DEFAULTS)
	root = CreateFrame("Frame", "CreedUILoot", UIParent)
	root:SetWidth(K.w)
	root:SetHeight(100)
	root:SetFrameStrata("MEDIUM")
	root:SetScale(db.scale)
	root:EnableMouse(true)
	root.deco = C.Panel(root, false)
	C.PanelTheme(root.deco, C.Pal())
	root.title = C.Text(root, C.FONT, 12, "OUTLINE", "LEFT", K.w - 40)
	root.title:SetPoint("TOPLEFT", root, "TOPLEFT", K.pad + 2, -7)
	root.title:SetTextColor(0.98, 0.85, 0.52)
	C.LText(root.title, "Loot")
	root.close = C.Button and C.Button(root, 18, 16, "x", function() db.shown = false end)
	if root.close then root.close:SetPoint("TOPRIGHT", root, "TOPRIGHT", -6, -5) end
	-- the marks earned this run, on an Argent Dawn token, and how many in all
	root.token = C.Tex(root, "ARTWORK", MARK_ICON)
	root.token:SetWidth(15)
	root.token:SetHeight(15)
	root.token:SetPoint("TOPLEFT", root, "TOPLEFT", K.pad + 2, -(K.head + 1))
	root.token:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	root.marks = C.Text(root, C.FONT, 11, "OUTLINE", "LEFT", 44)
	root.marks:SetPoint("LEFT", root.token, "RIGHT", 5, 0)
	root.marks:SetTextColor(1, 0.86, 0.45)
	root.markTotal = C.Text(root, C.FONT, 10, nil, "LEFT", 110)
	root.markTotal:SetPoint("LEFT", root.marks, "RIGHT", 4, 0)
	root.markTotal:SetTextColor(0.7, 0.68, 0.62)
	root.more = C.Text(root, C.FONT, 10, nil, "LEFT", K.w - 2 * K.pad)
	root.more:SetTextColor(0.7, 0.68, 0.62)
	C.Vis(root, false)
	C.Movable(root, "loot", "Loot", function(f)
		f:ClearAllPoints()
		if CreedUIMeter then
			f:SetPoint("BOTTOMRIGHT", CreedUIMeter, "BOTTOMLEFT", -10, 0) -- beside the damage meter
		else
			f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -20, 16)
		end
	end)
	Listen()
	local driver = CreateFrame("Frame", "CreedUILootDriver")
	driver:SetScript("OnUpdate", function()
		if S.broken or not db.enabled then return end
		local ok, err = pcall(Step, arg1 or 0)
		if not ok then
			S.broken = true
			db.enabled = false
			Apply()
			db.enabled = true
			C.Print(C.L("the loot window stopped after an error: ") .. tostring(err))
		end
	end)
	Apply()
end)

C.RegisterPart({
	key = "loot", name = "Loot",
	note = "The run's loot in a small window: the marks you earned, then the gear that dropped for you, newest first, with its icon and rarity. Point at one for its tooltip.",
	get = function() return db and db.enabled and db.shown end,
	set = function(on)
		if db then
			db.enabled = on and true or false
			db.shown = db.enabled
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

C.OnWorld(function()
	if db then Listen() end -- a chat window made since
end)
