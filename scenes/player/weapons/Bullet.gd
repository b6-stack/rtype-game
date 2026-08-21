class_name Bullet
extends Area2D
## Bullet — projectile used by weapons and enemies.
## Compact, sleek arcade laser bolts, micro-missiles, and plasma pellets.

signal hit_target(position: Vector2)

var velocity: Vector2 = Vector2.RIGHT * 800.0
var damage: int = 5
var is_enemy_bullet: bool = false

const MAX_LIFETIME: float = 4.0
var _lifetime: float = 0.0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _poly: Polygon2D = $Polygon2D
@onready var _glow_core: Polygon2D = $GlowCore

const SPRITE_PLASMA := preload("res://assets/sprites/bullet_plasma_orb.png")
const SPRITE_MISSILE := preload("res://assets/sprites/bullet_missile_rocket.png")

var BASE_POINTS: PackedVector2Array = PackedVector2Array([
	Vector2(6, 0), Vector2(2, -2), Vector2(-3, -1.5),
	Vector2(-4, 0), Vector2(-3, 1.5), Vector2(2, 2)
])

func _ready() -> void:
	pass

func setup(vel: Vector2, col: Color, dmg: int,
		size_mult: float = 1.0, enemy: bool = false, sprite_type: String = "") -> void:
	velocity = vel
	damage = dmg
	is_enemy_bullet = enemy

	if _poly == null:
		_poly = $Polygon2D
	if _glow_core == null:
		_glow_core = $GlowCore
	if _sprite == null:
		_sprite = $Sprite2D

	if sprite_type == "plasma" or size_mult >= 2.0:
		if _sprite and SPRITE_PLASMA:
			_sprite.texture = SPRITE_PLASMA
			_sprite.scale = Vector2(0.026, 0.026) * size_mult
			_sprite.flip_h = true
			_sprite.modulate = col
			_sprite.visible = true
			if _poly: _poly.visible = false
			if _glow_core: _glow_core.visible = false
	elif sprite_type == "missile":
		if _sprite and SPRITE_MISSILE:
			_sprite.texture = SPRITE_MISSILE
			_sprite.scale = Vector2(0.028, 0.028) * size_mult
			_sprite.flip_h = false
			_sprite.modulate = Color.WHITE
			_sprite.visible = true
			if _poly: _poly.visible = false
			if _glow_core: _glow_core.visible = false
	else:
		# Sleek compact glowing energy laser bolt
		if _sprite: _sprite.visible = false
		if _poly:
			_poly.visible = true
			_poly.color = col
			var pts := PackedVector2Array()
			for p in BASE_POINTS:
				pts.append(p * size_mult)
			_poly.polygon = pts
		if _glow_core:
			_glow_core.visible = true
			_glow_core.scale = Vector2.ONE * size_mult
			_glow_core.modulate = col.lightened(0.85)

	rotation = velocity.angle()
	
	if enemy:
		collision_layer = 8    # layer 4 (bit 3) = enemy bullet
		collision_mask  = 2    # layer 2 (bit 1) = player
		add_to_group("enemy_bullet")
	else:
		collision_layer = 4    # layer 3 (bit 2) = player bullet
		collision_mask  = 16 | 32 # layer 5 (enemies) + layer 6 (bosses)
		add_to_group("player_bullet")

func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	_lifetime += delta
	var screen_width: float = get_viewport_rect().size.x
	if _lifetime >= MAX_LIFETIME or global_position.x > screen_width + 100.0 or global_position.x < -100.0:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	_handle_collision(area)

func _on_body_entered(body: Node2D) -> void:
	_handle_collision(body)

func _handle_collision(target: Node) -> void:
	if not is_instance_valid(target):
		return
		
	if is_enemy_bullet:
		if target.is_in_group("player") or target.name == "Player" or target.name == "HurtBox":
			var p: Node = target if target.is_in_group("player") else target.get_parent()
			if p and p.has_method("_take_hit"):
				p._take_hit("projectile")
			hit_target.emit(global_position)
			queue_free()
	else:
		# Player bullet hitting enemy or boss
		var hit_target_entity: Node = target
		if not hit_target_entity.has_method("take_damage") and target.get_parent():
			hit_target_entity = target.get_parent()
			
		if hit_target_entity and hit_target_entity.has_method("take_damage"):
			hit_target_entity.take_damage(damage)
			hit_target.emit(global_position)
			queue_free()
		elif target.is_in_group("enemies") or target.is_in_group("bosses"):
			if target.has_method("take_damage"):
				target.take_damage(damage)
			hit_target.emit(global_position)
			queue_free()
