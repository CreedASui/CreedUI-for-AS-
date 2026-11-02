-- Creed UI smoke run: load everything, play a run with bosses, a guardian, a target and a DoT
-- on a crowd, and dump frames for rendering.
-- usage: lua50 smoke.lua <scratch> <addon dir> <outdir>
MOCK_SCRATCH = arg[1]
local DIR, OUT = arg[2], arg[3]
dofile(MOCK_SCRATCH .. "/cui/mock_cui.lua")
dofile(MOCK_SCRATCH .. "/bt/sim.lua")
local M = MOCK
M.InstallAPI()
M.phase = "ready"
M.Load(DIR)
for i = 1, 20 do M.Frame(1 / 30) end

local pub = SIM.Publish
SIM.Publish = function()
	pub()
	if AZS_RUN then
		AZS_RUN.lvl, AZS_RUN.xp, AZS_RUN.xpn, AZS_RUN.sh, AZS_RUN.lives = 20, 5, 27, 300, 2
		AZS_RUN.proc, AZS_RUN.pv, AZS_RUN.pm = "seal_fate", 3, 5
	end
end
SIM.StartRun("naxx", { killAfter = 60 })
local b = SIM.run.bosses
M.runTime = b[2].at + 6
b[1].state = "dead"
SIM.Publish()
-- a mini-boss fighting too
M.guardians = { { id = 77, name = "Sir Zeliek", hp = 21500, hpm = 36000, awake = true } }
AZS_UNITS_UPDATED = M.now
AZS_RUN.lvl, AZS_RUN.xp, AZS_RUN.xpn, AZS_RUN.sh, AZS_RUN.lives = 20, 5, 27, 300, 2
AZS_RUN.proc, AZS_RUN.pv, AZS_RUN.pm = "seal_fate", 3, 5
-- a target
M.unit.target = { exists = true, name = "Plagued Ghoul", hp = 300, hpm = 900, level = 20, hostile = true }
AZS_TARGET = { kind = "elite", id = 5, name = "Plagued Ghoul", hp = 640, hpm = 1600, state = 0, elite = 1 }
M.Fire("PLAYER_TARGET_CHANGED")
-- a party of five, the run's tally
M.unit.party1 = { exists = true, name = "Melkor", class = "Mage", level = 20, hp = 1500, hpm = 2000, mp = 800, mpm = 1200, power = 0 }
M.unit.party2 = { exists = true, name = "Zulyara", class = "Priest", level = 20, hp = 1650, hpm = 1800, mp = 1100, mpm = 1500, power = 0 }
M.unit.party3 = { exists = true, name = "Damyen", class = "Warrior", level = 19, hp = 2100, hpm = 3000, mp = 40, mpm = 100, power = 1 }
M.unit.party4 = { exists = true, name = "Huofa", class = "Hunter", level = 20, hp = 0, hpm = 2200, mp = 0, mpm = 1000, power = 0, dead = true }
M.Fire("PARTY_MEMBERS_CHANGED")
AZS_RUN.kills, AZS_RUN.gold, AZS_RUN.chest = 188, 143, 31
-- the meter and luck
M.meter = {
	damage = {
		{ key = "ability:ss:r3", name = "Sinister Strike", icon = "Interface\\Icons\\Spell_Shadow_RitualOfSacrifice", amount = 13200, school = 1 },
		{ key = "ability:bf:r2", name = "Blade Flurry", icon = "Interface\\Icons\\Ability_Warrior_PunishingBlow", amount = 10600, school = 8 },
		{ key = "ability:bs:r1", name = "Backstab", icon = "Interface\\Icons\\Ability_BackStab", amount = 8000, school = 4 },
		{ key = "ability:ev:r1", name = "Eviscerate", icon = "Interface\\Icons\\Ability_Warrior_Challange", amount = 3300, school = 32 },
		{ key = "ability:bf2:r1", name = "Blade Flurry (pulse)", icon = "Interface\\Icons\\Ability_Warrior_PunishingBlow", amount = 2300, school = 16 },
		{ key = "melee", name = "Melee", amount = 1500 },
		{ key = "talent:rogue.riposte:r1", name = "Riposte", icon = "Interface\\Icons\\Ability_Ambush", amount = 154, school = 1, proc = true },
	},
}
AZS_STATS = { luck = 0.41, gluck = 0.22 }
-- abilities on cooldown
M.actions[1].start, M.actions[1].dur = M.now - 1, 6
M.actions[3].start, M.actions[3].dur = M.now - 4, 5

-- a crowd with Corruption ticking on everyone, plus some strikes
local crowd = {}
for i = 1, 12 do
	crowd[i] = M.Enemy("Plagued Ghoul", -14 + math.mod(i, 4) * 6, -6 + math.floor(i / 4) * 5)
end
local function Fight(seconds)
	local acc, dotAcc = 0, 0
	SIM.Advance(seconds, 1 / 30, function(s)
		acc = acc + 1 / 30
		dotAcc = dotAcc + 1 / 30
		if dotAcc >= 1 then
			dotAcc = dotAcc - 1
			for i = 1, table.getn(crowd) do M.Hit(crowd[i], 10 + math.random(0, 4), "corruption", true) end
		end
		if acc >= 0.45 then
			acc = acc - 0.45
			M.Hit(crowd[math.random(1, 12)], 900 + math.random(0, 300), "strike", false, math.random() < 0.2)
		end
		if AZS_RUN then AZS_RUN.lvl, AZS_RUN.xp, AZS_RUN.xpn, AZS_RUN.sh, AZS_RUN.lives = 20, 5, 27, 300, 2 end
		if AZS_RUN then AZS_RUN.proc, AZS_RUN.pv, AZS_RUN.pm = "seal_fate", 3, 5 end
		if AZS_RUN then AZS_RUN.kills, AZS_RUN.gold, AZS_RUN.chest, AZS_RUN.lvl = 188, 143, 31, 16 end
	end)
end
Fight(3.3)
M.Dump(OUT .. "/hud_1.txt")
M.guardians[1].hp = 9000
M.actions[2].start, M.actions[2].dur = M.now - 2, 7
M.actions[12].start, M.actions[12].dur = M.now - 0.5, 4
Fight(1.4)
M.Dump(OUT .. "/hud_2.txt")
-- the boss drops under 30%: enraged
for i = 1, table.getn(SIM.run.bosses) do
	local b = SIM.run.bosses[i]
	if b.state == "up" then b.hp = 0.22 end
end
SIM.run.kill = 400
Fight(1.0)
M.Dump(OUT .. "/hud_3.txt")

local n = table.getn(M.problems)
print("problems: " .. n)
for i = 1, math.min(n, 5) do print(M.problems[i]) end
for i = 1, table.getn(M.chat) do print("CHAT: " .. M.chat[i]) end
print("hud clock shown: " .. tostring(M.hud.clock) .. ", bosses: " .. tostring(M.hud.bosses) .. ", build: " .. tostring(M.hud.build))
print("PlayerFrame parent hidden: " .. tostring(PlayerFrame.__parent == CreedUIHidden) .. ", MainMenuBar: " .. tostring(MainMenuBar.__parent == CreedUIHidden))
