MOCK_SCRATCH = arg[1]
local DIR, OUT = arg[2], arg[3]
dofile(MOCK_SCRATCH .. "/cui/mock_cui.lua")
dofile(MOCK_SCRATCH .. "/bt/sim.lua")
local M = MOCK
M.InstallAPI()
M.phase = "ready"
M.Load(DIR)
for i = 1, 5 do M.Frame(1 / 30) end
-- the 1.12 warrior's trees: name, tier, column, max, prerequisite (tier, column), points here
local T = {
	{ "Arms", "WarriorArms", {
		{ "Improved Heroic Strike", 1, 1, 3, nil, 3 }, { "Deflection", 1, 2, 5, nil, 2 }, { "Improved Rend", 1, 3, 3, nil, 3 },
		{ "Improved Charge", 2, 1, 2 }, { "Tactical Mastery", 2, 2, 5, nil, 5 }, { "Improved Thunder Clap", 2, 4, 3 },
		{ "Improved Overpower", 3, 1, 2 }, { "Anger Management", 3, 2, 1, { 2, 2 }, 1 }, { "Deep Wounds", 3, 3, 3, { 1, 3 }, 3 },
		{ "Two-Handed Weapon Specialization", 4, 2, 5, nil, 2 }, { "Impale", 4, 3, 2, { 3, 3 }, 2 },
		{ "Axe Specialization", 5, 1, 5 }, { "Sweeping Strikes", 5, 2, 1 }, { "Mace Specialization", 5, 3, 5 }, { "Sword Specialization", 5, 4, 5 },
		{ "Polearm Specialization", 6, 1, 5 }, { "Improved Hamstring", 6, 3, 3 },
		{ "Mortal Strike", 7, 2, 1, { 5, 2 } } } },
	{ "Fury", "WarriorFury", {
		{ "Booming Voice", 1, 2, 5 }, { "Cruelty", 1, 3, 5, nil, 5 },
		{ "Improved Demoralizing Shout", 2, 2, 5 }, { "Unbridled Wrath", 2, 3, 5 },
		{ "Improved Cleave", 3, 1, 3 }, { "Piercing Howl", 3, 2, 1 }, { "Blood Craze", 3, 3, 3 }, { "Improved Battle Shout", 3, 4, 5 },
		{ "Dual Wield Specialization", 4, 1, 5 }, { "Improved Execute", 4, 2, 2 }, { "Enrage", 4, 3, 5 },
		{ "Improved Slam", 5, 1, 5 }, { "Death Wish", 5, 2, 1 }, { "Improved Intercept", 5, 4, 2 },
		{ "Improved Berserker Rage", 6, 1, 2 }, { "Flurry", 6, 3, 5, { 4, 3 } },
		{ "Bloodthirst", 7, 2, 1, { 5, 2 } } } },
	{ "Protection", "WarriorProtection", {
		{ "Shield Specialization", 1, 2, 5 }, { "Anticipation", 1, 3, 5 },
		{ "Improved Bloodrage", 2, 1, 2 }, { "Toughness", 2, 3, 5 }, { "Iron Will", 2, 4, 5 },
		{ "Last Stand", 3, 1, 1, { 2, 1 } }, { "Improved Shield Block", 3, 2, 3, { 1, 2 } }, { "Improved Revenge", 3, 3, 3 }, { "Defiance", 3, 4, 5 },
		{ "Improved Sunder Armor", 4, 1, 3 }, { "Improved Disarm", 4, 2, 3 }, { "Improved Taunt", 4, 3, 2 },
		{ "Improved Shield Wall", 5, 1, 2 }, { "Concussion Blow", 5, 2, 1 }, { "Improved Shield Bash", 5, 3, 2 },
		{ "One-Handed Weapon Specialization", 6, 3, 5 },
		{ "Shield Slam", 7, 2, 1, { 5, 2 } } } },
}
local ICONS = { "Ability_Ambush", "Ability_BackStab", "Ability_Warrior_Challange", "Ability_Warrior_PunishingBlow", "Spell_Shadow_RitualOfSacrifice" }
GetNumTalentTabs = function() return 3 end
GetTalentTabInfo = function(t)
	local spent = 0
	for _, d in ipairs(T[t][3]) do spent = spent + (d[6] or 0) end
	return T[t][1], "Interface\\Icons\\" .. ICONS[t], spent, T[t][2]
end
GetNumTalents = function(t) return table.getn(T[t][3]) end
GetTalentInfo = function(t, i)
	local d = T[t][3][i]
	return d[1], "Interface\\Icons\\" .. ICONS[math.mod(i * 3 + t, 5) + 1], d[2], d[3], d[6] or 0, d[4], nil, 1
end
GetTalentPrereqs = function(t, i)
	local p = T[t][3][i][5]
	if p then return p[1], p[2], 1 end
end
CharacterFrame:Show()
for i = 1, 5 do M.Frame(1 / 30) end
this = CharacterFrameTab4
CharacterFrameTab4.__scripts.OnClick()
for i = 1, 10 do M.Frame(1 / 30) end
M.Dump(OUT .. "/talents.txt")
print("problems: " .. table.getn(M.problems))
for i = 1, math.min(5, table.getn(M.problems)) do print(M.problems[i]) end
