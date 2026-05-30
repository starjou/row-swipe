extends Node2D

signal game_over_signal
signal score_updated(score: int, combo: int)
signal bar_dropped
signal row_pushed

var bm: BoardManager
var sm: ScoreManager
var bar_nodes: Dictionary = {}

# 裝置類型
var _is_mobile: bool = false

# 拖曳狀態
var _input_on: bool = false
var _dragging: bool = false
var _sel_id: int = -1
var _drag_start_x: float = 0.0
var _drag_start_col: int = 0
var _last_clamped: int = 0
var _max_left: int = 0
var _max_right: int = 0

# ── 初始化 ─────────────────────────────────────────────────────────

func _ready() -> void:
	clip_children = CanvasItem.CLIP_CHILDREN_DISABLED
	bm = BoardManager.new()
	sm = ScoreManager.new()
	_is_mobile = OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("web_touchscreen")
	if OS.get_name() == "Web":
		JavaScriptBridge.eval("""
			window._godot_mouse_released = 0;
			window._godot_dragging = false;
			var _gdCanvas = document.getElementById('canvas');
			_gdCanvas.style.touchAction = 'none';
			_gdCanvas.addEventListener('mousedown', function(e) {
				window._godot_dragging = true;
				window._godot_mouse_released = 0;
			});
			_gdCanvas.addEventListener('mouseup', function(e) {
				window._godot_dragging = false;
				window._godot_mouse_released = 1;
			});
			_gdCanvas.addEventListener('mouseleave', function(e) {
				if (window._godot_dragging) {
					window._godot_mouse_released = 1;
				}
			});
		""")

func start_game() -> void:
	for id in bar_nodes:
		bar_nodes[id].queue_free()
	bar_nodes.clear()
	bm.reset()
	sm.reset()

	for _i in 2:
		var new_ids := bm.generate_row()
		bm.push_row(new_ids)
	bm.apply_gravity()

	for id in bm.bars:
		_spawn_bar(id)

	_sync_positions_instant()
	_set_input(true)
	queue_redraw()

# ── 每幀輪詢 JS 狀態（桌面滑鼠 Web 專用）────────────────────────────

func _process(_delta: float) -> void:
	if OS.get_name() != "Web" or _is_mobile or not _dragging:
		return
	var released = JavaScriptBridge.eval("window._godot_mouse_released || 0")
	if released == 1:
		JavaScriptBridge.eval("window._godot_mouse_released = 0")
		_finalize_drag()

# ── 桌面版 fallback ────────────────────────────────────────────────

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		if OS.get_name() != "Web" and _dragging:
			_finalize_drag()

# ── 輸入開關 ───────────────────────────────────────────────────────

func _set_input(val: bool) -> void:
	_input_on = val
	if not val:
		_dragging = false
		_sel_id = -1
		_last_clamped = 0
		_refresh_selection()

func _refresh_selection() -> void:
	for id in bar_nodes:
		bar_nodes[id].set_selected(id == _sel_id)

# ── 橫條節點管理 ───────────────────────────────────────────────────

func _spawn_bar(bar_id: int) -> BarNode:
	var d: Dictionary = bm.get_bar_data(bar_id)
	var bn := BarNode.new()
	add_child(bn)
	bn.setup(bar_id, int(d["width"]), d["color"])
	bar_nodes[bar_id] = bn
	return bn

func _remove_bar(bar_id: int) -> void:
	if bar_nodes.has(bar_id):
		bar_nodes[bar_id].queue_free()
		bar_nodes.erase(bar_id)

func _sync_positions_instant() -> void:
	for id in bar_nodes:
		var d: Dictionary = bm.get_bar_data(id)
		if not d.is_empty():
			bar_nodes[id].set_grid_pos(int(d["row"]), int(d["col"]))

# ── 輸入處理 ───────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not _input_on:
		return

	if _is_mobile:
		if event is InputEventScreenTouch:
			if event.pressed:
				_on_press(to_local(event.position))
			else:
				if _dragging:
					_finalize_drag()
		elif event is InputEventScreenDrag:
			if _dragging:
				_on_drag(to_local(event.position))
	else:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_on_press(to_local(event.position))
			else:
				if _dragging:
					_finalize_drag()
		elif event is InputEventMouseMotion:
			if _dragging:
				_on_drag(to_local(event.position))

func _on_press(local_pos: Vector2) -> void:
	if _dragging and _sel_id >= 0:
		_finalize_drag()
		return

	var board_w: float = BoardConst.COLS * BoardConst.CELL_SIZE
	var board_h: float = BoardConst.ROWS * BoardConst.CELL_SIZE
	if local_pos.x < 0 or local_pos.x > board_w or local_pos.y < 0 or local_pos.y > board_h:
		return

	var col: int = int(local_pos.x / BoardConst.CELL_SIZE)
	var row: int = BoardConst.ROWS - 1 - int(local_pos.y / BoardConst.CELL_SIZE)
	var id: int = bm.get_bar_at(row, col)

	if id < 0:
		_sel_id = -1
		_dragging = false
		_refresh_selection()
		return

	_sel_id = id
	_dragging = true
	_last_clamped = 0
	_drag_start_x = local_pos.x
	_drag_start_col = int(bm.bars[id]["col"])
	_max_left = bm.max_left_distance(id)
	_max_right = bm.max_right_distance(id)
	_refresh_selection()

