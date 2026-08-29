extends Node
## AudioManager — pooled SFX playback & 10-level procedural synthwave music engine.
## Generates 16-bit PCM AudioStreamWAV streams in GDScript.

var music_volume: float = 0.8
var sfx_volume: float = 1.0
var music_muted: bool = false
var sfx_muted: bool = false

## Music uses two alternating players instead of reassigning .stream on a
## single one. AudioStreamPlayer.stop() only queues a command for the audio
## mixer thread — it does not synchronously guarantee that thread has
## released the old buffer before the next line runs. Reassigning .stream
## on the player that may still be mid-callback on the native audio thread
## is a use-after-free race (matches an observed SIGSEGV inside
## AudioTrackCallback::onMoreData that persisted even after adding .stop()
## calls). Swapping to the OTHER player — which has been idle since the
## previous track change — sidesteps the race entirely.
var _music_player_a: AudioStreamPlayer
var _music_player_b: AudioStreamPlayer
var _active_music_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
const _POOL_SIZE: int = 16

# Procedural SFX streams
var _sfx_charge: AudioStreamWAV
var _sfx_charge_red: AudioStreamWAV
var _sfx_charge_yellow: AudioStreamWAV
var _sfx_charge_green: AudioStreamWAV
var _sfx_charge_max: AudioStreamWAV
var _sfx_full_charge_ready: AudioStreamWAV

var _sfx_pickup: AudioStreamWAV
var _sfx_explosion: AudioStreamWAV
var _sfx_hit: AudioStreamWAV
var _sfx_boss: AudioStreamWAV

# Level music tracks & Boss music tracks
var _level_tracks: Dictionary = {}
var _boss_music_tracks: Dictionary = {}
var _victory_music_track: AudioStreamWAV = null
var _menu_music_track: AudioStreamWAV = null
var _current_level_music: int = -1
var _current_boss_music_index: int = -1
var _is_boss_music: bool = false

