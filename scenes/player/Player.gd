class_name Player
extends CharacterBody2D
## Player — controlled by single-finger touch / mouse or keyboard.
## Features weapon system, charge weapons, landscape hazard collision,
## and safe corridor respawn with invincibility period.

signal hit(lives_remaining: int)
signal died

# ── Weapon system ─────────────────────────────────────────────
const WEAPON_SCRIPTS: Array[String] = [
	"res://scenes/player/weapons/WeaponVulcan.gd",
	"res://scenes/player/weapons/WeaponLaser.gd",
	"res://scenes/player/weapons/WeaponPlasma.gd",
	"res://scenes/player/weapons/WeaponMissile.gd",
	"res://scenes/player/weapons/WeaponWave.gd",
	"res://scenes/player/weapons/WeaponBouncer.gd",
	"res://scenes/player/weapons/WeaponDrill.gd",
	"res://scenes/player/weapons/WeaponRicochet.gd",
	"res://scenes/player/weapons/WeaponGravity.gd",
	"res://scenes/player/weapons/WeaponLightning.gd",
]

const WEAPON_DATA_PATHS: Array[String] = [
	"res://resources/weapons/weapon_vulcan.tres",
	"res://resources/weapons/weapon_laser.tres",
	"res://resources/weapons/weapon_plasma.tres",
	"res://resources/weapons/weapon_missile.tres",
	"res://resources/weapons/weapon_wave.tres",
	"res://resources/weapons/weapon_bouncer.tres",
	"res://resources/weapons/weapon_drill.tres",
	"res://resources/weapons/weapon_ricochet.tres",
	"res://resources/weapons/weapon_gravity.tres",
	"res://resources/weapons/weapon_lightning.tres",
]

## Set by Game.gd — the Node that all player bullets are added to
var bullet_container: Node = null

## Set by Game.gd — reference to HUD for charge bar updates
var hud: Node = null

## Set by LevelGenerator — corridor Y bounds for clamping
var corridor_top: float = 120.0
var corridor_bottom: float = 960.0

# ── Config ────────────────────────────────────────────────────
const MOVE_SMOOTH: float = 16.0
const SHIP_MARGIN: float = 24.0
const INVINCIBILITY_TIME: float = 3.0
const CHARGE_TIME: float = 3.0

# ── State ──────────────────────────────────────────────────────
var _current_weapon: WeaponBase = null
var _target_pos: Vector2 = Vector2(280.0, 540.0)
var _is_invincible: bool = false
var _invincibility_timer: float = 0.0
var _is_charging: bool = false
var _charge_level: float = 0.0
var _auto_fire: bool = true
var _is_dead: bool = false

# ── Node refs ─────────────────────────────────────────────────
@onready var _muzzle: Marker2D = $MuzzlePoint
@onready var _sprite: Sprite2D = $Visual/Sprite2D
@onready var _thruster_poly: Polygon2D = $Visual/ThrusterPoly
@onready var _shield_ring: Polygon2D = $Visual/ShieldRing
@onready var _hurtbox: Area2D = $HurtBox

func _ready() -> void:
	add_to_group("player")
	_hurtbox.add_to_group("player_hurtbox")
	global_position = Vector2(280.0, 540.0)
	_target_pos = global_position

	# Connect InputManager
	InputManager.move_input.connect(_on_move_input)
	InputManager.charge_start.connect(_on_charge_start)
	InputManager.charge_end.connect(_on_charge_end)

	# Connect GameState weapon changes
	GameState.weapon_changed.connect(_on_weapon_changed)

	# Equip starting weapon
	_equip_weapon(GameState.current_weapon_index)

func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	# Smooth movement toward touch/mouse position
	global_position = global_position.lerp(_target_pos, MOVE_SMOOTH * delta)

	# Free flight range across screen
	global_position.x = clamp(global_position.x, 60.0, 1840.0)

	# Landscape boundary collision check
	if not _is_invincible:
		if global_position.y <= corridor_top + 10.0 or global_position.y >= corridor_bottom - 10.0:
			_take_hit("landscape")

	global_position.y = clamp(global_position.y,
			corridor_top + SHIP_MARGIN, corridor_bottom - SHIP_MARGIN)

	# Primary fire: only when finger/mouse is touching screen and not charging
	if InputManager.is_touching() and not _is_charging and _current_weapon != null:
		_current_weapon.fire(_muzzle.global_position)

	# Weapon charge accumulation
	if _is_charging:
		var weapon_charge_time := CHARGE_TIME
		if _current_weapon:
			var data_path: String = WEAPON_DATA_PATHS[GameState.current_weapon_index] \
					if GameState.current_weapon_index < WEAPON_DATA_PATHS.size() else ""
			if ResourceLoader.exists(data_path):
				var data: WeaponData = load(data_path)
				weapon_charge_time = data.charge_time
		_charge_level = min(_charge_level + delta / weapon_charge_time, 1.0)
		if hud:
			hud.set_charge(_charge_level)
			hud.show_charge_bar(true)

	# Invincibility period handling
	if _is_invincible:
		_invincibility_timer -= delta
		# Visual flashing shield & ship transparency
		_sprite.modulate.a = 0.35 + 0.65 * abs(sin(_invincibility_timer * 18.0))
		if _shield_ring:
			_shield_ring.visible = true
			_shield_ring.rotation += delta * 4.0
			_shield_ring.modulate.a = 0.4 + 0.6 * abs(sin(_invincibility_timer * 12.0))
		if _invincibility_timer <= 0.0:
			_is_invincible = false
			_sprite.modulate.a = 1.0
			if _shield_ring:
				_shield_ring.visible = false

	# Keyboard fallback position
	_apply_keyboard_fallback(delta)

	# Thruster animation
	_animate_thruster()

