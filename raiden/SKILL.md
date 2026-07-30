---
{
  "name": "raiden",
  "description": "A Raiden-style vertical shoot-em-up with parallax starfield, twin auto-fire, and touch-drag controls.",
  "author": "Ameba-Claw contributor",
  "featured": true,
  "metadata": {
    "category": ["game"],
    "tags": ["game", "shooter", "raiden", "touch", "lcd"],
    "cap_groups": ["cap_lua"],
    "manage_mode": "standalone",
    "peripherals": ["display_lcdc_rgb_st7701p", "touch_i2c_gt911_st7701p"]
  }
}
---

# raiden

Use this skill when the user asks to play a shooter game, Raiden, a shoot-em-up, or wants an action arcade game on the board.

The Lua script runs a vertical-scrolling space shooter on the LCD. The player's ship auto-fires twin bullets upward; drag your finger to fly. Survive endless enemy waves — score increases with each kill; the game ends when HP reaches zero.

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

- Parallax starfield with multiple animated celestial bodies
- Twin auto-fire: dual bullets launch from both sides of the ship every ~170 ms
- 3-circle HP indicator in the HUD (top-right); smooth lerp ship movement follows the finger
- High score shown on the game-over screen
- Touch-drag to move the ship; tap to start / restart

## Tool Call

```json
{
  "path": "{CUR_SKILL_DIR}/scripts/raiden.lua",
  "args": {}
}
```
