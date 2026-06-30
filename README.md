# Row Swipe

A sliding puzzle game built with Godot 4. Drag rows left and right to align matching colors — clear lines to score points before the board fills up.

**Play on itch.io:** https://starjou.itch.io/row-swipe

## Gameplay

- **Drag** a row left or right to shift it
- Rows with all matching colors are cleared automatically
- New rows push in from the bottom each turn
- Clearing multiple lines at once scores bonus points
- Chain clears across turns for a combo multiplier

### Scoring

| Clear | Points |
|-------|--------|
| 1 line | 100 |
| 2 lines | 300 |
| 3 lines | 700 |
| n lines | 100 × (2ⁿ − 1) |

Combo multiplier applies when you clear lines on consecutive turns (×4, ×8, …).

## Controls

| Input | Action |
|-------|--------|
| Mouse drag / Touch | Slide a row |
| Any input | Wake from idle fade |
| Click / Tap (during demo) | Return to start screen |

## Architecture

```
main.gd          — Root node. UI, high-score persistence (local + Firebase).
board.gd         — Game controller. Input, animation loop, Demo Mode AI.
board_manager.gd — Pure data layer. Grid state, movement, gravity, line clear.
score_manager.gd — Pure data layer. Scoring and combo logic.
bar_node.gd      — Node2D visual. Draws cells with _draw(), drives Tween animations.
board_const.gd   — Global constants (ROWS, COLS, CELL_SIZE, timings).
```

## Development

Open the project in **Godot 4.x** and run `main.tscn`.

### Export & Deploy

Requires [Godot 4.x](https://godotengine.org/) and [itch.io butler](https://itch.io/docs/butler/).

```powershell
.\deploy.ps1
```

This headless-exports to `build/index.html` and pushes to itch.io via butler.

## High Scores

Best score is saved locally as a `.dat` file and synced to Firebase Realtime Database on Web builds.
