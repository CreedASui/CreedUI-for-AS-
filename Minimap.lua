-- Creed UI: the minimap. A metal ring in the map's colors replaces the game's border; on its foot
-- a little box keeps the local time (hover it for the run's), and under it sits the zone's name
-- in the timer's title style (above, the ring leaves no room before the screen's edge). The zoom
-- buttons go: the mouse wheel zooms. Turning this part off puts the game's minimap back as it was.

local C = CreedUI
local DEFAULTS = { enabled = true, clock = true }
local RUN_PHASES = { playing = true, choosing = true, paused = true, dead = true, victory = true }
local LINE = 14 -- the flourish each side of the zone's name
local HIDE = { "MinimapBorder", "MinimapBorderTop", "MinimapZoomIn", "MinimapZoomOut", "MinimapToggleButton",
	"GameTimeFrame", "MinimapZoneTextButton", "MinimapNorthTag" }

local db
local W = {}
local S = { applied = false, hidden = {}, zoneClock = 0, clockClock = 0, zone = nil, clockText = nil,
	titleA = 0, stamp = -1, hadClock = false }

local Call = C.Call -- no stray nil arguments (see Core)

------------------------------------------------------------------------ building
local function Build()
	if W.frame or type(Minimap) ~= "table" then return end
	local m = Minimap
	local f = CreateFrame("Frame", "CreedUIMinimap", m)
	W.frame = f
	f:SetPoint("CENTER", m, "CENTER", 0, 0)
	W.ring = C.Tex(f, "ARTWORK", C.ART .. "MapRing")
	W.ring:SetAllPoints(f)
	W.glow = C.Tex(f, "BACKGROUND", C.ART .. "Glow", "ADD")
	W.glow:SetPoint("CENTER", f, "TOP", 0, -6)
	W.glow:SetWidth(28)
	W.glow:SetHeight(28)
	W.north = C.Text(f, C.FONT, 9, "OUTLINE", "CENTER", 20)
	W.north:SetText("N")
	-- the zone's name, with the timer's flourishes
	W.title = C.Text(f, C.TITLE_FONT, 14, nil, "CENTER", 260)
	W.titleBg = C.Tex(f, "BACKGROUND", C.ART .. "Glow")
	W.titleBg:SetVertexColor(0, 0, 0, 0.5)
	W.lineL = C.Tex(f, "BORDER", C.FLAT)
	W.lineR = C.Tex(f, "BORDER", C.FLAT)
	W.gemL = C.Tex(f, "ARTWORK", C.ART .. "Diamond")
	W.gemR = C.Tex(f, "ARTWORK", C.ART .. "Diamond")
	for _, t in ipairs({ W.lineL, W.lineR }) do
		t:SetWidth(LINE)
		t:SetHeight(1)
	end
	for _, t in ipairs({ W.gemL, W.gemR }) do
		t:SetWidth(8)
		t:SetHeight(8)
	end
	-- the local time in a little box on the ring's foot, edged in the ring's metal
	local r = CreateFrame("Frame", "CreedUIMinimapClock", f)
	W.box = r
	r:SetHeight(16)
	r:SetWidth(44)
	r:SetPoint("CENTER", f, "BOTTOM", 0, 5)
	W.boxBg = C.Tex(r, "BACKGROUND", C.FLAT)
	W.boxBg:SetAllPoints(r)
	W.boxBg:SetGradientAlpha("VERTICAL", 0, 0, 0, 0.9, 0.09, 0.09, 0.11, 0.9)
	W.boxEdge = {}
	for i, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
		local t = C.Tex(r, "BORDER", C.FLAT)
		t:SetPoint(side[1], r, side[1], 0, 0)
		t:SetPoint(side[2], r, side[2], 0, 0)
		if i <= 2 then t:SetHeight(1) else t:SetWidth(1) end
		W.boxEdge[i] = t
	end
	W.boxText = C.Text(r, C.FONT, 11, "OUTLINE", "CENTER", 80)
	W.boxText:SetPoint("CENTER", r, "CENTER", 0, 0)
	W.boxText:SetTextColor(1, 0.95, 0.84)
	r:EnableMouse(true)
	r:SetScript("OnEnter", function()
		if not GameTooltip then return end
		GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
		GameTooltip:SetText(C.L("Local time"), 0.98, 0.85, 0.52)
		local t = RUN_PHASES[Call(AZS_GetPhase) or ""] and Call(AZS_GetRunTime)
		if type(t) == "number" then
			GameTooltip:AddDoubleLine(C.L("Run time"), C.Clock(t), 0.8, 0.8, 0.8, 1, 1, 1)
			local len = Call(AZS_GetRunLength)
			if type(len) == "number" and len > t then
				GameTooltip:AddDoubleLine(C.L("Final boss in"), C.Clock(len - t), 0.8, 0.8, 0.8, 1, 1, 1)
			end
		end
		C.ShowTip()
	end)
	r:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	C.Vis(r, false)
