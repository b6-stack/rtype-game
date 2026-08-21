extends Node
## AudioManager — pooled SFX playback and music control singleton.
## All audio streams are optional; pass null to play nothing.

var music_volume: float = 0.8
var sfx_volume: float = 1.0
var music_muted: bool = false
var sfx_muted: bool = false

var _music_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
const _POOL_SIZE: int = 16

func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = &"Master"
	add_child(_music_player)

	for i in _POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = &"Master"
		add_child(p)
		_sfx_pool.append(p)

# ── Music ────────────────────────────────────────────────────

func play_music(stream: AudioStream, loop: bool = true) -> void:
	if stream == null:
		return
	_music_player.stream = stream
	_music_player.volume_db = _vol_db(music_volume, music_muted)
	_music_player.play()

func stop_music() -> void:
	_music_player.stop()

func set_music_volume(vol: float) -> void:
	music_volume = clamp(vol, 0.0, 1.0)
	if _music_player:
		_music_player.volume_db = _vol_db(music_volume, music_muted)

func toggle_music_mute() -> void:
	music_muted = !music_muted
	if _music_player:
		_music_player.volume_db = _vol_db(music_volume, music_muted)

# ── SFX ──────────────────────────────────────────────────────

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

# ── Helpers ──────────────────────────────────────────────────

func _get_free_sfx_player() -> AudioStreamPlayer:
	for p in _sfx_pool:
		if not p.playing:
			return p
	# All busy — steal the first one
	return _sfx_pool[0]

func _vol_db(vol: float, muted: bool) -> float:
	if muted or vol <= 0.0:
		return -80.0
	return linear_to_db(vol)
