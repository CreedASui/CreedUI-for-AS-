-- Creed UI: friends down, in a party.
-- When a friend falls, a banner says so over the field with the game's raid warning sound. Where
-- they lie, a mark glows on the ground (stand on it to bring them back) with their name in their
-- class color and how far they are; while you revive them it turns bright green and counts up.
-- While they're off the screen, a gold arrow at its edge points the way, with the distance.

local C = CreedUI
local DEFAULTS = { enabled = true, scale = 1, sound = true }
local BANNER_IN, BANNER_HOLD, BANNER_OUT = 0.2, 3.2, 0.8
local MARK_YARDS = 3          -- the mark's width on the ground
local MARK_MIN, MARK_MAX = 34, 110
local EDGE = 46               -- how far in from the screen's edge the arrows ride
local READ_EVERY = 0.25
local MAX_FRIENDS = 4
local DOWN_COLOR, REVIVE_COLOR = { 1, 0.42, 0.28 }, { 0.35, 1, 0.55 }
-- the friend's class crest inside the mark: the game's character-creation class sheet, four across
local CRESTS = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
local CREST_AT = {
	WARRIOR = { 0, 0.25, 0, 0.25 }, MAGE = { 0.25, 0.49609375, 0, 0.25 }, ROGUE = { 0.49609375, 0.7421875, 0, 0.25 },
	DRUID = { 0.7421875, 0.98828125, 0, 0.25 }, HUNTER = { 0, 0.25, 0.25, 0.5 }, SHAMAN = { 0.25, 0.49609375, 0.25, 0.5 },
	PRIEST = { 0.49609375, 0.7421875, 0.25, 0.5 }, WARLOCK = { 0.7421875, 0.98828125, 0.25, 0.5 }, PALADIN = { 0, 0.25, 0.5, 0.75 },
}
local CREST_ALPHA = 0.68 -- see-through, as the mark is, but plain to see

local db
local layer, banner
local S = { friends = {}, n = 0, seen = {}, primed = false, readAt = -10, marks = {}, registered = false, handlerAt = -10,
	lastAt = nil, broken = false, bannerAt = nil, requests = {} }

------------------------------------------------------------------------ the game's answers
-- a friend's class (the game's English key, MAGE...) by their name, from the party
local function ClassOf(name)
	for i = 1, 4 do
		local unit = "party" .. i
		if C.Call(UnitName, unit) == name then
			local _, file = C.Call(UnitClass, unit)
			return file
		end
	end
end

local function ClassColor(name)
	local file = ClassOf(name)
	local c = type(RAID_CLASS_COLORS) == "table" and file and RAID_CLASS_COLORS[file]
	if c then return c.r, c.g, c.b end
	return 1, 1, 1
end

-- who is down now: { id, name, anchorId } each; nil while the game can't tell
local function ReadDowned()
	if type(AZS_GetDownedPartyMembers) ~= "function" then return nil end
	local list = C.Call(AZS_GetDownedPartyMembers)
	if type(list) ~= "table" then return nil end
	local out = {}
	for i = 1, table.getn(list) do
		local d = list[i]
		if type(d) == "table" and d.id ~= nil and table.getn(out) < MAX_FRIENDS then
			table.insert(out, { id = tostring(d.id), name = tostring(d.name or "?"),
				anchorId = (type(d.anchorId) == "string" and d.anchorStatus ~= "unavailable") and d.anchorId or nil })
		end
	end
	return out
end

-- the friend you stand over and how far along their revive is (0 to 1), from the game's revive line
local function Reviving()
	local r = type(AZS_GetRevive) == "function" and C.Call(AZS_GetRevive) or nil
	if type(r) ~= "table" or r.reviving == nil or r.reviving == "" or r.reviving == 0 then return nil, 0 end
	return tostring(r.reviving), C.Clamp(tonumber(r.rshare) or 0, 0, 1)
end

------------------------------------------------------------------------ the banner
local function Alert(names, now)
	if table.getn(names) == 1 then
		C.SetText(banner.text, C.F("{1} is down!", names[1]))
	else
		C.SetText(banner.text, C.F("{1} are down!", table.concat(names, C.L(" and "))))
	end
	S.bannerAt = now
	if db.sound and type(PlaySound) == "function" then pcall(PlaySound, "RaidWarning") end
end

local function StepBanner(now)
	if not S.bannerAt then
		C.Vis(banner, false)
		return
	end
	local age = now - S.bannerAt
	local a
	if age < BANNER_IN then a = C.Smooth(age / BANNER_IN)
	elseif age < BANNER_IN + BANNER_HOLD then a = 1
	else a = 1 - C.Smooth((age - BANNER_IN - BANNER_HOLD) / BANNER_OUT) end
	if a <= 0.01 and age > BANNER_IN then
		S.bannerAt = nil
		C.Vis(banner, false)
		return
	end
	C.Vis(banner, true)
	C.Alpha(banner, a)
	local pulse = 1 - C.Smooth(age / 0.5)
	C.Alpha(banner.glow, 0.45 + 0.4 * pulse)
