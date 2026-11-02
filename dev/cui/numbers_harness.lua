-- A mock 1.12 client + Azeroth Survivors combat text API, run under real Lua 5.0.
-- Widget methods are checked against the game's own method lists.

local SCRATCH = arg[1]
local ADDON_FILE = arg[2]
dofile(SCRATCH .. "/engine_methods.lua")
ENGINE_METHODS["WorldFrame"] = ENGINE_METHODS["Frame"]

local now = 100.0
function GetTime() return now end

local problems = {}
local function Problem(msg)
	table.insert(problems, msg)
end

------------------------------------------------------------------ widgets
local updaters = {}       -- frames with OnUpdate
local eventFrames = {}    -- frames with events
local allFontStrings = {}
local IMPL = {}

local function NewObject(kind, parent)
	local obj = { __kind = kind, __parent = parent, __points = {}, __shown = true, __alpha = 1, __scale = 1,
		__scripts = {}, __events = {}, __w = 0, __h = 0 }
	setmetatable(obj, { __index = function(t, k)
		local first = string.sub(k, 1, 1)
		if first == string.upper(first) and string.find(first, "%a") then
			if not ENGINE_METHODS[kind][k] then
				error("the game has no " .. kind .. ":" .. k, 2)
			end
			return IMPL[k] or function() end
		end
		return nil
	end })
	return obj
end

function IMPL.SetPoint(self, point, rel, relPoint, x, y)
	self.__points[point] = { rel = rel, relPoint = relPoint, x = x or 0, y = y or 0 }
	self.__npoints = (self.__npoints or 0) + 1
end
function IMPL.ClearAllPoints(self) self.__points = {} end
function IMPL.SetAllPoints(self, rel) self.__points.ALL = rel end
function IMPL.Show(self) self.__shown = true end
function IMPL.Hide(self) self.__shown = false end
function IMPL.IsShown(self) return self.__shown end
function IMPL.IsVisible(self)
	local o = self
	while o do
		if not o.__shown then return false end
		o = o.__parent
	end
	return true
end
function IMPL.SetAlpha(self, a)
	if type(a) ~= "number" or a ~= a then error("bad alpha " .. tostring(a), 2) end
	self.__alpha = a
end
function IMPL.GetAlpha(self) return self.__alpha end
function IMPL.SetScale(self, s)
	if type(s) ~= "number" or s <= 0 or s ~= s then error("bad scale " .. tostring(s), 2) end
	self.__scale = s
	self.__nscale = (self.__nscale or 0) + 1
end
function IMPL.GetScale(self) return self.__scale end
function IMPL.GetEffectiveScale(self)
	local s, o = 1, self
	while o do
		s = s * (o.__scale or 1)
		o = o.__parent
	end
	return s
end
function IMPL.SetWidth(self, w) self.__w = w end
function IMPL.SetHeight(self, h) self.__h = h end
function IMPL.GetWidth(self) return self.__w end
function IMPL.GetHeight(self) return self.__h end
function IMPL.SetScript(self, name, fn)
	if not ENGINE_METHODS[self.__kind].SetScript then error("no SetScript", 2) end
	self.__scripts[name] = fn
	if name == "OnUpdate" then table.insert(updaters, self) end
end
function IMPL.GetScript(self, name) return self.__scripts[name] end
function IMPL.RegisterEvent(self, name)
	self.__events[name] = true
	table.insert(eventFrames, self)
end
function IMPL.UnregisterEvent(self, name) self.__events[name] = nil end
function IMPL.CreateFontString(self)
	local fs = NewObject("FontString", self)
	table.insert(allFontStrings, fs)
	return fs
end
function IMPL.CreateTexture(self)
	local t = NewObject("Texture", self)
	self.__textures = self.__textures or {}
	table.insert(self.__textures, t)
	return t
end
function IMPL.SetText(self, t)
	if t ~= nil and type(t) ~= "string" and type(t) ~= "number" then error("bad text", 2) end
	self.__text = t
	self.__nset = (self.__nset or 0) + 1
