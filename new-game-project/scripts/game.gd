# === game.gd ===
# Autoload singleton holding all player state, item/quest data, and save/load.
# Central store so HUD, menus, player, and NPCs read/write one source of truth.
extends Node

# === SIGNALS ===
signal stats_changed()
signal gold_changed(amount: int)
signal leveled_up(new_level: int)
signal notify(text: String, color: Color)
signal inventory_changed()
signal quest_updated(quest_id: String)
signal shout_unlocked()

# === PLAYER STATS ===
var max_health: float = 100.0
var health: float = 100.0
var max_magicka: float = 60.0
var magicka: float = 60.0
var max_stamina: float = 100.0
var stamina: float = 100.0
var level: int = 1
var xp: int = 0
var xp_next: int = 100
var gold: int = 25
var skills: Dictionary = {"one_handed": 15, "destruction": 12, "block": 10, "speech": 10}
var known_shout: bool = false  # FUS RO DAH unlocked after first dragon

# === INVENTORY ===
var inventory: Array = []  # each: {"id": String, "count": int}
var equipped_weapon: String = "iron_sword"

# === QUESTS / FLAGS ===
# stage values: 0=unknown, 1=active, 2=ready-to-turn-in, 3=complete
var quests: Dictionary = {"main": 0, "sweetroll": 0, "freetrial": 0}
var flags: Dictionary = {}
var dragons_slain: int = 0

# === RUNTIME REFERENCES (set by main.gd) ===
var dialogue: Node = null
var hud: Node = null
var shop: Node = null
var world: Node = null
var ui_open: bool = false  # true while a menu/dialogue blocks gameplay input

# === ITEM DATABASE (Temu listings) ===
const ITEMS := {
	"iron_sword": {"name": "Iron Sword (Pack of 1)", "type": "weapon", "dmg": 12, "value": 25,
		"icon": "sword", "rating": 4.2, "desc": "Ships from overseas warehouse. Mild rusting is normal."},
	"steel_sword": {"name": "Steel Sword PRO MAX", "type": "weapon", "dmg": 19, "value": 90,
		"icon": "sword", "rating": 4.5, "desc": "Now 30% more pointy. Battery not included."},
	"bandit_axe": {"name": "Used Bandit Axe", "type": "weapon", "dmg": 15, "value": 40,
		"icon": "axe", "rating": 3.1, "desc": "Pre-owned. Slight blood. As-is, no returns."},
	"draugr_dagger": {"name": "Ancient Draugr Dagger", "type": "weapon", "dmg": 8, "value": 50,
		"icon": "sword", "rating": 2.8, "desc": "Cursed blade from the tombs. Handle with care (literally)."},
	"dragonbone_sword": {"name": "DragonBone Sword (LIMITED)", "type": "weapon", "dmg": 34, "value": 400,
		"icon": "sword", "rating": 5.0, "desc": "Forged from a 1-star seller. Absorbs the spirit of refunds."},
	"health_potion": {"name": "Healthe Potion", "type": "potion", "heal": 55, "value": 15,
		"icon": "potion_health", "rating": 4.0, "desc": "May contain trace amounts of health. Drink responsibly."},
	"magicka_potion": {"name": "Magickaa Elixir", "type": "potion", "magicka": 50, "value": 18,
		"icon": "potion_magicka", "rating": 3.9, "desc": "Tastes of blueberry and regret."},
	"stamina_potion": {"name": "Energie Tonic", "type": "potion", "stamina": 60, "value": 12,
		"icon": "potion_stamina", "rating": 4.1, "desc": "Legally distinct from a popular energy drink."},
	"sweetroll": {"name": "Sweetroll", "type": "food", "heal": 12, "value": 5,
		"icon": "sweetroll", "rating": 4.8, "desc": "Someone keeps stealing these. Watch your knees."},
	"dragon_claw": {"name": "Golden Dragon Claw", "type": "misc", "value": 150,
		"icon": "claw", "rating": 4.7, "desc": "The puzzle solution is on the bottom. Of course it is."},
	"ancient_tome": {"name": "Word Wall Instructions (PDF)", "type": "misc", "value": 30,
		"icon": "book", "rating": 2.2, "desc": "Translated by AI. The Thu'um may sound slightly off."},
	"iron_helmet": {"name": "Iron Helmet (One Size)", "type": "misc", "value": 35,
		"icon": "helm", "rating": 3.7, "desc": "One size fits none. May reduce peripheral vision to zero."},
}

func _ready() -> void:
	_reset_run()

