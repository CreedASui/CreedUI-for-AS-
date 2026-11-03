-- Damage numbers: a single hit beside a DoT that has stacked for two seconds (out/numbers.txt).
MOCK_SCRATCH = arg[1]
local DIR, OUT = arg[2], arg[3]
dofile(MOCK_SCRATCH .. "/cui/mock_cui.lua")
dofile(MOCK_SCRATCH .. "/bt/sim.lua")
local M = MOCK
M.InstallAPI()
M.phase = "playing"
M.Load(DIR)
for i = 1, 60 do M.Frame(1 / 30) end
local dot = M.Enemy("Ghoul", 12, 0)
local lone = M.Enemy("Ghoul", -12, 0)
for k = 1, 5 do
	M.Hit(dot, 40 + k, "corruption", true)
	for i = 1, 15 do M.Frame(1 / 30) end
end
M.Hit(lone, 342, "strike", false)
for i = 1, 8 do M.Frame(1 / 30) end
M.Dump(OUT .. "/numbers.txt")
print("problems: " .. table.getn(M.problems))
