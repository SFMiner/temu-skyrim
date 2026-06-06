# TEMU SKYRIM 🐉
### *The Elder Scrolls V, but it shipped from a 1-star seller. Free shipping on all shouts.*

A top-down 2D action-RPG demake of Skyrim, built in **Godot 4.6** as a one-shot by
Claude Opus 4.8. Every character sprite was generated from **natural-language
descriptions** via the LPC AI wrapper; everything else (tiles, props, the dragon,
effects, UI, SFX) is procedurally generated pixel art / synthesized audio.

## ▶ How to run
1. Launch `Godot_v4.6-stable_win64.exe`.
2. Import / open the project in `new-game-project/`.
3. Press **Play** (F5 in the editor), or run:
   `Godot_v4.6-stable_win64.exe --path new-game-project`

## 🎮 Controls
| Action | Key |
|---|---|
| Move | WASD / Arrows |
| Sprint | Shift (uses Stamina) |
| Attack (melee) | J / Left-click |
| Magic (Frostbolt) | K / Right-click (uses Magicka) |
| **Shout — FUS RO DAH** | Q (unlocked after slaying the dragon) |
| Talk / Interact | E / Space |
| Inventory | I |
| Pause | Esc |
| Save / Load | F5 / F9 |

## ✨ What's in it (the spirit of Skyrim, on a budget)
- **The Helgen intro**, Temu-ified: *"Hey. You. You're finally awake..."*
- **The town of Beigeton** — Jarl Balgreuf, a guard, Belethor the reseller (shop),
  and wandering villagers, all with Temu-flavored dialogue.
- **The Thu'um**: `FUS RO DAH` force-push shout with cooldown + screen shake.
- **A dragon boss** (DraGON™, Free Returns) that hovers, breathes fire, swoops —
  and on death plays the **soul-absorption** that unlocks your shout.
- **Quests**: *DraGON™ Returns* (main), *The Sweetroll Heist* (the guard who took
  an arrow to the knee), plus Belethor's "free sample."
- **Wolves & a bandit camp**, melee + magic combat, knockback, blood/hit FX.
- **Leveling & skills** (One-Handed (Knockoff), Destruction (Generic Brand)…),
  XP, gold, and an **inventory/shop** of cheap listings with ⭐ ratings.
- Snowfall, fantasy music, elk/raven/wind ambience, synthesized SFX.

## 🛠 How the art pipeline works
- `tools/lpc_compose.py` — turns the AI wrapper's hash-params into combined,
  animated LPC spritesheets (`assets/chars/<name>_<anim>.png`).
- `tools/gen_art.py` — procedural Nordic pixel-art (tiles, props, dragon, FX, UI).
- `tools/gen_audio.py` — numpy-synthesized SFX (shout, magic, level-up, roar…).
- `scripts/lpc_frames.gd` — slices those sheets into a `SpriteFrames` at runtime.

The game is **code-driven**: a tiny `Main.tscn` boots `scripts/main.gd`, which
builds every screen, the world, and all entities in GDScript (no fragile
hand-authored scene files).

*Built in one shot. Reviews were mixed. 4.2 ⭐*