end

------------------------------------------------------------------------ the marks and arrows
local function NewMark()
	local m = { alpha = 0 }
	local f = CreateFrame("Frame", nil, layer)
	m.frame = f
	f:SetWidth(40)
	f:SetHeight(40)
	f:EnableMouse(false)
	m.halo = C.Tex(f, "BACKGROUND", C.ART .. "Glow", "ADD")
	m.halo:SetPoint("CENTER", f, "CENTER", 0, 0)
	m.crest = C.Tex(f, "BORDER", CRESTS)
	m.crest:SetPoint("CENTER", f, "CENTER", 0, 0)
	C.Vis(m.crest, false)
	m.ring = C.Tex(f, "ARTWORK", C.ART .. "ReviveMark", "ADD")
	m.ring:SetPoint("CENTER", f, "CENTER", 0, 0)
	m.name = C.Text(f, C.FONT, 12, "OUTLINE", "CENTER", 160)
	m.name:SetPoint("BOTTOM", m.ring, "TOP", 0, 2)
	m.info = C.Text(f, C.FONT, 11, "OUTLINE", "CENTER", 160)
	m.info:SetPoint("TOP", m.ring, "BOTTOM", 0, -2)
	-- the arrow at the screen's edge, and its distance
	m.arrowFrame = CreateFrame("Frame", nil, layer)
	m.arrowFrame:SetWidth(36)
	m.arrowFrame:SetHeight(36)
	m.arrow = C.Tex(m.arrowFrame, "ARTWORK", C.ART .. "EdgeArrow")
	m.arrow:SetAllPoints(m.arrowFrame)
	m.arrowText = C.Text(m.arrowFrame, C.FONT, 11, "OUTLINE", "CENTER", 120)
	C.Vis(f, false)
	C.Vis(m.arrowFrame, false)
	return m
end

local function Mark(id)
	local m = S.marks[id]
	if not m then
		m = NewMark()
		S.marks[id] = m
	end
	return m
end

-- the arrow turned to point at `ang` (radians, screen up is pi/2): its picture points up
local function Turn(tex, ang)
	local t = ang - math.pi / 2
	local c, s = math.cos(t), math.sin(t)
	local function uv(dx, dy)
		local rx, ry = dx * c + dy * s, -dx * s + dy * c
		return 0.5 + rx, 0.5 - ry
	end
	local ulx, uly = uv(-0.5, 0.5)
	local llx, lly = uv(-0.5, -0.5)
	local urx, ury = uv(0.5, 0.5)
	local lrx, lry = uv(0.5, -0.5)
	tex:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry)
end

local function HideMark(m)
	C.Vis(m.frame, false)
	C.Vis(m.arrowFrame, false)
end

-- a friend on the screen: the mark on their spot, sized by the ground it covers
local function PlaceMark(m, e, f, ratio, revive, share)
	local size = MARK_YARDS * (tonumber(e.uiUnitsPerYard) or 12) * ratio
	size = math.floor(C.Clamp(size, MARK_MIN, MARK_MAX) * (db.scale or 1) + 0.5)
	C.Size(m.ring, size, size)
	-- their class crest inside, as see-through as the mark; the rising spirit when it isn't known
	local at = CREST_AT[ClassOf(f.name) or ""]
	if m.crestAt ~= at then
		m.crestAt = at
		m.ring:SetTexture(C.ART .. (at and "ReviveRing" or "ReviveMark"))
		if at then m.crest:SetTexCoord(at[1], at[2], at[3], at[4]) end
	end
	if at then
		C.Size(m.crest, size * 0.58, size * 0.58)
		C.Alpha(m.crest, CREST_ALPHA)
	end
	C.Vis(m.crest, at ~= nil)
	C.Size(m.halo, size * 1.8, size * 1.8)
	local col = revive and REVIVE_COLOR or DOWN_COLOR
	C.Color(m.ring, col[1], col[2], col[3], 1)
	C.Color(m.halo, col[1], col[2], col[3], 0.45 + (revive and 0.35 * share or 0.15 * math.sin(GetTime() * 3)))
	C.SetText(m.name, f.name)
	C.TextColor(m.name, ClassColor(f.name))
	if revive then
		C.SetText(m.info, C.F("Reviving {1}", math.floor(share * 100) .. "%"))
		C.TextColor(m.info, REVIVE_COLOR[1], REVIVE_COLOR[2], REVIVE_COLOR[3])
	else
		C.SetText(m.info, type(e.playerDistance) == "number" and C.F("{1} yd", math.floor(e.playerDistance + 0.5)) or "")
		C.TextColor(m.info, 1, 0.9, 0.75)
	end
	C.Place(m.frame, "CENTER", WorldFrame, "BOTTOMLEFT", math.floor(e.x * ratio * 10 + 0.5) / 10, math.floor(e.y * ratio * 10 + 0.5) / 10)
	C.Vis(m.frame, true)
	C.Vis(m.arrowFrame, false)
