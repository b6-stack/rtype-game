class_name Bullet
extends Area2D
## Bullet — multi-archetype projectile used by weapons and enemies.
## Supports 10 distinct custom geometry archetypes, sprites, piercing, and particle trails.

signal hit_target(position: Vector2)

var velocity: Vector2 = Vector2.RIGHT * 800.0
var damage: int = 5
var is_enemy_bullet: bool = false
var bullet_type: String = "generic"
var pierce_count: int = 0

const MAX_LIFETIME: float = 4.0
var _lifetime: float = 0.0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _poly: Polygon2D = $Polygon2D
@onready var _glow_core: Polygon2D = $GlowCore

const SPRITE_PLASMA := preload("res://assets/sprites/bullet_plasma_orb.png")
const SPRITE_MISSILE := preload("res://assets/sprites/bullet_missile_rocket.png")

# Geometry archetypes for weapons
const SHAPES: Dictionary = {
	"vulcan": [
		[Vector2(10, 0), Vector2(3, -2.5), Vector2(-7, -1.2), Vector2(-10, 0), Vector2(-7, 1.2), Vector2(3, 2.5)],
		[Vector2(6, 0), Vector2(1, -1.0), Vector2(-4, 0), Vector2(1, 1.0)]
	],
	"laser": [
		[Vector2(24, -2.5), Vector2(24, 2.5), Vector2(-24, 2.5), Vector2(-24, -2.5)],
		[Vector2(22, -1.0), Vector2(22, 1.0), Vector2(-22, 1.0), Vector2(-22, -1.0)]
	],
	"wave": [
		[Vector2(8, -10), Vector2(13, 0), Vector2(8, 10), Vector2(2, 6), Vector2(5, 0), Vector2(2, -6)],
		[Vector2(6, -6), Vector2(9, 0), Vector2(6, 6), Vector2(3, 3), Vector2(5, 0), Vector2(3, -3)]
	],
	"bouncer": [
		[Vector2(7, 0), Vector2(3.5, -6), Vector2(-3.5, -6), Vector2(-7, 0), Vector2(-3.5, 6), Vector2(3.5, 6)],
		[Vector2(3.5, 0), Vector2(1.8, -3), Vector2(-1.8, -3), Vector2(-3.5, 0), Vector2(-1.8, 3), Vector2(1.8, 3)]
	],
	"drill": [
		[Vector2(16, 0), Vector2(-8, -8), Vector2(-4, -3), Vector2(-10, 0), Vector2(-4, 3), Vector2(-8, 8)],
		[Vector2(10, 0), Vector2(-4, -4), Vector2(-2, 0), Vector2(-4, 4)]
	],
	"ricochet": [
		[Vector2(9, 0), Vector2(0, -7), Vector2(-9, 0), Vector2(0, 7)],
		[Vector2(5, 0), Vector2(0, -3.5), Vector2(-5, 0), Vector2(0, 3.5)]
	],
	"gravity": [
		[Vector2(9, 0), Vector2(6, -7), Vector2(0, -9), Vector2(-6, -7), Vector2(-9, 0), Vector2(-6, 7), Vector2(0, 9), Vector2(6, 7)],
		[Vector2(4.5, 0), Vector2(3, -3.5), Vector2(0, -4.5), Vector2(-3, -3.5), Vector2(-4.5, 0), Vector2(-3, 3.5), Vector2(0, 4.5), Vector2(3, 3.5)]
	],
	"lightning": [
		[Vector2(13, 0), Vector2(4, -6), Vector2(2, -1.5), Vector2(-6, -7), Vector2(-2, 0), Vector2(-11, 7), Vector2(-2, 2.5), Vector2(3, 6)],
		[Vector2(8, 0), Vector2(2, -3), Vector2(0, 0), Vector2(-4, -3.5), Vector2(-1, 0), Vector2(-7, 3.5), Vector2(0, 1.5), Vector2(1.5, 3)]
	],
	"generic": [
		[Vector2(6, 0), Vector2(2, -2), Vector2(-3, -1.5), Vector2(-4, 0), Vector2(-3, 1.5), Vector2(2, 2)],
		[Vector2(3, 0), Vector2(0, -1), Vector2(-2, 0), Vector2(0, 1)]
	]
}

func _ready() -> void:
	pass

func setup(vel: Vector2, col: Color, dmg: int,
		size_mult: float = 1.0, enemy: bool = false, sprite_type: String = "", pierces: int = 0) -> void:
	velocity = vel
	damage = dmg
	is_enemy_bullet = enemy
	bullet_type = sprite_type if sprite_type != "" else ("generic" if enemy else "vulcan")
	pierce_count = pierces

	if _poly == null: _poly = $Polygon2D
	if _glow_core == null: _glow_core = $GlowCore
	if _sprite == null: _sprite = $Sprite2D

	if sprite_type == "plasma" or size_mult >= 2.2:
		if _sprite and SPRITE_PLASMA:
			_sprite.texture = SPRITE_PLASMA
			_sprite.scale = Vector2(0.028, 0.028) * size_mult
			_sprite.flip_h = true
			_sprite.modulate = col
			_sprite.visible = true
			if _poly: _poly.visible = false
			if _glow_core: _glow_core.visible = false
	elif sprite_type == "missile":
		if _sprite and SPRITE_MISSILE:
			_sprite.texture = SPRITE_MISSILE
			_sprite.scale = Vector2(0.030, 0.030) * size_mult
			_sprite.flip_h = false
			_sprite.modulate = Color.WHITE
			_sprite.visible = true
			if _poly: _poly.visible = false
			if _glow_core: _glow_core.visible = false
	else:
		if _sprite: _sprite.visible = false
		var key: String = sprite_type if SHAPES.has(sprite_type) else ("generic" if enemy else "vulcan")
		var shape_data: Array = SHAPES[key]
		if _poly:
			_poly.visible = true
			_poly.color = col
			var pts := PackedVector2Array()
			for p in shape_data[0]:
				pts.append(p * size_mult)
			_poly.polygon = pts
		if _glow_core:
			_glow_core.visible = true
			var core_pts := PackedVector2Array()
			for p in shape_data[1]:
				core_pts.append(p * size_mult)
			_glow_core.polygon = core_pts
			_glow_core.modulate = Color.WHITE.lerp(col, 0.2)

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

	# Special animation twists per weapon
	if bullet_type == "drill" and _poly:
		_poly.rotation += delta * 20.0
	elif bullet_type == "gravity" and _poly:
		_poly.rotation += delta * 12.0
	elif bullet_type == "lightning" and _poly and randf() < 0.3:
		_poly.scale.y = -_poly.scale.y

	if _lifetime >= MAX_LIFETIME or global_position.x > 2000.0 or global_position.x < -150.0:
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
		# If striking an active force-field or shield barrier, let the shield deflect/absorb
		if target.is_in_group("boss_shield") or target.is_in_group("enemy_shield"):
			return

		# Player bullet hitting enemy or boss core
		var hit_target_entity: Node = target
		if not hit_target_entity.has_method("take_damage") and target.get_parent():
			hit_target_entity = target.get_parent()

		if hit_target_entity and hit_target_entity.has_method("take_damage"):
			hit_target_entity.take_damage(damage)
			hit_target.emit(global_position)
			if pierce_count > 0:
				pierce_count -= 1
			else:
				queue_free()
		elif target.is_in_group("enemies") or target.is_in_group("bosses"):
			if target.has_method("take_damage"):
				target.take_damage(damage)
			hit_target.emit(global_position)
			if pierce_count > 0:
				pierce_count -= 1
			else:
				queue_free()
