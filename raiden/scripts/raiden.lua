-- raiden.lua — vertical shooter for the 480x480 ST7701P RGB LCD + GT911 touch.
-- High-level modules only: display (2D canvas), touch (GT911), sys (timing).
-- Run as a background job:  AT+CLAW=lua_execute_async,<path>/raiden.lua
-- (async jobs have no wall-clock deadline, so the game loop runs until stopped.)

local d   = require("display")
local t   = require("touch")
local sys = require("sys")

-- Board device ids (this board: PKE8721FLM RGB panel + GT911 touch).
local DISPLAY_ID = "display_lcdc_rgb_st7701p"
local TOUCH_ID   = "touch_i2c_gt911_st7701p"

local W, H = 480, 480

-- ---- init ---------------------------------------------------------------
local ok, err = d.init(DISPLAY_ID)
if not ok then print("raiden: display init failed: " .. tostring(err)); return end
d.backlight(true)
W, H = d.width, d.height

ok, err = t.init(TOUCH_ID)
if not ok then print("raiden: touch init failed: " .. tostring(err)); d.deinit(); return end

math.randomseed(sys.millis())

-- ---- colours ------------------------------------------------------------
local C_BG      = 0x000010
local C_STAR_HI = 0xC8D0FF
local C_STAR_LO = 0x404066
local C_SHIP    = 0x33CCFF
local C_SHIP_D  = 0x0077AA
local C_FLAME   = 0xFF8822
local C_BULLET  = 0xFFEE44
local C_ENEMY   = 0xFF4444
local C_ENEMY_D = 0xAA2222
local C_HP      = 0xFF3355
local C_HP_OFF  = 0x442233
local C_WHITE   = 0xFFFFFF
local C_ACCENT  = 0x00FF66
local C_DIM     = 0x8899BB

-- ---- starfield (2 parallax layers) --------------------------------------
local NSTAR = 48
local star_x, star_y, star_v, star_c = {}, {}, {}, {}
for i = 1, NSTAR do
    star_x[i] = math.random(0, W - 1)
    star_y[i] = math.random(0, H - 1)
    if i % 2 == 0 then star_v[i] = 2; star_c[i] = C_STAR_LO   -- far layer, slow/dim
    else               star_v[i] = 5; star_c[i] = C_STAR_HI end -- near layer, fast/bright
end
local star_pts = {}  -- reused flat {x,y,c,...} buffer for draw_points
local function step_stars(active)
    local n = 0
    for i = 1, NSTAR do
        if active then
            star_y[i] = star_y[i] + star_v[i]
            if star_y[i] >= H then star_y[i] = 0; star_x[i] = math.random(0, W - 1) end
        end
        star_pts[n + 1] = star_x[i]
        star_pts[n + 2] = star_y[i]
        star_pts[n + 3] = star_c[i]
        n = n + 3
    end
    for i = n + 1, #star_pts do star_pts[i] = nil end
    d.draw_points(star_pts)
end

-- ---- game state ---------------------------------------------------------
local state         -- "menu" | "playing" | "gameover"
local ship_x, ship_y
local tgt_x, tgt_y
local hp, score, high = 3, 0, 0
local bullets = {}  -- {x, y}
local enemies = {}  -- {x, y, v}
local last_fire, last_spawn = 0, 0

local function reset_game()
    ship_x, ship_y = W / 2, H - 80
    tgt_x, tgt_y   = ship_x, ship_y
    hp, score = 3, 0
    bullets = {}
    enemies = {}
    last_fire, last_spawn = 0, 0
end

-- ---- drawing helpers ----------------------------------------------------
local function draw_ship(x, y)
    -- engine flame flickers
    local f = math.random(6, 14)
    d.fill_triangle(x - 7, y + 16, x + 7, y + 16, x, y + 16 + f, C_FLAME)
    -- hull: upward-pointing triangle
    d.fill_triangle(x, y - 20, x - 18, y + 18, x + 18, y + 18, C_SHIP)
    d.fill_triangle(x, y - 6,  x - 10, y + 14, x + 10, y + 14, C_SHIP_D)
end

