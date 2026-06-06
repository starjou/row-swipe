extends RefCounted
class_name ScoreManager

var score: int = 0
var combo: int = 0          # 連消計數（從 1 開始）
var best_combo: int = 0
var best_score: int = 0     # 跨局最高分（不在 reset 中清除）

const BASE_PER_LINE: int = 100

func reset() -> void:
	score = 0
	combo = 0
	best_combo = 0
	# best_score 刻意保留

## 每次消行後呼叫，支援連消加成
func add_clears(line_count: int) -> void:
	var base := BASE_PER_LINE * (int(pow(2, line_count)) - 1)
	if combo > 0:
		# 有連消：combo 1 = ×4，combo 2 = ×8…
		score += base * int(pow(2, combo + 1))
	else:
		score += base
	combo += 1
	best_combo = maxi(best_combo, combo)

## 沒有消行時重置連消
func reset_combo() -> void:
	combo = 0
