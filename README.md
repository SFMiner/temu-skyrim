# TEMU SKYRIM
## *The Elder Scrolls V: But It Shipped from a 1-Star Seller*

A one-shot Godot 4.6 demake celebrating cheap knockoff aesthetics. Explore a snowy town, slay a dragon, loot ancient dungeons filled with undead. All in code. All surprisingly fun.

![Godot 4.6](https://img.shields.io/badge/Godot-4.6-blue) ![GDScript](https://img.shields.io/badge/Language-GDScript-success) ![License](https://img.shields.io/badge/License-MIT-green)

---

## Quick Start

### Prerequisites
- **Godot 4.6 stable** - [Download here](https://godotengine.org/download/archive/4.6-stable/)

### How to Play
1. Clone this repo
2. Open `new-game-project` folder in Godot
3. Press **F5** to run (or click Play)
4. Enjoy the reviews

---

## Controls

| Key | Action |
|-----|--------|
| **WASD** | Move around |
| **E** | Talk to NPCs / Interact with objects |
| **J** | Melee attack |
| **K** | Cast magic (frost bolt) |
| **Q** | Shout (unlock after defeating dragon) |
| **Left Shift** | Sprint (costs stamina) |
| **I** | Inventory |
| **Esc** | Pause menu |
| **F5** | Save game |
| **F9** | Load game |

---

## What You Get

### 🏔️ The Overworld
- **Beigeton**: A snowy town with NPCs, shops, and a campfire
- **Wilderness**: Roaming wolves, scattered settlements
- **Bandit Camp**: East side, enemies that respawn when you leave
- **Dragon Lair**: North, where the final boss waits

### 🐉 The Quest
1. Talk to the **Jarl** in the keep → Accept main quest
2. Head north, fight the **dragon** (yes, it's actually a boss)
3. Slay it, get the **shout**, unlock magic
4. Profit (150 gold + legendary sword)

### 🏺 The Dungeon
- Ancient stone catacombs filled with **draugr** (undead warriors)
- **Interactive objects**: Loot chests, read ancient texts
- **Respawning enemies**: Kill them, they come back after 20 seconds if you leave
- **Exit portal**: Return to the overworld whenever you want
- Built entirely in code, ready to duplicate and customize

### 🎮 Systems That Actually Work
- **Combat**: Melee, magic, shouts with screen shake
- **Skills**: One-handed, destruction magic, blocking, speech (they level up as you use them)
- **Inventory**: Pick up items, equip weapons, sell to merchants
- **Dialogue**: NPCs with quest hooks
- **Respawning**: Skyrim-style enemy respawn when you're far enough away
- **Save/Load**: Cloud-backed (Temu cloud™)

---

## Project Structure

```
new-game-project/
├── scripts/                 # All game logic (GDScript)
│   ├── main.gd             # Game flow & scene transitions
│   ├── player.gd           # Player movement, combat, spells
│   ├── overworld.gd        # World building & NPC placement
│   ├── dungeon.gd          # Dungeon scene with respawn system
│   ├── enemy.gd            # Base enemy AI
│   ├── humanoid_enemy.gd   # Enemy variant (bandits, draugr)
│   ├── npc.gd              # NPCs with dialogue
│   ├── game.gd             # Autoload: player state, quests, items
│   ├── audio.gd            # Autoload: music & SFX
│   └── ...                 # UI, projectiles, effects
├── assets/
│   ├── chars/              # Character sprites (LPC format)
│   ├── props/              # World objects (cave, chest, signpost)
│   ├── fx/                 # Visual effects (shout, blood, glow)
│   ├── ui/                 # UI graphics
│   ├── env/                # Tiles & terrain
│   ├── items/              # Item icons
│   └── audio/              # Music & ambient sounds
└── project.godot           # Godot project config

tools/
├── gen_art.py              # Procedural pixel art generator
├── gen_audio.py            # Procedural SFX synthesizer
└── lpc_compose.py          # Composites character sprites
```

---

## For People Who Want to Tinker

### Add a New Dungeon
```gdscript
# Copy scripts/dungeon.gd to dungeon_myname.gd
# Change these lines:
const PLAYER_SPAWN := Vector2(800, 1000)  # Where player starts
const EXIT := Vector2(800, 100)            # Where exit portal goes

func _spawn_draugr() -> void:
    # Change spawn positions and enemy types here
    _register_spawn(Vector2(600, 500), _make_draugr)  # Add more of these
```

Then in `main.gd`, change the load function to use your new dungeon script.

### Add a New Enemy Type
```gdscript
# In dungeon.gd, add a new make function:
func _make_skeleton() -> Node:
    var s := HumanoidEnemy.new()
    s.char_name = "skeleton"     # Needs sprite at assets/chars/skeleton_*.png
    s.max_hp = 45.0
    s.damage = 10.0
    s.speed = 120.0
    return s

# Then use it in _spawn_draugr():
_register_spawn(Vector2(600, 500), _make_skeleton)
```

---

## Tech Behind the Scenes

- **Godot 4.6**: Pure GDScript, no scene files (everything built in code)
- **LPC Sprites**: Character sprites are procedurally generated and composited
- **Procedural Art**: Game tiles, effects, and props generated via Python/PIL
- **Procedural Audio**: SFX synthesized with numpy (shout, magic, dragon roar)
- **Finite State Machines**: Enemy AI using simple IDLE → CHASE → ATTACK states
- **Signal-Based State**: Game autoload holds all persistent state

---

## Features You'll Notice

✨ **Top-Down Pixel Art** - Everything is procedurally generated or hand-drawn in code  
✨ **NPCs with Dialogue** - Talk to townspeople, accept quests  
✨ **Respawning Enemies** - Kill bandits, leave the area, they're back when you return  
✨ **Skill Progression** - Your skills level up as you use them  
✨ **Boss Fight** - Actual dragon with multi-phase mechanics  
✨ **Loot System** - Enemies drop items, chests have treasure  
✨ **Atmospheric Sound** - Ambient dungeon audio, battle music, SFX  
✨ **Save/Load** - Keep your progress (locally, no actual cloud)  

---

## Known Quirks (Features)

- 🌟 Items have Temu ratings (4.2 stars, "slight blood as-is")
- 🌟 NPCs reference the product review system constantly
- 🌟 Dragon is literally named "DraGON™"
- 🌟 Sweetroll is a real quest item (Ice Creams meme)
- 🌟 Every NPC has a typo or absurd dialogue
- 🌟 Controls are named things like "FUS RO DAH" (the shout)

This is intentional. It's a parody. Have fun with it.

---

## How This Was Built

This is a demonstration of **Claude Opus 4.8 agentic capability** for rapid game prototyping. Built in one continuous session using:

- **Code generation** for all GDScript
- **Procedural generation** for art and audio
- **AI-generated sprites** from natural language descriptions
- **Full integration** from concept to playable game

It's a real, playable game—not a tech demo. All systems work. All code is clean. All art was generated.

---

## Credits & Attribution

**Engine & Framework:**
- [Godot 4.6](https://godotengine.org/) - Open source game engine (MIT License)

**Art Assets:**
- Character sprites generated using [Universal LPC Spritesheet Character Generator](https://sanderfrenken.github.io/Universal-LPC-Spritesheet-Character-Generator/) by Sander Frenken
- Sprites composed from the [Liberated Pixel Cup](https://lpc.opengameart.org/) community artwork
  - Built on work by many artists including: Lanea Zimmerman, Charles Sannyong Xie, Jordan Irwin, Sharm, and the LPC community
  - Licensed under CC0, GPL 2.0, and GPL 3.0 (see individual asset licenses)
- Procedural pixel art generation (tiles, props, effects) via custom Python scripts
- Procedural UI assets

**Audio:**
- SFX synthesized with numpy
- Ambient dungeon audio from freesound.org community
- Music composed with procedural synthesis

**Special Thanks:**
- The [Liberated Pixel Cup](https://lpc.opengameart.org/) community for the extensive sprite library
- OpenGameArt.org for community resources
- The Godot community and documentation

**Game Concept:**
- Inspired by the "Temu version of X" internet meme
- Built by Claude Opus 4.8 (Anthropic) as a demonstration of agentic game development capabilities

---

## License

MIT License - do whatever you want with it. Make a sequel. Make it terrible. Make it yours.

See LICENSE file for details.

---

## Play It, Mod It, Have Fun

This is a hobby project meant to be enjoyed and hacked on. Clone it, add a dungeon named after your cat, change the dragon to a giant chicken. The code is yours.

Questions? Open an issue. Found a bug? Fix it and send a PR. Want to add something cool? Go for it.

**Now go forth and slay that dragon. 🐉⚔️**

---

*"Temu Skyrim: Because sometimes the best adventures come from the cheapest sellers."*