end
function IMPL.GetText(self) return self.__text end
function IMPL.SetFont(self, path, size, flags)
	if type(path) ~= "string" or type(size) ~= "number" then error("bad SetFont", 2) end
	self.__font, self.__size, self.__flags = path, size, flags
	return 1
end
function IMPL.GetFont(self) return self.__font, self.__size, self.__flags end
function IMPL.GetStringWidth(self)
	local t = string.gsub(self.__text or "", "|c%x%x%x%x%x%x%x%x", "")
	t = string.gsub(t, "|r", "")
	return string.len(t) * (self.__size or 12) * 0.5
end
function IMPL.SetTextColor(self, r, g, b)
	if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then error("bad color", 2) end
	self.__color = { r, g, b }
end
function IMPL.GetParent(self) return self.__parent end
function IMPL.SetTexture(self, path)
	if path ~= nil and type(path) ~= "string" then error("bad texture", 2) end
	self.__texture = path
end
function IMPL.GetTexture(self) return self.__texture end
function IMPL.GetName(self) return self.__name end
function IMPL.Click(self) if self.__scripts.OnClick then this = self; self.__scripts.OnClick() end end

local allButtons = {}
function CreateFrame(kind, name, parent)
	if kind ~= "Frame" and kind ~= "Button" then error("unexpected frame type " .. tostring(kind)) end
	local f = NewObject(kind, parent)
	if kind == "Button" then table.insert(allButtons, f) end
	f.__name = name
	if name then setglobal(name, f) end
	return f
end
function setglobal(k, v) _G[k] = v end
function getglobal(k) return _G[k] end

WorldFrame = NewObject("WorldFrame")
WorldFrame.__w, WorldFrame.__h = 1024, 768
UIParent = NewObject("Frame")
UIParent.__w, UIParent.__h, UIParent.__scale = 1137.8, 853.3, 0.9

local chat = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(self, msg) table.insert(chat, msg) end }
SlashCmdList = {}
UISpecialFrames = {}
local cvars = { CombatDamage = "1" }
function GetCVar(k) return cvars[k] end
function SetCVar(k, v) cvars[k] = v end

------------------------------------------------------------------ the game's combat text API
local world = { events = {}, nEvents = 0, anchors = {}, nAnchor = 0, stream = 1, handler = nil, enemies = {}, dropped = 0 }
world.camX, world.camY = 0, 0
local SCALE = 9 -- screen units per yard

local function ScreenOf(x, y)
	return 512 + (x - world.camX) * SCALE, 330 + (y - world.camY) * SCALE + 30
end

function AZS_GetCombatTextCapabilities()
	return { apiVersion = 1, impactAnchors = true, followAnchors = true, frameProjection = true,
		distanceMetrics = true, frameHandler = true, maxEventsPerRead = 256, maxAnchorsPerRead = 256,
		eventCapacity = 4096, anchorCapacity = 4096, eventRetentionSeconds = 5, anchorRetentionSeconds = 5 }
end

local reads = 0
function AZS_GetCombatTextEvents(cursor, limit)
	reads = reads + 1
	if limit ~= nil and (type(limit) ~= "number" or limit < 1 or limit > 256) then
		return nil, { code = "INVALID_ARGUMENT", message = "limit" }
	end
	limit = limit or 256
	if cursor == nil then
		return { apiVersion = 1, streamId = "s" .. world.stream, worldId = "w1", clockSeconds = now,
			cursor = world.stream .. ":" .. world.nEvents, events = {}, hasMore = false, droppedCount = 0 }
	end
	local _, _, s, index = string.find(cursor, "^(%d+):(%d+)$")
	if tonumber(s) ~= world.stream then
		return nil, { code = "STREAM_CHANGED", message = "new stream" }
	end
	index = tonumber(index)
	local out, n = {}, 0
	while index < world.nEvents and n < limit do
		index = index + 1
		n = n + 1
		out[n] = world.events[index]
	end
	return { apiVersion = 1, streamId = "s" .. world.stream, worldId = "w1", clockSeconds = now,
		cursor = world.stream .. ":" .. index, events = out, hasMore = index < world.nEvents, droppedCount = 0 }
end

