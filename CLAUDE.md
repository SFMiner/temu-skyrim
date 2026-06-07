# CLAUDE.md — Temu Skyrim

Guidance for working in this repo. Read this before making changes.

## What this is
A top-down 2D action-RPG **demake of Skyrim** built in **Godot 4.6**, as a self-aware
"Temu version of X" parody — budget-knockoff jank and humor throughout (DraGON™,
Dragonbornn™, free shipping, 1-star reviews). The Godot project lives in
`new-game-project/`; the repo root holds tooling and docs.

The aesthetic and feature goal is to keep the *spirit* of Skyrim (intro, town, shouts,
dragon, dungeons, quests, leveling) over fidelity. Creative decisions are generally at
the implementer's discretion; keep the Temu tone.

## Golden rule: it's code-driven
A minimal `new-game-project/Main.tscn` boots `scripts/main.gd`, which builds the world,
UI, and entities **entirely in GDScript**. **Do not hand-author large `.tscn` scenes** —
add features in code following the existing patterns. New "scenes" (overworld, dungeon,
temple) are plain `Node2D` scripts instantiated via `set_script` and swapped by `main.gd`.

## How to run & validate (bundled binary)
Binary: `Godot_v4.6-stable_win64.exe` at the repo root. Project path: `new-game-project`.

- **Parse / import check (primary):**
  `Godot_v4.6-stable_win64.exe --headless --path new-game-project --editor --quit-after 250`
  → expect no `SCRIPT ERROR` / `Parse Error` / `not found`. This registers new
  `class_name`s and imports new assets.
- **Runtime smoke test:** set `TEMU_AUTOSTART=1` then
  `... --headless --quit-after 150` → boots straight into the overworld; grep output
  for `SCRIPT ERROR` / `Failed loading resource` / `Nonexistent`.
- **Force a reimport** of changed assets: `... --headless --path new-game-project --import`.
- `TEMU_SHOT=1` with the real renderer dumps screenshots.

### Validation gotchas
- `--check-only --script res://scripts/foo.gd` (single-script) gives **false**
  `Compile Error: Identifier not found: Game/Audio` — autoloads aren't loaded in
  isolation. Trust the full `--editor` import scan instead.
- `LSP: Failed to parse script: res://scripts/dungeon_flow_test.gd` is a **pre-existing,
  flaky** editor-only warning; ignore it (it doesn't affect the game compile).
- A benign `ERROR: N resources still in use at exit` can appear on headless quit — not a bug.

## Architecture

### Autoloads (singletons, `project.godot`)
- **`Game`** (`scripts/game.gd`) — the single source of truth: player stats, inventory,
  `ITEMS` database, `quests`/`flags`, gold/XP/leveling, skills, save/load, and shared
  signals. Also holds runtime refs set by `main.gd`: `Game.dialogue`, `Game.hud`,
  `Game.shop`, `Game.world`, and `Game.ui_open`.
- **`Audio`** (`scripts/audio.gd`) — `Audio.sfx(key, vol_db, pitch_var)`,
  `play_music(key, vol_db)`, `play_ambient(key)`. Keys = filenames discovered at runtime
  in `assets/audio/`.

### Scene flow (`main.gd`)
`_start_overworld()` / `_load_dungeon(pos)` / `_load_temple(pos)` each `queue_free` the
current `_world` and instantiate a fresh `Node2D` with the target script. Worlds set
`Game.world = self` in `_ready` and expose a `player` var. `main.gd` owns the persistent
UI (`_hud`, `_dialogue`, `_pause`) so they survive world swaps. To add a new "scene",
copy the `_load_dungeon` pattern.

### Enemies (`scripts/enemy.gd` + subclasses)
- **`Enemy`** = the shared brain: chase/attack FSM, knockback, damage, loot, XP, blood,
  death. Subclasses override only the visuals: `_build_visual`, `_update_visual(moving)`,
  `_play_attack`, and `_on_death` (custom death hook — called by `_die()` *after* loot).
- **`HumanoidEnemy`** (`char_name` → LPC sheet) for human foes: bandit, draugr, Steve,
  Necromancer. **`Wolf`/`Spider`/`GiantSpider`/`Sweetie`** extend `Enemy` directly with
  frame-animated `Sprite2D`s (battler art).
- Player attacks every node in group **`"enemies"`** via `take_damage(amount, knockback)`
  — so any new enemy must add to that group (the base does) and implement `take_damage`
  (the base does). **Bosses** also `add_to_group("boss")`; the HUD reads the first boss's
  `display_name`/`hp`/`max_hp` for the boss bar (see `giant_spider.gd`, `necromancer.gd`).
- Tint via the child sprite's `modulate` (the base `_tint()` only flashes the node white/
  red). Scale via `spr.scale`. Configure per-spawn extras (`gold_drop`, `loot`) in the
  spawner; stats set in `_build_visual` win over pre-`add_child` assignments.
