# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Godot 4.x 橫條滑動消行遊戲。視窗尺寸 512×720，Board 位於 (0, 80)，上方 80px 為 UI 區。
Web export 部署至 itch.io，最高分透過 Firebase Realtime Database 同步。

## Running / Exporting

- 開發：用 Godot 4.x Editor 開啟專案，執行 `main.tscn`。
- 匯出 & 發布：執行 `deploy.ps1`（headless export → itch.io butler push）。

## Architecture

```
main.gd        — 根節點。連接信號、顯示 UI、讀寫最高分（本機 .dat / Firebase）。
board.gd       — 遊戲主控。持有 BoardManager + ScoreManager，處理輸入、動畫、遊戲迴圈、Demo Mode AI。
board_manager.gd — 純資料層（無 Node）。管理 grid[row][col] 與 bars dict，執行移動/重力/消行。
score_manager.gd — 純資料層。計分與連消邏輯。
bar_node.gd    — Node2D，視覺表現。用 _draw() 繪製方塊，負責所有 Tween 動畫。
board_const.gd — 全域常數（ROWS、COLS、CELL_SIZE、動畫時間）。
```

**資料流：** `board.gd` 呼叫 `BoardManager` 改變資料 → 依回傳結果驅動 `BarNode` 動畫 → 動畫結束後繼續下一步。`main.gd` 只透過 signal 感知分數變化與遊戲結束。

**座標系：** grid row 0 = 最底部，row ROWS-1 = 最頂部。screen Y = `(ROWS - 1 - row) * CELL_SIZE`。

**遊戲迴圈（每回合）：**
1. 玩家滑動橫條 → `_finalize_drag()` → `sm.reset_combo()` → `_run_turn()`
2. `_resolve_physics()`：循環執行重力 + 消行，直到穩定
3. `_push_new_row()`：從底部推入新列；頂排有格子 → game over
4. 再次 `_resolve_physics()`，若盤面清空則重複推新列

**平台差異：** Web + 桌面滑鼠需透過 `JavaScriptBridge` 偵測 `mouseup`/`mouseleave`（Godot Web export 的 InputEventMouseButton release 有遺失問題）。

## UI Flow

- 載入完成 → Start 畫面（game_over_screen 顯示，FinalScore 隱藏，按鈕文字 "Start"）
- 按 Start/Restart → 遊戲開始，End 按鈕出現（位於 HeadPanel）
- 按 End 或 game over → Game Over 畫面（FinalScore 顯示，按鈕文字 "Restart"）
- Start/Game Over 畫面靜置 5 秒 → Demo Mode 自動啟動
- 遊戲進行中靜置 15 秒 → Board + HeadPanel fade out（0.3s）；任何輸入 → fade in

## Demo Mode

`board.gd` 的 `start_demo_mode()` / `stop_demo_mode()`。AI 邏輯：
- `_pick_best_move()`：枚舉所有合法移動，用 `bm.score_move()` 評分
- `score_move()`（board_manager.gd）：clone 盤面模擬移動，計算連鎖消行數 × 100；無消行則給目標列填滿程度的部分分
- Demo 期間 `_allow_best_update = false`，best score 完全不更新（記憶體 + 雲端）
- 玩家 click/touch（pressed）→ 停止 demo，回到 Start 畫面

## Scoring

- 單次得分：`BASE_PER_LINE (100) × (2^line_count - 1)`（多行指數加成，1行=100，2行=300，3行=700）
- combo 倍率：`× 2^(combo+1)`（combo 1 = ×4，combo 2 = ×8）
- combo 在每次拖曳成功移動時歸零（`_finalize_drag`），同一次拖曳的連鎖消行累積 combo
- `best_score` 由 `main.gd` 的 `_on_score_updated` 維護（不在 ScoreManager 內更新）