## 10 Level Full Scores (matching LevelGenerator biomes & moods)
const LEVEL_THEMES: Array[Dictionary] = [
	# Level 1: Blue Cave — Subterranean Echoes (Cm - Ab - Eb - Bb)
	{
		"title": "Subterranean Echoes",
		"chord_roots": [130.81, 103.83, 155.56, 116.54],
		"chord_thirds": [1.2, 1.25, 1.25, 1.25],
		"chord_fifths": [1.5, 1.5, 1.5, 1.5],
		"chord_dur": 1.0,
		"melody": [1.5, 1.333, 1.2, 1.0, 1.2, 1.333, 1.5, 1.778],
		"melody_step": 0.5,
		"arp": [1.0, 1.2, 1.5, 1.778],
		"arp_step": 0.125,
		"bass_style": "pulse",
		"drum_style": "ambient_pulse",
		"brightness": 0.3,
		"tremolo": 0.1,
		"voices": 1,
		"duration": 4.0
	},
	# Level 2: Red Cavern — Magma Veins (Dm - Bb - Gm - A)
	{
		"title": "Magma Veins",
		"chord_roots": [146.83, 116.54, 98.00, 110.00],
		"chord_thirds": [1.2, 1.25, 1.2, 1.25],
		"chord_fifths": [1.5, 1.5, 1.5, 1.5],
		"chord_dur": 1.0,
		"melody": [1.0, 1.2, 1.5, 1.414, 1.333, 1.2, 1.0, 1.5],
		"melody_step": 0.5,
		"arp": [1.0, 1.2, 1.5, 1.2],
		"arp_step": 0.125,
		"bass_style": "wobble",
		"drum_style": "four_on_floor",
		"brightness": 0.4,
		"tremolo": 0.0,
		"voices": 1,
		"duration": 4.0
	},
	# Level 3: Green Base — Biolab Infiltration (Em - C - G - D)
	{
		"title": "Biolab Infiltration",
		"chord_roots": [164.81, 130.81, 196.00, 146.83],
		"chord_thirds": [1.2, 1.25, 1.25, 1.25],
		"chord_fifths": [1.5, 1.5, 1.5, 1.5],
		"chord_dur": 1.0,
		"melody": [1.2, 1.0, 1.5, 1.333, 1.2, 1.5, 1.778, 2.0],
		"melody_step": 0.5,
		"arp": [1.0, 1.25, 1.5, 1.25],
		"arp_step": 0.125,
		"bass_style": "walk",
		"drum_style": "breakbeat",
		"brightness": 0.35,
		"tremolo": 0.15,
		"voices": 1,
		"duration": 4.0
	},
	# Level 4: Brown Fortress — Iron Citadel (Fm - Db - Bbm - C)
	{
		"title": "Iron Citadel",
		"chord_roots": [174.61, 138.59, 116.54, 130.81],
		"chord_thirds": [1.2, 1.25, 1.2, 1.25],
		"chord_fifths": [1.5, 1.5, 1.5, 1.5],
		"chord_dur": 1.0,
		"melody": [1.0, 1.0, 1.2, 1.333, 1.5, 1.5, 1.414, 1.2],
		"melody_step": 0.5,
		"arp": [1.0, 1.2, 1.5, 1.0],
		"arp_step": 0.125,
		"bass_style": "march",
		"drum_style": "industrial_march",
		"brightness": 0.45,
		"tremolo": 0.0,
		"voices": 1,
		"duration": 4.0
	},
	# Level 5: Purple Alien — Xenomorphic Hive (Gm - Eb - F - Dm)
	{
		"title": "Xenomorphic Hive",
		"chord_roots": [196.00, 155.56, 174.61, 146.83],
		"chord_thirds": [1.2, 1.25, 1.25, 1.2],
		"chord_fifths": [1.5, 1.5, 1.5, 1.5],
		"chord_dur": 1.0,
		"melody": [1.0, 1.06, 1.2, 1.414, 1.26, 1.122, 1.0, 0.944],
		"melody_step": 0.5,
		"arp": [1.0, 1.122, 1.26, 1.414],
		"arp_step": 0.125,
		"bass_style": "drone",
		"drum_style": "tribal_poly",
		"brightness": 0.25,
		"tremolo": 0.35,
		"voices": 1,
		"duration": 4.0
	},
	# Level 6: Teal Station — Cyber Orbital (Am - F - Dm - Em)
	{
		"title": "Cyber Orbital",
		"chord_roots": [220.00, 174.61, 146.83, 164.81],
		"chord_thirds": [1.2, 1.25, 1.2, 1.2],
		"chord_fifths": [1.5, 1.5, 1.5, 1.5],
		"chord_dur": 1.0,
		"melody": [1.5, 1.778, 2.0, 1.778, 1.5, 1.333, 1.2, 1.333],
		"melody_step": 0.5,
		"arp": [1.0, 1.2, 1.5, 2.0, 1.5, 1.2, 1.0, 0.75],
		"arp_step": 0.0625,
		"bass_style": "pulse",
		"drum_style": "speed_synth",
		"brightness": 0.5,
		"tremolo": 0.0,
		"voices": 1,
		"duration": 4.0
	},
	# Level 7: Crimson Core — Thermal Reactor (Bm - G - Em - F#)
	{
		"title": "Thermal Reactor",
		"chord_roots": [246.94, 196.00, 164.81, 185.00],
		"chord_thirds": [1.2, 1.25, 1.2, 1.25],
		"chord_fifths": [1.5, 1.5, 1.5, 1.5],
		"chord_dur": 1.0,
		"melody": [1.0, 1.2, 1.333, 1.5, 1.8, 1.5, 1.333, 1.2],
		"melody_step": 0.5,
		"arp": [1.0, 1.333, 1.5, 1.8],
		"arp_step": 0.125,
		"bass_style": "stab",
		"drum_style": "four_on_floor",
		"brightness": 0.5,
		"tremolo": 0.0,
		"voices": 1,
		"duration": 4.0
	},
	# Level 8: Gold Final — Ascent to Glory (C - G - Am - F)
	{
		"title": "Ascent to Glory",
		"chord_roots": [261.63, 196.00, 220.00, 174.61],
		"chord_thirds": [1.25, 1.25, 1.2, 1.25],
		"chord_fifths": [1.5, 1.5, 1.5, 1.5],
		"chord_dur": 1.0,
		"melody": [1.0, 1.25, 1.5, 2.0, 1.875, 1.667, 1.5, 1.25],
		"melody_step": 0.5,
		"arp": [1.0, 1.25, 1.5, 1.875, 2.0, 1.5],
		"arp_step": 0.125,
		"bass_style": "pulse",
		"drum_style": "four_on_floor",
		"brightness": 0.55,
		"tremolo": 0.0,
		"voices": 2,
		"duration": 4.0
	},
	# Level 9: Cosmic Void — Event Horizon (Dm - Bb - C - Gm)
	{
		"title": "Event Horizon",
		"chord_roots": [146.83, 116.54, 130.81, 98.00],
		"chord_thirds": [1.2, 1.25, 1.25, 1.2],
		"chord_fifths": [1.5, 1.5, 1.5, 1.5],
		"chord_dur": 1.0,
		"melody": [1.0, 1.122, 1.333, 1.2, 1.5, 1.414, 1.2, 1.0],
		"melody_step": 0.5,
		"arp": [1.0, 1.2, 1.5, 1.778],
		"arp_step": 0.25,
		"bass_style": "drone",
		"drum_style": "ambient_pulse",
		"brightness": 0.15,
		"tremolo": 0.25,
		"voices": 2,
		"duration": 4.0
	},
	# Level 10: Solar Core — Supernova Climax (Em - G - D - Bm)
	{
		"title": "Supernova Climax",
		"chord_roots": [164.81, 196.00, 146.83, 123.47],
		"chord_thirds": [1.2, 1.25, 1.25, 1.2],
		"chord_fifths": [1.5, 1.5, 1.5, 1.5],
		"chord_dur": 1.0,
		"melody": [1.5, 1.875, 2.0, 2.25, 2.0, 1.875, 1.5, 1.25],
		"melody_step": 0.5,
		"arp": [1.0, 1.25, 1.5, 2.0, 2.5, 2.0],
		"arp_step": 0.0833,
		"bass_style": "stab",
		"drum_style": "speed_synth",
		"brightness": 0.6,
		"tremolo": 0.0,
		"voices": 2,
		"duration": 4.0
	}
]

