-- 1.17.0 (1.17.3: marks at its head, read from the chat; 1.18.1: icons by name, New tags): the run's loot window, five items in. Writes out/loot.txt.
MOCK_SCRATCH = arg[1]
local DIR, OUT = arg[2], arg[3]
dofile(MOCK_SCRATCH .. "/cui/mock_cui.lua")
dofile(MOCK_SCRATCH .. "/bt/sim.lua")
local M = MOCK
M.InstallAPI()
M.phase = "ready"
M.Load(DIR)
for i = 1, 20 do M.Frame(1 / 30) end
SIM.StartRun("scholomance", { killAfter = 120 })
M.runTime = 30
SIM.Publish()
SIM.Advance(0.5, 1 / 30)
local I = "Interface\\Icons\\"
M.items = { [1] = { name = "Necropile Robe", quality = 3, icon = I .. "INV_Chest_Cloth_42" },
	[2] = { name = "Darkmaster's Signet", quality = 4, icon = I .. "INV_Jewelry_Ring_14" },
	[3] = { name = "Bone Fragment", quality = 1, icon = I .. "INV_Misc_Bone_08" },
	[4] = { name = "Ghostly Boots", quality = 2, icon = I .. "INV_Boots_Cloth_05" },
	[5] = { name = "Barov's Ledger", quality = 5, icon = I .. "INV_Misc_Book_06" } }
local colors = { "ff0070dd", "ffa335ee", "ffffffff", "ff1eff00", "ffff8000" }
for i = 1, 5 do
	M.runTime = 60 + i * 47
	ChatFrame1:AddMessage("You receive loot: |c" .. colors[i] .. "|Hitem:" .. i .. ":0:0:0|h[" .. M.items[i].name .. "]|h|r" .. (i == 3 and "x3" or "") .. ".")
	SIM.Advance(0.1, 1 / 30)
end
ChatFrame1:AddMessage("You receive loot: [Novice's Boots] New in your collection!")
ChatFrame1:AddMessage("You receive loot: [Gravecaller's Signet] Already collected")
ChatFrame1:AddMessage("You earn 12 marks (348 in all).")
ChatFrame1:AddMessage("You earn 8 marks (356 in all).")
SIM.Advance(0.5, 1 / 30)
M.Dump(OUT .. "/loot.txt")
print("problems: " .. table.getn(M.problems))
for i = 1, math.min(5, table.getn(M.problems)) do print(M.problems[i]) end
