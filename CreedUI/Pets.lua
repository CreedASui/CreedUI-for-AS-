-- Creed UI: the pet bar.
-- Just over the skill bar on its left, a small gold-railed bar for your pets. When the game gives
-- the pet its own buttons (a hunter's beast, a warlock's demon), they are here: click one to use
-- it, right-click to switch its autocast, point at it for the game's tooltip, a dark veil while it
-- cools down. Otherwise each kind of summon you have out (Spirit Wolves, Treants, an Infernal...)
-- shows its face, how many there are and the seconds the first one has left, followed by the
-- skills you've seen it use (from the damage meter), each with its damage on its tooltip.
-- Nothing out, nothing shows; it hides behind the level-up cards.

local C = CreedUI
local DEFAULTS = { enabled = true, scale = 1 }
local K = { slot = 30, skill = 22, gap = 4, pad = 7, actions = 10, skills = 4, groups = 4 }

local db
local root
local S = { slots = {}, alpha = 0, broken = false, mode = nil }

------------------------------------------------------------------------ what there is
-- the game's pet buttons: { index, name, icon, active, auto, autoAllowed } each, or nil for none
local function Actions()
	if type(GetPetActionInfo) ~= "function" then return nil end
	if type(PetHasActionBar) == "function" and not PetHasActionBar() then return nil end
	local out
	for i = 1, K.actions do
		local name, _, tex, isToken, active, autoAllowed, auto = GetPetActionInfo(i)
		if name then
			out = out or {}
			if isToken and type(tex) == "string" then tex = getglobal(tex) or tex end
			if isToken and type(name) == "string" then name = getglobal(name) or name end
			table.insert(out, { index = i, name = name, icon = tex, active = active, auto = auto, autoAllowed = autoAllowed })
		end
	end
	return out
end

-- your summons by kind, each with the skills the meter saw it use
local function Groups()
	if type(AZS_GetSummonGroups) ~= "function" then return nil end
	local ok, groups = pcall(AZS_GetSummonGroups)
	if not ok or type(groups) ~= "table" or table.getn(groups) == 0 then return nil end
	return groups
end

------------------------------------------------------------------------ the slots
local function NewSlot(i)
	local s = { cool = 0 }
	local b = CreateFrame("Button", nil, root)
	s.button = b
	b:EnableMouse(true)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	s.bg = C.Tex(b, "BACKGROUND", C.FLAT)
	s.bg:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3)
	s.bg:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
	s.bg:SetVertexColor(0.03, 0.03, 0.04, 0.92)
	s.icon = b:CreateTexture(nil, "BORDER")
	s.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3)
	s.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
	s.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	s.shade = C.Tex(b, "ARTWORK", C.FLAT)
	s.shade:SetPoint("TOP", b, "TOP", 0, -3)
	s.shade:SetVertexColor(0, 0, 0, 0.66)
	s.bezel = C.Tex(b, "OVERLAY", C.ART .. "Slot")
	s.bezel:SetAllPoints(b)
	s.top = CreateFrame("Frame", nil, b)
	s.top:SetAllPoints(b)
	s.top:SetFrameLevel(b:GetFrameLevel() + 2)
	-- autocast on, or the pet's stance in use: a gold glow round the slot
	s.glow = C.Tex(s.top, "OVERLAY", C.ART .. "Glow", "ADD")
	s.glow:SetPoint("CENTER", b, "CENTER", 0, 0)
	s.glow:SetVertexColor(1, 0.80, 0.40)
	s.count = C.Text(s.top, C.FONT, 11, "OUTLINE", "RIGHT", 30)
	s.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
	s.time = C.Text(s.top, C.FONT, 9, "OUTLINE", "CENTER", 40)
	s.time:SetPoint("TOP", b, "BOTTOM", 0, -1)
	s.time:SetTextColor(1, 0.86, 0.6)
	C.Vis(s.shade, false)
	C.Vis(s.glow, false)
	b:SetScript("OnClick", function()
		if s.kind ~= "action" then return end
		if arg1 == "RightButton" then
			if type(TogglePetAutocast) == "function" then C.Call(TogglePetAutocast, s.index) end
		elseif type(CastPetAction) == "function" then
			C.Call(CastPetAction, s.index)
		end
	end)
	b:SetScript("OnEnter", function()
		if not GameTooltip or C.unlocked then return end
		GameTooltip:SetOwner(b, "ANCHOR_TOP")
		if s.kind == "action" and GameTooltip.SetPetAction then
			GameTooltip:SetPetAction(s.index)
			GameTooltip:Show()
			return
		end
		GameTooltip:AddLine(s.name or "?", 0.98, 0.85, 0.52)
		if s.kind == "summon" then
			if (s.n or 1) > 1 then GameTooltip:AddLine(C.F("{1} out", s.n), 1, 1, 1) end
			if s.left then GameTooltip:AddLine(C.F("{1} s left", math.ceil(s.left)), 1, 1, 1) end
			if not s.hasSkills then GameTooltip:AddLine(C.L("Its skills show here once it uses them."), 0.7, 0.7, 0.7, 1) end
		elseif s.kind == "skill" and s.amount then
			GameTooltip:AddDoubleLine(C.L("Damage"), C.Commas(math.floor(s.amount + 0.5)), 0.8, 0.8, 0.8, 1, 1, 1)
		end
		C.ShowTip()
	end)
	b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	S.slots[i] = s
	return s
