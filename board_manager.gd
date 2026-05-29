extends RefCounted
class_name BoardManager

## grid[row][col] = bar_id，或 -1（空格）
## row 0 = 最底部，row ROWS-1 = 最頂部
var grid: Array = []

## bars[bar_id] = { row, col, width, color }
var bars: Dictionary = {}

var _next_id: int = 0

# ── 初始化 ─────────────────────────────────────────────────────────

func reset() -> void:
	grid.clear()
	for _r in BoardConst.ROWS:
		var row: Array = []
		for _c in BoardConst.COLS:
			row.append(-1)
		grid.append(row)
	bars.clear()
	_next_id = 0

# ── Grid 輔助 ──────────────────────────────────────────────────────

func _place(bar_id: int, row: int, col: int, width: int) -> void:
	for c in range(col, col + width):
		grid[row][c] = bar_id

func _erase(bar_id: int) -> void:
	var row: int = bars[bar_id]["row"]
	var col: int = bars[bar_id]["col"]
	var width: int = bars[bar_id]["width"]
	if row < 0 or row >= BoardConst.ROWS:
		return
	for c in range(col, col + width):
		if grid[row][c] == bar_id:
			grid[row][c] = -1

func get_bar_at(row: int, col: int) -> int:
	if row < 0 or row >= BoardConst.ROWS or col < 0 or col >= BoardConst.COLS:
		return -1
	return grid[row][col]

func get_bar_data(bar_id: int) -> Dictionary:
	return bars.get(bar_id, {})

func is_empty() -> bool:
	return bars.is_empty()

# ── 建立橫條 ───────────────────────────────────────────────────────

func _new_bar(row: int, col: int, width: int, color: Color) -> int:
	var id: int = _next_id
	_next_id += 1
	bars[id] = {"row": row, "col": col, "width": width, "color": color}
	if row >= 0:
		_place(id, row, col, width)
	return id

# ── 生成新列 ───────────────────────────────────────────────────────

func generate_row() -> Array:
	var layout: Array = _random_layout()
	var ids: Array = []
	for seg in layout:
		ids.append(_new_bar(-1, int(seg["col"]), int(seg["width"]), _rand_color()))
	return ids

func _random_layout() -> Array:
	var cells: Array = []
	for i in BoardConst.COLS:
		cells.append(1 if randf() < 0.55 else 0)

	var total: int = 0
	for v in cells:
		total += int(v)
	if total >= BoardConst.COLS:
		cells[randi() % BoardConst.COLS] = 0
	elif total == 0:
		cells[randi() % BoardConst.COLS] = 1

	var result: Array = []
	var c: int = 0
	while c < BoardConst.COLS:
		if int(cells[c]) == 1:
			var start: int = c
			while c < BoardConst.COLS and int(cells[c]) == 1:
				c += 1
			var run: int = c - start
			var pos: int = start
			while run > 0:
				var w: int = mini(4, run)
				result.append({"col": pos, "width": w})
				pos += w
				run -= w
		else:
			c += 1
	return result

func _rand_color() -> Color:
	var palette: Array = [
		Color(0.88, 0.35, 0.35),
		Color(0.35, 0.65, 0.88),
		Color(0.35, 0.80, 0.50),
		Color(0.90, 0.76, 0.28),
		Color(0.68, 0.35, 0.88),
		Color(0.92, 0.58, 0.28),
	]
	return palette[randi() % palette.size()]

# ── 從底部頂上新列 ─────────────────────────────────────────────────

func push_row(bar_ids: Array) -> bool:
	for c in BoardConst.COLS:
		if grid[BoardConst.ROWS - 1][c] != -1:
			return false

	var placed: Array = []
	for id in bars:
		if int(bars[id]["row"]) >= 0:
			placed.append(id)
	placed.sort_custom(func(a, b): return int(bars[a]["row"]) > int(bars[b]["row"]))

	for id in placed:
		_erase(id)
	for id in placed:
		var new_row: int = int(bars[id]["row"]) + 1
		bars[id]["row"] = new_row
		_place(id, new_row, int(bars[id]["col"]), int(bars[id]["width"]))

	for id in bar_ids:
		bars[id]["row"] = 0
		_place(id, 0, int(bars[id]["col"]), int(bars[id]["width"]))

	return true