func _reset_run() -> void:
	max_health = 100.0; health = max_health
	max_magicka = 60.0; magicka = max_magicka
	max_stamina = 100.0; stamina = max_stamina
	level = 1; xp = 0; xp_next = 100; gold = 25
	skills = {"one_handed": 15, "destruction": 12, "block": 10, "speech": 10}
	known_shout = false
	inventory = []
	equipped_weapon = "iron_sword"
	quests = {"main": 0, "sweetroll": 0, "freetrial": 0}
	flags = {}
	dragons_slain = 0
	add_item("iron_sword", 1)
	add_item("health_potion", 3)
	add_item("sweetroll", 1)

# === ITEM HELPERS ===
func item_def(id: String) -> Dictionary:
	return ITEMS.get(id, {"name": id, "type": "misc", "value": 0, "icon": "book", "rating": 1.0, "desc": "???"})

func add_item(id: String, count: int = 1) -> void:
	for e in inventory:
		if e.id == id:
			e.count += count
			inventory_changed.emit()
			return
	inventory.append({"id": id, "count": count})
	inventory_changed.emit()

func remove_item(id: String, count: int = 1) -> bool:
	for i in inventory.size():
		if inventory[i].id == id:
			inventory[i].count -= count
			if inventory[i].count <= 0:
				inventory.remove_at(i)
			inventory_changed.emit()
			return true
	return false

func count_of(id: String) -> int:
	for e in inventory:
		if e.id == id:
			return e.count
	return 0

func weapon_damage() -> float:
	var base: float = item_def(equipped_weapon).get("dmg", 8)
	# one-handed skill scales damage — Temu "skill tree"
	return base * (1.0 + skills.get("one_handed", 0) * 0.02)

# === ECONOMY ===
func add_gold(n: int) -> void:
	gold += n
	gold_changed.emit(gold)
	if n > 0:
		Audio.sfx("coin")

func spend_gold(n: int) -> bool:
	if gold >= n:
		gold -= n
		gold_changed.emit(gold)
		return true
	return false

# === PROGRESSION ===
func add_xp(n: int) -> void:
	xp += n
	while xp >= xp_next:
		xp -= xp_next
		_level_up()
	stats_changed.emit()

func _level_up() -> void:
	level += 1
	xp_next = int(xp_next * 1.4) + 25
	max_health += 15; max_magicka += 8; max_stamina += 8
	health = max_health; magicka = max_magicka; stamina = max_stamina
	Audio.sfx("levelup")
	leveled_up.emit(level)
	notify.emit("LEVEL UP! You are now level %d (Temu Plus member)" % level, Color(1, 0.84, 0.3))

func skill_up(skill: String, amount: int = 1) -> void:
	if not skills.has(skill):
		skills[skill] = 0
	skills[skill] += amount
	add_xp(8 * amount)
	var pretty := {"one_handed": "One-Handed (Knockoff)", "destruction": "Destruction (Generic Brand)",
		"block": "Block (Some Assembly Required)", "speech": "Speech (Auto-Translated)"}
	notify.emit("Skill increased: %s" % pretty.get(skill, skill), Color(0.8, 0.9, 1.0))

func unlock_shout() -> void:
	if known_shout:
		return
	known_shout = true
	shout_unlocked.emit()
	notify.emit("SHOUT UNLOCKED: FUS RO DAH — Free shipping on all shouts!", Color(0.81, 0.91, 1.0))

func set_quest(id: String, stage: int) -> void:
	quests[id] = stage
	quest_updated.emit(id)

# === SAVE / LOAD ===
const SAVE_PATH := "user://temu_save.json"

func save_game() -> void:
	var data := {
		"max_health": max_health, "health": health, "max_magicka": max_magicka, "magicka": magicka,
		"max_stamina": max_stamina, "stamina": stamina, "level": level, "xp": xp, "xp_next": xp_next,
		"gold": gold, "skills": skills, "known_shout": known_shout, "inventory": inventory,
		"equipped_weapon": equipped_weapon, "quests": quests, "flags": flags, "dragons_slain": dragons_slain,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()
		notify.emit("Saved to cloud (Temu Basic tier)", Color(0.7, 1.0, 0.7))

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return false
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		f.close(); return false
	f.close()
	var d: Dictionary = json.data
	max_health = d.get("max_health", 100.0); health = d.get("health", max_health)
	max_magicka = d.get("max_magicka", 60.0); magicka = d.get("magicka", max_magicka)
	max_stamina = d.get("max_stamina", 100.0); stamina = d.get("stamina", max_stamina)
	level = int(d.get("level", 1)); xp = int(d.get("xp", 0)); xp_next = int(d.get("xp_next", 100))
	gold = int(d.get("gold", 25)); skills = d.get("skills", skills)
	known_shout = d.get("known_shout", false)
	inventory = d.get("inventory", [])
	equipped_weapon = d.get("equipped_weapon", "iron_sword")
	quests = d.get("quests", quests); flags = d.get("flags", {})
	dragons_slain = int(d.get("dragons_slain", 0))
	stats_changed.emit(); inventory_changed.emit(); gold_changed.emit(gold)
	return true
