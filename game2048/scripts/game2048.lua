-- ============================================================
--  2048  .  RTL8721F  .  ST7701P 480x480 LCD + GT911 Touch
-- ============================================================
--  Swipe to move tiles. Merge same numbers. Reach 2048!
--  Tap "New Game" to restart. Auto-saves best score.
-- ============================================================

local d       = require("display")
local t       = require("touch")
local gesture = require("gesture")
local sys     = require("sys")
local cjson   = require("cjson")
local file    = require("file")

-- -- layout constants (carefully sized for 480x480) ----------
local W, H      = 480, 480
local GRID_N    = 4
local TOP_BAR   = 64
local BOARD_PAD = 8
local AVAIL_W   = W - 16
local AVAIL_H   = H - TOP_BAR - BOARD_PAD - 8
local AVAIL     = math.min(AVAIL_W, AVAIL_H)
local GAP       = 6
local CELL      = (AVAIL - GAP * (GRID_N - 1) - GAP * 2) // GRID_N
local BOARD_W   = CELL * GRID_N + GAP * (GRID_N - 1)
local BOARD_L   = (W - BOARD_W) // 2
local BOARD_TOP = TOP_BAR + (H - TOP_BAR - BOARD_PAD - BOARD_W) // 2

-- -- color palette for each tile value -----------------------
local TILE_STYLE = {
    [2]    = {bg=0xEEE4DA, fg=0x776E65},
    [4]    = {bg=0xEDE0C8, fg=0x776E65},
    [8]    = {bg=0xF2B179, fg=0xFFFFFF},
    [16]   = {bg=0xF59563, fg=0xFFFFFF},
    [32]   = {bg=0xF67C5F, fg=0xFFFFFF},
    [64]   = {bg=0xF65E3B, fg=0xFFFFFF},
    [128]  = {bg=0xEDCF72, fg=0xFFFFFF},
    [256]  = {bg=0xEDCC61, fg=0xFFFFFF},
    [512]  = {bg=0xEDC850, fg=0xFFFFFF},
    [1024] = {bg=0xEDC53F, fg=0xFFFFFF},
    [2048] = {bg=0xEDC22E, fg=0xFFFFFF},
    [4096] = {bg=0x3C3A32, fg=0xFFFFFF},
    [8192] = {bg=0x5C5A52, fg=0xFFFFFF},
}

local function get_tile_style(val)
    return TILE_STYLE[val] or {bg=0x1a1a2e, fg=0xFFFFFF}
end

-- -- easing --------------------------------------------------
local function ease_outBack(t)
    local c1 = 1.70158
    local c3 = c1 + 1
    return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end

-- -- cell helpers --------------------------------------------
local function cell_center(r, c)
    local x = BOARD_L + (c - 1) * (CELL + GAP) + CELL / 2
    local y = BOARD_TOP + (r - 1) * (CELL + GAP) + CELL / 2
    return x, y
end
local function cell_topleft(r, c)
    local x = BOARD_L + (c - 1) * (CELL + GAP)
    local y = BOARD_TOP + (r - 1) * (CELL + GAP)
    return x, y
end

-- -- text centering helper -----------------------------------
-- measure text then draw it truly centered at (cx, cy)
-- small downward nudge to compensate font ascent/baseline optical bias
local function draw_text_centered(cx, cy, str, color, font_px)
    local tw, th = d.measure_text(str, font_px)
    local ox = cx - tw / 2
    local oy = cy - th / 2 + th * 0.08
    d.draw_text(ox, oy, str, color, nil, font_px)
end

-- font size: pick the largest available that fits the cell width
-- available fonts: 14, 20, 24, 26
local function font_for_val(val)
    local s = tostring(val)
    for _, fs in ipairs({26, 24, 20, 14}) do
        local tw = d.measure_text(s, fs)
        if tw <= CELL - 8 then return fs end
    end
    return 14
end

-- ============================================================
--  Game state
-- ============================================================
local game = {
    state      = "menu",
    grid       = {},
    score      = 0,
    best       = 0,
    anim_t     = 0,
    anim_dur   = 130,
    new_tiles  = {},
    merge_tiles= {},
    has_won    = false,
    busy       = false,
}

local BEST_FILE = "vfs:/tmp/best_2048.json"
local function load_best()
    local data = file.read(BEST_FILE)
    if data and #data > 0 then
        local ok, tbl = pcall(cjson.decode, data)
        if ok and tbl and tbl.best then game.best = tbl.best end
    end
