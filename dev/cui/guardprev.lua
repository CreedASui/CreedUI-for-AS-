-- One boss and four guardians up at once: their bars under the timer (out/guards.txt).
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
SIM.Advance(1, 1 / 30)
local publish = SIM.Publish
SIM.Publish = function()
	publish()
	M.bosses = { { name = "Hakkar", hp = 87000, hpm = 100000 } }
	M.guardians = {
		{ id = 41, name = "Gnoll Packleader", hp = 9000, hpm = 10000, awake = true },
		{ id = 42, name = "Kobold Geomancer", hp = 6400, hpm = 10000, awake = true },
		{ id = 43, name = "Murloc Tidecaller", hp = 3100, hpm = 10000, awake = true },
		{ id = 44, name = "Defias Pillager", hp = 8800, hpm = 10000, awake = true },
	}
	AZS_UNITS_UPDATED = M.now
end
SIM.Advance(3, 1 / 30)
M.Dump(OUT .. "/guards.txt")
print("problems: " .. table.getn(M.problems))
