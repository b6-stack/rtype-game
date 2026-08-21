extends Control
## WinScreen — displayed after defeating all 8 bosses.

@onready var _score_label: Label = $Center/VBox/FinalScoreLabel
@onready var _hi_label: Label = $Center/VBox/HiScoreLabel
@onready var _play_again_btn: Button = $Center/VBox/PlayAgainButton
@onready var _menu_btn: Button = $Center/VBox/MenuButton

func _ready() -> void:
	_score_label.text = "FINAL SCORE: %d" % GameState.score
	_hi_label.text = "HIGH SCORE: %d" % GameState.high_score
	_play_again_btn.pressed.connect(GameState.start_game)
	_menu_btn.pressed.connect(GameState.go_to_menu)
	# Animate
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 1.5)
