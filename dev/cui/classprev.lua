-- The party's health bars in every class's color: three dumps of four friends (out/class1..3.txt).
MOCK_SCRATCH = arg[1]
local DIR, OUT = arg[2], arg[3]
dofile(MOCK_SCRATCH .. "/cui/mock_cui.lua")
dofile(MOCK_SCRATCH .. "/bt/sim.lua")
local M = MOCK
M.InstallAPI()
M.phase = "ready"
M.Load(DIR)
for i = 1, 20 do M.Frame(1 / 30) end
local CLASSES = { "Warrior", "Paladin", "Hunter", "Rogue", "Priest", "Shaman", "Mage", "Warlock", "Druid" }
local NAMES = { "Loadup", "Aroraa", "Huofa", "Creed", "Plaguetongue", "Tony", "Melkor", "Zulyara", "Damyen" }
for g = 1, 3 do
	for i = 1, 4 do
		local k = (g - 1) * 4 + i
		if CLASSES[k] then
			M.unit["party" .. i] = { exists = true, name = NAMES[k], class = CLASSES[k], level = 43, hp = 800, hpm = 817, mp = 500, mpm = 1000, power = 0 }
		else
			M.unit["party" .. i] = nil
		end
	end
	M.Fire("PARTY_MEMBERS_CHANGED")
	for i = 1, 60 do M.Frame(1 / 30) end
	M.Dump(OUT .. "/class" .. g .. ".txt")
end
print("problems: " .. table.getn(M.problems))
local l, b, r, t = M.Rect(CreedUIParty)
print("party", l, b, r, t)
