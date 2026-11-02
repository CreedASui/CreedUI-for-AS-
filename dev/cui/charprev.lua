MOCK_SCRATCH = arg[1]
local DIR, OUT = arg[2], arg[3]
dofile(MOCK_SCRATCH .. "/cui/mock_cui.lua")
dofile(MOCK_SCRATCH .. "/bt/sim.lua")
local M = MOCK
M.InstallAPI()
M.phase = "ready"
M.Load(DIR)
for i = 1, 5 do M.Frame(1 / 30) end
GetNumTalentTabs = function() return 0 end
AZS_RUN = AZS_RUN or {}
AZS_RUN.talents = {
	{ name = "Bloodthirst", icon = "Interface\\Icons\\Spell_Nature_BloodLust", rank = 2 },
	{ name = "Shadow Weaving", icon = "Interface\\Icons\\Spell_Shadow_BlackPlague" },
	{ name = "Deep Wounds", icon = "Interface\\Icons\\Ability_BackStab", rank = 3 },
	{ name = "Flurry", icon = "Interface\\Icons\\Ability_Ghoulfire" },
	{ name = "Execute", icon = "Interface\\Icons\\Ability_Warrior_PunishingBlow" },
}
-- some gear, as the screenshot has
M.gear[1] = { tex = "Interface\\Icons\\INV_Helmet_01", link = "|cff1eff00|Hitem:1|h[Green Helm]|h|r" }
M.gear[3] = { tex = "Interface\\Icons\\INV_Shoulder_01", link = "|cff0070dd|Hitem:2|h[Blue Pauldrons]|h|r" }
M.gear[5] = { tex = "Interface\\Icons\\INV_Chest_Plate01", link = "|cffa335ee|Hitem:3|h[Epic Plate]|h|r" }
M.gear[16] = { tex = "Interface\\Icons\\INV_Sword_01", link = "|cffff8000|Hitem:4|h[Legendary Blade]|h|r" }
M.gear[10] = { tex = "Interface\\Icons\\INV_Gauntlets_01", link = "|cffffffff|Hitem:5|h[Plain Gloves]|h|r" }
-- the slots' own icons, as the game sets them (icons the renderer has)
local icons = { Head = "Ability_Ambush", Shoulder = "Ability_Warrior_Challange", Chest = "Spell_Shadow_RitualOfSacrifice",
	MainHand = "Ability_Warrior_PunishingBlow", Hands = "Ability_BackStab", Neck = "INV_Jewelry_Necklace_07", Finger0 = "INV_Jewelry_Ring_03" }
for n, icon in pairs(icons) do
	for _, r in ipairs({ getglobal("Character" .. n .. "Slot"):GetRegions() }) do
		if r.__tex and string.find(r.__tex, "UI%-PaperDoll%-Slot") then r:SetTexture("Interface\\Icons\\" .. icon) end
	end
end
M.gear[2] = { tex = "Interface\\Icons\\INV_Jewelry_Necklace_07", link = "|cffa335ee|Hitem:6|h[Epic Necklace]|h|r" }
M.gear[11] = { tex = "Interface\\Icons\\INV_Jewelry_Ring_03", link = "|cff0070dd|Hitem:7|h[Blue Ring]|h|r" }
CharacterFrame:Show()
for i = 1, 15 do M.Frame(1 / 30) end
M.runValues["Gold:"]:SetText("+32%")
for i = 1, 12 do M.Frame(1 / 30) end
M.Dump(OUT .. "/char.txt")
local l, b, r, t = M.Rect(CharacterFrame)
print("cf", l, b, r, t)
local l2, b2, r2, t2 = M.Rect(CreedUICharacterStats)
print("stats", l2, b2, r2, t2)
print("problems: " .. table.getn(M.problems))
for i = 1, math.min(5, table.getn(M.problems)) do print(M.problems[i]) end
