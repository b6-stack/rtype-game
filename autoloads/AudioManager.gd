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

# Level music tracks & Boss music track
var _level_tracks: Dictionary = {}
var _boss_music_track: AudioStreamWAV = null
var _current_level_music: int = -1
var _is_boss_music: bool = false

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

func play_boss_music() -> void:
	if music_muted or _is_boss_music:
		return
	_is_boss_music = true
	var stream: AudioStreamWAV = _get_or_create_boss_track()
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

func _get_or_create_boss_track() -> AudioStreamWAV:
	if _boss_music_track != null:
		return _boss_music_track

	const RATE: int = 22050
	const DURATION: float = 2.40
	var sample_count: int = int(RATE * DURATION)

	_boss_music_track = _create_wav(sample_count, RATE, true, func(_i: int, t: float, _total: float) -> float:
		var step_16th: int = int(t * 13.33)
		var root: float = 185.0 # F#3
		var bass_freq: float = root * (1.5 if (step_16th % 4 == 3) else (1.0 if (step_16th % 2 == 0) else 0.5))
		var siren_freq: float = root * 2.0 * (1.333 if (step_16th % 8 < 4) else 1.5)

		var bass: float = (0.26 if sin(TAU * bass_freq * t) > 0.0 else -0.26)
		var lead: float = sin(TAU * siren_freq * t) * 0.28
		var noise_tick: float = (randf_range(-0.2, 0.2) if fmod(t, 0.15) < 0.02 else 0.0)

		return clampf(bass + lead + noise_tick, -0.9, 0.9)
	)
	return _boss_music_track

func _get_or_create_level_track(lvl: int) -> AudioStreamWAV:
	if _level_tracks.has(lvl):
		return _level_tracks[lvl]

	const RATE: int = 22050
	const DURATION: float = 2.80
	var sample_count: int = int(RATE * DURATION)

	var base_freqs: Array[float] = [
		130.81, 146.83, 164.81, 174.61, 196.00,
		220.00, 246.94, 261.63, 293.66, 329.63
	]
	var root: float = base_freqs[clampi(lvl - 1, 0, 9)]
	var scale_mults: Array[float] = [1.0, 1.20, 1.333, 1.50, 1.778]

	var track: AudioStreamWAV = _create_wav(sample_count, RATE, true, func(_i: int, t: float, _total: float) -> float:
		var step_8th: int = int(t * 5.714)
		var arpeggio_idx: int = step_8th % scale_mults.size()
		var lead_freq: float = root * 2.0 * scale_mults[arpeggio_idx]
		var bass_freq: float = root * (1.0 if (step_8th % 2 == 0) else 0.5)

		var lead: float = sin(TAU * lead_freq * t) * 0.25
		var bass: float = (0.22 if sin(TAU * bass_freq * t) > 0.0 else -0.22)
		var hihat_step: float = fmod(t, 0.175)
		var hihat: float = (randf_range(-0.15, 0.15) if hihat_step < 0.02 else 0.0)

		return clampf(lead + bass + hihat, -0.9, 0.9)
	)

	_level_tracks[lvl] = track
	return track

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
