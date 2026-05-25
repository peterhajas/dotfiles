-- subtitle-browser.lua
-- Toggleable subtitle browser panel for mpv. Two layouts:
--   b           — side panel  (video shrinks left, panel on right)
--   B (Shift-b) — below panel (window grows taller, panel below video)
-- While the panel is open:
--   /              — open search input (live filter)
--   j / k          — step to next / prev sub line
--   mousewheel     — scroll panel (outside panel = default volume)
--   left-click     — seek to that line

local msg     = require "mp.msg"
local utils   = require "mp.utils"
local ok_inp, input_mod = pcall(require, "mp.input")
if not ok_inp then input_mod = nil end

local SIDE_RATIO       = 0.35   -- side mode: panel width fraction
local BELOW_RATIO      = 0.50   -- below mode: panel height fraction of new total
local LINE_RATIO       = 0.033  -- of window height
local FS_CUR_RATIO     = 0.030
local FS_OTH_RATIO     = 0.022
local PAD_RATIO        = 0.012
local MANUAL_GRACE     = 4

local state = {
    open               = false,
    mode               = nil,    -- "side" | "below"
    subs               = nil,
    source             = nil,
    filter             = "",
    matching_subs      = nil,    -- array of sub_i that contain the filter
    match_set          = nil,    -- sub_i -> true, for fast lookup
    current_idx        = 0,
    last_idx           = -1,
    manual_offset      = 0,      -- row offset (paragraph mode)
    manual_until       = 0,
    loading            = false,
    in_search          = false,
    saved_sub_visible  = nil,
    saved_geometry     = nil,
    saved_keepaspect   = nil,
    layout             = nil,
    tokens             = nil,    -- array of {text, sub_i}; words only
    sub_first_token    = nil,    -- sub_i -> first token index
    visible_rows       = nil,    -- cached at render time for hit-testing
    rows_cache         = nil,    -- { tokens, max_chars, rows } memoization
}

local overlay = mp.create_osd_overlay("ass-events")

local temp_sub_files = {}

local function remove_temp_sub_file(path)
    if not path then return end
    os.remove(path)
    temp_sub_files[path] = nil
end

local function remove_all_temp_sub_files()
    for path in pairs(temp_sub_files) do
        os.remove(path)
        temp_sub_files[path] = nil
    end
end

-- ============================================================ SRT parsing

local function strip_tags(s)
    s = s:gsub("{[^}]*}", "")
    s = s:gsub("</?%a+[^>]*>", "")
    return s
end

local TIME_PAT = "^%s*(%d+):(%d+):(%d+)[,.](%d+)%s*%-%->%s*(%d+):(%d+):(%d+)[,.](%d+)"