end
local function save_best()
    file.write(BEST_FILE, cjson.encode({best = game.best}))
end

-- ============================================================
--  Core game logic
-- ============================================================

local function new_grid()
    local g = {}
    for r = 1, GRID_N do g[r] = {}; for c = 1, GRID_N do g[r][c] = 0 end end
    return g
end

local function clone_grid(g)
    local c = {}
    for r = 1, GRID_N do c[r] = {}; for cc = 1, GRID_N do c[r][cc] = g[r][cc] end end
    return c
end

local function empty_cells(g)
    local cells = {}
    for r = 1, GRID_N do for c = 1, GRID_N do
        if g[r][c] == 0 then cells[#cells+1] = {r=r, c=c} end
    end end
    return cells
end

local function spawn_tile(g)
    local empties = empty_cells(g)
    if #empties == 0 then return nil end
    local pick = empties[math.random(1, #empties)]
    g[pick.r][pick.c] = math.random() < 0.9 and 2 or 4
    return pick.r, pick.c
end

local function compress_line(line)
    local n = #line
    local non_zero = {}
    for i = 1, n do if line[i] ~= 0 then non_zero[#non_zero+1] = line[i] end end
    local result, score, merged_flags = {}, 0, {}
    local i = 1
    while i <= #non_zero do
        if i < #non_zero and non_zero[i] == non_zero[i+1] then
            result[#result+1] = non_zero[i] * 2
            merged_flags[#result] = true
            score = score + non_zero[i] * 2
            i = i + 2
        else
            result[#result+1] = non_zero[i]; i = i + 1
        end
    end
    while #result < n do result[#result+1] = 0 end
    return result, score, merged_flags
end

local function grid_changed(old, new)
    for r = 1, GRID_N do for c = 1, GRID_N do
        if old[r][c] ~= new[r][c] then return true end
    end end
    return false
end

local function do_move(dir)
    if game.busy then return false end
    local old_grid = clone_grid(game.grid)
    local new_grid = new_grid()
    local total_score, merge_cells = 0, {}

    if dir == "left" or dir == "right" then
        for r = 1, GRID_N do
            local line = {}
            for c = 1, GRID_N do line[c] = game.grid[r][c] end
            if dir == "right" then local rev={}; for i=GRID_N,1,-1 do rev[#rev+1]=line[i] end; line=rev end
            local compressed, sc, mflags = compress_line(line)
            total_score = total_score + sc
            local new_row = compressed
            if dir == "right" then local rev={}; for i=GRID_N,1,-1 do rev[#rev+1]=new_row[i] end; new_row=rev end
            for c = 1, GRID_N do new_grid[r][c] = new_row[c] end
            for k = 1, #mflags do if mflags[k] then
                local real_c = dir=="right" and (GRID_N-k+1) or k
                merge_cells[#merge_cells+1] = {r=r, c=real_c}
            end end
        end
    else
        for c = 1, GRID_N do
            local line = {}
            for r = 1, GRID_N do line[r] = game.grid[r][c] end
            if dir == "down" then local rev={}; for i=GRID_N,1,-1 do rev[#rev+1]=line[i] end; line=rev end
            local compressed, sc, mflags = compress_line(line)
            total_score = total_score + sc
            local new_col = compressed
            if dir == "down" then local rev={}; for i=GRID_N,1,-1 do rev[#rev+1]=new_col[i] end; new_col=rev end
            for r = 1, GRID_N do new_grid[r][c] = new_col[r] end
            for k = 1, #mflags do if mflags[k] then
                local real_r = dir=="down" and (GRID_N-k+1) or k
                merge_cells[#merge_cells+1] = {r=real_r, c=c}
            end end
        end
    end

    if not grid_changed(old_grid, new_grid) then return false end

    game.grid = new_grid
    game.score = game.score + total_score
    if game.score > game.best then game.best = game.score; save_best() end

    local sr, sc = spawn_tile(game.grid)
    game.new_tiles = sr and {{r=sr, c=sc}} or {}

    if not game.has_won then
        for r = 1, GRID_N do for c = 1, GRID_N do
            if game.grid[r][c] >= 2048 then game.has_won = true; game.state = "won" end
        end end
    end

    if #empty_cells(game.grid) == 0 then
        local can_move = false
        for r = 1, GRID_N do for c = 1, GRID_N do
            if c < GRID_N and game.grid[r][c] == game.grid[r][c+1] then can_move = true end
            if r < GRID_N and game.grid[r][c] == game.grid[r+1][c] then can_move = true end
        end end
        if not can_move and game.state ~= "won" then game.state = "over" end
    end

    game.busy = true
    game.anim_t = 0
    game.merge_tiles = merge_cells
    return true
end

-- ============================================================
--  Rendering
-- ============================================================

local function draw_tile(cx, cy, val, scale)
    if val == 0 then return end
    scale = scale or 1.0
    local style = get_tile_style(val)
    local half = CELL / 2 * scale
    local radius = 6 * scale
    local x, y, sz = cx - half, cy - half, half * 2

    d.fill_round_rect(x, y, sz, sz, radius, style.bg)
    d.draw_round_rect(x, y, sz, sz, radius, 0x222222, 1)

    local fs = font_for_val(val)
    local str = tostring(val)
    draw_text_centered(cx, cy, str, style.fg, fs)
end

local function draw_board_bg()
    d.fill_round_rect(BOARD_L - GAP, BOARD_TOP - GAP,
        BOARD_W + GAP*2, BOARD_W + GAP*2, 10, 0x2a2a3e)
    for r = 1, GRID_N do
        for c = 1, GRID_N do
            local x, y = cell_topleft(r, c)
            d.fill_round_rect(x, y, CELL, CELL, 6, 0x3a3a4e)
        end
    end
end

-- pick font size for score/best value: try largest first
local function font_for_number(n)
    local s = tostring(n)
    for _, fs in ipairs({26, 24, 20, 14}) do
        local tw = d.measure_text(s, fs)
        if tw <= 72 then return fs end
    end
    return 14
end

local function draw_top_bar()
    d.fill_rect(0, 0, W, TOP_BAR, 0x0d0d1a)

    -- -- left: title --
    d.draw_text(12, 10, "2048", 0xFFD700, nil, 26)
    d.draw_text(12, 40, "Swipe to merge!", 0x555577, nil, 14)

    -- -- right: score & best boxes --
    local box_w = 80
    local box_h = 48
    local box_gap = 8
    local bx2 = W - box_w - 10
    local bx1 = bx2 - box_w - box_gap

    -- BEST box
    d.fill_round_rect(bx1, 8, box_w, box_h, 6, 0x1a1a30)
    d.draw_round_rect(bx1, 8, box_w, box_h, 6, 0x333355, 1)
    d.draw_text_aligned(bx1, 10, box_w, 14, "BEST", 0x888899, "center")
    draw_text_centered(bx1 + box_w / 2, 10 + 14 + (box_h - 14) / 2,
        tostring(game.best), 0x66FF99, font_for_number(game.best))

    -- SCORE box
    d.fill_round_rect(bx2, 8, box_w, box_h, 6, 0x1a1a30)
    d.draw_round_rect(bx2, 8, box_w, box_h, 6, 0x333355, 1)
    d.draw_text_aligned(bx2, 10, box_w, 14, "SCORE", 0x888899, "center")
    draw_text_centered(bx2 + box_w / 2, 10 + 14 + (box_h - 14) / 2,
        tostring(game.score), 0xFFD700, font_for_number(game.score))

    -- separator
    d.draw_line(0, TOP_BAR, W, TOP_BAR, 0x333355, 2)
end

local function draw_game_playing()
    for r = 1, GRID_N do
        for c = 1, GRID_N do
            local val = game.grid[r][c]
            if val ~= 0 then
                local cx, cy = cell_center(r, c)
                local scale = 1.0

                if game.busy then
                    for _, mc in ipairs(game.merge_tiles) do
                        if mc.r == r and mc.c == c then
                            scale = 0.6 + 0.6 * ease_outBack(game.anim_t)
                        end
                    end
                end

                if game.busy then
                    for _, nt in ipairs(game.new_tiles) do
                        if nt.r == r and nt.c == c then
                            scale = ease_outBack(game.anim_t)
                            if scale < 0.01 then scale = 0.01 end
                        end
                    end
                end

                draw_tile(cx, cy, val, scale)
            end
        end
    end
end

local function draw_menu()
    d.fill_rect(0, 0, W, H, 0xCC0a0a14)
    local cy = H / 2
    d.draw_text_aligned(0, cy - 80, W, 60, "2048", 0xFFD700, "center")
    d.draw_text_aligned(0, cy - 20, W, 20, "Swipe to move tiles", 0x888899, "center")
    d.draw_text_aligned(0, cy + 6, W, 20, "Merge to reach 2048!", 0x6688AA, "center")

    local btn_w, btn_h = 200, 50
    local bx, by = W/2 - btn_w/2, cy + 50
    d.fill_round_rect(bx, by, btn_w, btn_h, 10, 0x2D8C2D)
    d.draw_round_rect(bx, by, btn_w, btn_h, 10, 0x44FF44, 2)
    -- use draw_text_centered for true centering inside button
    draw_text_centered(bx + btn_w / 2, by + btn_h / 2, "TAP TO START", 0xFFFFFF, 14)
end

local function draw_overlay(msg, sub, color)
    d.fill_rect(0, 0, W, H, 0xCC000000)
    d.draw_text_aligned(0, H/2 - 70, W, 60, msg, color, "center")
    d.draw_text_aligned(0, H/2 - 5, W, 20, sub, 0xAAAAAA, "center")

    local btn_w, btn_h = 200, 50
    local bx, by = W/2 - btn_w/2, H/2 + 40
    d.fill_round_rect(bx, by, btn_w, btn_h, 10, 0x2D5C8C)
    d.draw_round_rect(bx, by, btn_w, btn_h, 10, 0x4488CC, 2)
    draw_text_centered(bx + btn_w / 2, by + btn_h / 2, "TAP TO RESTART", 0xFFFFFF, 14)
end

-- ============================================================
--  Game flow
-- ============================================================

local function start_new_game()
    game.grid = new_grid()
    game.score = 0
    game.state = "playing"
    game.has_won = false
    game.busy = false
    game.anim_t = 0
    game.new_tiles = {}
    game.merge_tiles = {}
    spawn_tile(game.grid)
    spawn_tile(game.grid)
end

-- ============================================================
--  Main loop
-- ============================================================

function run(args)
    local ok, err = d.init("display_lcdc_rgb_st7701p")
    if not ok then print("display init failed:", err); return end
    d.backlight(true)

    local ok2, err2 = t.init("touch_i2c_gt911_st7701p")
    if not ok2 then print("touch init failed:", err2); d.deinit(); return end

    load_best()
    local g = gesture.new({swipe_min = 25})

    start_new_game()
    game.state = "menu"

    print("[2048] game started!")

    local need_redraw = true
    local anim_tick = 0

    while true do
        -- process touch events
        while true do
            local ev = t.get_event()
            if not ev then break end
            local gz = g:feed(ev)
            if gz then
                if gz.kind == "tap" then
                    if game.state == "menu" or game.state == "won" or game.state == "over" then
                        start_new_game()
                        need_redraw = true
                    end
                elseif gz.kind == "swipe" then
                    if game.state == "playing" and not game.busy then
                        local moved = do_move(gz.dir)
                        if moved then need_redraw = true end
                    end
                end
            end
        end

        -- heartbeat
        local gz2 = g:feed(nil)
        if gz2 then
            if gz2.kind == "tap" then
                if game.state == "menu" or game.state == "won" or game.state == "over" then
                    start_new_game()
                    need_redraw = true
                end
            elseif gz2.kind == "swipe" then
                if game.state == "playing" and not game.busy then
                    local moved = do_move(gz2.dir)
                    if moved then need_redraw = true end
                end
            end
        end

        -- advance animation
        if game.busy then
            game.anim_t = game.anim_t + 16 / game.anim_dur
            if game.anim_t >= 1.0 then
                game.anim_t = 1.0
                game.busy = false
            end
            need_redraw = true
        end

        -- menu/overlay pulse
        if game.state == "menu" or game.state == "won" or game.state == "over" then
            anim_tick = anim_tick + 1
            if anim_tick % 12 == 0 then need_redraw = true end
        end

        if need_redraw then
            need_redraw = false
            d.begin_frame({clear = true, color = 0x0d0d1a})

            draw_board_bg()

            if game.state == "menu" then
                draw_game_playing()
                draw_menu()
            elseif game.state == "playing" then
                draw_game_playing()
            elseif game.state == "won" then
                draw_game_playing()
                draw_overlay("YOU WIN!", "Score: " .. game.score, 0xFFD700)
            elseif game.state == "over" then
                draw_game_playing()
                draw_overlay("GAME OVER", "Score: " .. game.score, 0xFF4444)
            end

            draw_top_bar()
            d.present()
        end

        sys.sleep_ms(16)
    end
end
