-- Creed UI: stored level-ups.
-- With the game's Store Level-Ups setting on, a level gained doesn't stop the fight: it waits.
-- While some wait, a gold-railed "Level Up!" button glows over the skill bar with how many there
-- are; a new one makes it pulse. Click it and the game offers them, one after another, as its own
-- button does. While this part is on, the game's button is hidden; off, it comes back.

local C = CreedUI
local DEFAULTS = { enabled = true, scale = 1 }
local W, H = 180, 30

local db
local root
local S = { alpha = 0, n = 0, pop = nil, takeClock = 0, broken = false }

local function Waiting()
	if type(AZS_GetStoredLevels) ~= "function" then return 0 end
	local n = tonumber(C.Call(AZS_GetStoredLevels)) or 0
	if n > 0 and type(AZS_IsStoringLevels) == "function" and not C.Call(AZS_IsStoringLevels) then n = 0 end
	return n
end

local function Open()
	if type(AZS_OpenStoredLevels) == "function" and S.n > 0 then
		C.Call(AZS_OpenStoredLevels)
		if GameTooltip then GameTooltip:Hide() end
	end
end

local function ShowTip()
	if not GameTooltip or C.unlocked then return end
	GameTooltip:SetOwner(root, "ANCHOR_TOP")
	GameTooltip:AddLine(C.L("Level Up!"), 0.98, 0.85, 0.52)
	GameTooltip:AddLine(C.F("{1} level-ups wait. Click to pick their cards.", S.n), 1, 1, 1, 1)
	C.ShowTip()
end

local function Step(dt, now)
	local n = Waiting()
	if n > S.n then S.pop = now end -- one more: it pulses
	S.n = n
	local want = (n > 0) and (1 - C.cardsFade) or 0
	S.alpha = C.Toward(S.alpha, want, 8, dt)
	if S.alpha < 0.01 then
		C.Vis(root, false)
		return
	end
	C.Vis(root, true)
	C.Alpha(root, S.alpha)
	C.SetText(root.count, tostring(n))
	-- a slow breath of light, and a bright pulse when one more comes
	local pop = 0
	if S.pop then
		local age = now - S.pop
		pop = C.Smooth(age / 0.08) * (1 - C.Smooth((age - 0.08) / 0.7))
		if age > 0.8 then S.pop = nil end
	end
	local breath = 0.5 + 0.5 * math.sin(now * 2.4)
	C.Alpha(root.glow, 0.35 + 0.25 * breath + 0.4 * pop)
	C.Size(root.glow, W * (1.35 + 0.25 * pop), H * (2.6 + 0.6 * pop))
	C.Alpha(root.gemGlow, 0.5 + 0.5 * pop)
	S.takeClock = S.takeClock - dt
	if S.takeClock <= 0 then
		S.takeClock = 2
		C.TakeHud("levels")
	end
end

local function Apply()
	if db.enabled then
		C.TakeHud("levels")
	else
		C.ReleaseHud("levels")
		C.Vis(root, false)
		S.alpha = 0
	end
end

C.OnInit(function()
	db = C.DB("levelups", DEFAULTS)
	root = CreateFrame("Button", "CreedUILevelUps", UIParent)
	root:SetWidth(W)
	root:SetHeight(H)
	root:SetFrameStrata("MEDIUM")
	root:SetScale(db.scale)
	root:EnableMouse(true)
	root.glow = C.Tex(root, "BACKGROUND", C.ART .. "Glow", "ADD")
	root.glow:SetPoint("CENTER", root, "CENTER", 0, 0)
	root.glow:SetVertexColor(1, 0.72, 0.22)
	root.deco = C.Panel(root, false)
	C.PanelTheme(root.deco, C.Pal())
	root.label = C.Text(root, C.FONT, 14, "OUTLINE", "CENTER", W - 40)
	root.label:SetPoint("CENTER", root, "CENTER", -12, 0)
	root.label:SetTextColor(0.98, 0.85, 0.52)
	C.LText(root.label, "Level Up!")
	-- how many wait, on a red gem at the right end
	root.gemGlow = C.Tex(root, "ARTWORK", C.ART .. "Glow", "ADD")
	root.gemGlow:SetWidth(40)
	root.gemGlow:SetHeight(40)
	root.gemGlow:SetPoint("CENTER", root, "RIGHT", -18, 0)
	root.gemGlow:SetVertexColor(1, 0.4, 0.15)
	root.gem = C.Tex(root, "OVERLAY", C.ART .. "Gem")
	root.gem:SetWidth(26)
	root.gem:SetHeight(26)
	root.gem:SetPoint("CENTER", root, "RIGHT", -18, 0)
	root.gem:SetVertexColor(1, 0.3, 0.2)
	local top = CreateFrame("Frame", nil, root)
	top:SetAllPoints(root)
	top:SetFrameLevel(root:GetFrameLevel() + 2)
	root.count = C.Text(top, C.FONT, 12, "OUTLINE", "CENTER", 24)
	root.count:SetPoint("CENTER", root, "RIGHT", -18, 0)
	root:SetScript("OnClick", Open)
	root:SetScript("OnEnter", ShowTip)
	root:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	C.Vis(root, false)
	C.Movable(root, "levelups", "Stored level-ups", function(f)
		f:ClearAllPoints()
		f:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 118) -- over the skill bar and its XP line
	end)
	local driver = CreateFrame("Frame", "CreedUILevelUpsDriver")
	driver:SetScript("OnUpdate", function()
		if S.broken or not db.enabled then return end
		local dt = arg1 or 0
		if dt > 0.1 then dt = 0.1 end
		local ok, err = pcall(Step, dt, GetTime())
		if not ok then
			S.broken = true
			db.enabled = false
			Apply()
			db.enabled = true
			C.Print(C.L("the level-up button stopped after an error, so the game's own is back: ") .. tostring(err))
		end
	end)
	Apply()
end)

C.OnWorld(function()
	if db and db.enabled then C.TakeHud("levels") end
end)

C.OnLogout(function()
	if db then C.ReleaseHud("levels") end
end)

C.RegisterPart({
	key = "levelups", name = "Stored level-ups",
	note = "With the game's Store Level-Ups on: a glowing Level Up! button over the skill bar with how many wait. Click it to pick their cards. Replaces the game's button.",
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
