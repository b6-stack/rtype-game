extends Node
## AudioManager — pooled SFX playback & 10-level procedural synthwave music engine.
## Generates 16-bit PCM AudioStreamWAV streams in GDScript.

var music_volume: float = 0.8
var sfx_volume: float = 1.0
var music_muted: bool = false
var sfx_muted: bool = false

var _music_player: AudioStreamPlayer
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
var _current_level_music: int = -1
var _current_boss_music_index: int = -1
var _is_boss_music: bool = false

## Per-level theme parameters (index 0 = level 1), matching each level's
## biome name/mood in LevelGenerator.LEVEL_COLORS.
const LEVEL_THEMES: Array[Dictionary] = [
	{ "root": 130.81, "arp": [1.0, 1.2, 1.333, 1.5, 1.778], "step": 0.35, "bass_style": "drone", "brightness": 0.0, "percussion": 0.06, "tremolo": 0.0, "voices": 1, "duration": 3.2 },   # 1 Blue Cave — mysterious, sparse
	{ "root": 146.83, "arp": [1.0, 1.125, 1.2, 1.333, 1.5], "step": 0.20, "bass_style": "pulse", "brightness": 0.25, "percussion": 0.18, "tremolo": 0.0, "voices": 1, "duration": 2.6 },  # 2 Red Cavern — aggressive, driving
	{ "root": 164.81, "arp": [1.0, 1.2, 1.0, 1.333, 1.5, 1.2], "step": 0.24, "bass_style": "wobble", "brightness": 0.15, "percussion": 0.14, "tremolo": 0.15, "voices": 1, "duration": 2.9 }, # 3 Green Base — organic, syncopated
	{ "root": 174.61, "arp": [1.0, 1.0, 1.25, 1.5], "step": 0.22, "bass_style": "march", "brightness": 0.35, "percussion": 0.22, "tremolo": 0.0, "voices": 1, "duration": 2.6 },        # 4 Brown Fortress — militaristic
	{ "root": 196.00, "arp": [1.0, 1.122, 1.26, 1.414, 1.587], "step": 0.30, "bass_style": "drone", "brightness": 0.1, "percussion": 0.05, "tremolo": 0.35, "voices": 1, "duration": 3.4 }, # 5 Purple Alien — eerie, dissonant
	{ "root": 220.00, "arp": [1.0, 1.125, 1.25, 1.333, 1.5, 1.667, 1.875, 2.0], "step": 0.11, "bass_style": "pulse", "brightness": 0.4, "percussion": 0.28, "tremolo": 0.0, "voices": 1, "duration": 2.4 }, # 6 Teal Station — techy, fast
	{ "root": 246.94, "arp": [1.0, 1.2, 1.333, 1.5], "step": 0.15, "bass_style": "stab", "brightness": 0.35, "percussion": 0.24, "tremolo": 0.0, "voices": 1, "duration": 2.4 },        # 7 Crimson Core — intense
	{ "root": 261.63, "arp": [1.0, 1.125, 1.25, 1.333, 1.5, 1.667, 1.875], "step": 0.20, "bass_style": "march", "brightness": 0.45, "percussion": 0.16, "tremolo": 0.0, "voices": 1, "duration": 2.8 }, # 8 Gold Final — triumphant
	{ "root": 146.83, "arp": [1.0, 1.122, 1.0, 0.944], "step": 0.5, "bass_style": "drone", "brightness": 0.0, "percussion": 0.03, "tremolo": 0.2, "voices": 1, "duration": 4.0 },       # 9 Cosmic Void — ambient, spacious
	{ "root": 329.63, "arp": [1.0, 1.25, 1.5, 1.875, 2.0, 1.5], "step": 0.14, "bass_style": "pulse", "brightness": 0.5, "percussion": 0.3, "tremolo": 0.0, "voices": 1, "duration": 2.2 }, # 10 Solar Core — blazing
]

