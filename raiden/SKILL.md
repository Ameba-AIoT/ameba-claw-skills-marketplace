---
{
  "name": "raiden",
  "description": "A Raiden-style vertical shoot-em-up with parallax starfield, four enemy types, and touch-drag controls.",
  "author": "Ameba-Claw contributor",
  "featured": true,
  "metadata": {
    "category": ["game"],
    "tags": ["game", "shooter", "raiden", "touch", "lcd"],
    "cap_groups": ["cap_lua"],
    "manage_mode": "standalone",
    "peripherals": ["display"]
  }
}
---

# raiden

Use this skill when the user asks to play a shooter game, Raiden, a shoot-em-up, or wants an action arcade game on the board.

The Lua script runs a vertical-scrolling space shooter on the LCD. The player's ship auto-fires upward; drag your finger to fly. Survive waves of four distinct enemy types with varied bullet patterns. Score increases with each enemy destroyed; the game ends when the ship's HP reaches zero.

## Requirements

- **Display**: 480×480 LCD — device `display_lcdc_rgb_st7701p` (ST7701P RGB parallel, board `PKE8721FLM-VA4-N33-HMI-ST7701P`)
- **Touch**: GT911 capacitive touch panel — device `touch_i2c_gt911_st7701p` (same board)

The script hard-codes `W, H = 480, 480` and calls `d.init("display_lcdc_rgb_st7701p")`. It will not work on other resolutions or display drivers without modification.

## Lua Modules Used

| Module | Purpose |
|---|---|
| `display` | All 2D rendering (circles, triangles, arcs, batch primitives) |
| `touch` | Raw touch events for ship drag control |
| `sys` | `sys.millis()` for delta-time game loop |

## Features

- Parallax space background: twinkling stars, scrolling perspective grid, 5 animated celestial bodies (moon, Mars, ringed planet, etc.)
- Four enemy types with distinct art and bullet patterns (straight, aimed, spread)
- Particle explosion effects on enemy/ship destruction
- Batched draw calls (`d.fill_circles`, `d.draw_points`) for smooth 480×480 rendering
- High score displayed on game-over screen (in-memory per session)
- Touch-drag ship movement; tap to start/restart

## Tool Call

```json
{
  "path": "{CUR_SKILL_DIR}/scripts/raiden.lua",
  "args": {}
}
```
