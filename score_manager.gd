extends RefCounted
class_name ScoreManager

var score: int = 0
var combo: int = 0          # 連消計數（從 1 開始）
var best_combo: int = 0

const BASE_PER_LINE: int = 100

func reset() -> void:
	score = 0
	combo = 0
	best_combo = 0

## 每次消行後呼叫，支援連消加成
func add_clears(line_count: int) -> void:
	combo += 1
	best_combo = maxi(best_combo, combo)
	# 分數 = 底分 × 消行數 × 連消倍率
	score += BASE_PER_LINE * line_count * combo

## 沒有消行時重置連消
func reset_combo() -> void:
	combo = 0
