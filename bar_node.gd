extends Node2D
class_name BarNode

const MARGIN := 2.0

var bar_id: int = -1
var bar_width: int = 1
var theme_id: String = "default"  # 未來換皮只改這裡

var _bar_color: Color = Color.GRAY
var _selected: bool = false

# ── 初始化 ─────────────────────────────────────────────────────────

func setup(id: int, width: int, color: Color) -> void:
	bar_id = id
	bar_width = width
	_bar_color = color
	queue_redraw()

func set_selected(val: bool) -> void:
	_selected = val
	queue_redraw()

# ── 位置 ───────────────────────────────────────────────────────────

func set_grid_pos(row: int, col: int) -> void:
	position = grid_to_screen(row, col)

static func grid_to_screen(row: int, col: int) -> Vector2:
	return Vector2(
		col * BoardConst.CELL_SIZE,
		(BoardConst.ROWS - 1 - row) * BoardConst.CELL_SIZE
	)

# ── 動畫 ───────────────────────────────────────────────────────────

## 落下動畫：視覺位置 → 目標 row
func tween_to_row(target_row: int) -> Tween:
	var target_y := (BoardConst.ROWS - 1 - target_row) * BoardConst.CELL_SIZE
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:y", target_y, BoardConst.ANIM_GRAVITY)
	return tw

## 頂出動畫：從畫面下方滑入
func tween_push_in(target_row: int, col: int) -> Tween:
	position = Vector2(col * BoardConst.CELL_SIZE, BoardConst.ROWS * BoardConst.CELL_SIZE)
	var target := grid_to_screen(target_row, col)
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", target, BoardConst.ANIM_PUSH)
	return tw

## 現有橫條隨頂出往上移動
func tween_slide_up(new_row: int) -> Tween:
	var target_y := (BoardConst.ROWS - 1 - new_row) * BoardConst.CELL_SIZE
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:y", target_y, BoardConst.ANIM_PUSH)
	return tw

## 消除動畫：壓扁後消失
func tween_clear() -> Tween:
	var squish := BoardConst.ANIM_CLEAR * 0.65
	var fade   := BoardConst.ANIM_CLEAR * 0.35
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.05, 0.05), squish)
	tw.tween_property(self, "modulate:a", 0.0, fade)
	return tw

# ── 繪圖 ───────────────────────────────────────────────────────────

func _draw() -> void:
	var cs := BoardConst.CELL_SIZE
	var w := bar_width * cs - MARGIN * 2.0
	var h := cs - MARGIN * 2.0

	var base := _bar_color.lightened(0.15) if _selected else _bar_color

	# 主體
	draw_rect(Rect2(MARGIN, MARGIN, w, h), base)
	# 頂部高光
	draw_rect(Rect2(MARGIN, MARGIN, w, h * 0.30), Color(1, 1, 1, 0.20))
	# 底部陰影
	draw_rect(Rect2(MARGIN, MARGIN + h * 0.70, w, h * 0.30), Color(0, 0, 0, 0.18))
	# 選取外框
	if _selected:
		draw_rect(Rect2(MARGIN - 2, MARGIN - 2, w + 4, h + 4), Color.WHITE, false, 2.5)