local function draw_hud()
    d.draw_text(8, 8, "SCORE " .. score, C_WHITE, nil, 20)
    -- 3-circle HP indicator, top-right
    local on = {}
    for i = 1, hp do
        local cx = W - 20 - (i - 1) * 26
        on[#on + 1] = cx; on[#on + 1] = 20; on[#on + 1] = 9; on[#on + 1] = C_HP
    end
    if #on > 0 then d.fill_circles(on) end
    for i = hp + 1, 3 do
        local cx = W - 20 - (i - 1) * 26
        d.draw_circle(cx, 20, 9, C_HP_OFF, 2)
    end
end

local function center_text(y, str, color, font)
    local w = d.measure_text(str, font)
    d.draw_text((W - w) / 2, y, str, color, nil, font)
end

-- ---- state screens ------------------------------------------------------
local function draw_menu()
    d.begin_frame({clear = true, color = C_BG})
    step_stars(true)
    center_text(150, "RAIDEN",              C_ACCENT, 26)
    center_text(196, "SHOOTER V4",          C_WHITE,  20)
    center_text(300, "Tap to start",        C_WHITE,  20)
    center_text(340, "Touch & drag to move", C_DIM,   14)
    d.present()
end

local function draw_gameover()
    d.begin_frame({clear = true, color = C_BG})
    step_stars(true)
    center_text(150, "GAME OVER",         C_ENEMY, 26)
    center_text(210, "Score " .. score,   C_WHITE, 20)
    center_text(244, "High " .. high,     C_ACCENT, 20)
    center_text(320, "Tap to restart",    C_DIM,   14)
    d.present()
end

-- ---- playing update -----------------------------------------------------
local function update_playing(now)
    -- smooth follow toward finger target
    ship_x = ship_x + (tgt_x - ship_x) * 0.35
    ship_y = ship_y + (tgt_y - ship_y) * 0.35

    -- auto-fire twin bullets
    if now - last_fire >= 170 then
        last_fire = now
        bullets[#bullets + 1] = { ship_x - 12, ship_y - 12 }
        bullets[#bullets + 1] = { ship_x + 12, ship_y - 12 }
    end
    -- move bullets up, drop off-screen
    local kb = {}
    for i = 1, #bullets do
        local b = bullets[i]
        b[2] = b[2] - 12
        if b[2] > -16 then kb[#kb + 1] = b end
    end
    bullets = kb

    -- spawn enemies from the top
    if now - last_spawn >= 650 then
        last_spawn = now
        enemies[#enemies + 1] = { math.random(24, W - 24), -20, math.random(3, 6) }
    end

    -- move enemies, handle collisions
    local ke = {}
    for i = 1, #enemies do
        local e = enemies[i]
        e[2] = e[2] + e[3]
        local dead = false
        -- bullet hits
        for j = 1, #bullets do
            local b = bullets[j]
            if b[2] > 0 and math.abs(b[1] - e[1]) < 20 and math.abs(b[2] - e[2]) < 22 then
                dead = true
                b[2] = -100          -- consume the bullet
                score = score + 10
                break
            end
        end
        -- ship hit
        if not dead then
            local dxp, dyp = e[1] - ship_x, e[2] - ship_y
            if dxp * dxp + dyp * dyp < (18 + 20) * (18 + 20) then
                dead = true
                hp = hp - 1
            end
        end
        if not dead and e[2] < H + 20 then ke[#ke + 1] = e end
    end
    enemies = ke
end

local function draw_playing()
    d.begin_frame({clear = true, color = C_BG})
    step_stars(true)
    -- bullets
    for i = 1, #bullets do
        local b = bullets[i]
        if b[2] > 0 then d.fill_rect(b[1] - 2, b[2] - 7, 4, 14, C_BULLET) end
    end
    -- enemies (batched)
    if #enemies > 0 then
        local ec = {}
        for i = 1, #enemies do
            local e = enemies[i]
            ec[#ec + 1] = e[1]; ec[#ec + 1] = e[2]; ec[#ec + 1] = 16; ec[#ec + 1] = C_ENEMY
        end
        d.fill_circles(ec)
    end
    draw_ship(ship_x, ship_y)
    draw_hud()
    d.present()
end

-- ---- input --------------------------------------------------------------
local function poll_input()
    local tapped = false
    for ev in function() return t.get_event() end do
        if ev.type == "down" or ev.type == "move" then
            tgt_x = ev.x
            tgt_y = ev.y
            if tgt_y < H * 0.45 then tgt_y = H * 0.45 end   -- keep ship in lower half
            if tgt_y > H - 30 then tgt_y = H - 30 end
            if tgt_x < 20 then tgt_x = 20 elseif tgt_x > W - 20 then tgt_x = W - 20 end
            if ev.type == "down" then tapped = true end
        end
    end
    return tapped
end

-- ---- main loop ----------------------------------------------------------
reset_game()
state = "menu"

local function run()
    while true do
        local now = sys.millis()
        local tapped = poll_input()

        if state == "menu" then
            if tapped then reset_game(); state = "playing" end
            draw_menu()
        elseif state == "playing" then
            update_playing(now)
            draw_playing()
            if hp <= 0 then
                if score > high then high = score end
                state = "gameover"
            end
        else -- gameover
            if tapped then reset_game(); state = "playing" end
            draw_gameover()
        end
        -- no sleep: present() is synchronous and paces the frame.
    end
end

local ok2, e2 = pcall(run)
t.deinit()
d.deinit()
if not ok2 then error(e2) end