## 10 Boss Full Scores (matching boss identity & combat mechanics)
const BOSS_THEMES: Array[Dictionary] = [
	# Boss 1: Iron Claw — Titan Pincer
	{
		"title": "Titan Pincer",
		"chord_roots": [110.00, 146.83, 82.41, 138.59],
		"chord_thirds": [1.2, 1.25, 1.2, 1.2],
		"chord_fifths": [1.5, 1.5, 1.5, 1.414],
		"chord_dur": 1.0,
		"melody": [1.0, 1.2, 1.0, 1.414, 1.2, 1.0, 0.9, 1.0],
		"melody_step": 0.5,
		"arp": [1.0, 1.0, 1.2, 1.0],
		"arp_step": 0.125,
		"bass_style": "stomp",
		"drum_style": "industrial_march",
		"brightness": 0.35,
		"tremolo": 0.0,
		"voices": 1,
		"duration": 4.0
	},
	# Boss 2: Hydra — Serpentine Triad
	{
		"title": "Serpentine Triad",
		"chord_roots": [103.83, 164.81, 92.50, 155.56],
		"chord_thirds": [1.2, 1.25, 1.2, 1.2],
		"chord_fifths": [1.5, 1.5, 1.5, 1.5],
		"chord_dur": 1.0,
		"melody": [1.0, 1.122, 1.26, 1.414, 1.26, 1.122, 1.0, 1.26],
		"melody_step": 0.5,
		"arp": [1.0, 1.122, 1.26, 1.414],
		"arp_step": 0.125,
		"bass_style": "slither_poly",
		"drum_style": "tribal_poly",
		"brightness": 0.4,
		"tremolo": 0.3,
		"voices": 3,
		"duration": 4.0
	},
	# Boss 3: Behemoth — Armored Juggernaut
	{
		"title": "Armored Juggernaut",
		"chord_roots": [65.41, 58.27, 51.91, 49.00],
		"chord_thirds": [1.2, 1.2, 1.25, 1.25],
		"chord_fifths": [1.5, 1.5, 1.5, 1.5],
		"chord_dur": 1.0,
		"melody": [1.0, 1.0, 1.2, 1.0, 1.5, 1.414, 1.2, 1.0],
		"melody_step": 0.5,
		"arp": [1.0, 1.0, 1.2, 1.5],
		"arp_step": 0.25,
		"bass_style": "stomp",
		"drum_style": "industrial_march",
		"brightness": 0.2,
		"tremolo": 0.0,
		"voices": 1,
		"duration": 4.0
	},
	# Boss 4: Sentinel — Orbital Aegis
	{
		"title": "Orbital Aegis",
		"chord_roots": [155.56, 123.47, 138.59, 116.54],
		"chord_thirds": [1.2, 1.25, 1.2, 1.2],
		"chord_fifths": [1.5, 1.5, 1.5, 1.5],
		"chord_dur": 1.0,
		"melody": [1.333, 1.5, 1.778, 2.0, 1.778, 1.5, 1.333, 1.0],
		"melody_step": 0.5,
		"arp": [1.0, 1.333, 1.5, 2.0],
		"arp_step": 0.125,
		"bass_style": "stab",
		"drum_style": "speed_synth",
		"brightness": 0.5,
		"tremolo": 0.0,
		"voices": 1,
		"duration": 4.0
	},
	# Boss 5: Swarm Queen — Hive Carapace
	{
		"title": "Hive Carapace",
		"chord_roots": [220.00, 185.00, 196.00, 164.81],
		"chord_thirds": [1.2, 1.189, 1.2, 1.189],
		"chord_fifths": [1.5, 1.414, 1.5, 1.414],
		"chord_dur": 1.0,
		"melody": [1.0, 1.06, 1.12, 1.06, 1.2, 1.12, 1.06, 1.0],
		"melody_step": 0.5,
		"arp": [1.0, 1.06, 1.12, 1.06],
		"arp_step": 0.0625,
		"bass_style": "wobble",
		"drum_style": "breakbeat",
		"brightness": 0.45,
		"tremolo": 0.45,
		"voices": 2,
		"duration": 4.0
	},
	# Boss 6: Photon Core — Particle Overload
	{
		"title": "Particle Overload",
		"chord_roots": [164.81, 138.59, 110.00, 123.47],
		"chord_thirds": [1.25, 1.2, 1.25, 1.25],
		"chord_fifths": [1.5, 1.5, 1.5, 1.5],
		"chord_dur": 1.0,
		"melody": [1.5, 2.0, 2.5, 3.0, 2.5, 2.0, 1.5, 1.25],
		"melody_step": 0.5,
		"arp": [1.0, 1.25, 1.5, 2.0, 2.5, 2.0],
		"arp_step": 0.0625,
		"bass_style": "pulse",
		"drum_style": "speed_synth",
		"brightness": 0.65,
		"tremolo": 0.15,
		"voices": 1,
		"duration": 4.0
	},
	# Boss 7: Abyss Gate — Void Rift
	{
		"title": "Void Rift",
		"chord_roots": [146.83, 155.56, 138.59, 116.54],
		"chord_thirds": [1.2, 1.189, 1.2, 1.189],
		"chord_fifths": [1.5, 1.414, 1.5, 1.414],
		"chord_dur": 1.0,
		"melody": [1.0, 0.944, 1.0, 1.189, 1.0, 0.891, 0.944, 1.0],
		"melody_step": 0.5,
		"arp": [1.0, 1.0, 0.944, 1.0],
		"arp_step": 0.125,
		"bass_style": "drone",
		"drum_style": "ambient_pulse",
		"brightness": 0.1,
		"tremolo": 0.5,
		"voices": 2,
		"duration": 4.0
	},
	# Boss 8: Omega — Apex Flagship Requiem
	{
		"title": "Apex Flagship Requiem",
		"chord_roots": [130.81, 103.83, 87.31, 98.00],
		"chord_thirds": [1.2, 1.25, 1.2, 1.25],
		"chord_fifths": [1.5, 1.5, 1.5, 1.5],
		"chord_dur": 1.0,
		"melody": [1.0, 1.2, 1.5, 1.8, 1.5, 1.333, 1.2, 1.0],
		"melody_step": 0.5,
		"arp": [1.0, 1.2, 1.5, 1.8, 2.0, 1.5],
		"arp_step": 0.125,
		"bass_style": "march",
		"drum_style": "four_on_floor",
		"brightness": 0.55,
		"tremolo": 0.0,
		"voices": 3,
		"duration": 4.0
	},
	# Boss 9: Dread Star — Cosmic Cataclysm
	{
		"title": "Cosmic Cataclysm",
		"chord_roots": [58.27, 46.25, 41.20, 43.65],
		"chord_thirds": [1.2, 1.25, 1.2, 1.25],
		"chord_fifths": [1.5, 1.5, 1.414, 1.5],
		"chord_dur": 1.0,
		"melody": [1.0, 1.06, 1.0, 0.944, 1.0, 1.12, 1.0, 0.891],
		"melody_step": 0.5,
		"arp": [1.0, 1.06, 1.0, 0.944],
		"arp_step": 0.25,
		"bass_style": "drone",
		"drum_style": "ambient_pulse",
		"brightness": 0.1,
		"tremolo": 0.4,
		"voices": 2,
		"duration": 4.0
	},
	# Boss 10: Hyperion — Solar Incandescence
	{
		"title": "Solar Incandescence",
		"chord_roots": [146.83, 123.47, 98.00, 110.00],
		"chord_thirds": [1.25, 1.2, 1.25, 1.25],
		"chord_fifths": [1.5, 1.5, 1.5, 1.5],
		"chord_dur": 1.0,
		"melody": [1.5, 2.0, 1.875, 1.5, 2.25, 2.0, 1.875, 1.5],
		"melody_step": 0.5,
		"arp": [1.0, 1.25, 1.5, 1.875, 2.0, 2.5, 2.0, 1.5],
		"arp_step": 0.0625,
		"bass_style": "stab",
		"drum_style": "speed_synth",
		"brightness": 0.65,
		"tremolo": 0.0,
		"voices": 3,
		"duration": 4.0
	}
]