# ── 玩家移動 ───────────────────────────────────────────────────────

func move_bar(bar_id: int, delta_col: int) -> bool:
	if not bars.has(bar_id):
		return false
	var row: int = int(bars[bar_id]["row"])
	var col: int = int(bars[bar_id]["col"])
	var width: int = int(bars[bar_id]["width"])
	var new_col: int = col + delta_col
	if new_col < 0 or new_col + width > BoardConst.COLS:
		return false
	_erase(bar_id)
	var ok: bool = true
	for c in range(new_col, new_col + width):
		if grid[row][c] != -1:
			ok = false
			break
	if ok:
		bars[bar_id]["col"] = new_col
		_place(bar_id, row, new_col, width)
	else:
		_place(bar_id, row, col, width)
	return ok

func max_left_distance(bar_id: int) -> int:
	if not bars.has(bar_id):
		return 0
	var row: int = int(bars[bar_id]["row"])
	var col: int = int(bars[bar_id]["col"])
	var width: int = int(bars[bar_id]["width"])
	_erase(bar_id)
	var d: int = 0
	while col + d - 1 >= 0 and grid[row][col + d - 1] == -1:
		d -= 1
	_place(bar_id, row, col, width)
	return d

func max_right_distance(bar_id: int) -> int:
	if not bars.has(bar_id):
		return 0
	var row: int = int(bars[bar_id]["row"])
	var col: int = int(bars[bar_id]["col"])
	var width: int = int(bars[bar_id]["width"])
	_erase(bar_id)
	var d: int = 0
	while col + width + d < BoardConst.COLS and grid[row][col + width + d] == -1:
		d += 1
	_place(bar_id, row, col, width)
	return d

# ── 重力 ───────────────────────────────────────────────────────────

func apply_gravity() -> Array:
	var initial: Dictionary = {}
	for id in bars:
		initial[id] = int(bars[id]["row"])

	var sorted: Array = bars.keys()
	sorted.sort_custom(func(a, b): return int(bars[a]["row"]) < int(bars[b]["row"]))

	var any_moved: bool = true
	while any_moved:
		any_moved = false
		for id in sorted:
			if not bars.has(id):
				continue
			var row: int = int(bars[id]["row"])
			var col: int = int(bars[id]["col"])
			var width: int = int(bars[id]["width"])
			if row <= 0:
				continue
			var supported: bool = false
			for c in range(col, col + width):
				if grid[row - 1][c] != -1:
					supported = true
					break
			if not supported:
				_erase(id)
				bars[id]["row"] = row - 1
				_place(id, row - 1, col, width)
				any_moved = true

	var result: Array = []
	for id in bars:
		var init_row: int = int(initial.get(id, bars[id]["row"]))
		var cur_row: int = int(bars[id]["row"])
		if cur_row != init_row:
			result.append({"bar_id": id, "from_row": init_row, "to_row": cur_row})
	return result

# ── 消行 ───────────────────────────────────────────────────────────

func clear_lines() -> Dictionary:
	var removed_ids: Array = []
	var count: int = 0

	for r in range(BoardConst.ROWS - 1, -1, -1):
		var full: bool = true
		for c in BoardConst.COLS:
			if grid[r][c] == -1:
				full = false
				break
		if not full:
			continue

		count += 1
		var seen: Dictionary = {}
		for c in BoardConst.COLS:
			var id: int = grid[r][c]
			if id >= 0 and not seen.has(id):
				seen[id] = true
				removed_ids.append(id)
			grid[r][c] = -1
		for id in seen:
			bars.erase(id)

	return {"count": count, "bar_ids": removed_ids}