end

local function Layout()
	local m = Minimap
	local size = (m:GetWidth() or 140)
	if size < 40 then size = 140 end
	local ring = size / 0.875 + 2
	local f = W.frame
	f:SetWidth(ring)
	f:SetHeight(ring)
	f:SetFrameLevel(m:GetFrameLevel() + 6)
	W.box:SetFrameLevel(m:GetFrameLevel() + 8)
	W.north:ClearAllPoints()
	W.north:SetPoint("CENTER", f, "TOP", 0, -ring * 0.0375 - 0.5)
	W.title:ClearAllPoints()
	-- the zone's name steps down to leave the clock's box room; it slides in off the screen's edge
	W.title:SetPoint("TOP", f, "BOTTOM", S.titleShift or 0, db.clock and -9 or -1)
	W.titleBg:ClearAllPoints()
	W.titleBg:SetPoint("CENTER", W.title, "CENTER", 0, 0)
end

local function PlaceTitle()
	local tw = C.TextWidth(W.title)
	if tw <= 0 then tw = string.len(W.title.mt or "") * 7 end
	-- the name and its flourishes stay on the screen: the minimap sits by its edge
	local shift = 0
	local cx = W.frame:GetCenter()
	local right = type(GetScreenWidth) == "function" and GetScreenWidth() or nil
	if cx and right then
		local k = UIParent:GetEffectiveScale() / W.frame:GetEffectiveScale()
		local half = tw * 0.5 + 13 + LINE
		if cx + half > right * k - 4 then shift = right * k - 4 - (cx + half) end
		if cx - half + shift < 4 then shift = 4 - (cx - half) end
	end
	if shift ~= (S.titleShift or 0) then
		S.titleShift = shift
		W.title:ClearAllPoints()
		W.title:SetPoint("TOP", W.frame, "BOTTOM", shift, db.clock and -9 or -1)
	end
	C.Place(W.lineL, "RIGHT", W.title, "CENTER", -tw * 0.5 - 13, 0)
	C.Place(W.lineR, "LEFT", W.title, "CENTER", tw * 0.5 + 13, 0)
	C.Place(W.gemL, "CENTER", W.title, "CENTER", -tw * 0.5 - 8, 0)
	C.Place(W.gemR, "CENTER", W.title, "CENTER", tw * 0.5 + 8, 0)
	C.Size(W.titleBg, tw + 40, 26)
end

local function Theme(pal)
	local rim, t, g = pal.rim, pal.title, pal.glow
	W.ring:SetVertexColor(rim[1], rim[2], rim[3])
	W.gemL:SetVertexColor(rim[1], rim[2], rim[3])
	W.gemR:SetVertexColor(rim[1], rim[2], rim[3])
	W.title:SetTextColor(t[1], t[2], t[3])
	W.lineL:SetGradientAlpha("HORIZONTAL", t[1], t[2], t[3], 0, t[1], t[2], t[3], 0.75)
	W.lineR:SetGradientAlpha("HORIZONTAL", t[1], t[2], t[3], 0.75, t[1], t[2], t[3], 0)
	W.north:SetTextColor(1, 0.95, 0.8)
	for i = 1, 4 do W.boxEdge[i]:SetVertexColor(rim[1], rim[2], rim[3], 0.9) end
	W.glow:SetVertexColor(g[1], g[2], g[3], 0.35)
end

------------------------------------------------------------------------ zoom with the wheel
local function Wheel()
	local m = Minimap
	if type(m.GetZoom) ~= "function" or type(m.SetZoom) ~= "function" then return end
	local z = m:GetZoom() or 0
	local top = (type(m.GetZoomLevels) == "function" and m:GetZoomLevels() or 6) - 1
	if arg1 and arg1 > 0 and z < top then
		m:SetZoom(z + 1)
	elseif arg1 and arg1 < 0 and z > 0 then
		m:SetZoom(z - 1)
	end
end

