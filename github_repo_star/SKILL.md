---
{
  "name": "github_repo_star",
  "description": "Query a GitHub public repository's star count, fork count, and watcher count.",
  "author": "Ameba-Claw contributor",
  "metadata": {
    "cap_groups": [
      "cap_lua",
      "cap_http_request"
    ],
    "manage_mode": "runtime",
    "category": [
      "network"
    ],
    "tags": [
      "network",
      "github",
      "http",
      "info"
    ],
    "peripherals": []
  }
}
---
# github_repo_star

Query a GitHub public repository's star count, fork count, and watcher count.

## How to invoke

Query microsoft/vscode (default):
```json
{"path":"{CUR_SKILL_DIR}/scripts/main.lua","args":{}}
```

Query a specific repo:
```json
{"path":"{CUR_SKILL_DIR}/scripts/main.lua","args":{"owner":"torvalds","repo":"linux"}}
```

## Parameters

- `owner`: GitHub username or org (default: `"microsoft"`)
- `repo`: Repository name (default: `"vscode"`)

## Return value

- Success: `{"ok":true,"full_name":"microsoft/vscode","stars":170000,"forks":30000,"watchers":3000}`
- Error:   `{"error":"<reason>"}`