local function parse_srt(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local lines = {}
    for line in f:lines() do
        lines[#lines + 1] = (line:gsub("\r$", ""))
    end
    f:close()

    local subs = {}
    local n = #lines
    local i = 1
    while i <= n do
        local h1, m1, s1, ms1, h2, m2, s2, ms2 = lines[i]:match(TIME_PAT)
        if h1 then
            local st = h1 * 3600 + m1 * 60 + s1 + ms1 / 1000
            local et = h2 * 3600 + m2 * 60 + s2 + ms2 / 1000
            local parts = {}
            local j = i + 1
            while j <= n and not lines[j]:match(TIME_PAT) do
                parts[#parts + 1] = lines[j]
                j = j + 1
            end
            while #parts > 0 and parts[#parts]:match("^%s*$") do table.remove(parts) end
            if #parts > 0 and parts[#parts]:match("^%s*%d+%s*$") and j <= n then
                table.remove(parts)
                while #parts > 0 and parts[#parts]:match("^%s*$") do table.remove(parts) end
            end
            while #parts > 0 and parts[1]:match("^%s*$") do table.remove(parts, 1) end

            local text = strip_tags(table.concat(parts, " "))
            text = text:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
            if #text > 0 then
                subs[#subs + 1] = { start = st, stop = et, text = text }
            end
            i = j
        else
            i = i + 1
        end
    end
    table.sort(subs, function(a, b) return a.start < b.start end)
    return subs
end

-- Dedup YouTube-style sliding-window auto-captions. For each new sub, find the
-- longest suffix of the previous entry that's a prefix of this one, and keep
-- only the *new* tail. Drops exact dupes and substrings. Result: a stream of
-- "what was newly said" chunks with no visual repetition.
local function dedupe(subs)
    local out = {}
    for _, sub in ipairs(subs) do
        local last = out[#out]
        if not last then
            out[#out + 1] = { start = sub.start, stop = sub.stop, text = sub.text }
        else
            local prev, cur = last.text, sub.text
            if prev == cur or prev:find(cur, 1, true) then
                last.stop = sub.stop
            else
                local max_len = math.min(#prev, #cur)
                local overlap = 0
                for n = max_len, 1, -1 do
                    if prev:sub(-n) == cur:sub(1, n) then overlap = n; break end
                end
                local new_text = cur:sub(overlap + 1):gsub("^%s+", "")
                if #new_text > 0 then
                    out[#out + 1] = { start = sub.start, stop = sub.stop, text = new_text }
                end
            end
        end
    end
    return out
end

-- ============================================================ helpers

local function fmt_time(t)
    if not t then return "?" end
    local h = math.floor(t / 3600)
    local m = math.floor((t % 3600) / 60)
    local s = math.floor(t % 60)
    if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
    return string.format("%d:%02d", m, s)
end

local function find_sub_index(t)
    if not state.subs or #state.subs == 0 or not t then return 0 end
    local lo, hi, r = 1, #state.subs, 0
    while lo <= hi do
        local mid = math.floor((lo + hi) / 2)
        if state.subs[mid].start <= t then
            r = mid; lo = mid + 1
        else
            hi = mid - 1
        end
    end
    return r
end

local function ass_escape(s)
    s = s:gsub("\\", "\\\\")
    s = s:gsub("{", "\\{")
    s = s:gsub("}", "\\}")
    return s
end

-- Build the token stream from all subs. Each token is one word annotated with
-- its originating sub index. Timestamps are NOT inline tokens — they're
-- rendered in a left gutter at row-start time (see render).
local function build_tokens()
    if not state.subs then state.tokens = nil; state.sub_first_token = nil; return end
    local toks, firsts = {}, {}
    for raw_i, sub in ipairs(state.subs) do
        firsts[raw_i] = #toks + 1
        for word in sub.text:gmatch("%S+") do
            toks[#toks + 1] = { text = word, sub_i = raw_i }
        end
    end
    state.tokens = toks
    state.sub_first_token = firsts
end

-- Wrap `tokens` into rows that fit within `max_chars` main-font widths.
local function wrap_tokens(tokens, max_chars)
    local rows = {}
    local cur, cur_w = {}, 0
    for i, tok in ipairs(tokens) do
        local need = #tok.text
        local space = (#cur > 0) and 1 or 0
        if cur_w + space + need > max_chars and #cur > 0 then
            rows[#rows + 1] = { token_idxs = cur }
            cur = { i }
            cur_w = need
        else
            cur[#cur + 1] = i
            cur_w = cur_w + space + need
        end
    end
    if #cur > 0 then rows[#rows + 1] = { token_idxs = cur } end
    return rows
end

local function find_anchor_row(rows, target_first_tok)
    if not target_first_tok then return 1 end
    for r, row in ipairs(rows) do
        for _, t in ipairs(row.token_idxs) do
            if t >= target_first_tok then return r end
        end
    end
    return #rows
end

-- Memoized wrap_tokens. Re-wraps only when tokens or budget change.
local function get_rows(max_chars)
    local cache = state.rows_cache
    if cache and cache.tokens == state.tokens and cache.max_chars == max_chars then
        return cache.rows
    end
    local rows = wrap_tokens(state.tokens, max_chars)
    state.rows_cache = { tokens = state.tokens, max_chars = max_chars, rows = rows }
    return rows
end

-- Smooth float row position: interpolates between the current sub's anchor
-- and the next sub's anchor according to playback time. Gives teleprompter
-- scrolling instead of per-sub jumps.
local function smooth_anchor_row(rows, sub_i)
    if not sub_i or sub_i < 1 or not state.subs or not state.sub_first_token then
        return 1
    end
    local cur_first = state.sub_first_token[sub_i]
    if not cur_first then return 1 end
    local cur_row = find_anchor_row(rows, cur_first)
    local next_sub = state.subs[sub_i + 1]
    local next_first = state.sub_first_token[sub_i + 1]
    if not next_sub or not next_first then return cur_row end
    local next_row = find_anchor_row(rows, next_first)
    local t = mp.get_property_number("time-pos")
    local sub = state.subs[sub_i]
    if not t or not sub then return cur_row end
    local seg = next_sub.start - sub.start
    if seg <= 0 then return cur_row end
    local frac = (t - sub.start) / seg
    if frac < 0 then frac = 0 end
    if frac > 1 then frac = 1 end
    return cur_row + (next_row - cur_row) * frac
end

local function selected_sub_track()
    local tracks = mp.get_property_native("track-list") or {}
    local sub_rel = 0
    for _, t in ipairs(tracks) do
        if t.type == "sub" then
            if t.selected then return t, sub_rel end
            sub_rel = sub_rel + 1
        end
    end
    return nil, nil
end

-- ============================================================ sub loading

local render -- forward decl

local function finalize_subs(raw)
    if not raw then return nil end
    return dedupe(raw)
end

local function load_subs(cb)
    state.loading = true
    state.subs    = nil
    state.source  = nil
    state.filter  = ""
    state.matching_subs = nil
    state.match_set     = nil
    state.tokens  = nil
    state.sub_first_token = nil

    local track, sub_rel = selected_sub_track()
    if not track then
        state.loading = false
        if cb then cb(false) end
        return
    end

    local ext = track["external-filename"]
    if ext and ext ~= "" then
        local low = ext:lower()
        if low:match("%.srt$") or low:match("%.vtt$") then
            local subs = finalize_subs(parse_srt(ext))
            state.subs = subs
            state.source = ext
            state.loading = false
            build_tokens()
            if cb then cb(subs and #subs > 0) end
            return
        end
    end

    local src = mp.get_property("path")
    if not src or src == "" then
        state.loading = false
        if cb then cb(false) end
        return
    end

    -- os.tmpname() securely allocates the file on POSIX instead of exposing a
    -- predictable path in the shared temporary directory.
    local cache, temp_err = os.tmpname()
    if not cache then
        msg.error("could not allocate subtitle temp file: " .. tostring(temp_err or "?"))
        state.loading = false
        if cb then cb(false) end
        return
    end
    temp_sub_files[cache] = true

    msg.info("extracting embedded subtitle track " .. tostring(sub_rel))
    mp.command_native_async({
        name = "subprocess",
        args = { "ffmpeg", "-y", "-i", src,
            "-map", "0:s:" .. tostring(sub_rel), "-c:s", "srt", "-f", "srt", cache },
        capture_stdout = true,
        capture_stderr = true,
        playback_only  = false,
    }, function(success, result, err)
        local good = success and result and result.status == 0
        if good then
            local subs = finalize_subs(parse_srt(cache))
            remove_temp_sub_file(cache)
            state.subs = subs
            state.source = "embedded"
            state.loading = false
            build_tokens()
            if cb then cb(subs and #subs > 0) end
            state.current_idx = find_sub_index(mp.get_property_number("time-pos"))
            render()
        else
            remove_temp_sub_file(cache)
            msg.error("ffmpeg extract failed: " .. tostring(err or "?"))
            state.loading = false
            if cb then cb(false) end
        end
    end)
end

-- ============================================================ filtering

-- Compute which subs contain the search needle. Tokens stay intact — the
-- paragraph keeps all subs visible; we just track the match set and snap the
-- anchor to the first hit.
local function rebuild_filter()
    state.matching_subs = nil
    state.match_set     = nil
    state.manual_offset = 0
    state.manual_until  = 0
    if state.filter == "" or not state.subs then return end
    local needle = state.filter:lower()
    local matching, set = {}, {}
    for i, sub in ipairs(state.subs) do
        if sub.text:lower():find(needle, 1, true) then
            matching[#matching + 1] = i
            set[i] = true
        end
    end
    state.matching_subs = matching
    state.match_set     = set
end

-- ============================================================ layout

local function compute_layout()
    local dims = mp.get_property_native("osd-dimensions")
    if not dims or not dims.w or dims.w == 0 then return nil end
    local W, H = dims.w, dims.h

    local pad   = math.max(8,  math.floor(W * PAD_RATIO))
    local fs_o  = math.max(12, math.floor(H * FS_OTH_RATIO))
    local fs_c  = math.max(16, math.floor(H * FS_CUR_RATIO))
    local lh    = math.max(22, math.floor(H * LINE_RATIO))

    local px0, py0, pw, ph
    if state.mode == "below" then
        ph  = math.floor(H * BELOW_RATIO)
        pw  = W
        px0 = 0
        py0 = H - ph
    else  -- side (default)
        pw  = math.floor(W * SIDE_RATIO)
        ph  = H
        px0 = W - pw
        py0 = 0
    end

    return {
        W = W, H = H,
        panel_x0 = px0, panel_y0 = py0,
        panel_w  = pw,  panel_h  = ph,
        pad      = pad,
        cx       = px0 + pad,
        cy       = py0 + math.floor(ph / 2),
        line_h   = lh,
        fs_cur   = fs_c,
        fs_oth   = fs_o,
    }
end

-- ============================================================ rendering

local function ass_rect(x, y, w, h, color, alpha)
    return string.format(
        "{\\an7\\pos(%d,%d)\\bord0\\shad0\\1c%s\\1a&H%02X&\\p1}" ..
        "m 0 0 l %d 0 l %d %d l 0 %d{\\p0}",
        x, y, color, alpha, w, w, h, h)
end

local smooth_timer = nil

local function update_smooth_timer()
    local should_run = state.open and not mp.get_property_bool("pause")
    if should_run then
        if not smooth_timer then
            smooth_timer = mp.add_periodic_timer(0.05, function()
                if state.open then render() end
            end)
        end
    elseif smooth_timer then
        smooth_timer:kill()
        smooth_timer = nil
    end
end

function render()
    if not state.open then
        overlay.data = ""
        overlay:update()
        return
    end

    local L = compute_layout()
    if not L then return end
    state.layout = L
    -- Pin overlay resolution to current OSD size; otherwise the overlay's
    -- internal res sticks at creation time and breaks when geometry changes.
    overlay.res_x = L.W
    overlay.res_y = L.H

    local parts = {}

    -- panel background
    parts[#parts + 1] = ass_rect(L.panel_x0, L.panel_y0, L.panel_w, L.panel_h, "&H000000&", 0x80)

    -- divider (white): left edge in side mode, top edge in below mode
    if state.mode == "below" then
        parts[#parts + 1] = ass_rect(L.panel_x0, L.panel_y0, L.panel_w, 2, "&HFFFFFF&", 0x40)
    else
        parts[#parts + 1] = ass_rect(L.panel_x0, L.panel_y0, 2, L.panel_h, "&HFFFFFF&", 0x40)
    end

    -- search bar (if active)
    if state.in_search or state.filter ~= "" then
        local bar_h = math.floor(L.fs_oth * 2)
        parts[#parts + 1] = ass_rect(L.panel_x0, L.panel_y0, L.panel_w, bar_h, "&H222222&", 0x40)
        local cursor = state.in_search and "_" or ""
        local label = string.format("/ %s%s", ass_escape(state.filter), cursor)
        parts[#parts + 1] = string.format(
            "{\\an4\\pos(%d,%d)\\fs%d\\1c&HFFFFFF&\\bord1}%s",
            L.cx, L.panel_y0 + math.floor(bar_h / 2), L.fs_oth, label)
        local count_label
        if state.matching_subs then
            count_label = string.format("%d match%s", #state.matching_subs, #state.matching_subs == 1 and "" or "es")
        else
            count_label = ""
        end
        if count_label ~= "" then
            parts[#parts + 1] = string.format(
                "{\\an6\\pos(%d,%d)\\fs%d\\1c&HAAAAAA&\\bord1}%s",
                L.panel_x0 + L.panel_w - L.pad,
                L.panel_y0 + math.floor(bar_h / 2),
                math.max(11, L.fs_oth - 4),
                count_label)
        end
    end

    if state.loading then
        parts[#parts + 1] = string.format(
            "{\\an5\\pos(%d,%d)\\fs%d\\1c&HFFFFFF&\\bord1}loading subs…",
            L.panel_x0 + math.floor(L.panel_w / 2), L.cy, L.fs_oth)
    elseif not state.subs or #state.subs == 0 then
        parts[#parts + 1] = string.format(
            "{\\an5\\pos(%d,%d)\\fs%d\\1c&HFFFFFF&\\bord1}no subtitles",
            L.panel_x0 + math.floor(L.panel_w / 2), L.cy, L.fs_oth)
    elseif not state.tokens or #state.tokens == 0 then
        parts[#parts + 1] = string.format(
            "{\\an5\\pos(%d,%d)\\fs%d\\1c&HFFFFFF&\\bord1}empty",
            L.panel_x0 + math.floor(L.panel_w / 2), L.cy, L.fs_oth)
    else
        local fs    = L.fs_oth
        local tfs   = math.max(11, fs - 5)
        local gutter_chars = 7  -- enough for "1:23:45"
        local gutter_px    = math.floor(gutter_chars * tfs * 0.55) + L.pad
        local text_x0      = L.panel_x0 + L.pad + gutter_px
        local text_budget  = math.max(40, (L.panel_x0 + L.panel_w) - text_x0 - L.pad)
        local max_chars    = math.max(10, math.floor(text_budget / (fs * 0.45)))
        local rows = get_rows(max_chars)

        -- Pick the anchor: first match if searching (no smoothing), else
        -- smooth-interpolated row tied to time-pos.
        local anchor_row_f
        if state.matching_subs and #state.matching_subs > 0 then
            local first_tok = state.sub_first_token[state.matching_subs[1]]
            anchor_row_f = find_anchor_row(rows, first_tok)
        else
            anchor_row_f = smooth_anchor_row(rows, state.current_idx)
        end
        anchor_row_f = anchor_row_f + state.manual_offset
        if anchor_row_f < 1 then anchor_row_f = 1 end
        if anchor_row_f > #rows then anchor_row_f = #rows end

        local row_h = math.max(16, math.floor(fs * 1.20))
        local row_above = math.ceil((L.cy - L.panel_y0) / row_h) + 1
        local row_below = math.ceil(((L.panel_y0 + L.panel_h) - L.cy) / row_h) + 1
        local anchor_int = math.floor(anchor_row_f + 0.5)
        local lo = math.max(1, anchor_int - row_above)
        local hi = math.min(#rows, anchor_int + row_below)

        -- Determine the sub_i carried into each row from above (so we only
        -- print a gutter timestamp when a new sub actually starts on this row).
        -- For rows above `lo`, walk the rows from 1..lo-1 to find the last
        -- sub_i present, so the first visible row knows if it's a continuation.
        local carry = nil
        for r = 1, lo - 1 do
            local row = rows[r]
            local last_idx = row.token_idxs[#row.token_idxs]
            if last_idx then carry = state.tokens[last_idx].sub_i end
        end

        local visible = {}
        for r = lo, hi do
            local row = rows[r]
            row.y_top = L.cy + math.floor((r - anchor_row_f) * row_h) - math.floor(row_h / 2)
            row.row_h = row_h
            row.text_x0 = text_x0

            -- Find the first sub_i in this row that differs from `carry`.
            local first_new = nil
            local cur_carry = carry
            for _, t_idx in ipairs(row.token_idxs) do
                local s = state.tokens[t_idx].sub_i
                if s ~= cur_carry then
                    if not first_new then first_new = s end
                    cur_carry = s
                end
            end
            row.gutter_sub_i = first_new
            carry = cur_carry

            visible[#visible + 1] = row
        end
        state.visible_rows = visible

        -- Precompute per-token x positions for click hit-testing.
        local space_w = fs * 0.45
        for _, row in ipairs(visible) do
            local x = 0
            local positions = {}
            local first = true
            for _, t_idx in ipairs(row.token_idxs) do
                local tok = state.tokens[t_idx]
                if not first then x = x + space_w end
                first = false
                local tw = #tok.text * fs * 0.45
                positions[#positions + 1] = { x0 = x, x1 = x + tw, t_idx = t_idx }
                x = x + tw
            end
            row.positions = positions
        end

        -- Emit gutter timestamp for rows that start a new sub.
        for _, row in ipairs(visible) do
            if row.gutter_sub_i then
                local sub = state.subs[row.gutter_sub_i]
                if sub then
                    parts[#parts + 1] = string.format(
                        "{\\an7\\pos(%d,%d)\\fs%d\\1c&H888888&\\bord1\\b0\\clip(%d,%d,%d,%d)}%s",
                        L.panel_x0 + L.pad, row.y_top, tfs,
                        L.panel_x0, L.panel_y0, L.panel_x0 + L.panel_w, L.panel_y0 + L.panel_h,
                        ass_escape(fmt_time(sub.start)))
                end
            end
        end

        -- Emit one ASS event per visible row (the text).
        for _, row in ipairs(visible) do
            local pieces = {}
            pieces[#pieces + 1] = string.format(
                "{\\an7\\pos(%d,%d)\\fs%d\\1c&HFFFFFF&\\bord1\\b0\\clip(%d,%d,%d,%d)}",
                row.text_x0, row.y_top, fs,
                L.panel_x0, L.panel_y0, L.panel_x0 + L.panel_w, L.panel_y0 + L.panel_h)
            local first = true
            for _, t_idx in ipairs(row.token_idxs) do
                local tok = state.tokens[t_idx]
                if not first then pieces[#pieces + 1] = " " end
                first = false
                local color, bold
                if state.match_set and state.match_set[tok.sub_i] then
                    color = "&H00FF66&"  -- green (BGR)
                    bold  = "\\b1"
                elseif tok.sub_i == state.current_idx then
                    color = "&H00DDFF&"  -- yellow-gold
                    bold  = "\\b1"
                else
                    color = "&HFFFFFF&"
                    bold  = "\\b0"
                end
                pieces[#pieces + 1] = string.format("{\\1c%s%s}%s",
                    color, bold, ass_escape(tok.text))
            end
            parts[#parts + 1] = table.concat(pieces)
        end
    end

    overlay.data = table.concat(parts, "\n")
    overlay:update()
end

-- ============================================================ interactions

local function mouse_in_panel()
    local L = state.layout
    if not L then return false end
    local p = mp.get_property_native("mouse-pos")
    if not p then return false end
    return p.x >= L.panel_x0 and p.x <= (L.panel_x0 + L.panel_w)
        and p.y >= L.panel_y0 and p.y <= (L.panel_y0 + L.panel_h)
end

local function on_click()
    if not state.open or not state.subs then return end
    local L = state.layout
    if not L then return end
    local p = mp.get_property_native("mouse-pos")
    if not p then return end
    if p.x < L.panel_x0 or p.x > L.panel_x0 + L.panel_w then return end
    if p.y < L.panel_y0 or p.y > L.panel_y0 + L.panel_h then return end

    local rows = state.visible_rows
    if not rows then return end
    for _, row in ipairs(rows) do
        if p.y >= row.y_top and p.y < row.y_top + row.row_h then
            -- Gutter click: if this row carries a timestamp, seek to that sub.
            if p.x < row.text_x0 and row.gutter_sub_i then
                local sub = state.subs[row.gutter_sub_i]
                if sub then
                    state.manual_offset = 0
                    state.manual_until  = 0
                    mp.commandv("seek", tostring(sub.start), "absolute+exact")
                end
                return
            end
            -- Text click: walk per-token x ranges (relative to text_x0).
            local rel_x = p.x - row.text_x0
            local hit
            if row.positions then
                for _, pos in ipairs(row.positions) do
                    if rel_x < pos.x1 then hit = pos; break end
                end
                if not hit and #row.positions > 0 then
                    hit = row.positions[#row.positions]
                end
            end
            if hit then
                local tok = state.tokens[hit.t_idx]
                local sub = tok and state.subs[tok.sub_i]
                if sub then
                    state.manual_offset = 0
                    state.manual_until  = 0
                    mp.commandv("seek", tostring(sub.start), "absolute+exact")
                end
            end
            return
        end
    end
end

local function on_wheel(dir)
    if not state.open then return end
    if mouse_in_panel() then
        state.manual_offset = state.manual_offset + dir
        state.manual_until  = mp.get_time() + MANUAL_GRACE
        render()
    else
        mp.commandv("add", "volume", tostring(-dir * 2))
    end
end

local function step_sub(direction)
    if not state.subs or #state.subs == 0 then return end
    local target = (state.current_idx > 0 and state.current_idx or 1) + direction
    if target < 1 then target = 1 end
    if target > #state.subs then target = #state.subs end
    local sub = state.subs[target]
    if not sub then return end
    state.manual_offset = 0
    state.manual_until  = 0
    mp.commandv("seek", tostring(sub.start), "absolute+exact")
end

-- ============================================================ search

local function close_search()
    if not state.in_search then return end
    state.in_search = false
    if input_mod and input_mod.terminate then
        input_mod.terminate()
    end
    render()
end

local function open_search()
    if not input_mod then
        mp.osd_message("subtitle-browser: search needs mpv >=0.39")
        return
    end
    state.in_search = true
    render()
    input_mod.get({
        prompt = "search: ",
        default_text = state.filter,
        opened = function()
            state.in_search = true
        end,
        edited = function(text)
            state.filter = text or ""
            rebuild_filter()
            render()
        end,
        submit = function(text)
            state.filter = text or ""
            rebuild_filter()
            state.in_search = false
            input_mod.terminate()
            render()
        end,
        closed = function()
            state.in_search = false
            render()
        end,
    })
end

-- ============================================================ key bindings

local panel_keys_active = false

local function add_panel_keys()
    if panel_keys_active then return end
    panel_keys_active = true
    mp.add_forced_key_binding("j",          "sb-next",   function() step_sub(1)  end)
    mp.add_forced_key_binding("k",          "sb-prev",   function() step_sub(-1) end)
    mp.add_forced_key_binding("MBTN_LEFT",  "sb-click",  on_click)
    mp.add_forced_key_binding("WHEEL_UP",   "sb-wheelu", function() on_wheel(-1) end)
    mp.add_forced_key_binding("WHEEL_DOWN", "sb-wheeld", function() on_wheel(1)  end)
    mp.add_forced_key_binding("/",          "sb-search", open_search)
end

local function remove_panel_keys()
    if not panel_keys_active then return end
    panel_keys_active = false
    for _, name in ipairs({"sb-next","sb-prev","sb-click","sb-wheelu","sb-wheeld","sb-search"}) do
        mp.remove_key_binding(name)
    end
end

-- ============================================================ mode-specific open/close

local function apply_side()
    state.mode = "side"
    mp.set_property_number("video-margin-ratio-right", SIDE_RATIO)
end

local function unapply_side()
    mp.set_property_number("video-margin-ratio-right", 0)
end

local function apply_below()
    state.mode = "below"
    state.saved_geometry   = mp.get_property("geometry")
    state.saved_keepaspect = mp.get_property_bool("keepaspect-window")

    local dims = mp.get_property_native("osd-dimensions")
    if dims and dims.w and dims.w > 0 then
        local W, H = dims.w, dims.h
        local extra = math.floor(H * BELOW_RATIO / (1 - BELOW_RATIO))
        local new_h = H + extra
        mp.set_property_bool("keepaspect-window", false)
        mp.set_property("geometry", string.format("%dx%d", W, new_h))
    end
    mp.set_property_number("video-margin-ratio-bottom", BELOW_RATIO)
    -- The resize is async on macOS; nudge a re-render once the new canvas
    -- size has had time to take effect, in case the osd-dimensions observer
    -- doesn't fire synchronously.
    mp.add_timeout(0.15, render)
    mp.add_timeout(0.5,  render)
end

local function unapply_below()
    mp.set_property_number("video-margin-ratio-bottom", 0)
    if state.saved_geometry ~= nil then
        mp.set_property("geometry", state.saved_geometry)
        state.saved_geometry = nil
    end
    if state.saved_keepaspect ~= nil then
        mp.set_property_bool("keepaspect-window", state.saved_keepaspect)
        state.saved_keepaspect = nil
    end
end

local function close_panel()
    if not state.open then return end
    close_search()
    if state.mode == "below" then unapply_below()
    elseif state.mode == "side" then unapply_side()
    end
    if state.saved_sub_visible ~= nil then
        mp.set_property_bool("sub-visibility", state.saved_sub_visible)
        state.saved_sub_visible = nil
    end
    remove_panel_keys()
    state.open = false
    state.mode = nil
    state.layout = nil
    state.filter = ""
    state.matching_subs = nil
    state.match_set     = nil
    overlay.data = ""
    overlay:update()
    update_smooth_timer()
end

local function open_panel(mode)
    load_subs(function(ok)
        if not ok and not state.loading then
            mp.osd_message("subtitle-browser: no subs")
            return
        end
        state.open = true
        state.current_idx = find_sub_index(mp.get_property_number("time-pos"))
        state.last_idx = state.current_idx
        state.saved_sub_visible = mp.get_property_bool("sub-visibility")
        mp.set_property_bool("sub-visibility", false)
        if mode == "below" then apply_below() else apply_side() end
        add_panel_keys()
        render()
        update_smooth_timer()
    end)
end

local function toggle(mode)
    if state.open and state.mode == mode then
        close_panel()
    elseif state.open then
        -- switching from one mode to the other
        close_panel()
        open_panel(mode)
    else
        open_panel(mode)
    end
end

-- ============================================================ observers

mp.observe_property("time-pos", "number", function(_, t)
    if not state.open or not state.subs then return end
    local idx = find_sub_index(t)
    if idx ~= state.last_idx then
        state.last_idx = idx
        state.current_idx = idx
        if state.manual_until > 0 and mp.get_time() > state.manual_until then
            state.manual_offset = 0
            state.manual_until  = 0
        end
        render()
    end
end)

mp.observe_property("osd-dimensions", "native", function() if state.open then render() end end)
mp.observe_property("osd-width",  "number", function() if state.open then render() end end)
mp.observe_property("osd-height", "number", function() if state.open then render() end end)
mp.observe_property("pause", "bool", function() update_smooth_timer() end)

mp.observe_property("current-tracks/sub/id", "number", function()
    if state.open then
        load_subs(function(ok)
            if ok then
                state.current_idx = find_sub_index(mp.get_property_number("time-pos"))
            end
            render()
        end)
    end
end)

mp.register_event("end-file", function()
    remove_all_temp_sub_files()
    if state.open then close_panel() end
end)
mp.register_event("file-loaded", function()
    remove_all_temp_sub_files()
    state.subs = nil
    state.source = nil
end)
mp.register_event("shutdown", function()
    remove_all_temp_sub_files()
    close_panel()
end)

-- ============================================================ entrypoint

mp.add_key_binding("b", "subtitle-browser-toggle",          function() toggle("side")  end)
mp.add_key_binding("B", "subtitle-browser-toggle-portrait", function() toggle("below") end)
