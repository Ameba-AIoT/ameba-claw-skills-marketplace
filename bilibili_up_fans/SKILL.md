---
{
  "name": "bilibili_up_fans",
  "description": "查询 Bilibili UP 主的粉丝数。默认查询 Realtek Ameba 官方账号。",
  "author": "leann_wang",
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

当用户询问某个 Bilibili UP 主的粉丝数时，使用本 skill。

通过 `lua_run` 运行打包的 Lua 脚本。脚本调用 `http_request` 能力访问 Bilibili card API，提取 `data.card.fans`。

默认查询 **Realtek Ameba** 官方账号：
```
https://space.bilibili.com/3546854084053911
```

`search_http_allowlist` 必须允许 `api.bilibili.com` 或使用 `*`。

## Script Args Schema

```json
{
  "type": "object",
  "properties": {
    "mid": {
      "type": "string",
      "description": "可选，Bilibili 成员 ID，例如 3546854084053911"
    },
    "url": {
      "type": "string",
      "description": "可选，Bilibili 空间 URL，例如 https://space.bilibili.com/3546854084053911"
    },
    "timeout_ms": {
      "type": "integer",
      "description": "可选，HTTP 超时毫秒数，默认 15000"
    }
  }
}
```

`mid` 和 `url` 同时提供时，`mid` 优先。

## Tool Call Inputs

默认查询 Realtek Ameba：

```json
{
  "path": "{CUR_SKILL_DIR}/scripts/bilibili_up_fans.lua",
  "args": {}
}
```

查询指定 UP 主：

```json
{
  "path": "{CUR_SKILL_DIR}/scripts/bilibili_up_fans.lua",
  "args": {
    "mid": "3546854084053911"
  }
}
```

## Behavior

脚本打印一行可读文本和一行 JSON：

```text
[bilibili_up_fans] Realtek Ameba mid=3546854084053911 fans=1234
{"ok":true,"mid":"3546854084053911","name":"Realtek Ameba","fans":1234,"url":"https://space.bilibili.com/3546854084053911"}
```

将 `fans` 值报告给用户。若脚本出错，直接报告错误信息。
