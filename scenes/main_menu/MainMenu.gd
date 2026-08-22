extends Control
## MainMenu — title screen with Start Game and Quit buttons.

@onready var _start_btn: Button = $Center/VBox/StartButton
@onready var _boss_rush_btn: Button = $Center/VBox/BossRushButton
@onready var _quit_btn: Button = $Center/VBox/QuitButton
@onready var _hi_score_label: Label = $Center/VBox/HiScoreLabel
@onready var _star_container: Node2D = $StarContainer
@onready var _version_label: Label = $Center/VBox/VersionLabel
@onready var _difficulty_buttons: Array[Button] = [
	$Center/VBox/DifficultyRow/EasyButton,
	$Center/VBox/DifficultyRow/NormalButton,
	$Center/VBox/DifficultyRow/HardButton,
]

const STAR_COUNT: int = 120
var _stars: Array[Dictionary] = []

func _ready() -> void:
	_start_btn.pressed.connect(_on_start_pressed)
	_boss_rush_btn.pressed.connect(_on_boss_rush_pressed)
	_quit_btn.pressed.connect(_on_quit_pressed)
	_hi_score_label.text = "HIGH SCORE: %d" % GameState.high_score
	_version_label.text = "v%s" % GameState.APP_VERSION
	_setup_difficulty_buttons()
	_generate_stars()
	# Animate title in
	$Center/VBox/TitleLabel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property($Center/VBox/TitleLabel, "modulate:a", 1.0, 1.2)
	tw.parallel().tween_property($Center/VBox/TitleLabel, "position:y",
			$Center/VBox/TitleLabel.position.y, 0.8).from($Center/VBox/TitleLabel.position.y - 40)

func _process(delta: float) -> void:
	_scroll_stars(delta)

func _on_start_pressed() -> void:
	GameState.start_game()

func _on_boss_rush_pressed() -> void:
	GameState.start_boss_rush()

func _on_quit_pressed() -> void:
	get_tree().quit()

# ── Difficulty selector ──────────────────────────────────────

func _setup_difficulty_buttons() -> void:
	for i in _difficulty_buttons.size():
		var btn: Button = _difficulty_buttons[i]
		btn.button_pressed = (i == GameState.difficulty)
		btn.pressed.connect(_on_difficulty_pressed.bind(i))

func _on_difficulty_pressed(index: int) -> void:
	GameState.set_difficulty(index)

# ── Starfield ─────────────────────────────────────────────────

func _generate_stars() -> void:
	_stars.clear()
	var screen_size: Vector2 = get_viewport_rect().size
	for i in STAR_COUNT:
		_stars.append({
			"pos": Vector2(randf() * screen_size.x, randf() * screen_size.y),
			"speed": randf_range(30.0, 150.0),
			"size": randf_range(1.0, 3.5),
			"brightness": randf_range(0.5, 1.0),
		})
	_star_container.queue_redraw()

func _scroll_stars(delta: float) -> void:
	var screen_size: Vector2 = get_viewport_rect().size
	for s in _stars:
		s["pos"].x -= s["speed"] * delta
		if s["pos"].x < -5.0:
			s["pos"].x = screen_size.x + 5.0
			s["pos"].y = randf() * screen_size.y
	_star_container.queue_redraw()
