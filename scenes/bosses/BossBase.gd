class_name BossBase
extends CharacterBody2D
## BossBase — base class for all 8 boss encounters.
## Bosses enter from the right edge, slide to their arena position, show a
## health bar via BossManager, then execute multi-phase attack patterns.
## Subclasses override _phase_attack() and _on_phase_change().

signal died
signal health_changed(current: int, maximum: int)
signal phase_changed(new_phase: int)
signal entrance_complete

# ── Stats ─────────────────────────────────────────────────────
var boss_name: String = "Boss"
var max_health: int = 1000
var current_health: int = 1000
var phase_count: int = 2
var current_phase: int = 0
var score_value: int = 5000
var boss_color: Color = Color.DARK_RED
var size_scale: float = 1.0
var entry_speed: float = 120.0

## Injected by BossManager
var bullet_container: Node = null
var player_ref: Node = null

const BossBulletScene: PackedScene = preload("res://scenes/player/weapons/Bullet.tscn")

# ── Internal ──────────────────────────────────────────────────
var _is_dead: bool = false
var _is_entering: bool = true
var _arena_x: float = 1400.0     # X position boss stops at (right ~75% of screen)
var _time: float = 0.0
var _phase_time: float = 0.0
var _sprite: Sprite2D
var _entry_start_x: float = 2100.0
var _base_sprite_scale: Vector2 = Vector2.ONE
## Most boss_color values have channels near/at 0 (accent-style colors,
## not meant to stand alone), so using them as a full sprite modulate
## multiplied the painted boss artwork down to a noticeably dark/muddy
## look — making the hit-flash-to-white read as brightening rather than
## damage feedback. Lightened once here and reused for both the resting
## sprite tint and what the hit-flash tweens back to.
var _resting_modulate: Color = Color.WHITE

## Sprite scale/alpha while flying in — a small, dim, ghostly wisp rather
## than a smooth continuous fade (which read as barely-there/too-subtle-to-
## notice). Snaps to full size/opacity/solidity at arrival instead.
const ENTRY_SCALE_MULT: float = 0.4
const ENTRY_ALPHA: float = 0.35

func _ready() -> void:
	current_health = max_health
	_sprite = $Visual/Sprite2D
	_base_sprite_scale = Vector2(0.165, 0.165) * size_scale
	_resting_modulate = boss_color.lightened(0.45)
	# Start fully offscreen to the right, whatever the actual screen width is.
	_entry_start_x = get_viewport_rect().size.x + 250.0
	# Resting arena position — centered in the 45%-75% horizontal band (see
	# the default drift in _physics_process) rather than a fixed pixel value,
	# so it stays correct across different screen widths.
	_arena_x = get_viewport_rect().size.x * 0.60
	global_position.x = _entry_start_x
	global_position.y = 540.0
	add_to_group("bosses")

	# Intangible while entering — no landscape/player/bullet collisions at
	# all, so shots visibly sail straight through instead of being silently
	# absorbed by a boss that can't take damage yet.
	collision_layer = 0
	$HurtBox.collision_layer = 0
	$HurtBox.monitoring = false

	if _sprite:
		_sprite.modulate = Color(boss_color.r, boss_color.g, boss_color.b, ENTRY_ALPHA)
		_sprite.scale = _base_sprite_scale * ENTRY_SCALE_MULT

func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	_time += delta
	_phase_time += delta

	if _is_entering:
		_do_entry(delta)
		return

	# Default gentle drift within the center 45%-75% of the screen width —
	# most bosses have their own patrol/state movement that sets velocity
	# every frame in _phase_attack() below and simply overrides this, but a
	# few (Abyss Gate, Dread Star, Omega's final phase, Hyperion's
	# horizontal axis) never touched velocity at all and just sat at one
	# spot for the whole fight. This gives those a sensible default instead.
	var screen_w: float = get_viewport_rect().size.x
	velocity.x = cos(_time * 0.5) * (screen_w * 0.12)
	velocity.y = sin(_time * 0.35) * 70.0

	_phase_attack(delta)
	move_and_slide()

	# Clamp boss to arena bounds
	global_position.x = clamp(global_position.x, 150.0, 1850.0)
	global_position.y = clamp(global_position.y, 60.0, 1020.0)

# ── Override in subclasses ────────────────────────────────────

## Called every frame during combat — implement attack patterns here
func _phase_attack(delta: float) -> void:
	pass

## Called when phase changes — use to switch attack patterns
func _on_phase_change(new_phase: int) -> void:
	pass

# ── Public API ────────────────────────────────────────────────

func take_damage(amount: int) -> void:
	# Invulnerable while flying in: without this, continuous player fire
	# was landing hits the instant the boss came into range mid-entry —
	# chewing through health (and even triggering phase transitions)
	# before the boss had "arrived", and the resulting hit-flash tween
	# fought the entry fade for _sprite.modulate every frame, making the
	# materialize effect look glitchy instead of a clean fade-in.
	if _is_dead or _is_entering:
		return
	if GameState.ultra_mode_enabled:
		amount = int(amount * GameState.ULTRA_MODE_BOSS_DAMAGE_MULT)
	current_health = max(0, current_health - amount)
	health_changed.emit(current_health, max_health)
	if current_health > 0 and _sprite and is_inside_tree():
		var tw := create_tween()
		tw.tween_property(_sprite, "modulate", Color.WHITE, 0.06)
		tw.tween_property(_sprite, "modulate", _resting_modulate, 0.06)
	_check_phase_transition()
	if current_health <= 0:
		_die()

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area is Bullet and not area.is_enemy_bullet:
		take_damage(area.damage)
	elif area.is_in_group("player_bullet"):
		var dmg = 10
		if "damage" in area:
			dmg = area.damage
		take_damage(dmg)

