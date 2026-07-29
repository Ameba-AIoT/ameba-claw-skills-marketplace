---
name: current_weather
description: "Query current weather conditions and today's high/low temperature for any city using HTTP APIs. Accepts city name as input."
compatibility: RTL8721F
metadata:
  manage_mode: runtime
  category: network
---
# current_weather

Query real-time weather (condition description, current/high/low temperature)
for a given city using free HTTP APIs. No API key required for Options 1–3;
Option 4 requires an OpenWeatherMap API key.

## Parameter

- `city`: City or location name string (e.g. `"Suzhou Industrial Park"`,
  `"Beijing"`, `"Suzhou Industrial Park"`)

---

## Geocoding (required for Options 1 and 3)

Options 1 and 3 require latitude/longitude. Use the open-meteo geocoding API
to convert a city name to coordinates:

```
GET https://geocoding-api.open-meteo.com/v1/search?name={city}&count=1&language=en
```

Response:
```json
{"results": [{"name": "Suzhou", "admin1": "Jiangsu", "latitude": 31.30408, "longitude": 120.59538}]}
```

Extract `results[0].latitude` and `results[0].longitude`, then pass them to
the weather API. If `results` is empty the city was not found — try a shorter
or alternative spelling.

---

## Option 1 — open-meteo (recommended, free, no key)

```
GET https://api.open-meteo.com/v1/forecast
    ?latitude={lat}&longitude={lon}
    &current_weather=true
    &daily=temperature_2m_max,temperature_2m_min
    &timezone=auto
    &forecast_days=1
```

Response (key fields):
```json
{
  "current_weather": {"temperature": 26.1, "weathercode": 53},
  "daily": {"temperature_2m_max": [28.0], "temperature_2m_min": [23.0]}
}
```

Extract:
- `current_weather.temperature` → current temperature (°C)
- `daily.temperature_2m_max[0]` → today's high (°C)
- `daily.temperature_2m_min[0]` → today's low (°C)
- `current_weather.weathercode` → WMO code → description (see table below)

### WMO Weather Code Table

| Code | Description |
|---|---|
| 0 | Clear sky |
| 1 | Mainly clear |
| 2 | Partly cloudy |
| 3 | Overcast |
| 45, 48 | Fog |
| 51, 53, 55 | Drizzle (light / moderate / dense) |
| 61, 63, 65 | Rain (slight / moderate / heavy) |
| 71, 73, 75 | Snow (slight / moderate / heavy) |
| 80, 81, 82 | Rain showers (slight / moderate / heavy) |
| 95 | Thunderstorm |
| 96, 99 | Thunderstorm with hail |

---

## Option 2 — wttr.in (free, no key, city name direct)

```
GET https://wttr.in/{city}?format=j1
```

Replace spaces in `{city}` with `+` (e.g. `Suzhou+Industrial+Park`).

Response (key fields):
```json
{
  "current_condition": [{"temp_C": "27", "weatherDesc": [{"value": "Patchy rain nearby"}]}],
  "weather": [{"maxtempC": "28", "mintempC": "24"}]
}
```

Extract:
- `current_condition[0].temp_C` → current temperature (°C)
- `current_condition[0].weatherDesc[0].value` → weather description (English text, no code lookup needed)
- `weather[0].maxtempC` → today's high (°C)
- `weather[0].mintempC` → today's low (°C)

---

## Option 3 — met.no / Norwegian Meteorological Institute (free, no key)

Requires geocoding (see above). Requires a `User-Agent` header.

```
GET https://api.met.no/weatherapi/locationforecast/2.0/compact
    ?lat={lat}&lon={lon}
```

Headers: `User-Agent: ameba-claw/1.0`

Response (key fields):
```json
{
  "properties": {
    "timeseries": [
      {"time": "...", "data": {
        "instant": {"details": {"air_temperature": 26.2}},
        "next_1_hours": {"summary": {"symbol_code": "rain"}}
      }}
    ]
  }
}
```

Extract:
- `properties.timeseries[0].data.instant.details.air_temperature` → current temp (°C)
- `properties.timeseries[0].data.next_1_hours.summary.symbol_code` → condition string
- Today's high/low: iterate `timeseries[0..23]`, collect `air_temperature`, take max/min

---

## Option 4 — OpenWeatherMap (requires API key)

Accepts city name directly; no geocoding step needed.

**Step 1 — current condition:**
```
GET https://api.openweathermap.org/data/2.5/weather
    ?q={city}&appid={API_KEY}&units=metric
```

Response (key fields):
```json
{
  "name": "Suzhou",
  "weather": [{"description": "light rain"}],
  "main": {"temp": 26.14}
}
```

Extract: `weather[0].description` (condition), `main.temp` (current °C)

**Step 2 — today's high/low (3-hour forecast):**
```
GET https://api.openweathermap.org/data/2.5/forecast
    ?q={city}&appid={API_KEY}&units=metric&cnt=8
```

`cnt=8` returns the next 8 × 3-hour slots (≈ 24 hours). Take
`max(list[*].main.temp_max)` as today's high and `min(list[*].main.temp_min)`
as today's low.

---

## Prerequisites

Each option requires the corresponding host in the **HTTP Request URL allowlist**
(Web UI → HTTP Request settings). Use `*` to allow all hosts.

| Option | Hosts to allowlist |
|---|---|
| 1 | `geocoding-api.open-meteo.com`, `api.open-meteo.com` |
| 2 | `wttr.in` |
| 3 | `geocoding-api.open-meteo.com`, `api.met.no` |
| 4 | `api.openweathermap.org` |

Option 4 also requires an OpenWeatherMap API key (`appid`). The key is stored
outside this skill — ask the user or read it from the device configuration.

## Notes

- All temperatures are in °C; do not convert to Fahrenheit.
- Use `timezone=auto` in open-meteo so the daily high/low aligns with local
  midnight, not UTC.
- For Option 1, geocode first; if geocoding returns no results, try a shorter
  city name (e.g. `"Suzhou"` instead of `"Suzhou Industrial Park"`).