## Main Menu Full Score (Anthemic synthwave title theme)
const MENU_THEME: Dictionary = {
	"title": "Starlight Vanguard Main Theme",
	"chord_roots": [220.00, 174.61, 261.63, 196.00], # Am - F - C - G
	"chord_thirds": [1.2, 1.25, 1.25, 1.25],
	"chord_fifths": [1.5, 1.5, 1.5, 1.5],
	"chord_dur": 1.0,
	"melody": [1.5, 1.2, 1.0, 1.2, 1.5, 1.778, 2.0, 1.5],
	"melody_step": 0.5,
	"arp": [1.0, 1.2, 1.5, 2.0, 1.5, 1.2],
	"arp_step": 0.125,
	"bass_style": "pulse",
	"drum_style": "four_on_floor",
	"brightness": 0.55,
	"tremolo": 0.05,
	"voices": 2,
	"duration": 4.0
}

## Victory Full Score (Heroic ascending major fanfare)
const VICTORY_THEME: Dictionary = {
	"title": "Starlight Fanfare",
	"chord_roots": [261.63, 329.63, 392.00, 523.25], # C - E - G - C
	"chord_thirds": [1.25, 1.25, 1.25, 1.25],
	"chord_fifths": [1.5, 1.5, 1.5, 1.5],
	"chord_dur": 1.0,
	"melody": [1.0, 1.25, 1.5, 2.0, 2.25, 2.0, 1.875, 2.0],
	"melody_step": 0.5,
	"arp": [1.0, 1.25, 1.5, 2.0],
	"arp_step": 0.125,
	"bass_style": "stab",
	"drum_style": "four_on_floor",
	"brightness": 0.65,
	"tremolo": 0.0,
	"voices": 3,
	"duration": 4.0
}

func _ready() -> void:
	# GameState (autoload order: GameState before AudioManager) has already
	# loaded the persisted sound setting by the time this runs.
	music_muted = not GameState.sound_enabled
	sfx_muted = not GameState.sound_enabled

	_music_player_a = AudioStreamPlayer.new()
	_music_player_a.bus = &"Master"
	add_child(_music_player_a)
	_music_player_b = AudioStreamPlayer.new()
	_music_player_b.bus = &"Master"
	add_child(_music_player_b)
	_active_music_player = _music_player_a

	for i in _POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = &"Master"
		add_child(p)
		_sfx_pool.append(p)

	_generate_all_sfx()

# ── Music API ──────────────────────────────────────────────────

func play_level_music(level_num: int) -> void:
	if music_muted:
		return
	if _current_level_music == level_num and not _is_boss_music and _active_music_player.playing:
		return
	_current_level_music = level_num
	_is_boss_music = false
	var stream: AudioStreamWAV = _get_or_create_level_track(level_num)
	if stream:
		_switch_music_track(stream)

func play_boss_music(boss_index: int = 0) -> void:
	if music_muted:
		return
	if _is_boss_music and _current_boss_music_index == boss_index and _active_music_player.playing:
		return
	_is_boss_music = true
	_current_boss_music_index = boss_index
	var stream: AudioStreamWAV = _get_or_create_boss_track(boss_index)
	if stream:
		_switch_music_track(stream)

