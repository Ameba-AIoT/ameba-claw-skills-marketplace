---
{
  "name": "ws2812_led_strip",
  "description": "Drive a WS2812/WS2812B addressable RGB LED strip via SPI DMA. Supports per-pixel and full-strip colour control.",
  "author": "Ameba-Claw contributor",
  "metadata": {
    "cap_groups": ["cap_lua"],
    "manage_mode": "runtime",
    "category": ["control"],
    "tags": ["led", "ws2812", "rgb", "spi", "strip"],
    "peripherals": ["spi"]
  }
}
---

# ws2812_led_strip

Control a WS2812/WS2812B addressable RGB LED strip using the `led_strip` Lua module.
The driver uses SPI DMA (MOSI only) to generate the WS2812 one-wire waveform.

```lua
local led_strip = require("led_strip")
```

See full API, constructor options, board.json config pattern, and wiring notes in:
`lua/modules/lua_module_led_strip/docs/led_strip.md`

## Hardware requirements

An external WS2812/WS2812B LED strip with its DIN line connected to the MOSI pin.
SCLK, MISO, and CS are not wired. For more than 5 LEDs, an external 5 V supply is recommended.

## How to invoke

Run with defaults (config from board.json):
```json
{"path": "{CUR_SKILL_DIR}/scripts/main.lua", "args": {}}
```

No `led_strip` entry in board.json — supply all parameters explicitly:
```json
{"path": "{CUR_SKILL_DIR}/scripts/main.lua", "args": {"spi_idx": 0, "pin": "PA_8", "count": 15, "pinmux": "full"}}
```

`spi_idx`, `pin`, and `count` are required; `pinmux` is optional, default is dedicate. They are read from
board.json first; any missing field must be passed explicitly via `spi_idx`, `pin`, or `count`.

## Runtime behavior

Three effects play in order, cycling continuously. Each runs for 8 seconds before switching.

1. **rainbow** — smooth colour wheel spread across all pixels, shifting over time
2. **breathe** — all pixels pulse from dark to peak brightness in a single hue
3. **chase** — a bright comet races along the strip with a two-step fading tail
