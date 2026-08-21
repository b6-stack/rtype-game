class_name WeaponMissile
extends WeaponBase
## WeaponMissile — fires homing missiles that lock onto nearest enemies.

func _do_fire(spawn_pos: Vector2) -> void:
	var b: Bullet = _spawn_bullet(spawn_pos, Vector2.RIGHT * bullet_speed, bullet_color, damage, 1.0, "missile")
	if b:
		_attach_homing(b)

func _do_charge_fire(spawn_pos: Vector2, charge_level: float) -> void:
	var count: int = 2 + int(charge_level * 2) # 3-4 missiles
	for i in count:
		var angle: float = randf_range(-30.0, 30.0)
		var vel: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(angle)) * bullet_speed
		var b: Bullet = _spawn_bullet(spawn_pos, vel, bullet_color.lightened(0.2), int(damage * 1.5), 1.2, "missile")
		if b:
			_attach_homing(b)

func _attach_homing(b: Bullet) -> void:
	var steer_timer := Timer.new()
	steer_timer.wait_time = 0.05
	steer_timer.autostart = true
	b.add_child(steer_timer)
	steer_timer.timeout.connect(func():
		if not is_instance_valid(b):
			return
		var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
		var bosses: Array[Node] = get_tree().get_nodes_in_group("bosses")
		var targets: Array[Node] = enemies + bosses
		var closest: Node2D = null
		var min_dist: float = 99999.0
		for t in targets:
			if is_instance_valid(t) and t is Node2D:
				var t_node: Node2D = t as Node2D
				if t_node.global_position.x > b.global_position.x - 50.0:
					var d: float = b.global_position.distance_to(t_node.global_position)
					if d < min_dist:
						min_dist = d
						closest = t_node
		if closest:
			var desired: Vector2 = (closest.global_position - b.global_position).normalized() * b.velocity.length()
			b.velocity = b.velocity.lerp(desired, 0.22)
			b.rotation = b.velocity.angle()
	)