local projections, projectedIds = 0, 0
function AZS_ProjectCombatTextAnchors(ids, mode)
	projections = projections + 1
	if type(ids) ~= "table" or (mode ~= "follow" and mode ~= "impact") then
		return nil, { code = "INVALID_ARGUMENT", message = "args" }
	end
	local n = table.getn(ids)
	if n > 256 then return nil, { code = "INVALID_ARGUMENT", message = "too many" } end
	projectedIds = projectedIds + n
	local entries = {}
	for i = 1, n do
		local id = ids[i]
		local a = world.anchors[id]
		if type(id) ~= "string" then
			Problem("projected a non-string anchor id")
		end
		if not a then
			entries[i] = { anchorId = id, state = "unknownAnchor" }
		elseif now - a.born > 5 then
			entries[i] = { anchorId = id, state = "expired", reason = "age" }
		else
			local e = a.enemy
			local x, y
			if mode == "follow" and e.alive then x, y = e.x, e.y else x, y = e.deadX or a.x, e.deadY or a.y end
			if mode == "impact" then x, y = a.x, a.y end
			local sx, sy = ScreenOf(x, y)
			if sx < 0 or sx > 1024 or sy < 0 or sy > 768 then
				entries[i] = { anchorId = id, state = "offscreen", targetState = e.alive and "alive" or "dead" }
			else
				entries[i] = { anchorId = id, state = "onScreen", targetState = e.alive and "alive" or "dead",
					x = sx, y = sy, cameraDistance = 30, cameraDepth = 28, uiUnitsPerYard = SCALE }
			end
		end
	end
	return { apiVersion = 1, worldId = "w1", streamId = "s" .. world.stream, cameraSampleId = "c" .. now,
		clockSeconds = now, frameCurrent = true, entries = entries }
end

function AZS_RegisterCombatTextFrameHandler(fn)
	if type(fn) ~= "function" then return nil, { code = "INVALID_ARGUMENT" } end
	world.handler = fn
	return true
end
function AZS_UnregisterCombatTextFrameHandler(fn)
	if world.handler == fn then world.handler = nil end
	return true
end

AZS_UNITS = { { kind = "final", id = 900, name = "Hogger", hp = 5000, hpm = 9000, state = 0 } }
function GetInventoryItemTexture(unit, slot)
	if unit == "player" and slot == 16 then return "Interface\\Icons\\INV_Sword_27" end
	return nil
end
function AZS_GetSummonGroups()
	return { { key = "wolf", kind = "pet", name = "Wolf", icon = "Interface\\Icons\\Ability_Hunter_Pet_Wolf", count = 1 } }, 1
end
function AZS_GetTotems() return {} end
function AZS_GetPhase() return "playing" end

------------------------------------------------------------------ simulated fight
local serial = 0
local function NewEnemy(name, x, y)
	serial = serial + 1
	local e = { id = "t" .. serial, name = name, x = x, y = y, alive = true, hp = 6 + math.random(0, 8) }
	table.insert(world.enemies, e)
	return e
end

local hitsSent, damageSent = 0, 0
SKILLS = {
	fire = { spellId = 133, abilityName = "Fireball", icon = "Interface\\Icons\\Spell_Fire_FlameBolt", damageType = "spell", schoolMask = 4 },
	frost = { spellId = 116, abilityName = "Frostbolt", icon = "Interface\\Icons\\Spell_Frost_FrostBolt02", damageType = "spell", schoolMask = 16 },
	melee = { damageType = "melee", schoolMask = 1 },
	petmelee = { damageType = "melee", schoolMask = 1, sourceKind = "pet" },
	shield = { reflected = true, schoolMask = 8 },
}
local SKILL_NAMES = { "fire", "fire", "frost", "melee", "petmelee" }

