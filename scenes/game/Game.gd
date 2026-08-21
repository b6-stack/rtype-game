extends Node2D
## Game — root scene for active gameplay.
## Wires together: LevelGenerator, Player, EnemySpawner, BossManager,
## PowerUpSpawner, HUD, PauseMenu.

const SCROLL_SPEED_BASE: float = 180.0
const SCROLL_SPEED_INCREMENT: float = 18.0  # extra px/s per level

@onready var _background: Node2D = $ScrollingBackground
@onready var _chunk_parent: Node2D = $World/Chunks
@onready var _entity_parent: Node2D = $Entities
@onready var _player_bullets: Node2D = $Entities/PlayerBullets
@onready var _enemy_bullets: Node2D = $Entities/EnemyBullets
@onready var _enemies_node: Node2D = $Entities/Enemies
@onready var _bosses_node: Node2D = $Entities/Bosses
@onready var _powerups_node: Node2D = $Entities/PowerUps
@onready var _player: Player = $Entities/Player
@onready var _hud: Node = $HUD
@onready var _pause_menu: Node = $PauseMenu
@onready var _level_gen: LevelGenerator = $LevelGenerator
@onready var _enemy_spawner: EnemySpawner = $EnemySpawner
@onready var _boss_manager: BossManager = $BossManager
@onready var _powerup_spawner: PowerUpSpawner = $PowerUpSpawner
@onready var _boss_bar_panel: PanelContainer = $HUD/BossBarPanel
@onready var _boss_bar: ProgressBar = $HUD/BossBarPanel/VBox/BossBar
@onready var _boss_name_label: Label = $HUD/BossBarPanel/VBox/BossNameLabel

var _scroll_speed: float = SCROLL_SPEED_BASE

func _ready() -> void:
	_scroll_speed = SCROLL_SPEED_BASE + (GameState.level - 1) * SCROLL_SPEED_INCREMENT

	# Wire HUD pause button
	_hud.pause_requested.connect(_on_pause_requested)
	_pause_menu.resume_requested.connect(_on_resume)
	_pause_menu.quit_requested.connect(_on_quit)

	# GameState
	GameState.game_over.connect(_on_game_over)

	# Inject dependencies into spawners
	_enemy_spawner.enemy_parent   = _enemies_node
	_enemy_spawner.bullet_container = _enemy_bullets
	_enemy_spawner.player_ref     = _player
	_enemy_spawner.powerup_spawner = _powerup_spawner

	_boss_manager.boss_parent     = _bosses_node
	_boss_manager.bullet_container = _enemy_bullets
	_boss_manager.player_ref      = _player
	_boss_manager.level_generator = _level_gen
	_boss_manager.powerup_spawner = _powerup_spawner
	_boss_manager.hud             = self

	_powerup_spawner.powerup_parent = _powerups_node
	_powerup_spawner.scroll_speed   = _scroll_speed

	# Inject into level gen
	_level_gen.chunk_parent     = _chunk_parent
	_level_gen.enemy_spawner    = _enemy_spawner
	_level_gen.powerup_spawner  = _powerup_spawner
	_level_gen.boss_trigger_reached.connect(_boss_manager.trigger_boss)

	# Inject into player
	_player.set_bullet_container(_player_bullets)
	_player.hud = _hud

	# Boss bar starts hidden
	if _boss_bar_panel:
		_boss_bar_panel.visible = false

	# Start level
	_level_gen.initialize(GameState.level, _scroll_speed)

func _process(delta: float) -> void:
	# Drive background scroll
	_background.scroll(_scroll_speed, delta)

	# Update player corridor bounds from generator
	var bounds := _level_gen.get_corridor_bounds()
	_player.corridor_top    = bounds.x
	_player.corridor_bottom = bounds.y

	# Pause input
	if Input.is_action_just_pressed("pause_game"):
		_on_pause_requested()

# ── Boss bar helpers (called by BossManager) ──────────────────

func show_boss_bar(boss_name: String, max_hp: int) -> void:
	if _boss_bar_panel == null:
		return
	_boss_bar_panel.visible = true
	_boss_name_label.text = boss_name.to_upper()
	_boss_bar.max_value = max_hp
	_boss_bar.value = max_hp

func update_boss_bar(current: int, maximum: int) -> void:
	if _boss_bar == null:
		return
	_boss_bar.max_value = maximum
	_boss_bar.value = current

func hide_boss_bar() -> void:
	if _boss_bar_panel:
		_boss_bar_panel.visible = false

# ── Pause / quit ──────────────────────────────────────────────

func _on_pause_requested() -> void:
	_pause_menu.show_menu()

func _on_resume() -> void:
	_pause_menu.hide_menu()

func _on_quit() -> void:
	_pause_menu.hide_menu()
	GameState.go_to_menu()

func _on_game_over() -> void:
	await get_tree().create_timer(2.0).timeout
	GameState.go_to_game_over()
