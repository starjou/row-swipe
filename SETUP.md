# 場景設置說明 (SETUP.md)

## 專案設定

- Godot 4.x
- 視窗建議尺寸：512 × 720（對應 8格×64px = 512 寬，上方留 80px UI）

---

## 腳本掛載順序

把 `scripts/` 資料夾放進 `res://scripts/`，所有 .gd 都是 global class，
不需要手動 preload。

---

## Main.tscn 結構

```
Main  (Node)  ← 掛 main.gd
├── Board  (Node2D)  ← 掛 board.gd，位置 (0, 80)
└── UI  (CanvasLayer)
    ├── ScoreLabel  (Label)
    │   └── 位置 (8, 8)，字型大小 28，粗體
    ├── ComboLabel  (Label)
    │   └── 位置 (8, 44)，字型大小 20，顏色黃色
    └── GameOverPanel  (Panel)
        └── 位置填滿畫面，預設 visible=false
            ├── FinalScore  (Label)  ← 置中
            └── RestartButton  (Button)  ← 文字「再玩一次」
```

---

## 注意事項

1. **Board 的位置**：`(0, 80)` 讓 UI 區有空間。
   Board 大小 = 512 × 640（8×64, 10×64），請確認視窗夠大。

2. **輸入**：支援滑鼠（左鍵拖曳）與觸控（手機）。
   拖曳超過半格就會移動，未達半格自動復原。

3. **GameOverPanel**：可自行加背景色（半透明黑）讓玩家看清楚。

---

## 計分規則

| 狀況 | 分數 |
|------|------|
| 消 1 行 | 100 × 連消倍率 |
| 消 2 行 | 200 × 連消倍率 |
| 連消加成 | 每次連續消行，倍率 +1（斷掉就歸零） |

---

## 換皮說明（之後）

每個 `BarNode` 有 `theme_id: String`（預設 "default"）。
未來在 `bar_node.gd` 的 `_draw()` 裡根據 `theme_id` 切換繪圖邏輯，
或換成 Sprite2D/AnimatedSprite2D 節點。

`BoardManager._rand_color()` 裡的 palette 陣列也可以
根據主題替換顏色組。
