MOCK_SCRATCH = arg[1]
local DIR, OUT = arg[2], arg[3]
dofile(MOCK_SCRATCH .. "/cui/mock_cui.lua")
dofile(MOCK_SCRATCH .. "/bt/sim.lua")
local M = MOCK
M.InstallAPI()
M.phase = "ready"
M.Load(DIR)
for i = 1, 20 do M.Frame(1 / 30) end
M.zoneText = "Elwynn Forest"
local t0 = 60
local pub = SIM.Publish
SIM.Publish = function()
	pub()
	if AZS_RUN then
		local gained = 2.4 * (M.runTime - t0) + 30
		AZS_RUN.px, AZS_RUN.py, AZS_RUN.gold, AZS_RUN.chest = 100, 200, 40, 31
		AZS_RUN.lvl, AZS_RUN.xp, AZS_RUN.xpn = 11 + math.floor(gained / 120), math.mod(gained, 120), 120
		AZS_RUN.kills = 412
	end
end
SIM.StartRun("naxx", { killAfter = 120 })
M.runTime = t0
SIM.Publish()
AZS_LAIRS = {
	{ index = 1, state = "asleep", name = "Gnoll Packleader", id = 31, left = -1, x = 160, y = 140, flag = 1 },
	{ index = 2, state = "awake", name = "Kobold Geomancer", id = 32, left = -1, x = 60, y = 150, flag = 0 },
	{ index = 3, state = "empty", name = "Murloc Tidecaller", id = 0, left = 74, x = 40, y = 280, flag = 0 },
	{ index = 4, state = "empty", name = "Defias Pillager", id = 0, left = 19, x = 520, y = 330, flag = 0 },
}
AZS_LAIRS_UPDATED = M.now
AZS_CHESTS = { { id = 1, x = 130, y = 230, z = 0 } }
AZS_CHESTS_UPDATED = M.now
SIM.Advance(40, 1 / 30)
AZS_LAIRS_UPDATED = M.now
SIM.Advance(0.9, 1 / 30)
M.Dump(OUT .. "/lairs.txt")
M.Dump(OUT .. "/btn_a.txt")
local b = CreedUIMeterToggle
this = b
b.__scripts.OnEnter()
SIM.Advance(0.5, 1 / 30)
M.Dump(OUT .. "/btn_b.txt")
b.__scripts.OnLeave()
CreedUIDB.luck.shown = false
SIM.Advance(0.6, 1 / 30)
M.Dump(OUT .. "/btn_c.txt")
CreedUIDB.luck.shown = true
print("problems: " .. table.getn(M.problems))
for i = 1, math.min(5, table.getn(M.problems)) do print(M.problems[i]) end
local l, bt, r, t = M.Rect(Minimap)
print("minimap", l, bt, r, t)
