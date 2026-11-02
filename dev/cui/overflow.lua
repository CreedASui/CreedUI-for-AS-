-- in each language: words wider than the box they sit in (a font string's own width, or its button's)
MOCK_SCRATCH = arg[1]
local DIR = arg[2]
dofile(MOCK_SCRATCH .. "/cui/mock_cui.lua")
dofile(MOCK_SCRATCH .. "/bt/sim.lua")
local M = MOCK
M.InstallAPI()
M.phase = "ready"
M.Load(DIR)
for i = 1, 20 do M.Frame(1 / 30) end
SIM.StartRun("naxx", { killAfter = 60 })
M.runTime = 60
SIM.Publish()
AZS_STATS = { luck = 0.41, gluck = 0.22 }
M.meter = { damage = { { key = "melee", name = "Melee", amount = 30000 } } }
SIM.Advance(1, 1 / 30)
M.Slash("")
M.Slash("timer")
M.Slash("numbers")
local total = 0
for _, lang in ipairs({ "en", "fr", "de", "es", "pt", "zh", "ru", "ja", "ko", "pl", "tr" }) do
	M.Slash("language " .. lang)
	-- every option the windows show, each state
	SIM.Advance(0.5, 1 / 30)
	local n = 0
	for _, o in ipairs(M.All()) do
		if o.__kind == "FontString" and o.__text and o.__text ~= "" and M.Visible(o) then
			local tw = M.TextWidth(o)
			local box = o.__w
			local p = o.__parent
			if (not box or box <= 0) and p and p.__kind == "Button" and p.__w and o.__points and table.getn(o.__points) == 1 then
				box = p.__w - 4
			end
			if box and box > 0 and tw > box + 1 and not string.find(o.__text, "\n") then
				n = n + 1
				print(lang, string.format("%.0f > %.0f", tw, box), M.Plain(o.__text))
			end
		end
	end
	total = total + n
end
print("overflows: " .. total)
