extends Node

@onready var board: Node2D = $Board
@onready var score_label: Label = $UI/ScoreLabel
@onready var combo_label: Label = $UI/ComboLabel
@onready var game_over_panel: Control = $UI/GameOverPanel
@onready var final_score_label: Label = $UI/GameOverPanel/FinalScore
@onready var restart_btn: Button = $UI/GameOverPanel/RestartButton
@onready var version_label: Label = $UI/VersionLabel

var _combo_clear_tween: Tween = null

func _ready() -> void:
	board.game_over_signal.connect(_on_game_over)
	board.score_updated.connect(_on_score_updated)
	restart_btn.pressed.connect(_on_restart)
	version_label.text = "v0.1.1"
	version_label.add_theme_font_size_override("font_size", 12)
	version_label.modulate = Color(1, 1, 1, 0.4)
	version_label.anchors_preset = Control.PRESET_BOTTOM_RIGHT
	version_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	version_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	version_label.offset_left = -50
	version_label.offset_bottom = -4
	_start()

func _start() -> void:
	game_over_panel.visible = false
	score_label.text = "0"
	combo_label.text = ""
	board.start_game()

func _on_score_updated(score: int, combo: int) -> void:
	score_label.text = str(score)
	if _combo_clear_tween:
		_combo_clear_tween.kill()
		_combo_clear_tween = null
	if combo >= 2:
		combo_label.text = "COMBO ×%d" % combo
		_combo_clear_tween = create_tween()
		_combo_clear_tween.tween_interval(1.2)
		_combo_clear_tween.tween_callback(func(): combo_label.text = "")
	else:
		combo_label.text = ""

func _on_game_over() -> void:
	final_score_label.text = "Score: %d" % board.sm.score
	game_over_panel.visible = true

func _on_restart() -> void:
	_start()
