extends Node
## InputManager — translates multi-touch events into game actions.
## Primary finger: moves the player (position-based).
## Secondary finger: hold = charge weapon, release = fire charged shot.
## Falls back gracefully to mouse/keyboard for editor testing.

signal move_input(viewport_pos: Vector2)
signal charge_start
signal charge_end
@warning_ignore("unused_signal")
signal fire_pressed

# ── Touch state ──────────────────────────────────────────────
var _primary_id: int = -1
var _secondary_id: int = -1
var _primary_viewport_pos: Vector2 = Vector2(-1.0, -1.0)
var _is_touching: bool = false
var _is_charging: bool = false

# Keyboard/mouse fallback state
var _kb_direction: Vector2 = Vector2.ZERO
var _mouse_active: bool = false
var _mouse_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	set_process_input(true)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_on_drag(event as InputEventScreenDrag)
	# Keyboard fallback for PC editor testing
	elif event is InputEventKey:
		_on_key(event as InputEventKey)
	elif event is InputEventMouseButton:
		_on_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_on_mouse_motion(event as InputEventMouseMotion)

# ── Touch handlers ───────────────────────────────────────────

func _is_in_ui_dead_zone(pos: Vector2) -> bool:
	# Top HUD region (Y < 105.0) containing enlarged 2x Pause button, Score, and Goal bar
	if pos.y < 105.0:
		return true
	# Bottom HUD Charge bar region (Y > 1000.0)
	if pos.y > 1000.0:
		return true
	return false

func _on_touch(ev: InputEventScreenTouch) -> void:
	if ev.pressed:
		if _primary_id == -1:
			_primary_id = ev.index
			_primary_viewport_pos = _screen_to_viewport(ev.position)
			_is_touching = true
			if not _is_in_ui_dead_zone(_primary_viewport_pos):
				move_input.emit(_primary_viewport_pos)
		elif _secondary_id == -1 and ev.index != _primary_id:
			_secondary_id = ev.index
			if not _is_charging:
				_is_charging = true
				charge_start.emit()
	else:
		if ev.index == _primary_id:
			_primary_id = -1
			_is_touching = false
		elif ev.index == _secondary_id:
			_secondary_id = -1
			if _is_charging:
				_is_charging = false
				charge_end.emit()

func _on_drag(ev: InputEventScreenDrag) -> void:
	if ev.index == _primary_id:
		_primary_viewport_pos = _screen_to_viewport(ev.position)
		if not _is_in_ui_dead_zone(_primary_viewport_pos):
			move_input.emit(_primary_viewport_pos)

# ── Keyboard/mouse fallback ──────────────────────────────────

func _process(_delta: float) -> void:
	# Only used for PC keyboard fallback
	var dir := Vector2.ZERO
	if Input.is_action_pressed("move_right"): dir.x += 1.0
	if Input.is_action_pressed("move_left"):  dir.x -= 1.0
	if Input.is_action_pressed("move_down"):  dir.y += 1.0
	if Input.is_action_pressed("move_up"):    dir.y -= 1.0
	if dir != Vector2.ZERO:
		_kb_direction = dir.normalized()
	else:
		_kb_direction = Vector2.ZERO

	if Input.is_action_just_pressed("charge") and not _is_charging:
		_is_charging = true
		charge_start.emit()
	if Input.is_action_just_released("charge") and _is_charging:
		_is_charging = false
		charge_end.emit()

func _on_mouse_button(ev: InputEventMouseButton) -> void:
	if ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_mouse_active = true
			_mouse_pos = ev.position
			var vp_pos := get_viewport().get_mouse_position()
			if not _is_in_ui_dead_zone(vp_pos):
				move_input.emit(vp_pos)
		else:
			_mouse_active = false
	elif ev.button_index == MOUSE_BUTTON_RIGHT or ev.button_index == MOUSE_BUTTON_MIDDLE:
		if ev.pressed:
			if not _is_charging:
				_is_charging = true
				charge_start.emit()
		else:
			if _is_charging:
				_is_charging = false
				charge_end.emit()

func _on_mouse_motion(ev: InputEventMouseMotion) -> void:
	_mouse_pos = ev.position
	if _mouse_active or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var vp_pos := get_viewport().get_mouse_position()
		if not _is_in_ui_dead_zone(vp_pos):
			move_input.emit(vp_pos)

func _on_key(_ev: InputEventKey) -> void:
	pass  # handled by Input.is_action_pressed in _process

# ── Accessors ────────────────────────────────────────────────

func get_primary_viewport_pos() -> Vector2:
	return _primary_viewport_pos

func get_kb_direction() -> Vector2:
	return _kb_direction

func is_touching() -> bool:
	return _is_touching or _mouse_active or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_action_pressed("fire")

func is_charging() -> bool:
	return _is_charging

# ── Helpers ──────────────────────────────────────────────────

func _screen_to_viewport(screen_pos: Vector2) -> Vector2:
	var vp := get_viewport()
	if vp:
		return vp.get_canvas_transform().affine_inverse() * screen_pos
	return screen_pos
