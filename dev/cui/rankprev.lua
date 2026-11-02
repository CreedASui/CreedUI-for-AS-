-- The skill bar with each ability's rank in its box, the second one just ranked up and flashing.
-- Writes out/ranks.txt.
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
M.runTime = 60
SIM.Publish()
M.actions[5] = { tex = "Interface\\Icons\\Spell_Shadow_ShadowWordPain", start = 0, dur = 0 }
M.meter = { damage = {} }
local I = "Interface\\Icons\\"
M.loadout = { abilities = {
	{ key = "ss", rank = 4, slotId = 1, icon = I .. "Spell_Shadow_RitualOfSacrifice" },
	{ key = "bf", rank = 2, slotId = 2, icon = I .. "Ability_Warrior_PunishingBlow" },
	{ key = "bs", rank = 3, slotId = 3, icon = I .. "Ability_BackStab" },
	{ key = "ev", rank = 1, slotId = 4, icon = I .. "Ability_Warrior_Challange" },
	{ key = "swp", rank = 12, slotId = 5, icon = I .. "Spell_Shadow_ShadowWordPain" },
} }
SIM.Advance(2, 1 / 30)
M.loadout.abilities[2].rank = 3
AZS_SPELLS_UPDATED = M.now
for i = 1, 11 do M.Frame(1 / 30) end
M.Dump(OUT .. "/ranks.txt")
print("problems: " .. table.getn(M.problems))
for i = 1, math.min(5, table.getn(M.problems)) do print(M.problems[i]) end
local l, b, r, t = M.Rect(CreedUIBar)
print("bar", l, b, r, t)
