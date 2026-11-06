-- Creed UI: your own music, from a round button on the minimap's edge (1.23.0, asked for). Click it
-- to play, and it turns into a pause button; click again to pause; right-click for the next song.
-- The songs are your own files: put them in Interface\AddOns\CreedUI\Music named 1.mp3, 2.mp3 and so
-- on (Creed UI ships none), and tell it how many with /creed music <number>. The options hold its
-- volume. The game's PlayMusic plays a song over its own music, which fades out under it and comes
-- back when it stops; it has no pause, so a paused song starts over when played again, and a song
-- plays on until you change it.

local C = CreedUI
local DEFAULTS = { enabled = true, angle = 225, count = 3, track = 1, volume = 0.6 }
local DIR = "Interface\\AddOns\\CreedUI\\Music\\"

local db, button
local S = { playing = false }
local Call = C.Call

local function Path(n) return DIR .. n .. ".mp3" end

local function ShowState()
	if button then button.crest:SetTexture(C.ART .. (S.playing and "MusicPause" or "MusicPlay")) end
end

-- the game's music volume, which a song plays at (0 to 1)
local function ApplyVolume()
	if type(SetCVar) == "function" then SetCVar("MusicVolume", string.format("%.2f", db.volume)) end
end

local function Play()
	-- a song needs the game's music on
	if type(GetCVar) == "function" and GetCVar("EnableMusic") == "0" then SetCVar("EnableMusic", "1") end
	ApplyVolume()
	Call(PlayMusic, Path(db.track))
	S.playing = true
	ShowState()
end

local function Pause()
	Call(StopMusic)
	S.playing = false
	ShowState()
end

local function Next()
	db.track = math.mod(db.track, db.count) + 1
	if S.playing then Play() end
end

local function Click()
	if arg1 == "RightButton" then Next() elseif S.playing then Pause() else Play() end
end

local function Tip()
	GameTooltip:AddDoubleLine(C.L("Music"), C.F("Song {1} of {2}", db.track, db.count), 0.98, 0.85, 0.52, 0.75, 0.75, 0.8)
	GameTooltip:AddLine(C.L(S.playing and "Click: pause (the song starts over)" or "Click: play"), 1, 1, 1)
	GameTooltip:AddLine(C.L("Right-click: next song"), 1, 1, 1)
	GameTooltip:AddLine(C.L("Put your songs in Interface\\AddOns\\CreedUI\\Music, named 1.mp3, 2.mp3 and so on"), 0.65, 0.65, 0.7, 1)
end

local function Apply()
	if type(Minimap) ~= "table" then return end
	if not button then
		button = C.EdgeButton({
			frame = "CreedUIMusicButton", crest = "MusicPlay", store = db, field = "angle", angle = DEFAULTS.angle,
			tint = function(pal) return pal.title[1], pal.title[2], pal.title[3] end,
			held = function() return S.playing end,
			tip = Tip, click = Click,
		})
		if not button then return end
		ShowState()
	end
	if db.enabled then
		button.Place()
		button:Show()
	else
		button:Hide()
	end
end

------------------------------------------------------------------------ the options' volume row
-- beside the language: "Music volume: 60%", quieter and louder buttons either side
local row
function C.MusicHubRow(parent, x, y, width)
	row = {}
	row.minus = C.Button(parent, 24, 24, "-", function() C.SetMusicVolume(db.volume - 0.1) end)
	row.minus:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	row.label = C.Button(parent, width - 52, 24, "", function() if S.playing then Pause() else Play() end end)
	row.label:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 26, y)
	row.plus = C.Button(parent, 24, 24, "+", function() C.SetMusicVolume(db.volume + 0.1) end)
	row.plus:SetPoint("TOPLEFT", parent, "TOPLEFT", x + width - 24, y)
	C.musicRow = row
	C.MusicHubRefresh()
end
function C.MusicHubRefresh()
	if not (row and db) then return end
	C.SetText(row.label.text, C.F("Music volume: {1}", math.floor(db.volume * 100 + 0.5) .. "%"))
end
function C.SetMusicVolume(v)
	if not db then return end
	db.volume = C.Clamp(math.floor(v * 10 + 0.5) / 10, 0, 1)
	ApplyVolume()
	C.MusicHubRefresh()
end

-- /creed music [how many songs | next]
function C.MusicSlash(rest)
	local n = tonumber(rest or "")
	if n and n >= 1 and n <= 99 then
		db.count = math.floor(n)
		if db.track > db.count then db.track = 1 end
		C.Print(C.F("music: {1} songs", db.count))
	elseif rest == "next" then
		Next()
	else
		C.Print(C.F("/creed music followed by how many songs there are (now {1})", db.count))
	end
end

C.OnInit(function()
	db = C.DB("music", DEFAULTS)
	if type(db.angle) ~= "number" then db.angle = DEFAULTS.angle end
	db.count = C.Clamp(math.floor(tonumber(db.count) or 3), 1, 99)
	db.track = C.Clamp(math.floor(tonumber(db.track) or 1), 1, db.count)
	db.volume = C.Clamp(tonumber(db.volume) or DEFAULTS.volume, 0, 1)
end)

C.OnWorld(function()
	if not db then return end
	local ok, err = pcall(Apply)
	if not ok then C.Print(C.L("the minimap button stopped after an error: ") .. tostring(err)) end
end)

C.RegisterPart({
	key = "music", name = "Music button",
	note = "A play button on the minimap's edge for your own songs: click to play or pause, right-click for the next one. Put them in Interface\\AddOns\\CreedUI\\Music named 1.mp3, 2.mp3...; /creed music <number> says how many. The volume is beside the language.",
	get = function() return db and db.enabled end,
	set = function(on)
		if not db then return end
		db.enabled = on and true or false
		if not on and S.playing then Pause() end
		pcall(Apply)
	end,
})