- `Dragon` is a standalone boss (`CharacterBody2D`, not `Enemy`) with its own FSM.

### Quests, flags, dialogue, HUD
- **Quests:** `Game.quests` dict, stages `0 unknown / 1 active / 2 ready / 3 complete`.
  Add the key to the dict in **both** the init line and `_reset_run()`. `Game.set_quest(id,
  stage)` emits `quest_updated` → the HUD tracker (`hud.gd:_refresh_quests`) redraws. If
  you change quest state *without* `set_quest` (e.g. flag-only progress), emit
  `Game.quest_updated.emit(id)` yourself or the tracker won't refresh.
- **Flags:** `Game.flags` dict (free-form). Gate one-time content on flags (e.g. unique
  enemies that must not respawn).
- **Items:** add to `Game.ITEMS`. Fields: `name,type,value,icon,desc,rating` + per-type
  (`dmg` weapon, `heal/magicka/stamina` potion/food). `no_sell:true` makes an item
  unsellable in the shop (`menu_ui.gd`).
- **Dialogue:** `Game.dialogue.start(name, lines:Array[String], choices)` where each
  choice is `{"text": String, "action": Callable}`. **BBCode** is supported (`[i]`,
  `[color=#…]`). Toasts: `Game.notify.emit(text, Color)`. Full-screen FX in `hud.gd`:
  `flash(color)` and `fade_black(mid_callable, hold)`.
- **NPCs:** `overworld.gd:_spawn_npc(char_name, npc_name, pos, on_interact, can_wander)`
  builds an `Npc` from an LPC sheet. Quest-aware dialogue lives in the `_talk_*` callbacks.
- **Interactables:** `Interactable` + an `Area2D` in group `"interactable"` with an
  `on_interact` Callable (see `_build_cave_entrance`, `_build_shrine`, `_build_apology_board`).

### Soft pause (important)
There is **no `get_tree().paused`** — the game uses a soft-pause flag **`Game.ui_open`**
(set true by dialogue/menus/pause). Every actor that can affect gameplay must check it and
freeze: the player, NPCs, **`enemy.gd`**, `dragon.gd`, `necromancer.gd` casting, and
`projectile.gd` all early-return while `ui_open`. **Any new enemy/projectile/timed attack
must respect `Game.ui_open`** or it will keep hitting the player through menus/pause.

## Sprite pipeline
Two sources, by role: **humans = LPC**, **monsters = rpgbattlers** (battler art, like the
spiders/Sweetie).