## Per-boss theme parameters (index matches BossManager.BOSS_SCRIPTS order).
const BOSS_THEMES: Array[Dictionary] = [
	{ "root": 110.0, "arp": [1.0, 1.0, 1.2, 1.0], "step": 0.30, "bass_style": "stomp", "brightness": 0.1, "percussion": 0.2, "tremolo": 0.0, "voices": 1, "duration": 3.0 },             # Iron Claw — heavy mechanical stomp
	{ "root": 138.59, "arp": [1.0, 1.122, 1.26, 1.414, 1.26, 1.122], "step": 0.18, "bass_style": "wobble", "brightness": 0.2, "percussion": 0.1, "tremolo": 0.25, "voices": 3, "duration": 3.0 }, # Hydra — 3 interweaving/slithering voices
	{ "root": 98.0, "arp": [1.0, 1.0, 1.2], "step": 0.4, "bass_style": "stomp", "brightness": 0.0, "percussion": 0.15, "tremolo": 0.0, "voices": 1, "duration": 3.2 },                  # Behemoth — thunderous rumble
	{ "root": 185.0, "arp": [1.333, 1.5, 1.333, 1.5], "step": 0.15, "bass_style": "pulse", "brightness": 0.3, "percussion": 0.18, "tremolo": 0.0, "voices": 1, "duration": 2.4 },       # Sentinel — mechanical, rotating pulses
	{ "root": 220.0, "arp": [1.0, 1.06, 1.12, 1.06], "step": 0.10, "bass_style": "wobble", "brightness": 0.3, "percussion": 0.22, "tremolo": 0.4, "voices": 2, "duration": 2.2 },       # Swarm Queen — buzzing, insectoid
	{ "root": 440.0, "arp": [1.0, 1.125, 1.25, 1.5, 1.25, 1.125], "step": 0.13, "bass_style": "pulse", "brightness": 0.55, "percussion": 0.2, "tremolo": 0.1, "voices": 1, "duration": 2.2 }, # Photon Core — bright laser sweeps
	{ "root": 130.0, "arp": [1.0, 1.0, 0.944, 1.0], "step": 0.28, "bass_style": "wobble", "brightness": 0.05, "percussion": 0.08, "tremolo": 0.5, "voices": 1, "duration": 3.2 },       # Abyss Gate — dark, warped/dimensional
	{ "root": 164.81, "arp": [1.0, 1.2, 1.333, 1.5, 1.778, 1.5], "step": 0.16, "bass_style": "march", "brightness": 0.4, "percussion": 0.24, "tremolo": 0.0, "voices": 2, "duration": 2.6 }, # Omega — epic, layered grandeur
	{ "root": 73.42, "arp": [1.0, 1.06, 1.0, 0.944], "step": 0.5, "bass_style": "drone", "brightness": 0.0, "percussion": 0.05, "tremolo": 0.3, "voices": 2, "duration": 3.6 },         # Dread Star — ominous cosmic horror
	{ "root": 293.66, "arp": [1.0, 1.25, 1.5, 1.875, 2.0, 1.875, 1.5, 1.25], "step": 0.10, "bass_style": "stab", "brightness": 0.55, "percussion": 0.3, "tremolo": 0.0, "voices": 2, "duration": 2.2 }, # Hyperion — blazing solar intensity
]

func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = &"Master"
	add_child(_music_player)

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
	if _current_level_music == level_num and not _is_boss_music and _music_player.playing:
		return
	_current_level_music = level_num
	_is_boss_music = false
	var stream: AudioStreamWAV = _get_or_create_level_track(level_num)
	if stream:
		_music_player.stream = stream
		_music_player.volume_db = _vol_db(music_volume, music_muted)
		_music_player.play()

func play_boss_music(boss_index: int = 0) -> void:
	if music_muted:
		return
	if _is_boss_music and _current_boss_music_index == boss_index and _music_player.playing:
		return
	_is_boss_music = true
	_current_boss_music_index = boss_index
	var stream: AudioStreamWAV = _get_or_create_boss_track(boss_index)
	if stream:
		_music_player.stream = stream
		_music_player.volume_db = _vol_db(music_volume, music_muted)
		_music_player.play()

## Triumphant looping fanfare for the win screen.
func play_victory_music() -> void:
	_current_level_music = -1
	_is_boss_music = false
	if music_muted:
		return
	var stream: AudioStreamWAV = _get_or_create_victory_track()
	if stream:
		_music_player.stream = stream
		_music_player.volume_db = _vol_db(music_volume, music_muted)
		_music_player.play()

func play_music(stream: AudioStream, loop: bool = true) -> void:
	if stream == null:
		return
	_music_player.stream = stream
	_music_player.volume_db = _vol_db(music_volume, music_muted)
	_music_player.play()

func stop_music() -> void:
	_music_player.stop()
	_current_level_music = -1
	_is_boss_music = false

func set_music_volume(vol: float) -> void:
	music_volume = clamp(vol, 0.0, 1.0)
	if _music_player:
		_music_player.volume_db = _vol_db(music_volume, music_muted)

func toggle_music_mute() -> void:
	music_muted = !music_muted
	if _music_player:
		_music_player.volume_db = _vol_db(music_volume, music_muted)

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
	var sample_count: int = int(RATE * float(params.get("duration", 2.6)))

	var track: AudioStreamWAV = _create_wav(sample_count, RATE, true, func(_i: int, t: float, _total: float) -> float:
		return _synth_theme(t, params)
	)
	_boss_music_tracks[idx] = track
	return track

