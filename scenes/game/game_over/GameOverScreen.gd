extends Control
## GameOverScreen — shown when the player loses all lives.

@onready var _score_label: Label = $Center/VBox/ScoreLabel
@onready var _hi_label: Label = $Center/VBox/HiScoreLabel
@onready var _continue_btn: Button = $Center/VBox/ContinueButton
@onready var _retry_btn: Button = $Center/VBox/RetryButton
@onready var _menu_btn: Button = $Center/VBox/MenuButton

func _ready() -> void:
	_score_label.text = "SCORE: %d" % GameState.score
	_hi_label.text = "BEST: %d" % GameState.high_score
	_continue_btn.pressed.connect(GameState.continue_game)
	_retry_btn.pressed.connect(GameState.start_boss_rush if GameState.boss_rush_mode else GameState.start_game)
	_menu_btn.pressed.connect(GameState.go_to_menu)

	if not GameState.can_continue():
		_continue_btn.text = "CONTINUE (LOCKED ON HARD)"
		_continue_btn.disabled = true
		_continue_btn.modulate = Color(1, 1, 1, 0.5)
	AudioManager.stop_music()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 1.0)