## Main menu theme — a fuller, multi-layered piece (chord progression +
## arpeggio + a repeating melodic hook + sub-bass + percussion) rather
## than reusing the sparser in-game loop engine, since it's the game's
## first impression.
func play_menu_music() -> void:
	_current_level_music = -1
	_is_boss_music = false
	if music_muted:
		return
	var stream: AudioStreamWAV = _get_or_create_menu_theme_track()
	if stream:
		_switch_music_track(stream)

## Triumphant looping fanfare for the win screen.
func play_victory_music() -> void:
	_current_level_music = -1
	_is_boss_music = false
	if music_muted:
		return
	var stream: AudioStreamWAV = _get_or_create_victory_track()
	if stream:
		_switch_music_track(stream)

func play_music(stream: AudioStream, loop: bool = true) -> void:
	if stream == null:
		return
	_switch_music_track(stream)

func stop_music() -> void:
	_active_music_player.stop()
	_current_level_music = -1
	_is_boss_music = false

## Switches to the given track on whichever player is currently idle (the
## other one), then stops the previously-active player. Never reassigns
## .stream on a player that might still be mid-callback on the native audio
## thread — see the comment on _music_player_a/b above.
func _switch_music_track(stream: AudioStream) -> void:
	var next_player: AudioStreamPlayer = _music_player_b if _active_music_player == _music_player_a else _music_player_a
	var prev_player: AudioStreamPlayer = _active_music_player
	next_player.stream = stream
	next_player.volume_db = _vol_db(music_volume, music_muted)
	next_player.play()
	_active_music_player = next_player
	prev_player.stop()

func set_music_volume(vol: float) -> void:
	music_volume = clamp(vol, 0.0, 1.0)
	if _active_music_player:
		_active_music_player.volume_db = _vol_db(music_volume, music_muted)

func toggle_music_mute() -> void:
	music_muted = !music_muted
	if _active_music_player:
		_active_music_player.volume_db = _vol_db(music_volume, music_muted)

# ── High-Level SFX API ─────────────────────────────────────────

func play_charge_sfx() -> void:
	play_sfx(_sfx_charge)

## Plays tier-specific superweapon charge shot SFX based on charge_level
func play_charge_fire_sfx(charge_level: float) -> void:
	if charge_level >= 1.0:
		play_sfx(_sfx_charge_max)
	elif charge_level >= 0.66:
		play_sfx(_sfx_charge_green)
	elif charge_level >= 0.33:
		play_sfx(_sfx_charge_yellow)
	else:
		play_sfx(_sfx_charge_red)

func play_full_charge_ready_sfx() -> void:
	play_sfx(_sfx_full_charge_ready)

func play_pickup_sfx() -> void:
	play_sfx(_sfx_pickup)

func play_explosion_sfx() -> void:
	play_sfx(_sfx_explosion)

func play_hit_sfx() -> void:
	play_sfx(_sfx_hit)

func play_boss_sfx() -> void:
	play_sfx(_sfx_boss)

func play_sfx(stream: AudioStream) -> void:
	if stream == null or sfx_muted:
		return
	var player := _get_free_sfx_player()
	if player == null:
		# All _POOL_SIZE slots are busy (e.g. a chaotic boss fight with lots
		# of enemies dying at once). Drop the sound rather than force-reusing
		# a still-playing player — reassigning .stream on one that may still
		# be mid-callback on the native audio thread is a use-after-free
		# race (matches an observed SIGSEGV inside
		# AudioTrackCallback::onMoreData).
		return
	player.stream = stream
	player.volume_db = _vol_db(sfx_volume, sfx_muted)
	player.play()

func set_sfx_volume(vol: float) -> void:
	sfx_volume = clamp(vol, 0.0, 1.0)

func toggle_sfx_mute() -> void:
	sfx_muted = !sfx_muted

# ── Audio Generation Engine ─────────────────────────────────────

