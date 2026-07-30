---
{
  "name": "game2048",
  "description": "Ready-to-run 2048 sliding-tile puzzle game — activate this skill to launch it immediately (do not write your own script).",
  "author": "Ameba-Claw contributor",
  "featured": true,
  "metadata": {
    "category": ["game"],
    "tags": ["game", "2048", "puzzle", "touch", "lcd"],
    "cap_groups": ["cap_lua"],
    "manage_mode": "standalone",
    "peripherals": ["display_lcdc_rgb_st7701p", "touch_i2c_gt911_st7701p"]
  }
}
---

# game2048

**This skill contains a complete, ready-to-run Lua script. Do NOT write your own 2048 script. Just activate this skill and run the bundled script via the Tool Call below.**

Use this skill when the user asks to play 2048, launch the tile puzzle game, or wants a touch-screen game on the board.

The Lua script renders a 4×4 grid on the LCD. Swipe gestures move and merge tiles; matching tiles combine and double their value. Reach 2048 to win. The best score is persisted to `vfs:/tmp/best_2048.json` across sessions.

## Requirements

- **Display**: 480×480 LCD — device `display_lcdc_rgb_st7701p` (ST7701P RGB parallel, board `PKE8721FLM-VA4-N33-HMI-ST7701P`)
- **Touch**: GT911 capacitive touch panel — device `touch_i2c_gt911_st7701p` (same board)

The script hard-codes `W, H = 480, 480` and calls `d.init("display_lcdc_rgb_st7701p")`. It will not work on other resolutions or display drivers without modification.

## Lua Modules Used

| Module | Purpose |
|---|---|
| `display` | All 2D rendering |
| `touch` | Raw touch events |
| `gesture` | Swipe/tap detection |
| `sys` | `sleep_ms(16)` for ~60 fps loop |
| `cjson` | Best-score JSON encode/decode |
| `file` | VFS read/write for best score |

## Features

- Smooth tile spawn and merge animations (easing)
- Win overlay at 2048; continue playing or start a new game
- Game-over detection with restart button
- Persistent best score across sessions

## Tool Call

```json
{
  "path": "{CUR_SKILL_DIR}/scripts/game2048.lua",
  "args": {}
}
```
