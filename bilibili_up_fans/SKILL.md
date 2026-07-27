---
{
  "name": "bilibili_up_fans",
  "description": "Query a Bilibili UP creator's fan count. Defaults to the Realtek Ameba official account.",
  "author": "Ameba-Claw contributor",
  "featured": true,
  "metadata": {
    "category": ["network"],
    "tags": ["bilibili", "fans", "info"],
    "cap_groups": ["cap_lua", "cap_http_request"],
    "manage_mode": "web",
    "peripherals": []
  }
}
---

# bilibili_up_fans

Use this skill when the user asks about a Bilibili UP creator's fan count.

Runs a bundled Lua script via `lua_run`. The script calls the `http_request` capability to access the Bilibili card API and extracts `data.card.fans`.

Queries the **Realtek Ameba** official account by default:
```
https://space.bilibili.com/3546854084053911
```

`search_http_allowlist` must allow `api.bilibili.com` or use `*`.

## Script Args Schema

```json
{
  "type": "object",
  "properties": {
    "mid": {
      "type": "string",
      "description": "Optional. Bilibili member ID, e.g. 3546854084053911"
    },
    "url": {
      "type": "string",
      "description": "Optional. Bilibili space URL, e.g. https://space.bilibili.com/3546854084053911"
    },
    "timeout_ms": {
      "type": "integer",
      "description": "Optional. HTTP timeout in milliseconds, default 15000"
    }
  }
}
```

When both `mid` and `url` are provided, `mid` takes precedence.

## Tool Call Inputs

Query Realtek Ameba (default):

```json
{
  "path": "{CUR_SKILL_DIR}/scripts/bilibili_up_fans.lua",
  "args": {}
}
```

Query a specific UP creator:

```json
{
  "path": "{CUR_SKILL_DIR}/scripts/bilibili_up_fans.lua",
  "args": {
    "mid": "3546854084053911"
  }
}
```

## Behavior

The script prints one human-readable line and one JSON line:

```text
[bilibili_up_fans] Realtek Ameba mid=3546854084053911 fans=1234
{"ok":true,"mid":"3546854084053911","name":"Realtek Ameba","fans":1234,"url":"https://space.bilibili.com/3546854084053911"}
```

Report the `fans` value to the user. If the script errors, report the error message directly.