end

local function Put(i, x, size, kind)
	local s = S.slots[i] or NewSlot(i)
	s.kind = kind
	C.Size(s.button, size, size)
	C.Place(s.button, "BOTTOMLEFT", root, "BOTTOMLEFT", x, K.pad)
	C.Size(s.glow, size * 1.9, size * 1.9)
	C.Vis(s.button, true)
	return s
end

local function Cooldown(s, size)
	local start, dur, enable = 0, 0, 1
	if type(GetPetActionCooldown) == "function" then start, dur, enable = GetPetActionCooldown(s.index) end
	local left = (enable ~= 0 and (dur or 0) > 1.5) and (start + dur - GetTime()) or 0
	if left > 0 then
		C.Size(s.shade, size - 6, math.max(1, (size - 6) * left / dur))
		C.Vis(s.shade, true)
	else
		C.Vis(s.shade, false)
	end
end

------------------------------------------------------------------------ each frame
local function Step(dt, now)
	local n, x = 0, K.pad
	local actions = Actions()
	if actions then
		for i = 1, table.getn(actions) do
			local a = actions[i]
			n = n + 1
			local s = Put(n, x, K.slot, "action")
			s.index, s.name = a.index, a.name
			s.icon:SetTexture(a.icon)
			Cooldown(s, K.slot)
			C.Vis(s.glow, (a.auto or a.active) and true or false)
			C.SetText(s.count, "")
			C.SetText(s.time, "")
			x = x + K.slot + K.gap
		end
	else
		local groups = Groups() or {}
		local skills = C.petSkills or {}
		for g = 1, math.min(table.getn(groups), K.groups) do
			local grp = groups[g]
			n = n + 1
			local s = Put(n, x, K.slot, "summon")
			s.name, s.n, s.left = grp.name, tonumber(grp.count) or 1, tonumber(grp.remaining)
			s.icon:SetTexture(grp.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
			C.Vis(s.shade, false)
			C.Vis(s.glow, false)
			C.SetText(s.count, (s.n > 1) and tostring(s.n) or "")
			C.SetText(s.time, s.left and tostring(math.ceil(s.left)) or "")
			x = x + K.slot + K.gap
			local list = skills[grp.key] or skills[grp.name] or {}
			s.hasSkills = table.getn(list) > 0
			for k = 1, math.min(table.getn(list), K.skills) do
				n = n + 1
				local sk = Put(n, x, K.skill, "skill")
				sk.name, sk.amount = list[k].name, list[k].amount
				sk.icon:SetTexture(list[k].icon or "Interface\\Icons\\INV_Misc_QuestionMark")
				C.Vis(sk.shade, false)
				C.Vis(sk.glow, false)
				C.SetText(sk.count, "")
				C.SetText(sk.time, "")
				x = x + K.skill + K.gap
			end
			x = x + K.gap * 2
		end
	end
	for i = n + 1, table.getn(S.slots) do C.Vis(S.slots[i].button, false) end
	local want = (n > 0) and (1 - C.cardsFade) or 0
	S.alpha = C.Toward(S.alpha, want, 8, dt)
	if S.alpha < 0.01 then
		C.Vis(root, false)
		return
	end
	C.Width(root, math.max(x - K.gap + K.pad, K.slot + 2 * K.pad))
	C.Alpha(root, S.alpha)
	C.Vis(root, true)
end

local function Apply()
	if not db.enabled then
		C.Vis(root, false)
		S.alpha = 0
	end
end

C.OnInit(function()
	db = C.DB("pets", DEFAULTS)
	root = CreateFrame("Frame", "CreedUIPetBar", UIParent)
	root:SetWidth(K.slot + 2 * K.pad)
	root:SetHeight(K.slot + 2 * K.pad + 8)
	root:SetFrameStrata("MEDIUM")
	root:SetScale(db.scale)
	root.deco = C.Panel(root, false)
	C.PanelTheme(root.deco, C.Pal())
	C.Vis(root, false)
	C.Movable(root, "pets", "Pet bar", function(f)
		f:ClearAllPoints()
		if CreedUIBar then
			f:SetPoint("BOTTOMLEFT", CreedUIBar, "TOPLEFT", 0, 30) -- over the skill bar, on its left
		else
			f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM", -260, 110)
		end
	end)
	local driver = CreateFrame("Frame", "CreedUIPetBarDriver")
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
			C.Print(C.L("the pet bar stopped after an error: ") .. tostring(err))
		end
	end)
	Apply()
end)

C.RegisterPart({
	key = "pets", name = "Pet bar",
	note = "Over the skill bar on the left: your pet's own buttons (click to use, right-click for autocast), or each kind of summon you have out with its count, time left and the skills it has used.",
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