func _apply_keyboard_fallback(delta: float) -> void:
	var kb_dir := InputManager.get_kb_direction()
	if kb_dir != Vector2.ZERO:
		_target_pos += kb_dir * 650.0 * delta
		_target_pos.x = clamp(_target_pos.x, 60.0, 1840.0)
		_target_pos.y = clamp(_target_pos.y, corridor_top + 30.0, corridor_bottom - 30.0)

# ── Input handlers ────────────────────────────────────────────

func _on_move_input(viewport_pos: Vector2) -> void:
	_target_pos = viewport_pos

func _on_charge_start() -> void:
	if _is_dead:
		return
	_is_charging = true
	_charge_level = 0.0
	_auto_fire = false
	if hud:
		hud.show_charge_bar(true)
		hud.set_charge(0.0)

func _on_charge_end() -> void:
	if _is_dead or not _is_charging:
		return
	_is_charging = false
	_auto_fire = true
	if _current_weapon and _charge_level > 0.08:
		_current_weapon.charge_fire(_muzzle.global_position, _charge_level)
	_charge_level = 0.0
	if hud:
		hud.show_charge_bar(false)
		hud.set_charge(0.0)

# ── HurtBox & Damage Handling ─────────────────────────────────

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if (area is Bullet and area.is_enemy_bullet) or area.is_in_group("enemy_bullet") or area.is_in_group("enemy_hurtbox") or area.is_in_group("enemies") or area.is_in_group("bosses"):
		_take_hit("projectile")

func _on_hurtbox_body_entered(body: Node) -> void:
	if body is StaticBody2D or body.name.begins_with("Chunk") or (body.collision_layer & 1) != 0:
		_take_hit("landscape")
	elif body.is_in_group("enemies") or body.is_in_group("bosses"):
		_take_hit("enemy")

func _take_hit(source: String = "") -> void:
	if _is_invincible or _is_dead:
		return

	GameState.lose_life()
	hit.emit(GameState.lives)

	# Hit spark FX
	var fx: Node2D = load("res://scenes/effects/ExplosionFX.tscn").instantiate()
	var parent_node: Node = get_parent() if get_parent() else get_tree().current_scene
	if parent_node:
		parent_node.call_deferred("add_child", fx)
		if fx.has_method("setup"):
			fx.setup(global_position, Color(1.0, 0.4, 0.2), 0.8)

	if GameState.is_game_over:
		_die()
	else:
		_respawn_safe()

func _respawn_safe() -> void:
	_is_invincible = true
	_invincibility_timer = INVINCIBILITY_TIME
	_is_charging = false
	_charge_level = 0.0
	if hud:
		hud.show_charge_bar(false)
		hud.set_charge(0.0)

	# Position in open center of safe corridor
	var safe_y: float = (corridor_top + corridor_bottom) * 0.5
	global_position = Vector2(200.0, safe_y)
	_target_pos = global_position
	velocity = Vector2.ZERO

	# Clear all hostile enemy bullets on screen
	_clear_enemy_bullets_screen()

func grant_invincibility(duration: float = 6.0) -> void:
	_is_invincible = true
	_invincibility_timer = max(_invincibility_timer, duration)

func _clear_enemy_bullets_screen() -> void:
	var enemy_bullets: Array[Node] = get_tree().get_nodes_in_group("enemy_bullet")
	for b in enemy_bullets:
		if is_instance_valid(b):
			b.queue_free()

func _die() -> void:
	_is_dead = true
	_sprite.visible = false
	if _shield_ring:
		_shield_ring.visible = false
	died.emit()
	var fx: Node2D = load("res://scenes/effects/ExplosionFX.tscn").instantiate()
	var parent_node: Node = get_parent() if get_parent() else get_tree().current_scene
	if parent_node:
		parent_node.call_deferred("add_child", fx)
		if fx.has_method("setup"):
			fx.setup(global_position, Color.CYAN, 1.5)
	# Delay then game over scene transition
	await get_tree().create_timer(1.5).timeout
	GameState.go_to_game_over()

# ── Weapon management ─────────────────────────────────────────

func _on_weapon_changed(index: int) -> void:
	_equip_weapon(index)

func _equip_weapon(index: int) -> void:
	if _current_weapon != null:
		_current_weapon.queue_free()
		_current_weapon = null

	if index >= WEAPON_SCRIPTS.size():
		return

	var script: GDScript = load(WEAPON_SCRIPTS[index])
	if script == null:
		return

	var weapon := Node.new()
	weapon.set_script(script)
	add_child(weapon)
	_current_weapon = weapon as WeaponBase
	if _current_weapon == null:
		push_error("Player: weapon script is not a WeaponBase: %s" % WEAPON_SCRIPTS[index])
		return

	_current_weapon.bullet_container = bullet_container

	# Apply WeaponData resource if available
	if index < WEAPON_DATA_PATHS.size() and ResourceLoader.exists(WEAPON_DATA_PATHS[index]):
		var data: WeaponData = load(WEAPON_DATA_PATHS[index])
		_current_weapon.init_from_data(data)

func set_bullet_container(container: Node) -> void:
	bullet_container = container
	if _current_weapon:
		_current_weapon.bullet_container = container

# ── Visual ────────────────────────────────────────────────────

func _animate_thruster() -> void:
	if _thruster_poly == null:
		return
	var flicker: float = 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.025)
	_thruster_poly.scale.x = flicker