local function Hit(e, amount, crit, periodic, miss, skill)
	world.nAnchor = world.nAnchor + 1
	local anchorId = "a" .. world.nAnchor
	world.anchors[anchorId] = { enemy = e, born = now, x = e.x, y = e.y }
	world.nEvents = world.nEvents + 1
	local sk = SKILLS[skill or "fire"]
	local ev = { eventId = "e" .. world.nEvents, presentedAt = now, targetId = e.id, targetName = e.name,
		sourceId = "p1", sourceKind = sk.sourceKind or "player", critical = crit and true or false, periodic = periodic and true or false,
		reflected = sk.reflected and true or false, anchorId = anchorId, anchorStatus = "ready", damageType = sk.damageType,
		schoolMask = sk.schoolMask, spellId = sk.spellId, abilityName = sk.abilityName, icon = sk.icon }
	if miss then
		ev.kind = "miss"
		ev.result = { key = "immune", text = "Immune" }
	else
		ev.kind = "damage"
		ev.amount = amount
		damageSent = damageSent + amount
	end
	world.events[world.nEvents] = ev
	hitsSent = hitsSent + 1
end

local function FireEvent(name, a1)
	for i = 1, table.getn(eventFrames) do
		local f = eventFrames[i]
		if f.__events[name] and f.__scripts.OnEvent then
			this, event, arg1 = f, name, a1
			f.__scripts.OnEvent()
		end
	end
end

local function CountVisible()
	local visible, totalShown = 0, 0
	for i = 1, table.getn(allFontStrings) do
		local fs = allFontStrings[i]
		local visual = fs.__parent
		local holder = visual and visual.__parent
		if holder and holder.__parent == CreedUINumbersLayer and holder.__shown and holder.__alpha > 0.35 then
			visible = visible + 1
		end
	end
	return visible
end

local stats = {}
local function Frame(dt, handler)
	now = now + dt
	for i = 1, table.getn(updaters) do
		local f = updaters[i]
		if f.__shown and f.__scripts.OnUpdate then
			this, arg1 = f, dt
			f.__scripts.OnUpdate()
		end
	end
	if handler ~= false and world.handler then
		world.handler()
	end
	local v = CountVisible()
	if SN_TEST then
		local labels, n, sdb = SN_TEST.state()
		local live = 0
		for i = 1, n do
			local l = labels[i]
			if l.w and not l.culled then live = live + 1 end
			if l.w and not stats.firstShown[l] then stats.firstShown[l] = now; stats.shownCount = stats.shownCount + 1 end
			if l.culled and stats.firstShown[l] and not stats.culledAt[l] then
				stats.culledAt[l] = now
				if now - stats.firstShown[l] < 0.3 then stats.flicker = stats.flicker + 1 end
			end
		end
		stats.maxLive = math.max(stats.maxLive or 0, live)
		if live > sdb.maxLabels then Problem("more numbers than the cap on screen: " .. live .. " > " .. sdb.maxLabels) end
	end
	stats.maxVisible = math.max(stats.maxVisible or 0, v)
	stats.sumVisible = (stats.sumVisible or 0) + v
	stats.frames = (stats.frames or 0) + 1
end

local function ResetStats() stats = { firstShown = {}, culledAt = {}, flicker = 0, shownCount = 0 }; hitsSent = 0; damageSent = 0 end
ResetStats()

------------------------------------------------------------------ load the addon
local file = io.open(ADDON_FILE, "r")
local src = file:read("*a")
file:close()
src = src .. "\nSN_TEST = { state = function() return labels, nLabels, db end, short = Short, commas = Commas, widgets = function() return nAllWidgets end }\n"
CreedUI = { VERSION = "1.0.0", palStamp = 0 }
function CreedUI.DB(name)
	if type(CreedUIDB) ~= "table" then CreedUIDB = {} end
	CreedUIDB[name] = CreedUIDB[name] or {}
	return CreedUIDB[name]
end
function CreedUI.OldAddon() return false end
function CreedUI.RegisterPart() end
local chunk, err = loadstring(src, "Numbers.lua")
if not chunk then print("LOAD ERROR " .. err) os.exit(1) end
chunk()

FireEvent("ADDON_LOADED", "SmoothNumbers")
FireEvent("VARIABLES_LOADED")
FireEvent("PLAYER_ENTERING_WORLD")
-- the original per-enemy behaviour: crowd merging off for these scenarios
CreedUIDB.numbers.crowd = (os.getenv("CROWD") == "1")