------------------------------------------------------------------------ on and off
local function Apply()
	if type(Minimap) ~= "table" then return end
	Build()
	if db.enabled then
		if not S.applied then
			S.applied = true
			for i = 1, table.getn(HIDE) do
				local o = getglobal(HIDE[i])
				if type(o) == "table" and o.IsShown and o:IsShown() then
					o:Hide()
					S.hidden[HIDE[i]] = true
				end
			end
			if Minimap.EnableMouseWheel then
				Minimap:EnableMouseWheel(true)
				Minimap:SetScript("OnMouseWheel", Wheel)
			end
		end
		Layout()
		W.frame:Show()
		S.stamp = -1
	else
		if S.applied then
			S.applied = false
			for name in pairs(S.hidden) do
				local o = getglobal(name)
				if type(o) == "table" then o:Show() end
			end
			S.hidden = {}
			if Minimap.EnableMouseWheel then
				Minimap:SetScript("OnMouseWheel", nil)
				Minimap:EnableMouseWheel(false)
			end
		end
		if W.frame then W.frame:Hide() end
		C.ReleaseHud("localClock")
		S.hadClock = false
	end
end

-- the pieces the game may show again on its own (the zoom buttons enable themselves...)
local function KeepHidden()
	for name in pairs(S.hidden) do
		local o = getglobal(name)
		if type(o) == "table" and o.IsShown and o:IsShown() then o:Hide() end
	end
end

------------------------------------------------------------------------ every frame
local function Step(dt)
	if not db.enabled or not W.frame then return end
	local pal = C.Pal()
	if S.stamp ~= C.palStamp then
		S.stamp = C.palStamp
		Theme(pal)
		S.zone = nil
	end
	S.zoneClock = S.zoneClock - dt
	if S.zoneClock <= 0 then
		S.zoneClock = 0.5
		local zone = Call(GetMinimapZoneText) or Call(GetRealZoneText) or ""
		if zone ~= S.zone then
			S.zone = zone
			C.SetText(W.title, zone)
			PlaceTitle()
		end
		KeepHidden()
	end
	-- the clock: the device's time as the game reads it, once a second
	S.clockClock = S.clockClock - dt
	if S.clockClock <= 0 then
		S.clockClock = 1
		local text
		if db.clock and type(AZS_GetLocalTime) == "function" then
			local t = Call(AZS_GetLocalTime)
			if type(t) == "table" and type(t.text) == "string" then text = t.text end
		end
		if text then
			if text ~= W.boxText.mt then
				C.SetText(W.boxText, text)
				C.Width(W.box, math.max(40, math.floor(C.TextWidth(W.boxText) + 14)))
			end
			C.Vis(W.box, true)
			if not S.hadClock then
				S.hadClock = true
				C.TakeHud("localClock") -- only once ours has a time to show
			end
		elseif not db.clock or type(AZS_GetLocalTime) ~= "function" then
			C.Vis(W.box, false)
			if S.hadClock then
				S.hadClock = false
				C.ReleaseHud("localClock")
			end
		end
	end
	-- the north mark's soft glow breathes
	C.Color(W.glow, pal.glow[1], pal.glow[2], pal.glow[3], 0.22 + 0.1 * math.sin(GetTime() * 1.6))
end

C.OnInit(function()
	db = C.DB("minimap", DEFAULTS)
	local driver = CreateFrame("Frame", "CreedUIMinimapDriver")
	driver:RegisterEvent("ZONE_CHANGED")
	driver:RegisterEvent("ZONE_CHANGED_INDOORS")
	driver:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	driver:SetScript("OnEvent", function() S.zoneClock = 0 end)
	local broken = false
	driver:SetScript("OnUpdate", function()
		if broken then return end
		local dt = arg1 or 0
		if dt > 0.1 then dt = 0.1 end
		local ok, err = pcall(Step, dt)
		if not ok then
			broken = true
			db.enabled = false
			pcall(Apply)
			db.enabled = true
			C.Print(C.L("the minimap stopped after an error, so the game's own is back: ") .. tostring(err))
		end
	end)
end)

C.OnWorld(function()
	if not db then return end
	local ok, err = pcall(Apply)
	if not ok then C.Print(C.L("couldn't dress the minimap: ") .. tostring(err)) end
end)

C.OnLogout(function()
	if db then C.ReleaseHud("localClock") end
end)

C.RegisterPart({
	key = "minimap", name = "Minimap",
	note = "A metal ring in the map's colors, the local time on its foot and the zone's name under it. The mouse wheel zooms.",
	get = function() return db and db.enabled end,
	set = function(on)
		if db then
			db.enabled = on and true or false
			Apply()
		end
	end,
})

C.RegisterPart({
	key = "clock", name = "Clock on the minimap",
	note = "A little box on the minimap ring's foot with your local time. Hover it for the run's time and the time to the final boss.",
	get = function() return db and db.enabled and db.clock end,
	set = function(on)
		if db then
			db.clock = on and true or false
			S.clockClock = 0
			if W.frame then Layout() end
		end
	end,
})
