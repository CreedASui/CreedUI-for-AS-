-- The boss skulls in a fight: a near boss, the final boss farther off, a mini-boss with none,
-- and the options window in its two columns. Writes out/skulls.txt and out/hub.txt.
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
M.runTime = SIM.run.bosses[2].at + 8
SIM.Publish()
M.guardians = { { id = 77, name = "Sir Zeliek", hp = 21500, hpm = 36000, awake = true } }
AZS_UNITS_UPDATED = M.now
-- where the bosses stand: one near the hero, one far up the field
SIM.Advance(2, 1 / 30)
local near, far = M.bosses[1].name, M.bosses[table.getn(M.bosses)].name
M.waSpots[near] = { x = -2, y = -14 }
M.waNear[near] = 3.2
M.waSpots[far] = { x = 25, y = 6 }
M.waNear[far] = 1.3
-- the last boss of the run as the final one, so both kinds show
M.bosses[table.getn(M.bosses)].final = true
for i = 1, 30 do M.Frame(1 / 30) end
M.Dump(OUT .. "/skulls.txt")
M.Slash("")
for i = 1, 5 do M.Frame(1 / 30) end
M.Dump(OUT .. "/hub.txt")
print("bosses: " .. table.getn(M.bosses))
for i = 1, table.getn(M.bosses) do print("  " .. M.bosses[i].name .. (M.bosses[i].final and " (final)" or "")) end
print("problems: " .. table.getn(M.problems))
for i = 1, math.min(5, table.getn(M.problems)) do print(M.problems[i]) end
