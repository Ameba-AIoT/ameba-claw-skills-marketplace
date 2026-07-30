---
{
  "name": "public_ip_info",
  "description": "Query the device's public IP address, city, and ISP via the ip-api.com geolocation API. No authentication required.",
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
      "ip",
      "geolocation",
      "http",
      "info"
    ],
    "peripherals": []
  }
}
---
# public_ip_info

Query the device's public (WAN) IP address and its geolocation details (city,
region, ISP) using the free ip-api.com API. No API key or authentication required.

## API Reference

```
GET http://ip-api.com/json
```

Response:
```json
{
  "status": "success",
  "query": "1.2.3.4",
  "country": "China",
  "regionName": "Jiangsu",
  "city": "Suzhou",
  "isp": "China Telecom",
  "org": "..."
}
```

## Prerequisites

This skill calls `ip-api.com` via `http_request`. The host must appear in the
**HTTP Request URL allowlist** (Web UI → HTTP Request settings), otherwise the cap
returns `{"error":"blocked by allowlist..."}`.

Minimal allowlist entry: `ip-api.com` or `*` allows all hosts.

**Note:** ip-api.com does not support HTTPS on the free tier — use `http://`.

## How to invoke

No dedicated script. Call `http_request` directly with the endpoint and parse
the JSON response body:

```
GET http://ip-api.com/json
→ body.query       → public IP address
→ body.city        → city name
→ body.regionName  → province / region
→ body.isp         → Internet Service Provider
→ body.status      → "success" on success
```

## Notes

- The API returns the IP of the outbound interface as seen by the server — this
  is the public WAN IP, not the LAN address.
- `city` and `isp` may be in English even for Chinese IPs; both are acceptable.
- Rate limit: 45 requests/minute per IP (sufficient for individual queries).
