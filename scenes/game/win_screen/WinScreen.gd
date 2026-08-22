extends Control
## WinScreen — displayed after defeating all 10 bosses (normal run or Boss Rush).

@onready var _title_label: Label = $Center/VBox/YouWinLabel
@onready var _score_label: Label = $Center/VBox/FinalScoreLabel
@onready var _hi_label: Label = $Center/VBox/HiScoreLabel
@onready var _unlock_note_label: Label = $Center/VBox/UnlockNoteLabel
@onready var _play_again_btn: Button = $Center/VBox/PlayAgainButton
@onready var _menu_btn: Button = $Center/VBox/MenuButton

func _ready() -> void:
	_score_label.text = "FINAL SCORE: %d" % GameState.score
	_hi_label.text = "HIGH SCORE: %d" % GameState.high_score
	_menu_btn.pressed.connect(GameState.go_to_menu)

	# Unlocks are only earned on a legitimate run — cheats (one-shot or
	# persistent toggles) block both, rather than trivializing the reward.
	if not GameState.is_scoring_disabled():
		GameState.unlock_boss_rush()
		if GameState.boss_rush_mode:
			GameState.unlock_ultra_mode()
	else:
		_unlock_note_label.visible = true

	if GameState.boss_rush_mode:
		_title_label.text = "BOSS RUSH CLEAR!"
		_play_again_btn.pressed.connect(GameState.start_boss_rush)
	else:
		_play_again_btn.pressed.connect(GameState.start_game)

	AudioManager.play_victory_music()

	# Animate
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 1.5)