func _generate_all_sfx() -> void:
	const RATE: int = 22050

	# 1. Charge Hum SFX (0.35s rising pulse)
	_sfx_charge = _create_wav(int(RATE * 0.35), RATE, false, func(_i: int, t: float, _total: float) -> float:
		var freq: float = 220.0 + t * 900.0
		var vib: float = sin(TAU * 18.0 * t) * 15.0
		var env: float = sin(PI * (t / 0.35))
		return sin(TAU * (freq + vib) * t) * env * 0.30
	)

	# 2a. Red Tier Charge Shot SFX (80% tier - 0.25s)
	_sfx_charge_red = _create_wav(int(RATE * 0.25), RATE, false, func(_i: int, t: float, _total: float) -> float:
		var freq: float = 480.0 - t * 1200.0
		var env: float = 1.0 - (t / 0.25)
		return sin(TAU * freq * t) * env * 0.38
	)

	# 2b. Yellow Tier Charge Shot SFX (90% tier - 0.35s)
	_sfx_charge_yellow = _create_wav(int(RATE * 0.35), RATE, false, func(_i: int, t: float, _total: float) -> float:
		var freq1: float = 650.0 - t * 1400.0
		var freq2: float = 325.0 - t * 700.0
		var env: float = 1.0 - (t / 0.35)
		return (sin(TAU * freq1 * t) * 0.6 + sin(TAU * freq2 * t) * 0.4) * env * 0.45
	)

	# 2c. Green Tier Charge Shot SFX (95% tier - 0.45s)
	_sfx_charge_green = _create_wav(int(RATE * 0.45), RATE, false, func(_i: int, t: float, _total: float) -> float:
		var freq: float = 900.0 - t * 1600.0
		var sub: float = sin(TAU * 90.0 * t) * 0.4
		var env: float = 1.0 - (t / 0.45)
		return (sin(TAU * freq * t) * 0.6 + sub) * env * 0.52
	)

	# 2d. Flashing MAX Tier Charge Shot SFX (100% tier - 0.60s epic devastation blast)
	_sfx_charge_max = _create_wav(int(RATE * 0.60), RATE, false, func(_i: int, t: float, _total: float) -> float:
		var sub_freq: float = 180.0 - t * 260.0
		var sub: float = sin(TAU * sub_freq * t)
		var noise: float = randf_range(-1.0, 1.0)
		var env: float = 1.0 - (t / 0.60)
		return (sub * 0.6 + noise * 0.4) * env * 0.60
	)

	# 3. Full Charge Ready Chime SFX (0.20s 2-note ready chime)
	_sfx_full_charge_ready = _create_wav(int(RATE * 0.20), RATE, false, func(_i: int, t: float, _total: float) -> float:
		var freq: float = 1046.50 if t < 0.10 else 1567.98 # C6 -> G6
		var local_t: float = fmod(t, 0.10)
		var env: float = 1.0 - (local_t / 0.10)
		return sin(TAU * freq * t) * env * 0.45
	)

	# 4. Pickup Chime SFX (0.28s 3-note arpeggio C5-E5-G5)
	_sfx_pickup = _create_wav(int(RATE * 0.28), RATE, false, func(_i: int, t: float, _total: float) -> float:
		var note_idx: int = min(2, int(t / 0.09))
		var freqs: Array[float] = [523.25, 659.25, 783.99]
		var freq: float = freqs[note_idx]
		var local_t: float = fmod(t, 0.09)
		var env: float = 1.0 - (local_t / 0.09)
		return sin(TAU * freq * t) * env * 0.40
	)

	# 5. Explosion SFX (0.40s low-pass noise crash)
	_sfx_explosion = _create_wav(int(RATE * 0.40), RATE, false, func(_i: int, t: float, _total: float) -> float:
		var env: float = (1.0 - (t / 0.40)) ** 1.8
		var noise: float = randf_range(-1.0, 1.0)
		var rumble: float = sin(TAU * 70.0 * t)
		return (noise * 0.6 + rumble * 0.4) * env * 0.48
	)

	# 6. Hit Spark SFX (0.07s zap)
	_sfx_hit = _create_wav(int(RATE * 0.07), RATE, false, func(_i: int, t: float, _total: float) -> float:
		var freq: float = 1200.0 - t * 8000.0
		var env: float = 1.0 - (t / 0.07)
		return (sin(TAU * freq * t) + randf_range(-0.3, 0.3)) * env * 0.35
	)

	# 7. Boss Alarm Siren SFX (0.60s dual siren)
	_sfx_boss = _create_wav(int(RATE * 0.60), RATE, false, func(_i: int, t: float, _total: float) -> float:
		var siren: float = 440.0 if fmod(t, 0.30) < 0.15 else 660.0
		var env: float = sin(PI * (t / 0.60))
		return (0.3 if sin(TAU * siren * t) > 0.0 else -0.3) * env * 0.40
	)

func _get_or_create_boss_track(boss_index: int) -> AudioStreamWAV:
	var idx: int = clampi(boss_index, 0, BOSS_THEMES.size() - 1)
	if _boss_music_tracks.has(idx):
		return _boss_music_tracks[idx]

	const RATE: int = 22050
	var params: Dictionary = BOSS_THEMES[idx]
	var sample_count: int = int(RATE * float(params.get("duration", 4.0)))

	var track: AudioStreamWAV = _create_wav(sample_count, RATE, true, func(_i: int, t: float, _total: float) -> float:
		return _synth_theme(t, params)
	)
	_boss_music_tracks[idx] = track
	return track

func _get_or_create_menu_theme_track() -> AudioStreamWAV:
	if _menu_music_track != null:
		return _menu_music_track

	const RATE: int = 22050
	var sample_count: int = int(RATE * float(MENU_THEME.get("duration", 4.0)))

	_menu_music_track = _create_wav(sample_count, RATE, true, func(_i: int, t: float, _total: float) -> float:
		return _synth_theme(t, MENU_THEME)
	)
	return _menu_music_track

func _get_or_create_victory_track() -> AudioStreamWAV:
	if _victory_music_track != null:
		return _victory_music_track

	const RATE: int = 22050
	var sample_count: int = int(RATE * float(VICTORY_THEME.get("duration", 4.0)))

	_victory_music_track = _create_wav(sample_count, RATE, true, func(_i: int, t: float, _total: float) -> float:
		return _synth_theme(t, VICTORY_THEME)
	)
	return _victory_music_track

func _get_or_create_level_track(lvl: int) -> AudioStreamWAV:
	if _level_tracks.has(lvl):
		return _level_tracks[lvl]

	const RATE: int = 22050
	var idx: int = clampi(lvl - 1, 0, LEVEL_THEMES.size() - 1)
	var params: Dictionary = LEVEL_THEMES[idx]
	var sample_count: int = int(RATE * float(params.get("duration", 4.0)))

	var track: AudioStreamWAV = _create_wav(sample_count, RATE, true, func(_i: int, t: float, _total: float) -> float:
		return _synth_theme(t, params)
	)

	_level_tracks[lvl] = track
	return track