end

-- a friend off the screen: an arrow on its edge, toward them
local function PlaceArrow(m, e, f, ratio)
	local w, h = (WorldFrame:GetWidth() or 1024) * ratio, (WorldFrame:GetHeight() or 768) * ratio
	local cx, cy = w / 2, h / 2
	local dx, dy = e.x * ratio - cx, e.y * ratio - cy
	if e.state == "behindCamera" then dx, dy = -dx, -dy end
	if math.abs(dx) < 0.001 and math.abs(dy) < 0.001 then dy = -1 end
	-- out from the middle until the arrow meets the edge, EDGE in
	local kx = math.abs(dx) > 0.001 and (cx - EDGE) / math.abs(dx) or 1e9
	local ky = math.abs(dy) > 0.001 and (cy - EDGE) / math.abs(dy) or 1e9
	local k = math.min(kx, ky)
	local ax, ay = cx + dx * k, cy + dy * k
	local ang = math.atan2(dy, dx)
	Turn(m.arrow, ang)
	local r, g, b = ClassColor(f.name)
	C.Color(m.arrow, 0.6 + 0.4 * r, 0.55 + 0.4 * g, 0.4 + 0.4 * b, 1)
	C.Place(m.arrowFrame, "CENTER", layer, "BOTTOMLEFT", math.floor(ax + 0.5), math.floor(ay + 0.5))
	-- the words on the inner side of the arrow
	C.Place(m.arrowText, "CENTER", m.arrowFrame, "CENTER", -math.cos(ang) * 34, -math.sin(ang) * 26)
	local dist = type(e.playerDistance) == "number" and ("  " .. C.F("{1} yd", math.floor(e.playerDistance + 0.5))) or ""
	C.SetText(m.arrowText, f.name .. dist)
	C.Vis(m.arrowFrame, true)
	C.Vis(m.frame, false)
end

local function Project(ratio)
	local req = S.requests
	local n = 0
	for i = 1, S.n do
		local f = S.friends[i]
		if f.anchorId then
			n = n + 1
			local r = req[n] or { offset = { x = 0, y = 0, z = 0.2 } }
			req[n] = r
			r.anchorId, r.attachment, r.friend = f.anchorId, "position", f
		end
	end
	for i = n + 1, table.getn(req) do req[i] = nil end
	if n == 0 then return {} end
	local ok, res = pcall(AZS_ProjectWorldAnchors, req)
	local out = {}
	if not ok or type(res) ~= "table" or type(res.entries) ~= "table" then return out end
	for i = 1, n do
		local e = res.entries[i]
		if type(e) == "table" then out[req[i].friend.id] = e end
	end
	return out
end

local function Ratio()
	local ws, ls = WorldFrame:GetEffectiveScale(), layer:GetEffectiveScale()
	if type(ws) == "number" and type(ls) == "number" and ls > 0 then return ws / ls end
	return 1
end

local function Draw(now)
	local ratio = Ratio()
	local seen = (type(AZS_ProjectWorldAnchors) == "function") and Project(ratio) or {}
	local reviving, share = Reviving()
	local live = {}
	for i = 1, S.n do
		local f = S.friends[i]
		live[f.id] = true
		local m = Mark(f.id)
		local e = seen[f.id]
		local revive = reviving ~= nil and (reviving == f.id or reviving == f.name)
		if e and type(e.x) == "number" and type(e.y) == "number" and e.state == "onScreen" then
			PlaceMark(m, e, f, ratio, revive, share)
		elseif e and type(e.x) == "number" and type(e.y) == "number"
			and (e.state == "offscreen" or e.state == "behindCamera" or e.state == "clipped") then
			PlaceArrow(m, e, f, ratio)
		else
			HideMark(m)
		end
	end
	for id, m in pairs(S.marks) do
		if not live[id] then HideMark(m) end
	end
end

------------------------------------------------------------------------ each frame
local function Step(now)
	if now - S.readAt >= READ_EVERY then
		S.readAt = now
		local list = ReadDowned()
		if list then
			local fresh, ids = {}, {}
			for i = 1, table.getn(list) do
				ids[list[i].id] = true
				if S.primed and not S.seen[list[i].id] then table.insert(fresh, list[i].name) end
			end
			if table.getn(fresh) > 0 then Alert(fresh, now) end
			S.seen, S.primed = ids, true
			S.friends, S.n = list, table.getn(list)
		end
	end
	StepBanner(now)
	if S.n == 0 and next(S.marks) == nil then return end
	Draw(now)
