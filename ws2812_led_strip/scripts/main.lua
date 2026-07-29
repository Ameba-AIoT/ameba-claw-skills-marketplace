local cjson     = require("cjson")
local led_strip = require("led_strip")
local sys       = require("sys")
local file      = require("file")

local EFFECT_MS = 8000   -- each effect plays for 8 s before switching

local function board_led_cfg()
    local ok, s = pcall(file.read, "board.json")
    if ok and s then
        local ok2, cfg = pcall(cjson.decode, s)
        if ok2 and cfg and cfg.devices then
            for _, d in ipairs(cfg.devices) do
                if d.id == "led_strip" and d.params then
                    return d.params.spi, d.params.mosi, d.params.count
                end
            end
        end
    end
    return nil, nil, nil
end

function run(args)
    if type(args) ~= "table" then args = {} end

    local spi, mosi, count = board_led_cfg()
    if args.spi_idx ~= nil then spi   = tonumber(args.spi_idx) end
    if args.pin     ~= nil then mosi  = tostring(args.pin)     end
    if args.count   ~= nil then count = tonumber(args.count)   end
    local pinmux = args.pinmux or "dedicated"

    local missing = {}
    if spi   == nil then missing[#missing + 1] = "spi_idx" end
    if mosi  == nil then missing[#missing + 1] = "pin"     end
    if count == nil then missing[#missing + 1] = "count"   end
    if #missing > 0 then
        return cjson.encode({
            error = "missing params (not in board.json and not provided): " .. table.concat(missing, ", ")
        })
    end

    local ok_new, strip = pcall(led_strip.new, { spi = spi, mosi = mosi, count = count, pinmux = pinmux })
    if not ok_new then
        return cjson.encode({ error = "init failed: " .. tostring(strip) })
    end

    -- Smooth colour wheel spread across all pixels, shifting over time
    local function rainbow(deadline)
        local offset = 0
        local step   = math.floor(360 / count)
        while not led_strip.stop_requested() and sys.millis() < deadline do
            for i = 1, count do
                strip:set_pixel_hsv(i, (offset + (i - 1) * step) % 360, 255, 150)
            end
            strip:show()
            offset = (offset + 2) % 360
            sys.sleep_ms(30)
        end
    end

    -- All pixels pulse from dark to peak brightness in a single hue
    local function breathe(deadline)
        local v, dir = 0, 1
        while not led_strip.stop_requested() and sys.millis() < deadline do
            strip:fill_hsv(200, 255, v)
            strip:show()
            v = v + dir * 4
            if v >= 220 then dir = -1
            elseif v <= 0 then dir = 1 end
            sys.sleep_ms(12)
        end
    end

    -- Bright comet races along the strip with a two-step fading tail
    local function chase(deadline)
        local pos = 1
        while not led_strip.stop_requested() and sys.millis() < deadline do
            strip:clear()
            strip:set_pixel_hsv(pos,                          30, 255, 220)
            strip:set_pixel_hsv(((pos - 2) % count) + 1,     30, 220, 100)
            strip:set_pixel_hsv(((pos - 3) % count) + 1,     30, 200,  40)
            strip:show()
            pos = (pos % count) + 1
            sys.sleep_ms(50)
        end
    end

    local effects = { rainbow, breathe, chase }
    local idx = 1
    local ok_run, err = pcall(function()
        while not led_strip.stop_requested() do
            effects[idx](sys.millis() + EFFECT_MS)
            idx = (idx % #effects) + 1
        end
    end)

    strip:clear()
    strip:show()
    strip:close()
    if not ok_run then
        return cjson.encode({ error = tostring(err) })
    end
    return cjson.encode({ ok = true })
end
