# Creed UI: handoff for Claude Code

Read this first. It's where the work stands, the rules the code depends on, how to check it, and
what's next. It was written at the end of a long Claude session that built Creed UI with the
user (GitHub: **CreedASui**), who plays the game and publishes the addon. The user is not a
programmer: they test in game and send screenshots. Ship them a ready-to-install zip and a
picture of the change.

## 1. What this is

- **Creed UI** is a HUD addon for **Azeroth Survivors** ([wow.aethus.pl](https://wow.aethus.pl)), a
  World of Warcraft 1.12.1 roguelike played in the browser on **benilla**, a 1.12 client rewritten
  in Rust ([github.com/samwhosung/benilla](https://github.com/samwhosung/benilla)). The game adds its
  own addon API (`AZS_*`, see section 6).
- Addon language: **Lua 5.0** with the **1.12 widget API**.
- Current version: **1.8.3**. Repository: <https://github.com/CreedASui/CreedUI-for-AS->.
- 11 languages: en, fr, de, es, pt, zh, ru, ja, ko, pl, tr.

## 2. First thing to do

The repository may still be empty: the user hadn't uploaded yet. If so, the user attaches
`CreedUI-for-AS-github-upload.zip`. Its folder `CreedUI-for-AS-/` *is* the repository: put its
contents at the repo root, commit ("Creed UI 1.8.3"), push, tag `v1.8.3`, and make a GitHub release
**Creed UI 1.8.3** with the 1.8.3 entry of `CHANGELOG.md` as its text and `CreedUi-1.8.3.zip`
attached (a zip of the `CreedUI` folder; rebuild it from the repo if the user didn't attach it).

## 3. Layout

```
CreedUI/            the addon (this folder name is the install folder; never rename it)
  CreedUI.toc       load order, version, notes
  Core.lua          helpers, memo writers, language system, the options hub, /creed, panel art,
                    sizers and the resize cursor, tooltip faces, the meter's per-line icons
  Locale.lua        en/fr/de/es/pt rows; Locale_<zh|ru|ja|ko|pl|tr>.lua are generated (dev/tr)
  Timer.lua         the boss timer (DON'T TOUCH: the user loves it as it is)
  Numbers.lua       floating damage numbers (combat text API)
  Bosses.lua        boss and mini-boss bars        Units.lua    player and target frames
  Party.lua         party frames                   Chat.lua     dressed chat, kept clear of the dragon
  Bar.lua           skill bar, jewelry, XP/s, the gold panel with its two dragons
  Tally.lua         kills / gold / cache, docked inside the bar's panel
  Minimap.lua       metal ring, local clock, zone name
  MinimapButton.lua C.EdgeButton (draggable round buttons on the minimap's edge) and the C button
  Chests.lua        caches and guardians' lairs as pins on the minimap
  Meter.lua         damage meter (+ its crossed-swords edge button)
  Luck.lua          luck medallion (+ its clover edge button)
  Character.lua     the game's character window dressed: gear slots lit by rarity, the run's stats
                    read off the game's own labels and regrouped beside it, a Talents page in place
                    of Skills (the 3 talent trees, read-only), the Honor tab hidden
  Art/              original art, BLP2 uncompressed (made by dev/art scripts)
  Fonts/            Letters.ttf (Latin+Cyrillic, from Lora), LettersCJK.ttf (from Noto Sans CJK), OFL
dev/                tools: stand-in game client + tests, translations, art, fonts, renderer
                    (dev/README.md explains each)
dev/attic/          code kept for later (the 1.8.0 talents strip)
README.md, CHANGELOG.md
```

## 4. Rules the code depends on

**The game and its client**
- The install folder must stay `CreedUI`. The client loads it by its .toc name, every texture and
  font path is `Interface\\AddOns\\CreedUI\\...`, and settings live in `CreedUIDB` under that name.
  Release zips are named **`CreedUi-<version>.zip`** (the user's choice) and contain `CreedUI/`.
- **Lua 5.0:** no `#` (use `table.getn`), no `string.match` (use `string.find` with captures), no
  hex literals, `math.mod` not `%`, varargs through `arg` (`arg.n`), and at most 32 upvalues per function.
  Scripts get `this`, `event` and `arg1` as globals.
- **Only real 1.12 widget methods.** `dev/engine_methods.lua` lists them; the stand-in client errors
  on anything else, even *reading* a method a widget type doesn't have (`texture.IsMouseEnabled`). Check
  the object type first.
- **No stray `nil` arguments.** The game's API counts a passed `nil` as an argument and refuses
  the call. Use `C.Call(fn, a, b)`, and pass exact counts (`SetTexCoord` takes 4 *or* 8).
- **Memo writers** in Core (`C.SetText`, `C.Size`, `C.Width`, `C.Place`, `C.Vis`, `C.Alpha`, `C.Color`,
  `C.TextColor`, `C.TextWidth`) skip unchanged writes. Never mix them with direct calls on the same
  region.

**Text and languages**
- The game's fonts have no Chinese, Japanese, Korean or Cyrillic letters (and miss some Polish and
  Turkish ones), and a missing letter draws *nothing*.
  - Make font strings with `C.Text` / `C.SetFace` so the language's bundled face applies.
  - Show our own tooltips with `C.ShowTip()` (it swaps the tooltip's faces) instead of
    `GameTooltip:Show()`. Tooltips with the game's own content (`SetUnit`, `SetAction`, `SetTalent`)
    keep `GameTooltip:Show()`.
- Every word the player sees goes through `C.L` / `C.F` / `C.LText` and is translated into all 11
  languages: see "Translations" in `dev/README.md`. Then run `gen.py`, `locale_check.py` and
  `overflow.lua`, and check the bundled fonts have every new letter (fontTools cmap).

**Design and code style**
- **Art must be original.** The user doesn't want anything looking lifted from other addons. All
  art is drawn by the scripts in `dev/art` (numpy/PIL).
- The look: dark glass, a gold rail, the timer's metal, diamonds on corners (`C.Panel`). Smooth,
  "eye candy", but calm.
- **Parts:** every part registers with `C.RegisterPart` (key, name, note, get, set; optional scale),
  can be turned off (giving back the game's own UI exactly), and wraps its OnUpdate in `pcall`. After
  an error it turns itself off with a translated message.
- Comments are plain English prose describing what the player sees. Keep that voice.
- The options hub grows 26 px per part: at 17 parts it's 732 px tall, close to the 768 px screen.
  A new part needs a new hub layout (two columns or scrolling).

## 5. Checking before shipping

Build Lua 5.0.3 (lua.org) and install Python 3 with numpy, Pillow, scipy, fontTools and opencv-python.
From `dev/`:

```
lua50 cui/tests.lua . ../CreedUI                # 423 passed, 0 failed
lua50 cui/timer_tests.lua . ../CreedUI          # 78 passed
lua50 cui/numbers_harness.lua . ../CreedUI/Numbers.lua   # ALL CHECKS PASSED (also with CROWD=1)
lua50 cui/smoke.lua . ../CreedUI out            # problems: 0
lua50 cui/globals.lua . ../CreedUI              # only this, event, arg1
lua50 cui/overflow.lua . ../CreedUI             # overflows: 0
python3 cui/locale_check.py ../CreedUI          # LOCALE OK
```

For pictures, use a `cui/*prev.lua` scene and then `cui/render_cui.py`. To ship: bump `C.VERSION` in
Core.lua and `## Version` in the .toc, add a `CHANGELOG.md` entry, zip as `CreedUi-<version>.zip`,
send the user the zip and a preview, and tag and release on GitHub.

Add a test for every new behaviour, and prove a fix by showing the test fails on the old code.

## 6. The game's addon API (AZS)

The stand-in client (`dev/cui/mock_cui.lua`) encodes the exact shapes the code relies on. Read it
before using an API. Known:

- **Run state:** `AZS_RUN` (`lvl`, `xp`, `xpn`, `gold`, `kills`, `chest`, `rr`, `rrc`, `px`, `py`, ...),
  `AZS_STATS` (`luck`, `gluck`, ...; the full field list isn't known yet). `AZS_GetPhase`,
  `AZS_GetRunTime` (stops during cards and pause), `AZS_GetRunLength`, `AZS_GetLocalTime`.
- **Minimap data:** `AZS_LAIRS` + `AZS_LAIRS_UPDATED` (state asleep/awake/empty, `left`, `x`, `y`,
  `flag`), `AZS_CHESTS`.
- **The game's HUD pieces:** `AZS_SetHudShown` / `AZS_IsHudShown` (parts like `flag` and `localClock`),
  `AZS_SetOnTopOfScreens`.
- **Combat text:** `AZS_GetCombatTextCapabilities`, `AZS_GetCombatTextEvents(cursor, max)`,
  `AZS_ProjectCombatTextAnchors`, `AZS_RegisterCombatTextFrameHandler`. Events carry `meterSource` and
  `meterSourceKey` (the meter line a hit counts toward) and now a distance from the hero.
- **Meter API v1:** `AZS_GetMeterContext`, `AZS_GetMeterSnapshot(query)` (strict query keys;
  `sources` carry names and icons), checkpoints. Also summons, totems, bosses and guardians getters.
- **New in API 0.139.2, docs not obtained yet:** `AZS_GetDownedPartyMembers` (where each downed friend
  can be revived, on every map), `AZS_GetWorldAnchors` + `AZS_ProjectWorldAnchors` (markers on any
  enemy, its corpse spot, a cache, guardian, boss or lair, lifted N yards; no target or nameplate
  needed).
- `/creed probe` prints `AZS_STATS`, `AZS_RUN` and the stats the character panel found. Ask the user
  for its output when you need field names.

## 7. Next

1. **GitHub:** upload and release 1.8.3 if it isn't done (section 2).
2. **Boss skull:** a skull marker floating over each **boss** (not guardians), sized by distance, using
   the world anchors. Blocked on the API docs: ask the user to paste the addon-author section of the
   0.139.2 notes, or to run a dump of what those functions return.
3. **Downed party member** (co-op: you revive someone by standing on them):
   - a banner and a sound when someone in the party goes down;
   - a marker on the spot where they can be revived;
   - an arrow at the screen's edge with the distance while they're off-screen.

   Needs `AZS_GetDownedPartyMembers`'s docs.
4. **Run talents strip** (removed in 1.8.1, code in `dev/attic`): wait until the game says where it
   keeps the run's talents (`/creed probe`).
5. **Not yet confirmed in the real client:**
   - the bundled TTFs loading from the addon folder, and CJK rendering;
   - `SetCursor` taking an addon texture (the resize arrow; if it fails, the drawn arrow comes back);
   - the character window's assumptions: stats are read as "Label:" with the value on the same row,
     and the Run Stats panel is found by its title;
   - the talent trees' background paths (`Interface\\TalentFrame\\<bg>-TopLeft/-BottomLeft`).

   Ask the user for a screenshot after each change in these areas.
