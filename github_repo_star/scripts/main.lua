local cjson = require("cjson")
local cap   = require("cap")

function run(args)
    if type(args) ~= "table" then args = {} end
    local owner = tostring(args.owner or "microsoft")
    local repo  = tostring(args.repo  or "vscode")

    local ok, result = cap.call("http_request", cjson.encode({
        method  = "GET",
        url     = "https://api.github.com/repos/" .. owner .. "/" .. repo,
        headers = {["User-Agent"] = "ameba-claw/1.0"},
    }))

    if not ok then
        return cjson.encode({error = "http_request failed: " .. tostring(result)})
    end

    local resp
    local parse_ok, parse_err = pcall(function() resp = cjson.decode(result) end)
    if not parse_ok or type(resp) ~= "table" then
        return cjson.encode({error = "response parse error: " .. tostring(parse_err)})
    end

    if resp.status_code ~= 200 then
        return cjson.encode({error = "HTTP " .. tostring(resp.status_code), raw = result})
    end

    local body = resp.body
    if type(body) == "string" then
        local body_ok, body_err = pcall(function() body = cjson.decode(body) end)
        if not body_ok then
            return cjson.encode({error = "body parse error: " .. tostring(body_err), raw = result})
        end
    end

    if type(body) ~= "table" or type(body.stargazers_count) ~= "number" then
        return cjson.encode({error = "unexpected response shape", raw = result})
    end

    return cjson.encode({
        ok        = true,
        full_name = tostring(body.full_name or (owner .. "/" .. repo)),
        stars     = body.stargazers_count,
        forks     = body.forks_count,
        watchers  = body.watchers_count,
    })
end
