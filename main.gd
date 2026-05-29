extends Node

@onready var board: Node2D = $Board
@onready var score_label: Label = $UI/HeadPanel/HBoxContainer/ScoreLabel
@onready var combo_label: Label = $UI/ComboLabel
@onready var gain_label: Label = $UI/GainLabel
@onready var best_score_label: Label = $UI/HeadPanel/HBoxContainer/BestScoreLabel
@onready var game_over_screen: Control = $UI/GameOverScreen
@onready var go_best_score_label: Label = $UI/GameOverScreen/VBoxContainer/BestScore
@onready var final_score_label: Label = $UI/GameOverScreen/VBoxContainer/FinalScore
@onready var restart_btn: Button = $UI/GameOverScreen/VBoxContainer/RestartButton
@onready var version_label: Label = $UI/VersionLabel
@onready var sfx_drop: AudioStreamPlayer = $UI/sfxDrop
@onready var sfx_clear: AudioStreamPlayer = $UI/sfxClear
@onready var sfx_combo: AudioStreamPlayer = $UI/sfxCombo
@onready var sfx_push: AudioStreamPlayer = $UI/sfxPush
@onready var sfx_game_over: AudioStreamPlayer = $UI/sfxGameOver
@onready var bgm: AudioStreamPlayer = $UI/BGM

var _prev_score: int = 0
var _float_tweens: Dictionary = {}   # Label -> Tween
var _label_bases: Dictionary = {}    # Label -> Vector2 (起始位置)

func _ready() -> void:
	board.game_over_signal.connect(_on_game_over)
	board.score_updated.connect(_on_score_updated)
	board.bar_dropped.connect(func(): sfx_drop.play())
	board.row_pushed.connect(func(): sfx_push.play())
	restart_btn.pressed.connect(_on_restart)
	version_label.text = "v1.0.0"
	board.sm.best_score = _load_best_score()
	_update_best_label()
	# 記錄浮動 label 的初始位置
	_label_bases[combo_label] = combo_label.position
	_label_bases[gain_label]  = gain_label.position
	_start()

# ── 最高分存讀 ─────────────────────────────────────────────────────

func _load_best_score() -> int:
	if OS.get_name() == "Web":
		var val = JavaScriptBridge.eval("parseInt(localStorage.getItem('best_score') || '0')")
		return int(val)
	if FileAccess.file_exists("user://best_score.dat"):
		var f := FileAccess.open("user://best_score.dat", FileAccess.READ)
		return f.get_32()
	return 0

func _save_best_score(val: int) -> void:
	if OS.get_name() == "Web":
		JavaScriptBridge.eval("localStorage.setItem('best_score', %d)" % val)
	else:
		var f := FileAccess.open("user://best_score.dat", FileAccess.WRITE)
		f.store_32(val)

func _update_best_label() -> void:
	best_score_label.text = "BEST  %d" % board.sm.best_score

# ── 浮動淡出動畫 ────────────────────────────────────────────────────

func _float_out(label: Label, text: String) -> void:
	if _float_tweens.has(label) and _float_tweens[label]:
		_float_tweens[label].kill()
	label.text = text
	label.position = _label_bases[label]
	label.modulate.a = 1.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(label, "position:y", _label_bases[label].y - 50.0, 1.4)
	tw.tween_property(label, "modulate:a", 0.0, 1.4)
	_float_tweens[label] = tw

# ── 遊戲流程 ───────────────────────────────────────────────────────

func _start() -> void:
	game_over_screen.visible = false
	score_label.text = "Score  0"
	_prev_score = 0
	combo_label.modulate.a = 0.0
	gain_label.modulate.a = 0.0
	board.start_game()

func _on_score_updated(score: int, combo: int) -> void:
	var gain := score - _prev_score
	_prev_score = score
	score_label.text = "Score  %d" % score
	_update_best_label()
	if gain > 0:
		_float_out(gain_label, "+%d" % gain)
	if combo >= 2:
		sfx_combo.play()
		_float_out(combo_label, "COMBO ×%d" % combo)
	else:
		sfx_clear.play()

func _on_game_over() -> void:
	_save_best_score(board.sm.best_score)
	go_best_score_label.text = "BEST: %d" % board.sm.best_score
	final_score_label.text = "Score: %d" % board.sm.score
	sfx_game_over.play()
	bgm.stop()
	game_over_screen.visible = true

func _on_restart() -> void:
	bgm.play()
	_start()