local function Check(cond, msg)
	if not cond then Problem(msg) end
end

------------------------------------------------------------------ 1. formatting
local Short, Commas = SN_TEST.short, SN_TEST.commas
local cases = {
	{ 0, "0" }, { 7, "7" }, { 950, "950" }, { 999.9, "999" }, { 1000, "1K" }, { 1200, "1.2K" }, { 1234, "1.2K" },
	{ 1999, "1.9K" }, { 9999, "9.9K" }, { 10000, "10K" }, { 12345, "12.3K" }, { 99999, "99.9K" },
	{ 100000, "100K" }, { 123456, "123K" }, { 999999, "999K" }, { 1000000, "1M" }, { 1234567, "1.2M" },
	{ 25000000, "25M" }, { 3000000000, "3B" }, { 12800000000000, "12.8T" }, { 1e15, "1000T" },
}
for i = 1, table.getn(cases) do
	local got = Short(cases[i][1])
	Check(got == cases[i][2], "Short(" .. cases[i][1] .. ") gave " .. got .. ", wanted " .. cases[i][2])
end
local ccases = { { 0, "0" }, { 999, "999" }, { 1000, "1,000" }, { 12345, "12,345" }, { 1234567, "1,234,567" }, { 3000000000, "3,000,000,000" } }
for i = 1, table.getn(ccases) do
	local got = Commas(ccases[i][1])
	Check(got == ccases[i][2], "Commas(" .. ccases[i][1] .. ") gave " .. got)
end

------------------------------------------------------------------ 2. switched on: the game's numbers off
Check(cvars.CombatDamage == "0", "CombatDamage should be 0 while on, is " .. tostring(cvars.CombatDamage))
Check(world.handler ~= nil, "frame handler not registered")

------------------------------------------------------------------ 3. one boss, 25 hits a second for 4 s: totals add up
for i = 1, 6 do Frame(1 / 60) end -- subscribe
local boss = NewEnemy("Hogger", 2, 4)
ResetStats()
local labelsSeen = {}
local bossDamage = 0
for f = 1, 240 do
	if math.mod(f, 2) == 0 or math.mod(f, 3) == 0 then
		local crit = math.random() < 0.15
		local amount = math.random(500, 1500) * (crit and 2 or 1)
		bossDamage = bossDamage + amount
		Hit(boss, amount, crit, false)
	end
	Frame(1 / 60)
	local labels, n = SN_TEST.state()
	for i = 1, n do labelsSeen[labels[i]] = true end
end
for i = 1, 90 do Frame(1 / 60) end
local sum, count = 0, 0
for label in pairs(labelsSeen) do
	sum = sum + label.total
	count = count + 1
	Check(label.boss, "a label on the final boss should be marked as a boss")
end
Check(sum == bossDamage, "label totals " .. sum .. " should equal damage dealt " .. bossDamage)
print(string.format("boss: %d hits became %d numbers (all damage accounted for: %s)", hitsSent, count, tostring(sum == bossDamage)))
local _, nLeft = SN_TEST.state()
Check(nLeft == 0, "labels should all be gone after the fight, " .. nLeft .. " left")

------------------------------------------------------------------ 4. a dense pack under AoE (Clean)
local function Pack(n, cx, cy, spread)
	local pack = {}
	for i = 1, n do
		pack[i] = NewEnemy("Kobold", cx + (math.random() - 0.5) * spread, cy + (math.random() - 0.5) * spread)
	end
	return pack
end

