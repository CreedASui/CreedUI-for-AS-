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
SIM.Advance(6, 1 / 30)
M.Dump(OUT .. "/dragon.txt")
local l, b, r, t = M.Rect(CreedUIBar)
print("bar", l, b, r, t)
local pl, pb, pr, pt = M.Rect(CreedUIBar.panel or CreedUIBar)
print("panel", pl, pb, pr, pt)
print("problems: " .. table.getn(M.problems))