func _on_drag(local_pos: Vector2) -> void:
	if not _dragging or _sel_id < 0 or not bm.bars.has(_sel_id):
		return
	var dx: float = local_pos.x - _drag_start_x
	var clamped_dx: float = clampf(dx, _max_left * BoardConst.CELL_SIZE, _max_right * BoardConst.CELL_SIZE)
	_last_clamped = roundi(clamped_dx / BoardConst.CELL_SIZE)
	if bar_nodes.has(_sel_id):
		bar_nodes[_sel_id].position.x = _drag_start_col * BoardConst.CELL_SIZE + clamped_dx

func _finalize_drag() -> void:
	if not _dragging or _sel_id < 0:
		return

	var clamped: int = _last_clamped
	var committed_id: int = _sel_id

	_sel_id = -1
	_dragging = false
	_last_clamped = 0
	_refresh_selection()

	if clamped == 0:
		if bar_nodes.has(committed_id):
			var d: Dictionary = bm.get_bar_data(committed_id)
			if not d.is_empty():
				bar_nodes[committed_id].set_grid_pos(int(d["row"]), int(d["col"]))
		return

	if bm.move_bar(committed_id, clamped):
		bar_dropped.emit()
		if bar_nodes.has(committed_id):
			var d: Dictionary = bm.get_bar_data(committed_id)
			bar_nodes[committed_id].set_grid_pos(int(d["row"]), int(d["col"]))
		_set_input(false)
		_run_turn()
	else:
		if bar_nodes.has(committed_id):
			var d: Dictionary = bm.get_bar_data(committed_id)
			if not d.is_empty():
				bar_nodes[committed_id].set_grid_pos(int(d["row"]), int(d["col"]))

# ── 遊戲迴圈 ───────────────────────────────────────────────────────

func _run_turn() -> void:
	sm.reset_combo()
	await _resolve_physics()
	if not await _push_new_row():
		return
	await _resolve_physics()
	while bm.is_empty():
		if not await _push_new_row():
			return
		await _resolve_physics()
	_set_input(true)

func _resolve_physics() -> void:
	while true:
		var moves: Array = bm.apply_gravity()
		if moves.size() > 0:
			await _anim_gravity(moves)
			await get_tree().create_timer(BoardConst.ANIM_PAUSE).timeout
		var result: Dictionary = bm.clear_lines()
		if int(result["count"]) > 0:
			sm.add_clears(int(result["count"]))
			score_updated.emit(sm.score, sm.combo)
			await _anim_clear(result["bar_ids"])
			await get_tree().create_timer(BoardConst.ANIM_PAUSE).timeout
		else:
			break
	_sync_positions_instant()

func _push_new_row() -> bool:
	_sync_positions_instant()
	await get_tree().create_timer(BoardConst.ANIM_PAUSE).timeout
	var new_ids: Array = bm.generate_row()
	if not bm.push_row(new_ids):
		game_over_signal.emit()
		return false
	row_pushed.emit()
	await _anim_push_row(new_ids)
	return true

# ── 動畫 ───────────────────────────────────────────────────────────

func _anim_gravity(moves: Array) -> void:
	var last_tw: Tween = null
	for m in moves:
		var bar_id: int = int(m["bar_id"])
		var to_row: int = int(m["to_row"])
		if bar_nodes.has(bar_id):
			last_tw = bar_nodes[bar_id].tween_to_row(to_row)
	if last_tw:
		await last_tw.finished

func _anim_clear(bar_ids: Array) -> void:
	var last_tw: Tween = null
	for id in bar_ids:
		if bar_nodes.has(id):
			last_tw = bar_nodes[id].tween_clear()
	if last_tw:
		await last_tw.finished
	for id in bar_ids:
		_remove_bar(id)

func _anim_push_row(new_ids: Array) -> void:
	for id in new_ids:
		_spawn_bar(id)
	var last_tw: Tween = null
	for id in bar_nodes:
		var d: Dictionary = bm.get_bar_data(id)
		if d.is_empty():
			continue
		var target_row: int = int(d["row"])
		var target_col: int = int(d["col"])
		if id in new_ids:
			last_tw = bar_nodes[id].tween_push_in(target_row, target_col)
		else:
			last_tw = bar_nodes[id].tween_slide_up(target_row)
	if last_tw:
		await last_tw.finished

# ── 背景繪製 ───────────────────────────────────────────────────────

func _draw() -> void:
	var cs := BoardConst.CELL_SIZE
	var board_w := BoardConst.COLS * cs
	var board_h := BoardConst.ROWS * cs
	# 再疊上個別格子
	var cell_color := Color(0.2, 0.2, 0.2, 0.5)
	for r in BoardConst.ROWS:
		for c in BoardConst.COLS:
			draw_rect(Rect2(c * cs, r * cs, cs - 1, cs - 1), cell_color)
