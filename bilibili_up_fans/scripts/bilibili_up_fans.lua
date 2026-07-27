local cap = require("cap")
local cjson = require("cjson")

local DEFAULT_MID = "3546854084053911"
local DEFAULT_TIMEOUT_MS = 15000
local MAX_BODY_BYTES = 16384

local a = type(args) == "table" and args or {}

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function parse_mid(value)
    local spec = trim(value)
    if spec == "" then return nil end

    local mid = spec:match("^https?://space%.bilibili%.com/(%d+)")
    if mid then return mid end

    spec = spec:gsub("[#?].*$", "")
    mid = spec:match("^(%d+)$")
    if mid then return mid end

    return nil
end

local function request_timeout()
    local value = a.timeout_ms
    if type(value) ~= "number" then return DEFAULT_TIMEOUT_MS end
    value = math.floor(value)
    if value < 1 then return 1 end
    if value > 120000 then return 120000 end
    return value
end

local function selected_mid()
    local mid
    if type(a.mid) == "string" and trim(a.mid) ~= "" then
        mid = parse_mid(a.mid)
    elseif type(a.url) == "string" and trim(a.url) ~= "" then
        mid = parse_mid(a.url)
    else
        mid = DEFAULT_MID
    end
    if not mid then
        error("mid must be digits or a space.bilibili.com URL")
    end
    return mid
end

local function run()
    local mid = selected_mid()
    local api_url = "https://api.bilibili.com/x/web-interface/card?mid=" .. mid

    local req = cjson.encode({
        method = "GET",
        url = api_url,
        headers = {
            Accept = "application/json",
            Referer = "https://space.bilibili.com/" .. mid,
        },
        timeout = math.floor(request_timeout() / 1000),
    })

    local ok, result = cap.call("http_request", req)
    if not ok then
        error("http_request failed: " .. tostring(result))
    end

    local resp = cjson.decode(result)
    if resp.error then
        error("http_request error: " .. tostring(resp.error))
    end
    if resp.status_code ~= 200 then
        error(string.format("Bilibili API HTTP %d", resp.status_code))
    end

    -- body is already a table if Bilibili returned valid JSON
    local data
    if type(resp.body) == "table" then
        data = resp.body
    else
        local ok2, decoded = pcall(cjson.decode, tostring(resp.body or ""))
        if not ok2 or type(decoded) ~= "table" then
            error("Bilibili API returned invalid JSON")
        end
        data = decoded
    end

    if data.code ~= 0 then
        error(string.format("Bilibili API error code=%s message=%s",
            tostring(data.code), tostring(data.message or "")))
    end
    if type(data.data) ~= "table" or type(data.data.card) ~= "table" then
        error("Bilibili API response missing data.card")
    end

    local card = data.data.card
    if type(card.fans) ~= "number" then
        error("Bilibili API response missing data.card.fans")
    end

    local result_obj = {
        ok = true,
        mid = tostring(card.mid or mid),
        name = card.name or "",
        fans = card.fans,
        url = "https://space.bilibili.com/" .. mid,
    }

    print(string.format(
        "[bilibili_up_fans] %s mid=%s fans=%d",
        result_obj.name ~= "" and result_obj.name or result_obj.mid,
        result_obj.mid,
        result_obj.fans
    ))
    print(cjson.encode(result_obj))
end

local ok, err = pcall(run)
if not ok then
    print("[bilibili_up_fans] ERROR: " .. tostring(err))
    error(err)
end
