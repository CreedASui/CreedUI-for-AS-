-- 1.11.0's pieces: a friend down beside you being revived, another off the screen with the edge
-- arrow, the banner, the Level Up! button with stored level-ups, the meter on Damage Taken; then
-- the run's summary. Writes out/party.txt and out/summary.txt.
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
M.unit.party1 = { exists = true, name = "Melkor", class = "Mage", level = 20, hp = 0, hpm = 2000, mp = 0, mpm = 1200, power = 0, dead = true }
M.unit.party2 = { exists = true, name = "Zulyara", class = "Priest", level = 20, hp = 0, hpm = 1800, mp = 0, mpm = 1500, power = 0, dead = true }
M.Fire("PARTY_MEMBERS_CHANGED")
AZS_TAKEN = { { source = "Anub'Rekhan", dmg = 5400 }, { source = "Plagued Ghoul", dmg = 2300 }, { source = "Crypt Guard", dmg = 1250 },
	{ source = "Necro Knight", dmg = 640 } }
CreedUIDB.meter.tab = "taken"
M.storing, M.storedLevels = true, 3
M.downed = {}
SIM.Advance(1, 1 / 30)
M.downed = {
	{ id = 2, name = "Melkor", anchorId = "downed:2", anchorStatus = "ready", positionAvailable = true, wx = -9, wy = -9 },
	{ id = 3, name = "Zulyara", anchorId = "downed:3", anchorStatus = "ready", positionAvailable = true, wx = 140, wy = 30 },
}
M.revive = { down = 0, reviving = "Melkor", rshare = 0.62 }
for i = 1, 12 do M.Frame(1 / 30) end
M.Dump(OUT .. "/party.txt")
-- the run ends in victory
M.downed, M.revive = {}, {}
M.runEnd = { result = "victory", t = 1200, lvl = 27, kills = 3412, elites = 18, guardians = 4, bosses = 6, dmg = 5230000,
	taken = 148200, gold = 812, chests = 14, hero = "Creed the Undead Rogue" }
M.runTime = 1200
M.storedLevels = 0
for i = 1, 150 do M.Frame(1 / 30) end
M.Dump(OUT .. "/summary.txt")
print("problems: " .. table.getn(M.problems))
for i = 1, math.min(5, table.getn(M.problems)) do print(M.problems[i]) end
