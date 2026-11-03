-- The talent window: a warrior's three trees with the talents learned (out/talents.txt).
MOCK_SCRATCH = arg[1]
local DIR, OUT = arg[2], arg[3]
dofile(MOCK_SCRATCH .. "/cui/mock_cui.lua")
dofile(MOCK_SCRATCH .. "/bt/sim.lua")
local M = MOCK
M.InstallAPI()
M.phase = "ready"
M.Load(DIR)
for i = 1, 20 do M.Frame(1 / 30) end
SIM.StartRun("naxx", { killAfter = 120 })
M.runTime = 300
SIM.Publish()
M.meter = { damage = {} }
local I = "Interface\\Icons\\"
local icons = { "Ability_Ambush", "Ability_BackStab", "Ability_Warrior_PunishingBlow", "Ability_Warrior_Challange",
	"Spell_Shadow_RitualOfSacrifice", "Ability_Rogue_Eviscerate" }
local talents = {}
local function add(tree, name, rank, n)
	table.insert(talents, { key = tree .. name, tree = tree, rank = rank, name = name, icon = I .. icons[math.mod(n, table.getn(icons)) + 1] })
end
local arms = { { "Improved Heroic Strike", 3 }, { "Deflection", 5 }, { "Improved Rend", 3 }, { "Tactical Mastery", 5 },
	{ "Anger Management", 1 }, { "Deep Wounds", 3 }, { "Two-Handed Weapon Specialization", 5 }, { "Impale", 2 },
	{ "Axe Specialization", 5 }, { "Sweeping Strikes", 1 }, { "Mortal Strike", 1 } }
for i, t in ipairs(arms) do add("warrior.arms", t[1], t[2], i) end
add("warrior.fury", "Cruelty", 5, 2)
add("warrior.fury", "Unbridled Wrath", 5, 4)
add("warrior.protection", "Shield Specialization", 5, 1)
M.loadout = { abilities = {}, talents = talents }
SIM.Advance(1, 1 / 30)
M.Slash("talents")
for i = 1, 40 do M.Frame(1 / 30) end
M.Dump(OUT .. "/talents.txt")
print("problems: " .. table.getn(M.problems))
for i = 1, math.min(5, table.getn(M.problems)) do print(M.problems[i]) end
local l, b, r, t = M.Rect(CreedUITalents)
print("talents", l, b, r, t)