- LPC generator lives at `C:\Users\seanm\AI LPC Sprite Gen\`. The wrapper returns params
  only; **skip it** and hand-author `tools/<name>.json` from real items in
  `ai-wrapper/asset-manifest.json` (no API cost). Then run:
  `python tools/lpc_compose.py --params @tools/<name>.json --out new-game-project/assets/chars --name <name>`.
  `scripts/lpc_frames.gd` slices `assets/chars/<name>_<anim>.png` into runtime frames at
  load (NPC/HumanoidEnemy `char_name` = `<name>`). Existing recipes: `tools/{villager,
  mage,camilla,ysolda,sigrid,sam,steve}.json`.
- **Idle gotcha:** color-variant clothing layers (`Tunic`, `Longsleeve blouse`,
  `Sleeveless`, `Longsleeve laced`, dresses) ship **no idle** animation, so the composited
  `_idle.png` drops that layer. Fix: **rebuild `<name>_idle.png` from the walk sheet's
  standing frame** (column 0 of each of the 4 direction rows) with PIL.
- **Which clothes recolor:** plain `Longsleeve`/`Longsleeve 2` are **fixed cream**
  (`variants: null`) — a `_color` suffix silently no-ops. Use the color-variant tops above.
  Skirts (`Plain skirt`) and most hats/hair recolor fine and have idle.
- **No male floor-length robe** exists (`Robe` is female-only, misaligns on a male body).
  Fake one with `Longsleeve laced` + `Plain skirt` in a shared color (see `tools/mage.json`).
- **Monsters:** copy a few numbered frames from
  `GameAssets/rpgbattlers/**/Pixel-Style/<Monster>/<Monster> N.png` into
  `assets/enemies/`, then animate Spider-style (`spider.gd`/`sweetie.gd`), tint + scale.

## Asset import gotcha
Some hand-edited PNGs are structurally non-standard — PIL reads them but **Godot's
importer rejects them** (`valid=false` in the `.import`), causing runtime
`Failed loading resource`. Fix: re-save through PIL as a clean RGBA PNG
(`Image.open(p).convert("RGBA").save(p,"PNG")`), delete the stale `.import` + the
`.godot/imported/<name>.png-*` cache, then `--import`. Art is unchanged.

## Current content (as of this writing)
- **Overworld** (Beigeton): town (keep, NPCs, Belethor's shop), wilderness with wolves,
  bandit camp, dragon lair, cave → barrow dungeon.
- **Quests:** `main` (DraGON™), `sweetroll`, `golden_claw` (Farengar → barrow → Giant
  Frostbite Spider boss), `break_of_dawn` (Meridia parody → temple → Malkoran the
  necromancer → DawnBreaker™), `night` ("A Night to Remember" Sanguine parody → Sam →
  blackout → 4 antics: Belethor debt, apology board, duel Steve, defeat Sweetie the frost
  troll → trophy). `freetrial` is stubbed.
- **NPCs:** jarl, guard, Belethor, Sigrid, Ysolda, Camilla (distinct LPC sprites),
  Farengar (blue-robe mage), Sam (top-hatted Sanguine), plus dungeon NPC Arvel.
- **Enemies:** wolf, bandit(+chief), draugr, frost spider, Giant Frostbite Spider (boss),
  Dragon (boss), Malkoran (boss), Steve, Sweetie (frost troll).
- Candidate future quests are listed in `potential_quests.md`.

## Coding Patterns (in practice)

### Interaction system
- **Interactable class:** Any interactive object must be an `Interactable` instance (extends `Node2D`) with
  a proper `interact(player: Node2D) -> void` method. Player code checks `has_method("interact")`, not property
  assignment. See `scripts/interactable.gd`. Use in dungeons via `_make_interactable()` helper (see `dungeon.gd`).
- **Input consumption:** When handling input in `_input()`, call `get_viewport().set_input_as_handled()` on
  success so input doesn't cascade to other handlers (e.g., E press for dialogue shouldn't also open the dialogue box).
- **Interact range:** Keep dialogue/interaction range in sync with prompt visibility. NPCs show "[E] Talk" at 70px;
  keep `player._interact()` search radius consistent (e.g., 72px).

### Type inference quirks (GDScript 4.6 strict mode)
- **String concatenation:** `var path: String = DIR + name + ext` — explicit `String` type required when
  concatenating to avoid "cannot infer type" errors.
- **For-in loops:** `for ext: String in [".mp3", ".wav"]` — must annotate loop variable type.

### Respawn system (Skyrim-style)
- Track spawns in a `_spawns: Array` of `{"pos", "make", "node", "dead_at"}` metadata.
- Use `_register_spawn(pos, make_callable)` to spawn enemies and track them.
- In `_update_respawns(delta)`, poll every 1 second; respawn only if `dead_at + RESPAWN_DELAY` has passed
  AND player is `> RESPAWN_MIN_DIST` away. Use flags to prevent boss respawns (e.g., `giant_spider_slain`).
- Copy the pattern verbatim between overworld and dungeon — it's identical and simple.

### Asset naming
- Always verify actual asset filenames in `assets/` directories. Typos silently fail at runtime
  (`Failed loading resource`). Example: dungeon walls are `tile_dwall.png`, not `dungeon_wall.png`.
- If an asset renders as blank/invisible, check both the load path AND the actual filename on disk.

## Conventions
- GDScript: **tabs** for indentation, type hints on vars/params/returns, `class_name` for
  reusable types (auto-registers globally). Match the comment density and `# === SECTION ===`
  header style of neighboring files.
- Commit only when asked. End commit messages with the project's `Co-Authored-By` line.
- Leave the pre-existing unrelated working-tree churn (`.claude/scheduled_tasks.lock`,
  `project.godot`/`export_presets.cfg` import-setting tweaks) out of feature commits.
