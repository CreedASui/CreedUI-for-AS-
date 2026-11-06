-- The music button (1.23.0): playing, on the minimap's edge (out/music.txt), and the options with the
-- music volume beside the language (out/music_hub.txt).
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
M.phase = "playing"
SIM.Advance(1, 1 / 30)
this, arg1 = CreedUIMusicButton, "LeftButton"
CreedUIMusicButton.__scripts.OnClick()
SIM.Advance(1, 1 / 30)
M.Dump(OUT .. "/music.txt")
M.Slash("")
SIM.Advance(0.5, 1 / 30)
M.Dump(OUT .. "/music_hub.txt")
local l, b, r, t = M.Rect(CreedUIMusicButton)
print("button", l, b, r, t)
l, b, r, t = M.Rect(CreedUIOptions)
print("hub", l, b, r, t)
print("problems: " .. table.getn(M.problems))
