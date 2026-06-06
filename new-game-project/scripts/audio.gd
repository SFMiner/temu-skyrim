# === audio.gd ===
# Autoload audio manager: one music bus, one ambience bus, and a pool of SFX
# players so overlapping sounds (hits, coins) don't cut each other off.
extends Node

const DIR := "res://assets/audio/"
const SFX_VOICES := 10

var _music: AudioStreamPlayer
var _ambient: AudioStreamPlayer
var _sfx: Array[AudioStreamPlayer] = []
var _sfx_idx: int = 0
var _cache: Dictionary = {}
var _current_music: String = ""

func _ready() -> void:
	_music = AudioStreamPlayer.new()
	_music.volume_db = -8.0
	_music.bus = "Master"
	add_child(_music)
	_ambient = AudioStreamPlayer.new()
	_ambient.volume_db = -16.0
	add_child(_ambient)
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx.append(p)

func _load(name: String) -> AudioStream:
	if _cache.has(name):
		return _cache[name]
	var stream: AudioStream = null
	for ext: String in [".mp3", ".wav", ".ogg"]:
		var path: String = DIR + name + ext
		if ResourceLoader.exists(path):
			stream = load(path)
			break
	if stream:
		_cache[name] = stream
	return stream

func _set_loop(stream: AudioStream, loop: bool) -> void:
	if stream is AudioStreamMP3:
		stream.loop = loop
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
	elif stream is AudioStreamOggVorbis:
		stream.loop = loop

func play_music(name: String, vol_db: float = -8.0) -> void:
	if _current_music == name and _music.playing:
		return
	var s := _load(name)
	if not s:
		return
	_set_loop(s, true)
	_current_music = name
	_music.stream = s
	_music.volume_db = vol_db
	_music.play()

func stop_music() -> void:
	_current_music = ""
	_music.stop()

func play_ambient(name: String) -> void:
	var s := _load(name)
	if not s:
		return
	_set_loop(s, true)
	_ambient.stream = s
	_ambient.play()

func sfx(name: String, vol_db: float = 0.0, pitch_var: float = 0.0) -> void:
	var s := _load(name)
	if not s:
		return
	_set_loop(s, false)
	var p := _sfx[_sfx_idx]
	_sfx_idx = (_sfx_idx + 1) % SFX_VOICES
	p.stream = s
	p.volume_db = vol_db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()