local function Brawl(pack, seconds, hitsPerSecond)
	ResetStats()
	local acc = 0
	for f = 1, seconds * 60 do
		acc = acc + hitsPerSecond / 60
		while acc >= 1 do
			acc = acc - 1
			local e = pack[math.random(1, table.getn(pack))]
			if e.alive then
				local r = math.random()
				Hit(e, math.random(300, 2500), r < 0.12, r > 0.75, r > 0.97, SKILL_NAMES[math.random(1, 5)])
				e.hp = e.hp - 1
				if e.hp <= 0 then
					e.alive = false
					e.deadX, e.deadY = e.x, e.y
				end
			end
		end
		for i = 1, table.getn(pack) do
			local e = pack[i]
			if e.alive then
				e.x = e.x + (math.random() - 0.5) * 0.05
				e.y = e.y + (math.random() - 0.5) * 0.05
			else
				-- respawn, like a survivors wave
				pack[i] = NewEnemy("Kobold", e.x + (math.random() - 0.5) * 4, e.y + (math.random() - 0.5) * 4)
			end
		end
		Frame(1 / 60)
	end
	-- let every number run out (a DoT's waits up to ~4 s for a next tick)
	for i = 1, 330 do Frame(1 / 60) end
	print(string.format("   numbers shown: %d, pushed out within 0.3 s of showing: %d", stats.shownCount, stats.flicker))
	return hitsSent, stats.maxVisible, stats.sumVisible / stats.frames
end

local pack = Pack(40, 0, 0, 22)
local hits, maxV, avgV = Brawl(pack, 8, 180)
local _, _, db = SN_TEST.state()
print(string.format("clean, 40 enemies, 180 hits/s: %d hits, at most %d numbers on screen (%.1f on average); cap %d",
	hits, maxV, avgV, db.maxLabels))
Check(maxV <= db.maxLabels + 6, "clean: too many numbers on screen at once: " .. maxV)

------------------------------------------------------------------ 5. same fight, Minimal and Detailed
CreedUI.numberSlash("minimal")
hits, maxV, avgV = Brawl(pack, 6, 180)
print(string.format("minimal: %d hits, at most %d numbers (%.1f on average); cap %d", hits, maxV, avgV, db.maxLabels))
Check(maxV <= db.maxLabels + 4, "minimal: too many numbers: " .. maxV)

CreedUI.numberSlash("detailed")
hits, maxV, avgV = Brawl(pack, 6, 180)
print(string.format("detailed: %d hits, at most %d numbers (%.1f on average); cap %d", hits, maxV, avgV, db.maxLabels))
Check(maxV <= db.maxLabels + 8, "detailed: too many numbers: " .. maxV)
CreedUI.numberSlash("clean")

------------------------------------------------------------------ 6. spacing: visible numbers rarely sit on top of each other
local overlaps, pairsChecked = 0, 0
local function MeasureOverlap()
	local boxes = {}
	for i = 1, table.getn(allFontStrings) do
		local fs = allFontStrings[i]
		local visual = fs.__parent
		local holder = visual and visual.__parent
		if holder and holder.__parent == CreedUINumbersLayer and holder.__shown and holder.__alpha > 0.5 then
			local p = holder.__points.CENTER
			if p then
				local w = fs:GetStringWidth() * visual.__scale
				local textures = visual.__textures or {}
				for t = 1, table.getn(textures) do
					local tex = textures[t]
					if tex.__shown and tex.__w == 22 and tex.__texture then w = w + 26 * visual.__scale end
				end
				local h = 24 * visual.__scale * 0.8
				table.insert(boxes, { x = p.x, y = p.y, w = w, h = h })
			end
		end
	end
	for i = 1, table.getn(boxes) do
		for j = i + 1, table.getn(boxes) do
			local a, b = boxes[i], boxes[j]
			pairsChecked = pairsChecked + 1
			if math.abs(a.x - b.x) < (a.w + b.w) / 2 * 0.8 and math.abs(a.y - b.y) < (a.h + b.h) / 2 * 0.8 then
				overlaps = overlaps + 1
			end
		end
	end
end
ResetStats()
local acc = 0
for f = 1, 300 do
	acc = acc + 3
	while acc >= 1 do
		acc = acc - 1
		local e = pack[math.random(1, table.getn(pack))]
		Hit(e, math.random(300, 2500), math.random() < 0.1, false, false)
	end
	Frame(1 / 60)
	if math.mod(f, 10) == 0 then MeasureOverlap() end
end
print(string.format("spacing: %d of %d pairs of visible numbers overlap by more than 20%%", overlaps, pairsChecked))
Check(overlaps <= pairsChecked * 0.05 + 3, "too many overlapping numbers: " .. overlaps)
for i = 1, 90 do Frame(1 / 60) end

------------------------------------------------------------------ 6b. icons
do
	local _, _, db = SN_TEST.state()
	CreedUI.numberSlash("clean")
	for i = 1, 120 do Frame(1 / 60) end
	local dummy = NewEnemy("Dummy", -20, -10)
	local function Shown()
		-- every visible number: its text, its icon texture (or nil) and anchors
		local out = {}
		local labels, n = SN_TEST.state()
		for i = 1, n do
			local l = labels[i]
			if l.w and l.w.shown and l.target == dummy.id then
				local w = l.w
				table.insert(out, { text = w.text.__text, icon = w.icon.__shown and w.icon.__texture or nil,
					edge = w.edge.__shown, iconLeft = w.icon.__points.LEFT, textLeft = w.text.__points.LEFT,
					width = l.textWidth, total = l.total })
			end
		end
		return out
	end
	-- icons on: two skills on one enemy are two numbers, each with its own icon
	Check(db.icons == true, "icons should be on by default")
	Hit(dummy, 1000, false, false, false, "fire")
	Hit(dummy, 700, false, false, false, "frost")
	Hit(dummy, 300, false, false, false, "melee")
	Hit(dummy, 200, false, false, false, "petmelee")
	Hit(dummy, 100, false, false, false, "shield")
	for i = 1, 4 do Frame(1 / 60) end
	local shown = Shown()
	local icons = {}
	for i = 1, table.getn(shown) do
		local s = shown[i]
		if s.icon then icons[s.icon] = s.text end
		Check(s.icon ~= nil and s.edge, "every number here should show an icon (" .. tostring(s.text) .. ")")
		if s.icon and s.iconLeft and s.textLeft then
			local want = math.floor(-(22 + 4 + math.floor(s.width + 0.5)) / 2 + 0.5)
			Check(s.iconLeft.x == want, "icon should sit left so icon + number are centred: " .. s.iconLeft.x .. " vs " .. want)
			Check(s.textLeft.x == want + 26, "the number should start right after its icon")
		end
	end
	Check(table.getn(shown) == 5, "five skills on one enemy should give five numbers with icons on, got " .. table.getn(shown))
	Check(icons["Interface\\Icons\\Spell_Fire_FlameBolt"] == "1K", "Fireball's number should carry its icon")
	Check(icons["Interface\\Icons\\Spell_Frost_FrostBolt02"] == "700", "Frostbolt's number should carry its icon")
	Check(icons["Interface\\Icons\\INV_Sword_27"] == "300", "a swing should show the weapon in hand")
	Check(icons["Interface\\Icons\\Ability_Hunter_Pet_Wolf"] == "200", "a pet's swing should show the pet")
	Check(icons["Interface\\Icons\\Spell_Nature_Thorns"] == "100", "a damage shield should show Thorns")
	print("icons on: " .. table.getn(shown) .. " numbers on one enemy, each with its skill's icon")
	for i = 1, 90 do Frame(1 / 60) end
	-- icons off: one number for the enemy, no icon, centred
	CreedUI.numberSlash("reset")
	db.icons = false
	Hit(dummy, 1000, false, false, false, "fire")
	Hit(dummy, 700, false, false, false, "frost")
	for i = 1, 4 do Frame(1 / 60) end
	shown = Shown()
	Check(table.getn(shown) == 1 and shown[1].total == 1700, "icons off: one number holding both skills")
	Check(shown[1] and shown[1].icon == nil and not shown[1].edge, "icons off: no icon")
	if shown[1] then
		Check(shown[1].textLeft.x == math.floor(-math.floor(shown[1].width + 0.5) / 2 + 0.5), "icons off: the number is centred")
	end
	-- switching icons back on mid-fight shows the icon at once
	db.icons = true
	for i = 1, 2 do Frame(1 / 60) end
	shown = Shown()
	Check(shown[1] and shown[1].icon == "Interface\\Icons\\Spell_Fire_FlameBolt", "switching icons on shows the biggest hit's icon")
	for i = 1, 90 do Frame(1 / 60) end
end

------------------------------------------------------------------ 7. a new run / reload: STREAM_CHANGED
world.stream = world.stream + 1
for i = 1, 3 do Frame(1 / 60) end
Hit(pack[1], 1234, false, false)
for i = 1, 5 do Frame(1 / 60) end
local labels, n = SN_TEST.state()
Check(n >= 1, "after a stream change new hits should show again (labels: " .. n .. ")")
for i = 1, 90 do Frame(1 / 60) end

------------------------------------------------------------------ 8. the options window, every control
CreedUI.numberSlash("")
Check(CreedUINumbersOptions and CreedUINumbersOptions.__shown, "options window should open with /sn")
local buttons = {}
for i = 1, table.getn(allButtons) do
	local b, o = allButtons[i], allButtons[i]
	while o and o ~= CreedUINumbersOptions do o = o.__parent end
	if o then table.insert(buttons, b) end
end
local clicked = 0
for i = 1, table.getn(buttons) do
	local b = buttons[i]
	if b.__scripts.OnEnter then b.__scripts.OnEnter() end
	if b.__scripts.OnClick then this = b; b.__scripts.OnClick(); clicked = clicked + 1 end
	if b.__scripts.OnLeave then b.__scripts.OnLeave() end
	for f = 1, 5 do Frame(1 / 60) end
end
print("options: clicked " .. clicked .. " controls")
Check(clicked >= 9, "expected at least 9 clickable controls, found " .. clicked)
-- the big toggle was clicked once (off), so the game's numbers are back:
Check(cvars.CombatDamage == "1", "turning off should give the game its numbers back")
Check(world.handler == nil, "turning off should unregister the frame handler")
CreedUI.numberSlash("on")
Check(cvars.CombatDamage == "0", "turning on again should hide the game's numbers")
Check(world.handler ~= nil, "turning on again should register the frame handler")

------------------------------------------------------------------ 9. preview
CreedUI.numberSlash("preview")
ResetStats()
for f = 1, 200 do Frame(1 / 60) end
print(string.format("preview: at most %d numbers on screen", stats.maxVisible))
Check(stats.maxVisible >= 3, "preview should show numbers")
for f = 1, 300 do Frame(1 / 60) end

------------------------------------------------------------------ 10. every switch, one at a time, under fire
local keys = { "short", "group", "spread", "count", "school", "misses" }
for k = 1, table.getn(keys) do
	db[keys[k]] = not db[keys[k]]
	Brawl(pack, 1, 150)
	db[keys[k]] = not db[keys[k]]
end
for size = 6, 18, 6 do
	CreedUI.numberSlash("size " .. (size * 10))
	Brawl(pack, 1, 150)
end
CreedUI.numberSlash("size 100")

------------------------------------------------------------------ 11. a handler the game stopped calling
local saved = world.handler
world.handler = nil
for f = 1, 20 do Frame(1 / 60, false) end
Hit(pack[2], 777, false, false)
for f = 1, 10 do Frame(1 / 60, false) end
local _, n2 = SN_TEST.state()
Check(n2 >= 1, "with no frame handler calls the numbers should still come (OnUpdate)")
for f = 1, 60 do Frame(1 / 60, false) end
Check(world.handler ~= nil, "the addon should ask for its frame handler again")
for f = 1, 60 do Frame(1 / 60) end

------------------------------------------------------------------ 12. logout gives the numbers back
FireEvent("PLAYER_LOGOUT")
Check(cvars.CombatDamage == "1", "logout should restore the game's numbers, got " .. tostring(cvars.CombatDamage))

------------------------------------------------------------------ report
print(string.format("widgets made: %d, projections: %d (%d anchors), reads: %d", SN_TEST.widgets(), projections, projectedIds, reads))
for i = 1, table.getn(chat) do
	if string.find(chat[i], "problem") then Problem("addon reported: " .. chat[i]) end
end
print("chat lines: " .. table.getn(chat))
for i = 1, table.getn(chat) do print("  chat> " .. chat[i]) end
if table.getn(problems) == 0 then
	print("ALL CHECKS PASSED")
else
	for i = 1, table.getn(problems) do print("PROBLEM: " .. problems[i]) end
	os.exit(1)
end
