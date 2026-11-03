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
-- the panels that show only now and then: the run's summary, the level-up button, a friend down
M.runEnd = { result = "victory", t = 100000, lvl = 24, kills = 1834, elites = 12, guardians = 3, bosses = 5, dmg = 2400000,
	taken = 81234, gold = 512, chests = 9, hero = "Creed" }
M.storing, M.storedLevels = true, 3
M.unit.party1 = { exists = true, name = "Melkor", class = "Mage", level = 20, hp = 0, hpm = 2000, dead = true }
M.downed = { { id = 2, name = "Melkor", anchorId = "downed:2", anchorStatus = "ready", positionAvailable = true, wx = 8, wy = -6 } }
M.revive = { reviving = "Melkor", rshare = 0.5 }
AZS_TAKEN = { { source = "Plagued Ghoul", dmg = 1200 } }
CreedUIDB.meter.tab = "taken"
-- the talent window, open, with the longest tree names
M.loadout = { abilities = {}, talents = {
	{ key = "a", tree = "hunter.beast_mastery", rank = 5, name = "A", icon = "Interface\\Icons\\Ability_Ambush" },
	{ key = "b", tree = "druid.feral_combat", rank = 3, name = "B", icon = "Interface\\Icons\\Ability_Ambush" },
	{ key = "c", tree = "shaman.enhancement", rank = 12, name = "C", icon = "Interface\\Icons\\Ability_Ambush" } } }
M.Slash("talents")
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