func _get_or_create_victory_track() -> AudioStreamWAV:
	if _victory_music_track != null:
		return _victory_music_track

	const RATE: int = 22050
	const DURATION: float = 4.0
	var sample_count: int = int(RATE * DURATION)

	# Ascending major arpeggio (C5-E5-G5-C6-E6) with a soft sub-octave and
	# a bright octave-up sparkle layered on the lead note.
	var melody: Array[float] = [523.25, 659.25, 783.99, 1046.50, 1318.51]
	const NOTE_DUR: float = 0.42

	_victory_music_track = _create_wav(sample_count, RATE, true, func(_i: int, t: float, _total: float) -> float:
		var note_idx: int = int(t / NOTE_DUR) % melody.size()
		var freq: float = melody[note_idx]
		var local_t: float = fmod(t, NOTE_DUR)
		var env: float = 1.0 - pow(local_t / NOTE_DUR, 2.0) * 0.55

		var lead: float = sin(TAU * freq * t) * 0.45
		var sub: float = sin(TAU * freq * 0.5 * t) * 0.18
		var sparkle: float = sin(TAU * freq * 2.0 * t) * 0.10
		return clampf((lead + sub + sparkle) * env, -0.9, 0.9)
	)
	return _victory_music_track

func _get_or_create_level_track(lvl: int) -> AudioStreamWAV:
	if _level_tracks.has(lvl):
		return _level_tracks[lvl]

	const RATE: int = 22050
	var idx: int = clampi(lvl - 1, 0, LEVEL_THEMES.size() - 1)
	var params: Dictionary = LEVEL_THEMES[idx]
	var sample_count: int = int(RATE * float(params.get("duration", 2.8)))

	var track: AudioStreamWAV = _create_wav(sample_count, RATE, true, func(_i: int, t: float, _total: float) -> float:
		return _synth_theme(t, params)
	)

	_level_tracks[lvl] = track
	return track

## Shared parameterized synthesizer for level/boss themes — a handful of
## knobs (root pitch, arpeggio interval pattern, tempo, bass rhythm style,
## brightness/harmonic content, tremolo, percussion density, extra voices)
## combine into genuinely distinct-sounding, thematically-tuned tracks
## without needing a bespoke hand-written synth function per level/boss.
func _synth_theme(t: float, p: Dictionary) -> float:
	var root: float = p.get("root", 220.0)
	var arp: Array = p.get("arp", [1.0, 1.2, 1.333, 1.5, 1.778])
	var step: float = p.get("step", 0.2)
	var brightness: float = p.get("brightness", 0.0)
	var tremolo: float = p.get("tremolo", 0.0)
	var percussion: float = p.get("percussion", 0.15)
	var voices: int = p.get("voices", 1)

	var step_idx: int = int(t / step)
	var arp_idx: int = step_idx % arp.size()
	var lead_freq: float = root * 2.0 * float(arp[arp_idx])

	# Lead melody, with optional bright octave-up sparkle and tremolo.
	var lead: float = sin(TAU * lead_freq * t) * 0.25
	if brightness > 0.0:
		lead += sin(TAU * lead_freq * 2.0 * t) * 0.12 * brightness
	if tremolo > 0.0:
		lead *= (1.0 - tremolo * 0.5) + tremolo * 0.5 * sin(TAU * 6.0 * t)

	# Extra interweaving voices (e.g. Hydra's 3 heads) — detuned copies of
	# the lead at slightly offset ratios and phases.
	if voices > 1:
		for v in range(1, voices):
			var v_freq: float = lead_freq * (1.0 + 0.08 * v)
			lead += sin(TAU * v_freq * t + float(v) * 1.7) * 0.12

	# Bass rhythm styles.
	var bass_style: String = p.get("bass_style", "pulse")
	var bass: float = 0.0
	match bass_style:
		"pulse":
			var bf: float = root * (1.0 if (step_idx % 2 == 0) else 0.5)
			bass = (0.22 if sin(TAU * bf * t) > 0.0 else -0.22)
		"drone":
			bass = sin(TAU * root * 0.5 * t) * 0.26
		"stomp":
			var beat_t: float = fmod(t, step * 4.0)
			var env: float = maxf(0.0, 1.0 - beat_t / 0.3)
			bass = sin(TAU * root * 0.5 * t) * env * 0.38
		"march":
			var beat_t2: float = fmod(t, step * 2.0)
			bass = (0.24 if beat_t2 < step else -0.10)
		"wobble":
			var wob: float = sin(TAU * 2.0 * t)
			bass = sin(TAU * (root * 0.5) * (1.0 + 0.15 * wob) * t) * 0.24
		"stab":
			var beat_t3: float = fmod(t, step)
			var env3: float = maxf(0.0, 1.0 - beat_t3 / (step * 0.4))
			bass = sin(TAU * root * t) * env3 * 0.3

	# Percussion tick density.
	var perc_step: float = fmod(t, step * 0.875)
	var perc: float = (randf_range(-percussion, percussion) if perc_step < 0.02 else 0.0)

	return clampf(lead + bass + perc, -0.9, 0.9)

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
	return _sfx_pool[0]

func _vol_db(vol: float, muted: bool) -> float:
	if muted or vol <= 0.0:
		return -80.0
	return linear_to_db(vol)