## Full Multi-Layered Score Synthesizer for Levels and Bosses
## Combines 5 distinct musical layers:
## 1. Harmonic Pad & Sub-bass (chord progression roots, thirds, fifths)
## 2. Dynamic Arpeggiator (16th/8th triad textures with overtone sparkles)
## 3. Melodic Lead Hook (expressive motif with attack/decay envelope & vibrato)
## 4. Rhythmic Bassline (pulse, stomp, march, wobble, stab, walk, slither, battle march)
## 5. Drum & Percussion Section (four-on-the-floor, breakbeat, industrial march, speed synth, tribal, ambient)
func _synth_theme(t: float, p: Dictionary) -> float:
	var chord_roots: Array = p.get("chord_roots", [p.get("root", 220.0)])
	var chord_thirds: Array = p.get("chord_thirds", [1.2])
	var chord_fifths: Array = p.get("chord_fifths", [1.5])
	var chord_dur: float = p.get("chord_dur", 1.0)
	var melody: Array = p.get("melody", [1.0, 1.2, 1.5, 1.2])
	var melody_step: float = p.get("melody_step", 0.5)
	var arp: Array = p.get("arp", [1.0, 1.2, 1.5, 1.2])
	var arp_step: float = p.get("arp_step", 0.125)
	var bass_style: String = p.get("bass_style", "pulse")
	var drum_style: String = p.get("drum_style", "four_on_floor")
	var brightness: float = p.get("brightness", 0.3)
	var tremolo: float = p.get("tremolo", 0.0)
	var voices: int = p.get("voices", 1)

	# Determine active chord in progression
	var chord_idx: int = int(t / chord_dur) % chord_roots.size()
	var chord_t: float = fmod(t, chord_dur)
	var root: float = float(chord_roots[chord_idx])
	var third: float = float(chord_thirds[chord_idx % chord_thirds.size()])
	var fifth: float = float(chord_fifths[chord_idx % chord_fifths.size()])

	# 1. Harmonic Pad & Deep Sub-bass Bed
	var sub: float = sin(TAU * root * 0.5 * t) * 0.18
	var pad: float = (sin(TAU * root * t) + sin(TAU * root * third * t) * 0.6 + sin(TAU * root * fifth * t) * 0.4) * 0.07

	# 2. Sparkling Arpeggiator Layer
	var arp_idx: int = int(t / arp_step) % arp.size()
	var arp_freq: float = root * 2.0 * float(arp[arp_idx])
	var arp_val: float = sin(TAU * arp_freq * t) * 0.12
	if brightness > 0.0:
		arp_val += sin(TAU * arp_freq * 2.0 * t) * 0.04 * brightness

	# 3. Expressive Melodic Lead Hook
	var mel_idx: int = int(t / melody_step) % melody.size()
	var mel_freq: float = root * 2.0 * float(melody[mel_idx])
	var mel_local_t: float = fmod(t, melody_step)
	var mel_env: float = 1.0 - pow(mel_local_t / melody_step, 2.0) * 0.4
	var lead: float = sin(TAU * mel_freq * t) * 0.20 * mel_env
	if brightness > 0.0:
		lead += sin(TAU * mel_freq * 2.0 * t) * 0.08 * brightness * mel_env
	if tremolo > 0.0:
		lead *= (1.0 - tremolo * 0.5) + tremolo * 0.5 * sin(TAU * 7.0 * t)

	# Multi-voice Polyphony (e.g. Hydra 3-heads, Omega anthem, Hyperion celestial)
	if voices > 1:
		for v in range(1, voices):
			var v_freq: float = mel_freq * (1.0 + 0.006 * float(v))
			lead += sin(TAU * v_freq * t + float(v) * 1.5) * (0.08 / float(voices)) * mel_env

	# 4. Bassline Synthesizer
	var bass: float = 0.0
	match bass_style:
		"pulse":
			var step_idx: int = int(t / 0.25)
			var bf: float = root * (1.0 if step_idx % 2 == 0 else 0.5)
			bass = (0.22 if sin(TAU * bf * t) > 0.0 else -0.22)
		"drone":
			bass = sin(TAU * root * 0.5 * t) * 0.25
		"stomp":
			var beat_t: float = fmod(t, 0.5)
			var env: float = maxf(0.0, 1.0 - beat_t / 0.35)
			bass = sin(TAU * root * 0.5 * t) * env * 0.35
		"march":
			var beat_t: float = fmod(t, 0.25)
			bass = (0.22 if beat_t < 0.125 else -0.10)
		"wobble":
			var wob: float = sin(TAU * 3.0 * t)
			bass = sin(TAU * (root * 0.5) * (1.0 + 0.18 * wob) * t) * 0.24
		"stab":
			var beat_t: float = fmod(t, 0.25)
			var env: float = maxf(0.0, 1.0 - beat_t / 0.15)
			bass = sin(TAU * root * t) * env * 0.28
		"walk":
			var walk_notes: Array = [1.0, third, fifth, third]
			var walk_idx: int = int(chord_t / 0.25) % 4
			var bf: float = root * 0.5 * float(walk_notes[walk_idx])
			var beat_t: float = fmod(chord_t, 0.25)
			var env: float = maxf(0.0, 1.0 - beat_t / 0.22)
			bass = sin(TAU * bf * t) * env * 0.26
		"slither_poly":
			var glide: float = sin(TAU * 1.5 * t) * 0.1
			bass = sin(TAU * (root * 0.5 * (1.0 + glide)) * t) * 0.25
		"battle_march":
			var beat_t: float = fmod(t, 0.5)
			var env: float = maxf(0.0, 1.0 - beat_t / 0.25)
			bass = sin(TAU * root * 0.5 * t) * env * 0.32 + (0.12 if fmod(t, 0.25) < 0.125 else -0.12)

	# 5. Drum & Percussion Section
	var perc: float = 0.0
	var beat_1s: float = fmod(t, 1.0)
	var beat_half: float = fmod(t, 0.5)
	var beat_quarter: float = fmod(t, 0.25)
	var beat_16th: float = fmod(t, 0.125)

	match drum_style:
		"four_on_floor":
			# Kick on every quarter note
			if beat_quarter < 0.08:
				var kick_env: float = 1.0 - (beat_quarter / 0.08)
				perc += sin(TAU * (140.0 - beat_quarter * 1200.0) * beat_quarter) * kick_env * 0.35
			# Snare/clap on beats 2 & 4
			if beat_1s >= 0.5 and beat_1s < 0.65:
				var snare_t: float = beat_1s - 0.5
				var snare_env: float = 1.0 - (snare_t / 0.15)
				var noise: float = fposmod(sin(snare_t * 9999.0) * 43758.5453, 1.0) * 2.0 - 1.0
				perc += noise * snare_env * 0.22
			# Hi-hat on 16ths
			if beat_16th < 0.02:
				var hat_env: float = 1.0 - (beat_16th / 0.02)
				var noise: float = fposmod(sin(beat_16th * 12345.0) * 43758.5453, 1.0) * 2.0 - 1.0
				perc += noise * hat_env * 0.10

		"breakbeat":
			# Syncopated kick on 0.0, 0.375, 0.75
			var kick_hit: bool = false
			var kt: float = 0.0
			for kp in [0.0, 0.375, 0.75]:
				if beat_1s >= kp and beat_1s < kp + 0.08:
					kt = beat_1s - kp
					kick_hit = true
					break
			if kick_hit:
				var kick_env: float = 1.0 - (kt / 0.08)
				perc += sin(TAU * (150.0 - kt * 1400.0) * kt) * kick_env * 0.32
			# Snare on 0.5
			if beat_1s >= 0.5 and beat_1s < 0.65:
				var st: float = beat_1s - 0.5
				var s_env: float = 1.0 - (st / 0.15)
				var noise: float = fposmod(sin(st * 9999.0) * 43758.5453, 1.0) * 2.0 - 1.0
				perc += noise * s_env * 0.25

		"speed_synth":
			# Fast double-time kick
			if beat_quarter < 0.06:
				var kt: float = beat_quarter
				var kick_env: float = 1.0 - (kt / 0.06)
				perc += sin(TAU * (160.0 - kt * 1800.0) * kt) * kick_env * 0.35
			# Driving 16th hats
			if beat_16th < 0.025:
				var ht: float = beat_16th
				var h_env: float = 1.0 - (ht / 0.025)
				var noise: float = fposmod(sin(ht * 15432.0) * 43758.5453, 1.0) * 2.0 - 1.0
				perc += noise * h_env * 0.12

		"industrial_march":
			# Heavy downbeat hit
			if beat_half < 0.12:
				var kt: float = beat_half
				var k_env: float = 1.0 - (kt / 0.12)
				perc += sin(TAU * (110.0 - kt * 600.0) * kt) * k_env * 0.38
			# Metallic clatter on 16ths
			if beat_16th < 0.03:
				var mt: float = beat_16th
				var m_env: float = 1.0 - (mt / 0.03)
				perc += sin(TAU * 2400.0 * mt) * m_env * 0.12

		"tribal_poly":
			# Offbeat syncopated toms
			var tom_hit: bool = false
			var tt: float = 0.0
			for tp in [0.0, 0.25, 0.625, 0.875]:
				if beat_1s >= tp and beat_1s < tp + 0.08:
					tt = beat_1s - tp
					tom_hit = true
					break
			if tom_hit:
				var t_env: float = 1.0 - (tt / 0.08)
				perc += sin(TAU * 320.0 * tt) * t_env * 0.22

		"ambient_pulse":
			if beat_1s < 0.15:
				var kt: float = beat_1s
				var k_env: float = 1.0 - (kt / 0.15)
				perc += sin(TAU * (90.0 - kt * 300.0) * kt) * k_env * 0.20

	var combined: float = sub + pad + arp_val + lead + bass + perc
	return tanh(combined * 1.1) * 0.85

func _create_wav(sample_count: int, sample_rate: int, is_loop: bool, synth_func: Callable) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for i in sample_count:
		var t: float = float(i) / float(sample_rate)
		var val: float = clampf(synth_func.call(i, t, sample_count), -1.0, 1.0)
		var int_val := int(val * 32767.0)
		if int_val < 0:
			int_val += 65536
		bytes[i * 2] = int_val & 0xFF
		bytes[i * 2 + 1] = (int_val >> 8) & 0xFF

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	if is_loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = sample_count
	else:
		wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
	wav.data = bytes
	return wav

func _get_free_sfx_player() -> AudioStreamPlayer:
	for p in _sfx_pool:
		if not p.playing:
			return p
	return null

func _vol_db(vol: float, muted: bool) -> float:
	if muted or vol <= 0.0:
		return -80.0
	return linear_to_db(vol)
