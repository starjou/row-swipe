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
board.gd       — 遊戲主控。持有 BoardManager + ScoreManager，處理輸入、動畫、遊戲迴圈。
board_manager.gd — 純資料層（無 Node）。管理 grid[row][col] 與 bars dict，執行移動/重力/消行。
score_manager.gd — 純資料層。計分與連消邏輯。
bar_node.gd    — Node2D，視覺表現。用 _draw() 繪製方塊，負責所有 Tween 動畫。
board_const.gd — 全域常數（ROWS、COLS、CELL_SIZE、動畫時間）。
```

**資料流：** `board.gd` 呼叫 `BoardManager` 改變資料 → 依回傳結果驅動 `BarNode` 動畫 → 動畫結束後繼續下一步。`main.gd` 只透過 signal 感知分數變化與遊戲結束。

**座標系：** grid row 0 = 最底部，row ROWS-1 = 最頂部。screen Y = `(ROWS - 1 - row) * CELL_SIZE`。

**遊戲迴圈（每回合）：**
1. 玩家滑動橫條 → `_finalize_drag()` → `_run_turn()`
2. `_resolve_physics()`：循環執行重力 + 消行，直到穩定
3. `_push_new_row()`：從底部推入新列；頂排有格子 → game over
4. 再次 `_resolve_physics()`，若盤面清空則重複推新列

**平台差異：** Web + 桌面滑鼠需透過 `JavaScriptBridge` 偵測 `mouseup`/`mouseleave`（Godot Web export 的 InputEventMouseButton release 有遺失問題）。

## Key Constants

`board_const.gd` 是調整手感的主要入口：`ANIM_GRAVITY`、`ANIM_CLEAR`、`ANIM_PUSH`、`ANIM_PAUSE`。

## Scoring

`score += BASE_PER_LINE (100) × line_count × combo`。`combo` 在每次 `_run_turn` 開始時歸零，每次消行 +1。