func init_from_data(data: BossData) -> void:
	boss_name   = data.boss_name
	max_health  = data.max_health
	current_health = data.max_health
	phase_count = data.phase_count
	score_value = data.score_value
	boss_color  = data.color
	size_scale  = data.size_scale
	entry_speed = data.entry_speed

# ── Helpers ───────────────────────────────────────────────────

func _do_entry(delta: float) -> void:
	velocity.x = -entry_speed
	move_and_slide()

	# Small, dim, ghostly wisp for the whole flight — a gentle pulse so it
	# doesn't read as static/broken — then snaps to full size/opacity/
	# solidity at arrival, rather than a continuous fade that was too
	# subtle to notice.
	if _sprite:
		var pulse: float = ENTRY_ALPHA + 0.10 * sin(_time * 4.0)
		_sprite.modulate = Color(boss_color.r, boss_color.g, boss_color.b, pulse)
		_sprite.scale = _base_sprite_scale * ENTRY_SCALE_MULT

	if global_position.x <= _arena_x:
		global_position.x = _arena_x
		velocity = Vector2.ZERO
		_is_entering = false
		_phase_time = 0.0
		if _sprite:
			_sprite.modulate = _resting_modulate
			_sprite.scale = _base_sprite_scale
			_sprite.rotation = 0.0
		collision_layer = 32
		$HurtBox.collision_layer = 32
		$HurtBox.monitoring = true
		_on_entrance_ready()
		_spawn_arrival_burst()
		entrance_complete.emit()

## Override to reveal/enable any boss-specific extra visuals or hitboxes
## that were hidden and non-interactive during the entry glide — e.g.
## Hydra's heads or Sentinel's shield ring. These are separate Area2D
## children with their own collision/visibility, so the base sprite/
## HurtBox intangibility above doesn't cover them automatically.
func _on_entrance_ready() -> void:
	pass

func _spawn_arrival_burst() -> void:
	var parent_node: Node = get_parent() if get_parent() else get_tree().current_scene
	if parent_node == null:
		return
	for i in 4:
		var fx: Node2D = load("res://scenes/effects/ExplosionFX.tscn").instantiate()
		parent_node.call_deferred("add_child", fx)
		var offset := Vector2(randf_range(-70, 70), randf_range(-50, 50)) * size_scale
		if fx.has_method("setup"):
			fx.setup(global_position + offset, boss_color, size_scale * 1.8)

func _check_phase_transition() -> void:
	if phase_count <= 1:
		return
	var hp_fraction := float(current_health) / float(max_health)
	var threshold_per_phase := 1.0 / float(phase_count)
	var expected_phase := phase_count - 1 - int(hp_fraction / threshold_per_phase)
	expected_phase = clamp(expected_phase, 0, phase_count - 1)
	if expected_phase != current_phase:
		current_phase = expected_phase
		_phase_time = 0.0
		phase_changed.emit(current_phase)
		_on_phase_change(current_phase)

func _die() -> void:
	_is_dead = true
	GameState.add_score(score_value)
	_spawn_death_explosion()
	died.emit()
	queue_free()

func _spawn_death_explosion() -> void:
	_do_spawn_boss_explosions.call_deferred(global_position, boss_color, size_scale)

func _do_spawn_boss_explosions(pos: Vector2, col: Color, scale_s: float) -> void:
	var tree := get_tree()
	var parent_node: Node = get_parent() if get_parent() else (tree.current_scene if tree else null)
	if parent_node:
		for i in 6:
			var fx: Node2D = load("res://scenes/effects/ExplosionFX.tscn").instantiate()
			parent_node.add_child(fx)
			var offset := Vector2(randf_range(-90, 90), randf_range(-55, 55)) * scale_s
			fx.global_position = pos + offset
			if fx.has_method("setup"):
				fx.setup(pos + offset, col, scale_s * 1.6)

## Fires a bullet toward the player
func _fire_at_player(speed: float = 500.0, dmg: int = 1, col: Color = Color.ORANGE_RED) -> void:
	if bullet_container == null:
		return
	var dir := get_player_direction()
	_spawn_boss_bullet(dir * speed, col, dmg)

## Fires in a radial spread
func _fire_radial(count: int, speed: float = 450.0, dmg: int = 1,
		col: Color = Color.ORANGE_RED, angle_offset: float = 0.0) -> void:
	for i in count:
		var angle := TAU / float(count) * i + deg_to_rad(angle_offset)
		var vel := Vector2.RIGHT.rotated(angle) * speed
		_spawn_boss_bullet(vel, col, dmg)

func _spawn_boss_bullet(vel: Vector2, col: Color, dmg: int) -> void:
	if bullet_container == null:
		return
	var b: Bullet = BossBulletScene.instantiate()
	bullet_container.add_child(b)
	b.global_position = global_position
	b.setup(vel, col, dmg, 1.3, true)

func get_player_direction() -> Vector2:
	if player_ref and is_instance_valid(player_ref):
		return (player_ref.global_position - global_position).normalized()
	return Vector2.LEFT
