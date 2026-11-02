MOCK_SCRATCH = arg[1]
dofile(MOCK_SCRATCH .. "/cui/mock_cui.lua")
dofile(MOCK_SCRATCH .. "/bt/sim.lua")
local M = MOCK
M.InstallAPI()
M.phase = "ready"
local before = {}
for k in pairs(getfenv(0)) do before[k] = true end
M.Load(arg[2])
SIM.StartRun("naxx", { killAfter = 60 })
AZS_CHESTS = { { id = 1, x = 1, y = 2 } }
SIM.Advance(2, 1 / 30)
for k in pairs(getfenv(0)) do
	if not before[k] and type(k) == "string" and not string.find(k, "^CreedUI") and not string.find(k, "^SLASH_")
		and not string.find(k, "^AZS_") then print("new global: " .. k) end
end