end

------------------------------------------------------------------------ on and off
local OnFrame

local function Unregister()
	if S.registered and type(AZS_UnregisterWorldAnchorFrameHandler) == "function" then
		pcall(AZS_UnregisterWorldAnchorFrameHandler, OnFrame)
	end
	S.registered = false
end

local function Clear()
	for _, m in pairs(S.marks) do HideMark(m) end
	S.friends, S.n, S.bannerAt = {}, 0, nil
	C.Vis(banner, false)
end

local function Safe(now)
	if S.broken or not db or not db.enabled then return end
	local ok, err = pcall(Step, now)
	if not ok then
		S.broken = true
		Unregister()
		Clear()
		C.Print(C.L("the downed friends' marks stopped after an error: ") .. tostring(err))
	end
end

OnFrame = function()
	local now = GetTime()
	S.handlerAt = now
	Safe(now)
end

local function Register()
	if S.registered or type(AZS_RegisterWorldAnchorFrameHandler) ~= "function" then return end
	local ok, result, failure = pcall(AZS_RegisterWorldAnchorFrameHandler, OnFrame)
	S.registered = ok and failure == nil and result ~= false
end

local function SetEnabled(on)
	db.enabled = on and true or false
	if on then
		S.broken, S.primed, S.readAt = false, false, -10
		Register()
	else
		Unregister()
		Clear()
	end
end

local function Build()
	layer = CreateFrame("Frame", "CreedUIDowned", WorldFrame)
	layer:SetAllPoints(WorldFrame)
	layer:SetFrameStrata("LOW")
	layer:EnableMouse(false)
	banner = CreateFrame("Frame", "CreedUIDownedBanner", UIParent)
	banner:SetWidth(520)
	banner:SetHeight(60)
	banner:SetPoint("TOP", UIParent, "TOP", 0, -170)
	banner:SetFrameStrata("HIGH")
	banner:EnableMouse(false)
	banner.glow = C.Tex(banner, "BACKGROUND", C.ART .. "Glow", "ADD")
	banner.glow:SetPoint("CENTER", banner, "CENTER", 0, 4)
	banner.glow:SetWidth(520)
	banner.glow:SetHeight(110)
	banner.glow:SetVertexColor(1, 0.3, 0.15)
	banner.text = C.Text(banner, C.TITLE_FONT, 26, "OUTLINE", "CENTER", 520)
	banner.text:SetPoint("CENTER", banner, "CENTER", 0, 8)
	banner.text:SetTextColor(1, 0.5, 0.36)
	banner.sub = C.Text(banner, C.FONT, 13, "OUTLINE", "CENTER", 520)
	banner.sub:SetPoint("TOP", banner.text, "BOTTOM", 0, -4)
	banner.sub:SetTextColor(1, 0.92, 0.8)
	C.LText(banner.sub, "Stand on them to bring them back.")
	C.Vis(banner, false)
	if type(AZS_SetOnTopOfScreens) == "function" then pcall(AZS_SetOnTopOfScreens, banner, true) end
end

C.OnInit(function()
	db = C.DB("downed", DEFAULTS)
	Build()
	-- as the skulls: the game's handler moves the marks with its camera; while it's quiet, from here
	local driver = CreateFrame("Frame", "CreedUIDownedDriver")
	local nextTry = 0
	driver:SetScript("OnUpdate", function()
		if not db or not db.enabled or S.broken then return end
		local now = GetTime()
		if now - S.handlerAt > 0.25 then Safe(now) end
		if type(AZS_RegisterWorldAnchorFrameHandler) == "function" and now - S.handlerAt > 1 and now >= nextTry then
			nextTry = now + 5
			S.registered = false
			Register()
		end
	end)
end)

C.OnWorld(function()
	if not db then return end
	Clear()
	S.primed, S.readAt = false, -10
	if db.enabled then Register() end
	if banner and type(AZS_SetOnTopOfScreens) == "function" then pcall(AZS_SetOnTopOfScreens, banner, true) end
end)

C.RegisterPart({
	key = "downed", name = "Downed friends",
	note = "In a party: a warning and a sound when a friend goes down, a glowing mark where they lie (stand on it to bring them back), and an arrow at the screen's edge with the distance while they're off it.",
	get = function() return db and db.enabled end,
	set = function(on) if db then SetEnabled(on) end end,
	getScale = function() return db and db.scale or 1 end,
	setScale = function(v) if db then db.scale = v end end,
})
