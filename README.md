# Creed UI

A clean, smooth HUD for **Azeroth Survivors** ([wow.aethus.pl](https://wow.aethus.pl)), the World of Warcraft 1.12 roguelike. Everything is drawn in one look (dark glass, a gold rail, the timer's metal) and steps aside while you pick your cards.

## What's in it

- **Boss timer:** a themed countdown to each boss, with the run's time.
- **Boss and mini-boss bars:** red bars with real health numbers and the debuffs on them.
- **Boss skulls:** a skull floating over each boss wherever it is on the screen, large when it's near and small when it's far (gold over the final boss).
- **Your frame, your target and your party:** in class colors, portraits in metal rings.
- **Skill bar:** your abilities and jewelry, your XP a second, on a gold-framed panel guarded by two dragons wrapped in their wings.
- **Kills, gold and cache:** in the panel; hover for what each gives.
- **Damage meter:** Damage Done, Healing Done, Boss Damage and Party DPS, with icons, per second and shares. Resizable from any edge.
- **Luck medallion:** your luck and the odds of a Rare, Epic or Legendary card.
- **Minimap:** a metal ring, your local time, the caches and the guardians' lairs (with the time until each empty lair fills), and buttons on its edge you can drag around it: the **C** opens the options, the **crossed swords** show or hide the meter, the **clover** the luck window.
- **Character window:** gear slots lit in their rarity color, your run's stats grouped beside it (zeros dimmed, changes flashing), and a **Talents** page with your talent trees in place of Skills.
- **Chat:** dressed to match, and kept clear of the skill bar's dragon.
- **Damage numbers:** calm and readable; a spell hitting a crowd adds up into one number a second.

Every part can be turned on or off, sized and moved.

**Languages:** English, French, German, Spanish, Portuguese, Chinese, Russian, Japanese, Korean, Polish and Turkish, picked from the options or with `/creed language`.

## Install

1. Download the latest `CreedUi-<version>.zip` from [Releases](../../releases).
2. Unzip it into your game's `Interface/AddOns` folder. You should end up with `Interface/AddOns/CreedUI/CreedUI.toc`.
3. The folder must stay named `CreedUI`: the game loads it by that name, and your settings are kept under it.

## Commands

| Command | What it does |
| --- | --- |
| `/creed` | Opens the options (or click the C on the minimap's edge) |
| `/creed move`, `/creed lock` | Frees the frames to drag them, then locks them |
| `/creed reset` | Puts every frame back in its place |
| `/creed language <code>` | Picks the language (`auto` follows the game) |
| `/creed timer ...`, `/creed numbers ...` | The boss timer's and damage numbers' own settings |
| `/creed <part> on/off` | Turns a part on or off |
| `/creed probe` | Prints what the game gives addons, for reporting what's missing |

## Credits

Original art made for Creed UI. The bundled fonts in `CreedUI/Fonts` are made from Lora and Noto Sans CJK, both under the SIL Open Font License (see `CreedUI/Fonts/LICENSE.txt`).

## Working on it

The tools that build and check Creed UI (a stand-in game client with its tests, the translation, art and font scripts, a preview renderer) are in [`dev`](dev/README.md).
