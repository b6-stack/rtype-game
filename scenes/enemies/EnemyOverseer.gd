class_name EnemyOverseer
extends EnemyBase
## EnemyOverseer — stays at the back, periodically buffs nearby enemies' speed and fires targeted shots.

var _buff_timer: float = 0.0
const BUFF_INTERVAL: float = 3.5

func _ready() -> void:
	max_health = 80
	score_value = 600
	move_speed = 100.0
	shoot_cooldown = 2.5
	bullet_color = Color(1.0, 0.8, 0.2)
	bullet_speed = 420.0
	bullet_damage = 2
	enemy_color = Color(1.0, 0.85, 0.2)
	size_scale = 1.3
	super._ready()

func _move(delta: float) -> void:
	# Fly in from right, stop at x = 1500
	if global_position.x > 1500.0:
		velocity.x = -move_speed
	else:
		velocity.x = 0.0
		# Gentle vertical hover
		velocity.y = sin(_time * 2.0) * 40.0

	_buff_timer += delta
	if _buff_timer >= BUFF_INTERVAL:
		_buff_timer = 0.0
		_buff_allies()

func _shoot() -> void:
	_fire_at_player(bullet_speed, bullet_damage, bullet_color)

func _buff_allies() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if e != self and is_instance_valid(e) and global_position.distance_to(e.global_position) < 500.0:
			if "move_speed" in e:
				e.move_speed = min(e.move_speed * 1.2, 350.0)
