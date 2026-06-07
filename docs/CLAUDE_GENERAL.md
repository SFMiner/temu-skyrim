# CLAUDE_GENERAL.md — Code-Driven Godot RPG (reusable template)

A setting-agnostic engine contract for a top-down 2D action-RPG built **entirely in
GDScript** on Godot 4.x. Pair it with **`BUILDING_RPGS.md`** (the long-form how-to).

**Using this in a new project:** drop this file and `BUILDING_RPGS.md` into a blank
Godot project, **rename this to `CLAUDE.md`**, and let it be the "read me first" your
assistant follows. The conventions below describe the engine you build per the guide;
they become accurate as you implement it. As your game takes shape, add a project-
specific **"Current content"** section at the bottom (worlds, quests, NPCs, enemies).

> Names like `Game`, `Audio`, `Enemy`, and the env-var prefix are conventions, not
> requirements — keep them consistent within your project. Pick a short prefix for your
> debug env vars (shown here as `<GAME>_`).

## Golden rule: it's code-driven
A minimal `Main.tscn` boots `scripts/main.gd`, which builds the world, UI, and entities
**entirely in GDScript**. **Do not hand-author large `.tscn` scenes** — add features in
code following the established patterns. "Scenes" (worlds like an overworld, a dungeon,
etc.) are plain `Node2D` scripts instantiated via `set_script` and swapped by `main.gd`.

## How to run & validate
Run headless against your project path (`<project>` = the Godot project folder).

- **Parse / import check (primary):**
  `Godot --headless --path <project> --editor --quit-after 250`
  → expect no `SCRIPT ERROR` / `Parse Error` / `not found`. This registers new
  `class_name`s and imports new assets.
- **Runtime smoke test:** wire an env-var gate in `main.gd` (e.g. `<GAME>_AUTOSTART=1`
  boots straight into the first world), then
  `<GAME>_AUTOSTART=1 Godot --headless --path <project> --quit-after 150` → grep output
  for `SCRIPT ERROR` / `Failed loading resource` / `Nonexistent`. A `<GAME>_SHOT=1` gate
  that dumps screenshots with the real renderer is handy too.
- **Force a reimport** of changed assets: `Godot --headless --path <project> --import`.

### Validation gotchas
- `--check-only --script res://scripts/foo.gd` (single-script) gives a **false**
  `Compile Error: Identifier not found: Game/Audio` — autoloads aren't loaded in
  isolation. Trust the full `--editor` import scan instead.
- `LSP: Failed to parse script: ...` on a **test/helper script** can be a flaky,
  editor-only warning; confirm it doesn't appear in the actual game compile before
  chasing it.
- A benign `ERROR: N resources still in use at exit` can appear on headless quit — not a bug.

## Architecture

### Autoloads (singletons, `project.godot`)
- **`Game`** (`scripts/game.gd`) — the single source of truth: player stats, inventory,
  an `ITEMS` database, `quests`/`flags`, gold/XP/leveling, skills, save/load, and shared
  signals. Also holds runtime refs set by `main.gd`: `Game.dialogue`, `Game.hud`,
  `Game.shop`, `Game.world`, and the soft-pause flag `Game.ui_open`.
- **`Audio`** (`scripts/audio.gd`) — `Audio.sfx(key, vol_db, pitch_var)`,
  `play_music(key, vol_db)`, `play_ambient(key)`. Keys = filenames discovered at runtime
  in `assets/audio/`.

### Scene flow (`main.gd`)
`_start_overworld()` / `_load_<world>(pos)` each `queue_free` the current `_world` and
instantiate a fresh `Node2D` with the target script. Worlds set `Game.world = self` in
`_ready` and expose a `player` var. `main.gd` owns the persistent UI (`_hud`, `_dialogue`,
the pause overlay) so they survive world swaps. **To add a new world, write a `Node2D`
script and copy the `_load_<world>` pattern in `main.gd`.**

### Enemies (`scripts/enemy.gd` + subclasses)
- **`Enemy`** = the shared brain: chase/attack FSM, knockback, damage, loot, XP, blood,
  death. Subclasses override only the visuals: `_build_visual`, `_update_visual(moving)`,
  `_play_attack`, and `_on_death` (custom death hook — called by `_die()` *after* loot, so
  it's the clean place to fire quest progress).
- **Humanoid foes** drive a character spritesheet by name (a `char_name` → sheet helper).
  **Monster foes** extend `Enemy` directly with a frame-animated `Sprite2D` (flip on
  facing, cycle frames).
- The player attacks every node in group **`"enemies"`** via
  `take_damage(amount, knockback)` — any new enemy must be in that group (the base does it)
  and implement `take_damage` (the base does). **Bosses** also `add_to_group("boss")`; the
  HUD reads the first boss's `display_name`/`hp`/`max_hp` to draw a boss bar.
- Tint via the **child** sprite's `modulate` (the base `_tint()` only flashes the node
  white/red on hit). Scale via `spr.scale`. Set stats in `_build_visual`; set per-spawn
  extras (`gold_drop`, `loot`) on the instance before adding it to the tree.
- A bespoke boss can be a standalone `CharacterBody2D` with its own FSM when the shared
  brain doesn't fit — just honor the `"enemies"`/`"boss"` group + `take_damage` contract.

### Quests, flags, dialogue, HUD
- **Quests:** `Game.quests` dict, stages `0 unknown / 1 active / 2 ready / 3 complete`.
  Register each key in **both** the declaration and the run-reset function.
  `Game.set_quest(id, stage)` emits `quest_updated` → the HUD tracker redraws. If you
  change quest state *without* `set_quest` (e.g. flag-only progress), emit
  `Game.quest_updated.emit(id)` yourself or the tracker won't refresh.
