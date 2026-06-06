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
@onready var end_btn: Button = $UI/EndButton
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

var _loading_label: Label = null

func _ready() -> void:
	board.game_over_signal.connect(_on_game_over)
	board.score_updated.connect(_on_score_updated)
	board.bar_dropped.connect(func(): sfx_drop.play())
	board.row_pushed.connect(func(): sfx_push.play())
	restart_btn.pressed.connect(_on_restart)
	version_label.text = "v1.2.0"
	# 記錄浮動 label 的初始位置
	_label_bases[combo_label] = combo_label.position
	_label_bases[gain_label]  = gain_label.position
	bgm.finished.connect(func(): bgm.play())

	# 建立 loading label
	_loading_label = Label.new()
	_loading_label.text = "Loading..."
	_loading_label.add_theme_font_size_override("font_size", 32)
	_loading_label.add_theme_color_override("font_color", Color.WHITE)
	_loading_label.set_anchors_preset(Control.PRESET_CENTER)
	_loading_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_loading_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	$UI.add_child(_loading_label)

	end_btn.pressed.connect(_on_end_pressed)

	game_over_screen.visible = false
	_load_best_score_async()

# ── 最高分存讀 ─────────────────────────────────────────────────────

const FIREBASE_URL = "https://row-swipe-default-rtdb.asia-southeast1.firebasedatabase.app"

func _load_best_score_async() -> void:
	# 非 Web：直接讀檔，不需要等待
	if OS.get_name() != "Web":
		if FileAccess.file_exists("user://best_score.dat"):
			var f := FileAccess.open("user://best_score.dat", FileAccess.READ)
			board.sm.best_score = f.get_32()
		_on_load_done()
		return

	# Web：HTTPRequest 非同步讀取
	var http := HTTPRequest.new()
	add_child(http)

	var err := http.request(FIREBASE_URL + "/best_score.json")
	if err != OK:
		http.queue_free()
		_on_load_done()
		return

	var response: Array = await http.request_completed
	http.queue_free()

	var result: int = response[0]
	var response_code: int = response[1]
	var body: PackedByteArray = response[3]

	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var val := body.get_string_from_utf8().to_int()
		board.sm.best_score = maxi(board.sm.best_score, val)

	_on_load_done()

func _on_load_done() -> void:
	_loading_label.queue_free()
	_loading_label = null
	_update_best_label()
	_show_start_screen()

func _save_best_score(val: int) -> void:
	if OS.get_name() == "Web":
		JavaScriptBridge.eval("""
			(function() {
				try {
					var xhr = new XMLHttpRequest();
					xhr.open('GET', '%s/best_score.json', false);
					xhr.send();
					var current = (xhr.status === 200) ? (parseInt(xhr.responseText) || 0) : 0;
					window._godot_remote_best = current;
					if (%d > current) {
						var xhr2 = new XMLHttpRequest();
						xhr2.open('PUT', '%s/best_score.json', true);
						xhr2.setRequestHeader('Content-Type', 'application/json');
						xhr2.send(JSON.stringify(%d));
					}
				} catch(e) { window._godot_remote_best = 0; }
			})()
		""" % [FIREBASE_URL, val, FIREBASE_URL, val])
		# 把遠端讀到的值同步回 GDScript
		var remote := int(JavaScriptBridge.eval("window._godot_remote_best || 0"))
		if remote > board.sm.best_score:
			board.sm.best_score = remote
			_update_best_label()
		return
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

func _show_start_screen() -> void:
	go_best_score_label.text = "BEST: %d" % board.sm.best_score
	final_score_label.visible = false
	restart_btn.text = "Start"
	game_over_screen.visible = true

func _start() -> void:
	game_over_screen.visible = false
	score_label.text = "Score  0"
	_prev_score = 0
	combo_label.modulate.a = 0.0
	gain_label.modulate.a = 0.0
	end_btn.visible = true
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

func _on_end_pressed() -> void:
	board.set_process(false)
	board._set_input(false)
	_on_game_over()

func _on_game_over() -> void:
	end_btn.visible = false
	_save_best_score(board.sm.best_score)
	go_best_score_label.text = "BEST: %d" % board.sm.best_score
	final_score_label.text = "Score: %d" % board.sm.score
	final_score_label.visible = true
	restart_btn.text = "Restart"
	sfx_game_over.play()
	bgm.stop()
	game_over_screen.visible = true

func _on_restart() -> void:
	if not bgm.playing:
		bgm.play()
	_start()
