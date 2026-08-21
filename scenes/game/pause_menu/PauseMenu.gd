extends CanvasLayer
## PauseMenu — overlay shown when the game is paused.

@onready var _resume_btn: Button = $Overlay/Panel/VBox/ResumeButton
@onready var _quit_btn: Button = $Overlay/Panel/VBox/QuitButton

signal resume_requested
signal quit_requested

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resume_btn.pressed.connect(_on_resume_pressed)
	_quit_btn.pressed.connect(_on_quit_pressed)
	visible = false

func _on_resume_pressed() -> void:
	hide_menu()
	resume_requested.emit()

func _on_quit_pressed() -> void:
	hide_menu()
	quit_requested.emit()
	GameState.go_to_menu()

func show_menu() -> void:
	visible = true
	get_tree().paused = true
	_resume_btn.grab_focus()

func hide_menu() -> void:
	visible = false
	get_tree().paused = false
