-- A stand-in for Azeroth Survivors' character window, as the screenshot shows it: the game's own
-- CharacterFrame (art, portrait, name, the gear slots round the model, its tabs) with the server's
-- stat boxes under the model and its Run Stats panel beside it. Built from the stock 1.12 names
-- and geometry; the server's boxes in two ways (font strings straight on a box, and rows that are
-- frames of their own) so the reading copes with either.
local M = MOCK

local function Text(parent, text, x, y, justify, w)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	fs:SetFont("Fonts\\FRIZQT__.TTF", 11)
	fs:SetPoint(justify == "RIGHT" and "TOPRIGHT" or "TOPLEFT", parent, "TOPLEFT", x, y)
	fs:SetWidth(w or 80)
	fs:SetHeight(13)
	fs:SetText(text)
	return fs
end

function M.MakeCharacter()
	local cf = CreateFrame("Frame", "CharacterFrame", UIParent)
	cf:SetWidth(384)
	cf:SetHeight(512)
	cf:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -104)
	cf:SetFrameLevel(1)
	local portrait = cf:CreateTexture("CharacterFramePortrait", "BACKGROUND")
	CharacterFramePortrait = portrait
	portrait:SetWidth(60)
	portrait:SetHeight(60)
	portrait:SetPoint("TOPLEFT", cf, "TOPLEFT", 7, -6)
	local name = cf:CreateFontString("CharacterNameText", "ARTWORK")
	CharacterNameText = name
	name:SetFont("Fonts\\FRIZQT__.TTF", 12)
	name:SetPoint("CENTER", cf, "TOP", 0, -20)
	name:SetText("Creed")
	local close = CreateFrame("Button", "CharacterFrameCloseButton", cf)
	close:SetWidth(32)
	close:SetHeight(32)
	close:SetPoint("TOPRIGHT", cf, "TOPRIGHT", -30, -8)
	-- the tabs as 1.12 numbers them: Character, Pet, Reputation, Skills, Honor (the server hides Pet
	-- and Reputation); a click shows its page and hides the others, as CharacterFrame_ShowSubFrame
	SKILLS, HONOR = "Skills", "Honor"
	local pages = { "PaperDollFrame", "PetPaperDollFrame", "ReputationFrame", "SkillFrame", "HonorFrame" }
	M.charPages = pages
	for i, label in ipairs({ "Character", "Pet", "Reputation", "Skills", "Honor" }) do
		local tab = CreateFrame("Button", "CharacterFrameTab" .. i, cf)
		tab:SetWidth(80)
		tab:SetHeight(32)
		tab:SetPoint("TOPLEFT", cf, "BOTTOMLEFT", 11 + (i - 1) * 78, 78)
		tab:SetID(i)
		for _, part in ipairs({ "Left", "Middle", "Right" }) do
			local t = tab:CreateTexture("CharacterFrameTab" .. i .. part, "BORDER")
			t:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-InActiveTab")
			t:SetWidth(20)
			t:SetHeight(32)
			t:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, 0)
		end
		local fs = tab:CreateFontString("CharacterFrameTab" .. i .. "Text", "ARTWORK")
		setglobal("CharacterFrameTab" .. i .. "Text", fs)
		fs:SetFont("Fonts\\FRIZQT__.TTF", 10)
		fs:SetPoint("CENTER", tab, "CENTER", 0, 2)
		fs:SetText(label)
		if i == 1 then tab:Disable() end
		if i == 2 or i == 3 then tab:Hide() end
		tab:SetScript("OnClick", function()
			for j = 1, 5 do
				local other = getglobal("CharacterFrameTab" .. j)
				if j == this:GetID() then other:Disable() else other:Enable() end
			end
			-- shown first, then the others hidden (the order the game runs them in)
			for j, name in ipairs(pages) do if j == this:GetID() and getglobal(name) then getglobal(name):Show() end end
			for j, name in ipairs(pages) do if j ~= this:GetID() and getglobal(name) then getglobal(name):Hide() end end
		end)
	end

	local pd = CreateFrame("Frame", "PaperDollFrame", cf)
	pd:SetAllPoints(cf)
	pd:SetFrameLevel(2)
	for i, part in ipairs({ "TopLeft", "TopRight", "BottomLeft", "BottomRight" }) do
		local t = pd:CreateTexture(nil, "BORDER")
		t:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-" .. part)
		t:SetWidth(256)
		t:SetHeight(256)
		t:SetPoint("TOPLEFT", pd, "TOPLEFT", (i == 2 or i == 4) and 258 or 2, (i > 2) and -257 or -1)
	end
	local level = pd:CreateFontString("CharacterLevelText", "ARTWORK")
	CharacterLevelText = level
	level:SetFont("Fonts\\FRIZQT__.TTF", 10)
	level:SetPoint("TOP", name, "BOTTOM", 0, -6)
	level:SetText("Level 1 Human Warrior")

	local model = CreateFrame("Frame", "CharacterModelFrame", pd)
	model:SetWidth(233)
	model:SetHeight(300)
	model:SetPoint("TOPLEFT", pd, "TOPLEFT", 65, -76)
	model:SetFrameLevel(3)

	-- the slots: eight down each side, the weapons under the model
	local ids = { Head = 1, Neck = 2, Shoulder = 3, Shirt = 4, Chest = 5, Waist = 6, Legs = 7, Feet = 8, Wrist = 9,
		Hands = 10, Finger0 = 11, Finger1 = 12, Trinket0 = 13, Trinket1 = 14, Back = 15, MainHand = 16,
		SecondaryHand = 17, Ranged = 18, Tabard = 19, Ammo = 0 }
	local left = { "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist" }
	local right = { "Hands", "Waist", "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1" }
	local function SlotButton(n, x, y)
		local b = CreateFrame("Button", "Character" .. n .. "Slot", pd)
		b:SetWidth(37)
		b:SetHeight(37)
		b:SetPoint("TOPLEFT", pd, "TOPLEFT", x, y)
		b:SetID(ids[n])
		b:SetFrameLevel(4)
		b:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
		local icon = b:CreateTexture("Character" .. n .. "SlotIconTexture", "BORDER")
		icon:SetAllPoints(b)
		icon:SetTexture("Interface\\Paperdoll\\UI-PaperDoll-Slot-" .. n)
		b:EnableMouse(true)
	end
	for i, n in ipairs(left) do SlotButton(n, 21, -74 - (i - 1) * 41) end
	for i, n in ipairs(right) do SlotButton(n, 305, -74 - (i - 1) * 41) end
	for i, n in ipairs({ "MainHand", "SecondaryHand", "Ranged", "Ammo" }) do SlotButton(n, 122 + (i - 1) * 41, -386) end

	-- the server's stat boxes under the model
	local function Box(x, y, w, rows, asFrames)
		local box = CreateFrame("Frame", nil, pd)
		box:SetWidth(w)
		box:SetHeight(8 + table.getn(rows) * 14)
		box:SetPoint("TOPLEFT", pd, "TOPLEFT", x, y)
		box:SetFrameLevel(5)
		box:EnableMouse(true)
		local bg = box:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints(box)
		bg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
		for i, row in ipairs(rows) do
			local owner = box
			local ry = -4 - (i - 1) * 14
			if asFrames then
				owner = CreateFrame("Frame", nil, box)
				owner:SetWidth(w)
				owner:SetHeight(14)
				owner:SetPoint("TOPLEFT", box, "TOPLEFT", 0, ry)
				owner:EnableMouse(true)
				ry = 0
			end
			Text(owner, row[1], 4 + (row[3] and 8 or 0), ry, "LEFT", 70)
			Text(owner, row[2], w - 4, ry, "RIGHT", 50)
		end
		return box
	end
	M.charBoxes = {
		Box(66, -288, 110, { { "Health:", "445" }, { "Damage:", "+46%" }, { "Haste:", "+16%" }, { "Crit:", "20.4%" },
			{ "Crit Dmg:", "243%" }, { "Armor:", "31%" } }),
		Box(180, -288, 112, { { "Area:", "+15%" }, { "Targets:", "+1", true }, { "Echo:", "8%", true } }, true),
		Box(180, -338, 112, { { "Speed:", "+24%" }, { "Regen:", "2.5", true }, { "Pickup:", "22 yd", true } }, true),
	}

	-- the server's Run Stats panel, beside the window
	local run = CreateFrame("Frame", "AZSRunStatsMock", UIParent)
	run:SetWidth(220)
	run:SetHeight(250)
	run:SetPoint("TOPLEFT", cf, "TOPRIGHT", -30, -12)
	run:EnableMouse(true)
	local title = run:CreateFontString(nil, "OVERLAY")
	title:SetFont("Fonts\\FRIZQT__.TTF", 13)
	title:SetPoint("TOP", run, "TOP", 0, -8)
	title:SetText("Run Stats")
	local rows = { { "Lifesteal:", "1.5%" }, { "Kill Heal:", "0" }, { "Thorns:", "0%" }, { "Lives:", "0" },
		{ "Experience:", "+20%" }, { "Gold:", "+27%" }, { "Luck:", "+0%" }, { "Buff Power:", "+30%" }, { "DoT Stacks:", "1" },
		{ "DoT Haste:", "+0%" }, { "Execute:", "+30%" }, { "Vs Afflicted:", "+15%" } }
	M.runValues = {}
	for i, row in ipairs(rows) do
		Text(run, row[1], 12, -30 - (i - 1) * 17, "LEFT", 110)
		M.runValues[row[1]] = Text(run, row[2], 208, -30 - (i - 1) * 17, "RIGHT", 60)
	end
	M.runPanel = run

	-- the Skills page: its art and a list of skills; the Honor page
	local skill = CreateFrame("Frame", "SkillFrame", cf)
	skill:SetAllPoints(cf)
	skill:SetFrameLevel(2)
	local art = skill:CreateTexture(nil, "BORDER")
	art:SetTexture("Interface\\PaperDollInfoFrame\\SkillFrame-TopLeft")
	art:SetAllPoints(skill)
	local list = CreateFrame("Frame", "SkillListMock", skill)
	list:SetWidth(300)
	list:SetHeight(300)
	list:SetPoint("TOPLEFT", skill, "TOPLEFT", 20, -80)
	list:EnableMouse(true)
	Text(list, "Swords", 4, -4, "LEFT", 100)
	skill:Hide()
	local honor = CreateFrame("Frame", "HonorFrame", cf)
	honor:SetAllPoints(cf)
	honor:Hide()

	-- gear with links in their rarity's color
	M.gear[1] = { tex = "Interface\\Icons\\INV_Helmet_01", link = "|cffffffff|Hitem:1:0:0:0|h[Plain Helm]|h|r", q = 1 }
	M.gear[5] = { tex = "Interface\\Icons\\INV_Chest_Plate01", link = "|cff0070dd|Hitem:2:0:0:0|h[Blue Plate]|h|r", q = 3 }
	M.gear[16] = { tex = "Interface\\Icons\\INV_Sword_01", link = "|cffa335ee|Hitem:3:0:0:0|h[Epic Blade]|h|r", q = 4 }
	return cf
end
