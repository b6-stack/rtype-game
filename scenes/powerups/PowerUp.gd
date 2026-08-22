class_name PowerUp
extends Area2D
## PowerUp — floating item pickup. Supports weapons (0..9), Life Core (+1 HP),
## and Super Invincibility Shield (6s force-field).

var powerup_type: String = "weapon" # "weapon", "life", "shield"
var weapon_index: int = 0
var scroll_speed: float = 180.0

var _sprite: Sprite2D
var _label: Label

const SPRITE_WEAPON := preload("res://assets/sprites/powerup_capsule.png")
const SPRITE_LIFE := preload("res://assets/sprites/powerup_life.png")
const SPRITE_SHIELD := preload("res://assets/sprites/powerup_shield.png")

const WEAPON_COLORS: Array[Color] = [
	Color(0.0, 1.0, 1.0),   # 0 Vulcan     - cyan
	Color(1.0, 0.0, 1.0),   # 1 Laser      - magenta
	Color(0.2, 1.0, 0.3),   # 2 Plasma     - green
	Color(1.0, 0.5, 0.0),   # 3 Missile    - orange
	Color(0.4, 0.6, 1.0),   # 4 Wave       - blue
	Color(1.0, 0.95, 0.1),  # 5 Bouncer    - yellow
	Color(1.0, 0.2, 0.2),   # 6 Drill      - red
	Color(0.8, 0.3, 1.0),   # 7 Ricochet   - violet
	Color(0.2, 0.4, 1.0),   # 8 Gravity    - deep blue
	Color(1.0, 1.0, 1.0),   # 9 Lightning  - bright white
]

const WEAPON_LETTERS: Array[String] = [
	"V","L","P","M","W","B","D","R","G","Z"
]

func _ready() -> void:
	_sprite = $Sprite2D
	_label = $Label
	_apply_style()
	collision_layer = 64   # bit 6 = powerups
	collision_mask  = 2    # bit 1 = player

func setup(w_index: int, speed: float, p_type: String = "weapon") -> void:
	weapon_index = w_index
	scroll_speed = speed
	powerup_type = p_type
	if is_inside_tree():
		_apply_style()

func _physics_process(delta: float) -> void:
	global_position.x -= scroll_speed * delta
	# Gentle sine bob and slow rotation
	global_position.y += sin(Time.get_ticks_msec() * 0.004) * 0.9
	if _sprite:
		_sprite.rotation += delta * 1.5
		# Pulsing energy glow
		var pulse: float = 0.90 + 0.15 * sin(Time.get_ticks_msec() * 0.008)
		if powerup_type == "weapon":
			_sprite.scale = Vector2(0.065, 0.065) * pulse
		elif powerup_type == "life":
			_sprite.scale = Vector2(0.060, 0.060) * pulse
		else:
			_sprite.scale = Vector2(0.055, 0.055) * pulse

	if global_position.x < -100.0:
		queue_free()

func _apply_style() -> void:
	if _sprite == null or _label == null:
		return

	if powerup_type == "life" or weapon_index == 100:
		powerup_type = "life"
		_sprite.texture = SPRITE_LIFE
		_sprite.modulate = Color.WHITE
		_label.text = "+1"
		_label.modulate = Color(0.2, 1.0, 0.4)
	elif powerup_type == "shield" or weapon_index == 101:
		powerup_type = "shield"
		_sprite.texture = SPRITE_SHIELD
		_sprite.modulate = Color.WHITE
		_label.text = "SHD"
		_label.modulate = Color(0.2, 0.9, 1.0)
	else:
		powerup_type = "weapon"
		_sprite.texture = SPRITE_WEAPON
		var col := WEAPON_COLORS[weapon_index] if weapon_index < WEAPON_COLORS.size() else Color.WHITE
		_sprite.modulate = col
		if weapon_index < WEAPON_LETTERS.size():
			_label.text = WEAPON_LETTERS[weapon_index]
		_label.modulate = Color.WHITE

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_hurtbox") or area.owner is Player or area.get_parent() is Player:
		_collect()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") or body is Player:
		_collect()

func _collect() -> void:
	AudioManager.play_pickup_sfx()
	if powerup_type == "life":
		GameState.gain_life()
	elif powerup_type == "shield":
		var players: Array[Node] = get_tree().get_nodes_in_group("player")
		for p in players:
			if is_instance_valid(p) and p.has_method("grant_invincibility"):
				p.grant_invincibility(6.0)
	else:
		GameState.set_weapon(weapon_index)

	_spawn_collect_fx()
	queue_free()

func _spawn_collect_fx() -> void:
	if not is_inside_tree():
		return
	var fx: Node2D = load("res://scenes/effects/PickupFX.gd").new()
	var parent_node: Node = get_parent() if get_parent() else get_tree().current_scene
	if parent_node:
		parent_node.call_deferred("add_child", fx)
		if fx.has_method("setup_custom"):
			if powerup_type == "life":
				fx.setup_custom(global_position, "1-UP (+1 LIFE)", Color(0.2, 1.0, 0.4))
			elif powerup_type == "shield":
				fx.setup_custom(global_position, "INVINCIBLE (6s)", Color(0.2, 0.8, 1.0))
			else:
				fx.setup(global_position, weapon_index)
		elif fx.has_method("setup"):
			fx.setup(global_position, weapon_index)