- **Flags:** `Game.flags` dict (free-form). Gate one-time content on flags (e.g. a unique
  enemy that must not respawn).
- **Items:** add to `Game.ITEMS`. Fields: `name, type, value, icon, desc, rating` +
  per-type (`dmg` for weapons; `heal/magicka/stamina` for potion/food). `no_sell: true`
  makes an item unsellable in the shop.
- **Dialogue:** `Game.dialogue.start(name, lines: Array[String], choices)` where each
  choice is `{"text": String, "action": Callable}`. **BBCode** is supported (`[i]`,
  `[color=#…]`). Toasts: `Game.notify.emit(text, Color)`. Full-screen FX on the HUD:
  `flash(color)` and `fade_black(mid_callable, hold)`.
- **NPCs:** a `_spawn_npc(char_name, npc_name, pos, on_interact, can_wander)` helper builds
  an NPC from a character sheet; quest-aware dialogue lives in its `_talk_*` callback,
  branching on `Game.quests`/`Game.flags`.
- **Interactables:** an `Interactable` node + an `Area2D` in group `"interactable"` with an
  `on_interact` Callable. (See the interaction rules under "Coding patterns".)

### Soft pause (important)
There is **no `get_tree().paused`** — use a soft-pause flag **`Game.ui_open`** (set true
by dialogue/menus/pause). Every actor that can affect gameplay must check it and freeze:
the player, NPCs, the enemy brain, any custom-FSM boss, and projectiles all early-return
while `ui_open`. **Any new enemy / projectile / timed attack must respect `Game.ui_open`**
or it will keep hitting the player through menus and the pause screen.

### Save / load
Serialize the relevant `Game` fields (stats, inventory, equipped, `quests`, `flags`, …) to
JSON at `user://`. Because quests and flags are plain dicts, **new quests/flags persist
automatically** — no save-format changes when you add content.

## Sprite pipeline
Two sources by role: **humans = LPC** layered sheets; **monsters = battler frames**.

- **LPC humanoids:** hand-author a small param recipe `tools/<name>.json`, composite the
  layers into per-animation sheets, and slice them at load into a runtime `SpriteFrames`
  (an NPC/enemy with `char_name = "<name>"` then animates). The compositor needs an
  external LPC generator checkout — see `BUILDING_RPGS.md` §6 for the setup and the
  path-portability caveat (the tool paths must be parameterized for a fresh machine).
- **LPC gotchas worth knowing:**
  - Many color-variant clothing layers ship **no idle** animation, so the composited
    `_idle.png` drops that layer. Fix: **rebuild `<name>_idle.png` from the walk sheet's
    standing frame** (column 0 of each of the 4 direction rows) with PIL.
  - Some "plain" tops are **fixed-color** (a `_color` suffix silently no-ops) — use the
    color-variant tops for recolorable clothing. Skirts and most hats/hair recolor fine.
  - Some garments only exist for one body type; you can fake a missing one by layering
    other pieces in a shared color (e.g. a long top + a skirt reads as a robe).
- **Monsters:** copy a few numbered battler frames into `assets/enemies/`, then animate
  them in a `Sprite2D` (flip + frame-cycle), tint and scale in code.

## Asset import gotcha
Some hand-edited PNGs are structurally non-standard — PIL reads them but **Godot's
importer rejects them** (`valid=false` in the `.import`), causing runtime
`Failed loading resource`. Fix: re-save through PIL as a clean RGBA PNG
(`Image.open(p).convert("RGBA").save(p, "PNG")`), delete the stale `.import` + the
`.godot/imported/<name>.png-*` cache, then `--import`. Art is unchanged.

## Coding patterns (in practice)

### Interaction system
- **Interactable class:** an interactive object is an `Interactable` instance (extends
  `Node2D`) with an `interact(player: Node2D) -> void` method. Player code checks
  `has_method("interact")`, not a property. Build them via a `_make_interactable()` helper.
- **Input consumption:** when handling input in `_input()`, call
  `get_viewport().set_input_as_handled()` on success so it doesn't cascade to other handlers
  (e.g. the same E-press shouldn't both trigger and immediately advance a dialogue box).
- **Interact range:** keep interaction range in sync with prompt visibility (e.g. an NPC
  shows "[E] Talk" at 70px → keep the player's interact search radius ~72px).

### GDScript strict-mode type quirks
- **String concatenation:** annotate the target: `var path: String = DIR + name + ext`
  (avoids "cannot infer type").
- **For-in loops:** annotate the loop var: `for ext: String in [".mp3", ".wav"]`.

### Respawn manager
- Track spawns in a `_spawns: Array` of `{"pos", "make", "node", "dead_at"}`.
- `_register_spawn(pos, make_callable)` spawns and tracks an enemy.
- `_update_respawns(delta)` polls ~once a second; respawn only if `dead_at + RESPAWN_DELAY`
  passed **and** the player is `> RESPAWN_MIN_DIST` away. Flag-gate bosses so they don't
  respawn. The pattern is identical across worlds — copy it verbatim.

### Asset naming
- Verify actual filenames in `assets/`. Typos fail silently at runtime
  (`Failed loading resource`). If art renders blank/invisible, check **both** the load path
  and the on-disk filename.

## Conventions
- GDScript: **tabs** for indentation, type hints on vars/params/returns, `class_name` for
  reusable types (auto-registers globally). Match the comment density and
  `# === SECTION ===` header style of neighboring files.
- Commit only when asked. Keep unrelated working-tree churn out of feature commits.

---

## Current content
*(Fill this in as you build — your worlds, quests, NPCs, and enemies. Keeping it current
gives your assistant an accurate map of the game.)*
