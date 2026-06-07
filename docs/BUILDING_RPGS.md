# Building Reusable Code-Driven RPGs

A practical guide to the architecture behind this project (a top-down 2D action-RPG
on **Godot 4.6**, built almost entirely in GDScript) and how to reuse it as a
foundation for *other* RPGs.

This repo — "Temu Skyrim" — is the running worked example, but the patterns are
theme-agnostic: **the engine is reusable; the theme is just content.**

> **Honesty up front.** The *engine* (everything in `new-game-project/scripts/`) is
> portable and runs anywhere Godot 4.6 does. The *asset-generation toolchain*
> (`tools/*.py`) is **not** portable as-is: it hardcodes absolute paths to the
> author's machine and depends on an external sprite generator that isn't in this
> repo. See [§6 Known limitations](#6-known-limitations--making-this-a-real-template).

## Table of contents
1. [Overview & philosophy](#1-overview--philosophy)
2. [Fresh-clone setup](#2-fresh-clone-setup)
3. [Part 1 — The reusable engine](#3-part-1--the-reusable-engine)
4. [Part 2 — Spinning up a new RPG](#4-part-2--spinning-up-a-new-rpg)
5. [Part 3 — Validate & ship](#5-part-3--validate--ship)
6. [Known limitations / making this a real template](#6-known-limitations--making-this-a-real-template)
7. [Appendix — pitfalls & gotchas](#7-appendix--pitfalls--gotchas)
8. [Checklist — a new RPG starting point in an afternoon](#8-checklist--a-new-rpg-starting-point-in-an-afternoon)

---

## 1. Overview & philosophy

The architecture produces a **top-down 2D action-RPG**: a player walks a tiled
world, talks to NPCs, takes quests, fights enemies, levels up, manages an
inventory, and saves/loads. It is deliberately built as:

**A code-driven, reskinnable engine + a thin content layer.**

- **Engine** = generic systems: state store, scene management, an enemy brain, a
  quest/flag system, dialogue, HUD, inventory/shop, save/load.
- **Content** = the theme: which NPCs/quests/items/enemies/worlds exist, and what
  the sprites and text say.

### Why code-driven (almost no `.tscn` scenes)
A single minimal `new-game-project/Main.tscn` boots one script (`scripts/main.gd`),
which **builds every world, entity, and UI element in GDScript at runtime**. Worlds
are plain `Node2D` scripts, not hand-authored scene files.

Benefits, especially if you iterate with an AI assistant:
- **Diffable & reviewable** — game content lives in `.gd` text, not opaque binary
  `.tscn`. No scene-merge conflicts.
- **Fast, scriptable iteration** — adding an NPC or quest is editing a function, not
  wiring nodes in the editor.
- **AI-friendly** — a model can author dialogue, quests, and spawn logic directly
  against documented patterns (see [§4](#4-part-2--spinning-up-a-new-rpg)).

Trade-off: you give up the visual editor for layout. For a systems-driven RPG with
procedural/tiled worlds, that's a good trade. For a hand-placed cinematic game, less so.

---

## 2. Fresh-clone setup

What a new contributor needs:

1. **Godot 4.6** — download it yourself. The editor binary is **gitignored**
   (`Godot_v4.6-stable_win64.exe` in `.gitignore`), so it is *not* in the repo.
2. Open `new-game-project/` as the project, or run headless (see [§5](#5-part-3--validate--ship)).
3. The game **runs out of the box** — all art/audio is already committed under
   `new-game-project/assets/`. You only need the toolchain in `tools/` if you want to
   *regenerate or add* art, and that toolchain needs setup (see [§6](#6-known-limitations--making-this-a-real-template)).

Repo layout (the real paths — be precise):

```
<repo root>/
├─ Godot_v4.6-stable_win64.exe      # gitignored — download separately
├─ README.md                        # tracked
├─ CLAUDE.md                        # engine contract / working notes for AI assistants
├─ potential_quests.md              # content backlog (may be untracked locally)
├─ tools/                           # art/audio generators + sprite recipes (see §6)
│  ├─ gen_art.py  gen_audio.py  lpc_compose.py
│  └─ <name>.json                   # LPC sprite param recipes
└─ new-game-project/                # the Godot project
   ├─ Main.tscn                     # minimal boot scene -> scripts/main.gd
   ├─ project.godot                 # autoloads, input map, export settings
   ├─ export_presets.cfg            # includes a "Web" preset
   ├─ scripts/                      # ALL game code
   └─ assets/                       # chars, enemies, env, props, fx, items, ui, audio
```

---

## 3. Part 1 — The reusable engine

### 3.1 The skeleton: `Main.tscn` → `main.gd`

`Main.tscn` contains essentially nothing but a root node with `scripts/main.gd`
attached. `main.gd`:
- creates the persistent UI (`_hud`, `_dialogue`, the pause overlay) and stores
  references on the `Game` singleton,
- shows a title/intro, then builds the first world,
- owns global input (save/load/pause) and the scene-swap methods.

The mental model: **`main` is the shell that lives forever; worlds come and go inside it.**

### 3.2 Single source of truth: the `Game` autoload

Registered in `project.godot` as an autoload (alongside `Audio`):

```gdscript
# project.godot
[autoload]
Game="*res://scripts/game.gd"
Audio="*res://scripts/audio.gd"
```

`Game` (`scripts/game.gd`) is a `GameState`-style singleton holding **all** mutable
game state so the HUD, player, menus, and NPCs read/write one place:

- **Stats:** health/magicka/stamina, level, xp, gold, skills.
- **Inventory & items:** `inventory` array + an `ITEMS` dictionary "database".
- **Progression:** `quests` and `flags` dictionaries.
- **Runtime refs** (set by `main.gd`): `Game.dialogue`, `Game.hud`, `Game.shop`,
  `Game.world`, and the soft-pause flag `Game.ui_open`.
- **Signals** the UI listens to: `stats_changed`, `gold_changed`, `leveled_up`,
  `notify(text, color)`, `inventory_changed`, `quest_updated(id)`, …

Helpers you'll reuse constantly:

```gdscript
Game.add_item(id, count)      # also emits inventory_changed
Game.remove_item(id, count)
Game.count_of(id) -> int
Game.add_gold(n) / Game.spend_gold(n) -> bool
Game.add_xp(n)                # auto-levels
Game.set_quest(id, stage)     # emits quest_updated -> HUD refresh
```

The `Audio` autoload is just as small: `Audio.sfx(key, vol_db, pitch_var)`,
`Audio.play_music(key, vol_db)`, `Audio.play_ambient(key)`. Keys are filenames
discovered at runtime in `assets/audio/`.

### 3.3 Scene management: worlds as swappable scripts

There are no per-level scene files. Each "world" is a `Node2D` script
(`overworld.gd`, `dungeon.gd`, `temple.gd`). `main.gd` swaps them:

```gdscript
# scripts/main.gd — the pattern; copy it for any new world type
func _load_dungeon(exit_pos: Vector2) -> void:
    if _world and is_instance_valid(_world):
        _world.queue_free()
    _world = Node2D.new()
    _world.set_script(load("res://scripts/dungeon.gd"))
    add_child(_world)
    _world.set_meta("overworld_exit_pos", exit_pos)
    Game.ui_open = false
```

Each world script, in `_ready()`, sets `Game.world = self`, builds its ground/props/
entities in code, and exposes a `player` var. Because `main` owns the HUD/dialogue,
those survive the swap. **To add a new world type, write a `Node2D` script and add a
twin `_load_X()` to `main.gd`.**

### 3.4 The enemy framework: one brain, many skins

`scripts/enemy.gd` defines `Enemy` — the shared "brain": a chase/attack finite-state
machine, knockback, damage handling, loot, XP, blood, and death. **Subclasses
override only visuals**, via these virtuals:

```gdscript
func _build_visual() -> void        # create the sprite, set stats/display_name
func _update_visual(moving: bool)   # animate/flip per facing
func _play_attack() -> void         # attack animation/sfx
func _on_death() -> void            # custom hook — fire quest progress, etc.
```

Two contracts every enemy honors (the base does this for you):
- It joins the group **`"enemies"`** and implements
  `take_damage(amount, knockback)`. The player's attack code hits everything in that
  group, so any new enemy "just works."
- `_die()` grants loot/XP **then** calls `_on_death()` — so overriding `_on_death`
  is the clean place to set a quest flag when a specific foe dies.

Two subclass styles:

```gdscript
# Humanoids: drive an LPC sheet by name (scripts/humanoid_enemy.gd)
class_name HumanoidEnemy extends Enemy
var char_name := "bandit"            # -> assets/chars/bandit_*.png via LPCFrames

# Monsters: frame-animate a battler Sprite2D (scripts/spider.gd, sweetie.gd)
class_name Spider extends Enemy
# loads assets/enemies/spider1..N.png, flips on facing, cycles frames
```

**Bosses** additionally `add_to_group("boss")`; the HUD reads the first boss's
`display_name`/`hp`/`max_hp` to draw a boss bar (`giant_spider.gd`, `necromancer.gd`).
Tint a sprite via the **child** sprite's `modulate` (the base `_tint()` only flashes
the node white/red); scale via `spr.scale`. `Dragon` (`dragon.gd`) is a standalone
`CharacterBody2D` boss with its own FSM — proof you can drop in a bespoke entity when
the shared brain doesn't fit.

### 3.5 Quests, flags, dialogue, HUD

**Quests** are entries in `Game.quests` with an integer stage. Convention:
`0 = unknown, 1 = active, 2 = ready-to-turn-in, 3 = complete`. Register the key in
**both** the declaration and `_reset_run()` in `game.gd`. Advancing a quest:

```gdscript
Game.set_quest("golden_claw", 1)     # emits quest_updated -> hud._refresh_quests()
```

> **Gotcha:** the HUD tracker only redraws on the `quest_updated` signal. If you make
> progress by setting a **flag** without changing the stage, emit it yourself:
> `Game.quest_updated.emit("my_quest")` — otherwise the checklist won't refresh.

**Flags** (`Game.flags`, free-form dict) gate one-time content — e.g. a unique enemy
that must never respawn:

```gdscript
if not Game.flags.get("beacon_taken", false):
    add_child(BeaconBandit.new())    # spawned once; the foe sets the flag on death
```

**Items** live in `Game.ITEMS`. Each entry: `name, type, value, icon, desc, rating`,
plus per-type fields (`dmg` for weapons; `heal/magicka/stamina` for potions/food).
`"no_sell": true` makes an item unsellable in the shop.

**Dialogue** is one call, with optional branching choices and BBCode:

```gdscript
Game.dialogue.start("Jarl Balgreuf", [
    "So. You're the [i]Dragonbornn™[/i].",
    "Slay the dragon and Beigeton will reward you.",
], [
    {"text": "I'll do it.", "action": func(): _accept_main()},
    {"text": "What's in it for me?", "action": Callable()},
])
```

**Toasts:** `Game.notify.emit("Quest complete!", Color(0.8, 1, 0.8))`. Full-screen FX
live on the HUD: `Game.hud.flash(color)` and `Game.hud.fade_black(mid_callable, hold)`.

**NPCs & interactables** (built in the world scripts):

```gdscript
# overworld.gd
_spawn_npc("camilla", "Camilla", pos, _talk_camilla, true)  # char_name, name, pos, cb, wander
# quest-aware dialogue lives in the _talk_* callback, branching on Game.quests/flags
```

Interactables are an `Interactable` node + an `Area2D` in group `"interactable"` with
an `on_interact` Callable (see `_build_cave_entrance`, `_build_shrine`).

### 3.6 Soft pause (don't skip this)

There is **no `get_tree().paused`**. The game uses a soft-pause flag,
**`Game.ui_open`**, set true while a dialogue/menu/pause screen is up. Every actor
that can affect gameplay checks it and freezes: the player, NPCs, the enemy brain
(`enemy.gd`), `dragon.gd`, the necromancer's casting, and `projectile.gd` all
early-return while `ui_open`.

> **Rule:** any new enemy, projectile, or timed attack **must** check `Game.ui_open`,
> or it will keep hitting the player through menus and the pause screen. (This was a
> real bug — the original enemies didn't check it.)

### 3.7 Save/load

State is serialized as JSON to `user://temu_save.json`: the relevant fields of the
`Game` dict (stats, inventory, equipped weapon, `quests`, `flags`, …). Because quests
and flags are plain dicts, **new quests/flags persist automatically** — no save-format
changes needed when you add content.

---

## 4. Part 2 — Spinning up a new RPG

The engine above is the reusable part. Here's the workflow to build a *new* game on it.

### Step 0 — Reskin, don't rewrite
Copy the project; keep `scripts/` (the engine) intact. Your new game is: new art, new
`ITEMS`, new worlds, new NPCs/quests/enemies. Strip the demo content (the existing
quests/NPCs) or evolve it.

### Step 1 — Art (three sources)

This project mixes three pipelines. **All three currently hardcode machine-specific
paths — read [§6](#6-known-limitations--making-this-a-real-template) before relying on
them.**

1. **Procedural pixel-art** — `tools/gen_art.py` draws tiles, props, enemy battler
   frames touch-ups, fx, item icons, and UI with PIL, output into
   `new-game-project/assets/{env,props,enemies,fx,items,ui}`. This is where the ground
   tiles, chests, torches, and 32×32 item icons come from.
2. **LPC humanoid sheets** — for NPCs and humanoid enemies. You hand-author a param
   recipe and composite layered LPC art into per-animation sheets:
   ```bash
   python tools/lpc_compose.py --params @tools/mage.json \
       --out new-game-project/assets/chars --name mage
   ```
   `scripts/lpc_frames.gd` slices `assets/chars/<name>_<anim>.png` into a runtime
   `SpriteFrames` at load. An NPC/`HumanoidEnemy` with `char_name = "mage"` then
   animates automatically. Recipes are JSON like `tools/villager.json`:
   `{"params": {"clothes": "Robe_blue", "hair": "Long_blonde", ...}}` — values are
   manifest item names (spaces→underscores) + `_<variant>`.
3. **Monster battler frames** — for non-humanoid enemies (dragon, wolf, spider,
   frost troll). Drop numbered frames into `assets/enemies/` and animate them
   Spider-style (`spider.gd`/`sweetie.gd`): a `Sprite2D` that flips on facing and
   cycles frames, tinted/scaled in code.

Audio is generated similarly by `tools/gen_audio.py` into `assets/audio/`.

**LPC gotchas worth knowing** (they cost real time):
- Many color-variant clothing layers (`Tunic`, `Longsleeve blouse`, `Sleeveless`,
  `Longsleeve laced`, dresses) ship **no idle** animation, so the composited
  `_idle.png` drops that layer and the character stands half-dressed. Fix: rebuild
  `<name>_idle.png` from the walk sheet's standing frame (column 0 of each of the four
  direction rows) with PIL.
- Plain `Longsleeve`/`Longsleeve 2` are **fixed-color** — a `_color` suffix silently
  no-ops (you get cream). Use the color-variant tops above for recolorable clothing.
- There is **no male floor-length robe**; fake one with `Longsleeve laced` + `Plain
  skirt` in a shared color (see `tools/mage.json`).
- Some hand-edited PNGs are structurally non-standard: PIL reads them but **Godot's
  importer rejects them** (`valid=false` in the `.import`), causing runtime
  `Failed loading resource`. Fix: re-save through PIL as a clean RGBA PNG
  (`Image.open(p).convert("RGBA").save(p, "PNG")`), delete the stale `.import` + the
  `.godot/imported/<name>.png-*` cache entries, then re-import.

### Step 2 — Author a world
Copy the overworld-builder pattern: a `Node2D` script that, in `_ready()`, sets
`Game.world = self`, enables `y_sort_enabled`, and calls `_build_*` helpers to lay
down ground/roads/props, spawn NPCs, and register enemies. Reuse the spawn/respawn
manager (`_register_spawn` / `_update_respawns`) for enemies that repopulate.

### Step 3 — Author an NPC + quest (end-to-end)
Generalized from the existing `golden_claw` / `night` quests:

1. **Register the quest key** in `game.gd` (declaration + `_reset_run`):
   `"rescue": 0`.
2. **Add any items** to `Game.ITEMS` (reward weapon, quest token, …).
3. **Spawn the NPC** in the world: `_spawn_npc("elder", "Elder", pos, _talk_elder, false)`.
4. **Write the `_talk_elder` callback**, branching on `Game.quests.get("rescue", 0)`:
   offer the quest (stage 0 → `set_quest("rescue", 1)`), give hints while active,
   and hand out the reward + `set_quest("rescue", 3)` on completion.
5. **Gate the objective** — e.g. a unique enemy whose `_on_death` sets a flag and
   calls a progress check; or an `Interactable` that advances the stage.
6. **Add a HUD tracker line** for the quest's stages in `hud.gd:_refresh_quests()`.
7. Save/load already persists it. Done.

### Step 4 — Author an enemy / boss
Pick `HumanoidEnemy` (LPC sprite by `char_name`) for people or `Enemy` + battler
frames for monsters. Set stats in `_build_visual`, add to `"boss"` if you want the HUD
bar, and override `_on_death` to fire quest hooks. **Make sure it respects
`Game.ui_open`** (the base brain does; custom `_physics_process` overrides must add the
check themselves).

### Step 5 — The AI-assisted loop
This codebase is designed to be extended by an AI coding assistant:
- Keep a **`CLAUDE.md`** at the repo root describing the engine contract (autoloads,
  the enemy/quest/dialogue patterns, the validation commands, the gotchas). It's the
  "read me first" the model follows.
- Work in a **plan → build → validate → commit** rhythm.
- Let the model author the *content* (dialogue text, quest branching, sprite param
  recipes, spawn placement) against the documented patterns — that's where it's fast
  and low-risk, because the engine constrains it.

---

## 5. Part 3 — Validate & ship

No committed test runner; validation is headless Godot + env-var-gated boot modes in
`main.gd`.

**Parse/import scan (primary check) — registers new `class_name`s, imports new assets:**
```bash
Godot_v4.6-stable_win64.exe --headless --path new-game-project --editor --quit-after 250
# expect no SCRIPT ERROR / Parse Error / "not found"
```

**Runtime smoke tests — boot straight into gameplay (env-var gates in `main.gd`):**
```bash
# TEMU_AUTOSTART=1  -> boot into the overworld
# TEMU_SHOT=1       -> dump screenshots (real renderer)
# TEMU_DUNGEON_FLOW_TEST / TEMU_DUNGEON_TEST / TEMU_VERIFY_DUNGEON / TEMU_RESPAWN / TEMU_TEST
TEMU_AUTOSTART=1 Godot_v4.6-stable_win64.exe --headless --path new-game-project --quit-after 150
# grep output for: SCRIPT ERROR / Failed loading resource / Nonexistent
```

**Force a reimport of changed assets:**
```bash
Godot_v4.6-stable_win64.exe --headless --path new-game-project --import
```

**Validation gotchas (so you don't chase ghosts):**
- `--check-only --script res://scripts/foo.gd` on a single file reports a **false**
  `Identifier not found: Game/Audio` — autoloads aren't loaded in isolation. Trust the
  full `--editor` import scan.
- `LSP: Failed to parse script: ...dungeon_flow_test.gd` is a flaky **editor-only**
  warning; it doesn't affect the game compile.
- Stray `icon.svg` / recent-projects errors come from Godot's global state, not this
  repo. A benign `N resources still in use at exit` can appear on headless quit.

**Ship:** `export_presets.cfg` includes a **Web** preset — export to HTML5 for sharing
in a browser.

---

## 6. Known limitations / making this a real template

The engine is reusable today. The **asset toolchain is not portable** as committed —
be honest about this if you hand the repo to someone else:

| Limitation | Where | Effect |
|---|---|---|
| Hardcoded absolute paths | `tools/lpc_compose.py` (`GEN_DIR`, `MANIFEST`), `tools/gen_art.py` (`ROOT`) | Scripts only run on the author's machine/paths |
| External generator dependency | `lpc_compose.py` reads a **Universal-LPC-Spritesheet-Character-Generator** checkout + an `asset-manifest.json` that are **not in this repo** | LPC sheets can't be regenerated from a clean clone |
| Engine binary not committed | `.gitignore` excludes `Godot_v4.6-stable_win64.exe` | Contributors must download Godot 4.6 themselves |
| Working docs untracked | `CLAUDE.md`, `potential_quests.md` are local-only | The engine contract doesn't ship with a clone unless committed |

To productionize this as a genuine reusable template:
1. **Parameterize the tool paths** — take `GEN_DIR`/`MANIFEST`/`ROOT` from environment
   variables or CLI args with sensible relative defaults, instead of hardcoding.
2. **Vendor or document the LPC generator** — either add it as a submodule/setup
   script, or document the exact checkout + how to point the tools at it.
3. **Commit `CLAUDE.md`** so the engine contract travels with the repo (the already-
   committed art means the *game* runs from a clone; this makes *extending* it work too).
4. Note that all committed `assets/` are the safety net: the game runs without any of
   the generators — you only need them to add/regenerate art.

---

## 7. Appendix — pitfalls & gotchas

- **Code-driven lifetimes:** worlds are `queue_free`d on swap; don't hold cross-world
  references. Persistent UI lives on `main`, not the world.
- **Soft pause:** every damage-capable actor must check `Game.ui_open` (see §3.6).
- **Quest tracker refresh:** flag-only progress needs a manual
  `Game.quest_updated.emit(id)` (see §3.5).
- **Enemy group/`take_damage` contract:** join `"enemies"` (and `"boss"` for the bar);
  implement `take_damage(amount, knockback)`. The base does both.
- **Sprite tint** goes on the child sprite's `modulate`, not the node (the base flashes
  the node on hit).
- **LPC idle** is missing on color-variant clothing → rebuild idle from the walk frame.
- **PNG import** can fail on non-standard PNGs → re-save clean via PIL + clear the
  `.godot/imported` cache.
- **Single-script `--check-only`** false-positives on autoload identifiers → use the
  full import scan.

---

## 8. Checklist — a new RPG starting point in an afternoon

1. Copy the project; download Godot 4.6 (binary is gitignored).
2. Confirm it runs: `TEMU_AUTOSTART=1 ... --headless --quit-after 150` → no errors.
3. **Engine stays.** In `game.gd`, replace `ITEMS` and the `quests` keys with yours.
4. Build **one world**: a `Node2D` script that sets `Game.world = self` and lays down
   ground + a player spawn. Add a `_load_*` for it in `main.gd` if it's not the start.
5. Add **one NPC** via `_spawn_npc` + a `_talk_*` callback.
6. Add **one quest**: register the key, branch the NPC dialogue by stage, set a reward,
   add a HUD tracker line.
7. Add **one enemy** (`HumanoidEnemy` or `Enemy` + frames); confirm it respects
   `Game.ui_open`.
8. Generate or drop in art (mind §6's caveats); for humanoids, write a
   `tools/<name>.json` recipe and run `lpc_compose.py`, then rebuild idle from walk.
9. Validate: `--editor --quit-after 250` (parse/import) + a `TEMU_AUTOSTART` boot.
10. Commit. Keep a `CLAUDE.md` so your assistant can keep extending it.

You now have a playable, saveable, extensible RPG loop — and an engine you can pour any
theme into.
