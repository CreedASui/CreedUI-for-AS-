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
- Current version: **1.9.0**. Repository: <https://github.com/CreedASui/CreedUI-for-AS->.
- 11 languages: en, fr, de, es, pt, zh, ru, ja, ko, pl, tr.

## 2. Releases

The repository holds everything since 1.8.3. Claude Code sessions here may push only their own
branch and can't make tags or GitHub releases: the user makes each release on GitHub's website
(tag `v<version>`, title **Creed UI <version>**, the version's `CHANGELOG.md` entry as text, and
`CreedUi-<version>.zip` attached). Give them those steps and the zip.

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
  Skulls.lua        a skull over each boss (world anchors), sized by distance
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
- The options hub lays the parts out in two columns (the first half on the left) and grows 26 px
  per two parts: at 19 parts it's 432 px tall. A test keeps it under 700 px.

## 5. Checking before shipping

Build Lua 5.0.3 (lua.org) and install Python 3 with numpy, Pillow, scipy, fontTools and opencv-python.
From `dev/`:

```
lua50 cui/tests.lua . ../CreedUI                # 447 passed, 0 failed
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
- **World anchors (API 0.139.2):** read from the game's own code (below), mirrored in the stand-in.
  - `AZS_GetWorldAnchorCapabilities()`: kinds `enemy`, `elite`, `guardian`, `boss`, `finalBoss`,
    `cache`, `guardianLair`, `downedPartyMember`; attachments `position`, `overhead`; 256 a call.
  - `AZS_GetWorldAnchors(query, cursor, limit)`: query nil or `{ kinds = {...}, states = {...} }` (no
    other keys), cursor nil or a string, limit 1 to 256. Answers `{ apiVersion, catalogId, entries,
    hasMore, nextCursor, overflowed }`; each entry has `anchorId`, `kind`, a state (`alive`, `dead`,
    `downed`, `asleep`, `awake`, `empty`...), `attachments`, `positionAvailable`, `x/y/z`, ids
    (`unitId`, `cacheId`, `lairIndex`, `memberId`). Errors `NOT_READY`, `CATALOG_CHANGED` (read again
    from the start), `INVALID_ARGUMENT`.
  - `AZS_ProjectWorldAnchors(requests)`: each `{ anchorId, attachment = "position"|"overhead", offset =
    { x, y, z } }` in yards. Answers `{ cameraSampleId, frameCurrent, entries }`; each entry `state`
    (`onScreen`, `offscreen`, `behindCamera`, `clipped`, `notReady`, `expired`, `unknownAnchor`,
    `worldChanged`, `unsupportedAttachment`), `targetState`, `x`, `y` (WorldFrame's bottom left, as
    combat text), `cameraDepth`, `uiUnitsPerYard`, `playerDistance`.
  - `AZS_RegisterWorldAnchorFrameHandler(fn)`: called each frame after the camera, as combat text's.
  - `AZS_GetDownedPartyMembers()`: no arguments; a list of `{ id, name, positionAvailable, anchorStatus,
    anchorId, x, y, z, mapId, runId, spaceId }` (nil and an error before the run's lines come).
    `AZS_GetRevive()` / `AZS_REVIVE`: `{ down, share, by, reviving, rshare }` (your own revive and
    the friend you stand over). `AZS_DOWNED` + `AZS_DOWNED_UPDATED` are the raw list.
  - The exact nesting of the answers is the one thing not seen live: `/creed probe` prints them.
- **Where the API is written down:** the game's Lua for every `AZS_*` function, with comments, is
  inside its client, `https://wow.aethus.pl/wenilla_bg.wasm` (about 90 MB): `strings -n 3` it and
  search for `function AZS_`. The native side's field names and error messages are there too.
- `/creed probe` prints `AZS_STATS`, `AZS_RUN` and the stats the character panel found. Ask the user
  for its output when you need field names.

## 7. Next

1. **Boss skulls (1.9.0):** done, not yet seen in the real client. Ask the user for a screenshot in a
   boss fight and the output of `/creed probe` there; adjust `Skulls.lua` and the stand-in if the
   answers are nested differently.
2. **Downed party member** (co-op: you revive someone by standing on them):
   - a banner and a sound when someone in the party goes down;
   - a marker on the spot where they can be revived (world anchor kind `downedPartyMember`);
   - an arrow at the screen's edge with the distance while they're off-screen.

   The API is known now (section 6); `Skulls.lua` shows how to read and draw world anchors.
3. **Run talents strip** (removed in 1.8.1, code in `dev/attic`): wait until the game says where it
   keeps the run's talents (`/creed probe`).
4. **Not yet confirmed in the real client:**
   - the bundled TTFs loading from the addon folder, and CJK rendering;
   - `SetCursor` taking an addon texture (the resize arrow; if it fails, the drawn arrow comes back);
   - the character window's assumptions: stats are read as "Label:" with the value on the same row,
     and the Run Stats panel is found by its title;
   - the talent trees' background paths (`Interface\\TalentFrame\\<bg>-TopLeft/-BottomLeft`).

   Ask the user for a screenshot after each change in these areas.
