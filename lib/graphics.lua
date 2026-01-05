-- Avant_lab_V lib/graphics.lua | Version 1019
-- UPDATE: Mixer Spacing, Scale Header Format, Grid Interaction

local Graphics = {}
local Scales = include('lib/scales')

local sin = math.sin
local cos = math.cos
local floor = math.floor
local random = math.random
local pi = math.pi
local clamp = util.clamp
local linlin = util.linlin

local divs_names = {"1/1", "1/2", "1/4", "1/8", "1/16", "1/32", "1/64", "1/128", "1/256"}
local note_names = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}

-- [OPTIMIZATION] Helper to retrieve from cache safely
local function get_txt(id) return state.str_cache[id] or "..." end

local function draw_header_right(label) screen.level(15); screen.move(128, 8); screen.text_right(label) end

local function draw_left_e1(label, text) 
    screen.level(3); screen.move(0, 8); screen.text(label)
    screen.level(15); screen.move(0, 15); screen.text(text) 
end

local function draw_vertical_divider() screen.level(1); screen.move(85, 10); screen.line(85, 60); screen.stroke() end

-- [RESTORED] Original coordinates for Pages 2-6 (Center area)
local function draw_right_param_pair(label1, text1, label2, text2)
  local col1_x = 55 
  local col2_x = 95 
  local label_y = 53
  local value_y = 60
  
  screen.level(3); screen.move(col1_x, label_y); screen.text(label1)
  screen.level(15); screen.move(col1_x, value_y); screen.text(text1)
  
  screen.level(3); screen.move(col2_x, label_y); screen.text(label2)
  screen.level(15); screen.move(col2_x, value_y); screen.text(text2)
end

local function draw_goniometer_block(state)
  local cx = 106; local cy = 25
  local head = state.heads.gonio
  local len = state.GONIO_LEN
  local hist = state.gonio_history
  
  for i=0, len-1 do
     local idx = (head - 1 - i - 1) % len + 1
     local frame = hist[idx]
     if frame and frame.s > 0.5 then
        local brightness = math.floor(15 / (i * 0.5 + 1))
        if brightness > 1 then
           screen.level(brightness)
           local s = frame.s
           local w = frame.w
           local points = (i==0) and 10 or 3
           for p=1, points do
               local ang = random() * 6.28
               local rad = random() * s
               local px = cx + (cos(ang) * rad) + ((random()-0.5)*2 * w)
               local py = cy + (sin(ang) * rad * 1.4)
               screen.pixel(px, py); screen.fill()
           end
        end
     end
  end
end

local function tape_segment(x, y, wobble, gap_chance)
  if random() > gap_chance then screen.level(15); screen.rect(x, y + wobble, 1, 1); screen.fill() end
end
local function raster_line(x1, y1, x2, y2, wobble, gap_chance)
   local dist = x2 - x1; if dist < 1 then return end
   for x = x1, x2 do
     local t = (x - x1) / dist; local y = y1 + (y2 - y1) * t
     tape_segment(x, y, wobble, gap_chance)
   end
end
local function draw_reel(x, y, phase)
  screen.level(3); screen.circle(x, y, 10); screen.fill()
  screen.level(1); screen.circle(x, y, 3); screen.fill()
  screen.level(0)
  for i=0, 2 do
    local a = phase + (i * 2.094)
    local hx = x + cos(a) * 6; local hy = y + sin(a) * 6
    screen.circle(hx, hy, 2); screen.fill()
  end
end
local function draw_tape_head(x, y)
  screen.level(2); screen.rect(x - 8, y + 1, 2, 4); screen.fill()
  screen.rect(x + 6, y + 1, 2, 4); screen.fill()
  screen.level(8); screen.rect(x - 6, y, 12, 6); screen.fill()
  screen.level(0); screen.rect(x - 1, y, 2, 6); screen.fill()
  screen.level(2); screen.move(x, y); screen.line(x, y+6); screen.stroke()
end

local function draw_mixer_view(state, shift)
  screen.clear()
  local sel = state.mixer_sel
  local t = state.tracks[sel]
  
  -- [FIXED] Interaction via Grid Hold
  if state.grid_mixer_held then shift = true end
  
  screen.level(4); screen.move(64, 8); screen.text_center("SITRAL MIXER")
  
  screen.font_size(8)
  if not shift then
     local vol_db = util.linlin(0, 1, -60, 12, t.vol or 0)
     -- [FIXED] Spacing adjustment (values closer to labels)
     screen.level(3); screen.move(0, 62); screen.text("VOL:"); screen.level(15); screen.move(18, 62); screen.text(string.format("%.1f", vol_db))
     screen.level(3); screen.move(50, 62); screen.text("LOW:"); screen.level(15); screen.move(68, 62); screen.text(string.format("%.1f", t.l_low or 0))
     screen.level(3); screen.move(95, 62); screen.text("HI:"); screen.level(15); screen.move(110, 62); screen.text(string.format("%.1f", t.l_high or 0))
  else
     screen.level(3); screen.move(0, 62); screen.text("FLT:"); screen.level(15); screen.move(18, 62); screen.text(string.format("%.2f", t.l_filter or 0.5))
     screen.level(3); screen.move(50, 62); screen.text("PAN:"); screen.level(15); screen.move(68, 62); screen.text(string.format("%.2f", t.l_pan or 0))
     screen.level(3); screen.move(95, 62); screen.text("WID:"); screen.level(15); screen.move(110, 62); screen.text(string.format("%.2f", t.l_width or 1))
  end
  
  local x_base = 25; local spacing = 26; local y_top = 17; local y_bot = 49; local h_rail = y_bot - y_top
  
  for i=1, 4 do
     local x = x_base + ((i-1) * spacing); local trk = state.tracks[i]; local is_sel = (i == sel)
     if is_sel then screen.level(1); screen.rect(x-12, y_top-6, 24, h_rail+11); screen.stroke() end
     screen.level(2); screen.rect(x-1, y_top, 2, h_rail); screen.fill()
     local vol = trk.vol or 0.9; local y_vol = y_bot - (vol * h_rail)
     screen.level(is_sel and 15 or 8); screen.rect(x - 2, y_vol - 1, 5, 3); screen.fill()
     screen.level(0); screen.pixel(x, y_vol); screen.fill()

     local low = trk.l_low or 0; local high = trk.l_high or 0; local y_mid = y_top + (h_rail/2)
     screen.level(3); screen.move(x-6, y_top+5); screen.line(x-6, y_bot-5); screen.stroke()
     local y_low = y_mid - (clamp(low, -18, 18) * 0.33); screen.level(is_sel and 15 or 6); screen.pixel(x-6, y_low); screen.fill()
     screen.level(3); screen.move(x+6, y_top+5); screen.line(x+6, y_bot-5); screen.stroke()
     local y_high = y_mid - (clamp(high, -18, 18) * 0.33); screen.level(is_sel and 15 or 6); screen.pixel(x+6, y_high); screen.fill()
     
     local f = trk.l_filter or 0.5
     if math.abs(f - 0.5) > 0.01 then
        screen.level(15); local y_center = y_top + (h_rail/2); local dist = math.abs(f - 0.5); local h_cut = (dist / 0.5) * (h_rail / 2)
        screen.move(x, y_center); if f < 0.5 then screen.line(x, y_center + h_cut) else screen.line(x, y_center - h_cut) end; screen.stroke()
     end
     local p = trk.l_pan or 0; local px = x + (p * 8)
     screen.level(4); screen.move(x-8, y_bot+2); screen.line(x+8, y_bot+2); screen.stroke(); screen.level(is_sel and 15 or 8); screen.pixel(px, y_bot+2); screen.fill()
     local w = trk.l_width or 1; local wy = y_top - 4
     if w < 0.1 then screen.level(15); screen.pixel(x, wy); screen.fill()
     else screen.level(8); local spread = w * 2.5; screen.pixel(x-spread, wy); screen.fill(); screen.pixel(x+spread, wy); screen.fill() end
     screen.level(is_sel and 15 or 2); screen.font_size(8); screen.move(x+8, y_top); screen.text(i)
  end
  screen.update()
end

local function draw_plasma_bar_fluid(x, y, w, h, val, is_inverted, is_gr)
   local seg_w = 2; local gap = 1; local total_segs = math.floor(w / (seg_w + gap))
   screen.level(1)
   for i=0, total_segs-1 do screen.rect(x + (i * (seg_w+gap)), y, seg_w, h); screen.fill() end
   local active_float = val * total_segs; local active_int = math.floor(active_float); local active_frac = active_float - active_int
   local function get_brightness(pct) if is_gr then return 8 end; if pct < 0.6 then return 6 elseif pct < 0.9 then return 10 else return 15 end end
   for i=0, active_int-1 do
      local pos_x = x + (i * (seg_w+gap)); if is_inverted then pos_x = x + w - ((i+1) * (seg_w+gap)) end
      local pct = (i+1) / total_segs; screen.level(get_brightness(pct)); screen.rect(pos_x, y, seg_w, h); screen.fill()
   end
   if active_frac > 0.1 and active_int < total_segs then
      local i = active_int; local pos_x = x + (i * (seg_w+gap)); if is_inverted then pos_x = x + w - ((i+1) * (seg_w+gap)) end
      local pct = (i+1) / total_segs; local base_b = get_brightness(pct); local tip_b = math.floor(base_b * active_frac)
      if tip_b > 0 then screen.level(tip_b); screen.rect(pos_x, y, seg_w, h); screen.fill() end
   end
end

local function draw_master_view(state, shift)
   screen.clear()
   screen.font_size(8)
   
   if not shift then draw_left_e1("MONITOR", get_txt("main_mon")) 
   else draw_left_e1("CEIL", get_txt("limiter_ceil")) end
   
   draw_vertical_divider(); draw_header_right("MASTER"); draw_goniometer_block(state)
   
   local cx = 50; local w = 52; local y_start = 28 
   local gr = state.comp_gr or 0; local gr_norm = clamp(gr * 4, 0, 1) 
   screen.level(3); screen.move(cx - 38, y_start - 4); screen.text_right("GR")
   draw_plasma_bar_fluid(cx - 30, y_start - 7, w, 2, gr_norm, true, true)
   
   local amp_l_db = 20 * math.log10(state.amp_l > 0.0001 and state.amp_l or 0.0001)
   local amp_r_db = 20 * math.log10(state.amp_r > 0.0001 and state.amp_r or 0.0001)
   local l_norm = linlin(-60, 0, 0, 1, amp_l_db); l_norm = clamp(l_norm, 0, 1)
   local r_norm = linlin(-60, 0, 0, 1, amp_r_db); r_norm = clamp(r_norm, 0, 1)
   screen.level(3); screen.move(cx - 38, y_start + 4); screen.text_right("L")
   draw_plasma_bar_fluid(cx - 30, y_start + 1, w, 4, l_norm, false, false)
   screen.level(3); screen.move(cx - 38, y_start + 11); screen.text_right("R")
   draw_plasma_bar_fluid(cx - 30, y_start + 8, w, 4, r_norm, false, false)
   
   local bf = params:get("bass_focus")
   local txt_bf = {"OFF", "50Hz", "100Hz", "200Hz"}
   screen.level(3); screen.move(0, 53); screen.text("MONO BASS")
   screen.level(bf > 1 and 15 or 6); screen.move(0, 60); screen.text(txt_bf[bf] or "OFF")
   
   if not shift then
      draw_right_param_pair("THRESH", get_txt("comp_thresh"), "RATIO", get_txt("comp_ratio"))
   else
      draw_right_param_pair("BAL", get_txt("balance"), "DRIVE", get_txt("comp_drive"))
   end
   
   screen.update()
end

function Graphics.draw(state)
  local page = state.current_page
  local shift = state.k1_held or state.mod_shift_16 or state.grid_shift_active
  local amp_l = state.amp_l or 0
  local now = util.time()
  
  if page == 10 then draw_master_view(state, shift); return end
  if page == 9 then draw_mixer_view(state, shift); return end
  
  if page == 8 then
     screen.clear()
     screen.level(15); screen.move(64, 8); screen.text_center("TAPE LIBRARY")
     for i=1, 4 do
        local y = 15 + (i * 9)
        screen.level(i == state.tape_library_sel and 15 or 3)
        screen.move(5, y); screen.text("REEL " .. i)
        local txt = ""
        if state.tape_msg_timers[i] > now then txt = "SAVED!"
        else
           if state.tape_filenames[i] then txt = state.tape_filenames[i]
           elseif (state.tracks[i].rec_len or 0) > 0.1 then txt = "[RECORDED]"
           else txt = "[EMPTY]" end
        end
        if #txt > 20 then txt = "..." .. string.sub(txt, -18) end
        screen.move(123, y); screen.text_right(txt)
     end
     screen.level(3); screen.move(5, 60); screen.text("E2:Sel  K2:Load  K3:Save")
     screen.update()
     return
  end
  
  if page == 7 then
     screen.clear()
     local sel = state.track_sel or 1
     local t = state.tracks[sel]
     screen.level(3); screen.move(55, 8); screen.text("DEGRADE"); screen.level(6); screen.move(55, 15); screen.text(string.format("%.2f", t.wow_macro or 0))
     
     if not shift then
       local vol_db = util.linlin(0, 1, -60, 12, t.vol or 0)
       draw_left_e1("VOL", string.format("%.1fdB", vol_db))
       
       local speed = t.speed or 1; local dir_sym = speed < 0 and "<<" or ">>"
       screen.level(3); screen.move(55, 53); screen.text("SPEED"); screen.level(15); screen.move(55, 60); screen.text(string.format("%s %.2f", dir_sym, math.abs(speed)))
       screen.level(3); screen.move(95, 53); screen.text("DUB"); screen.level(15); screen.move(95, 60); screen.text(string.format("%.0f%%", (t.overdub or 0.5)*100))
     else
       local rec_db = t.rec_level or 0
       draw_left_e1("REC IN", string.format("%.1fdB", rec_db))
       
       local start_p = floor((t.loop_start or 0) * 100); local end_p = floor((t.loop_end or 1) * 100)
       draw_right_param_pair("START", start_p .. "%", "END", end_p .. "%")
     end
     draw_vertical_divider(); draw_header_right("TRACK " .. sel); draw_goniometer_block(state)
     
     local x_base = 0 
     for i=1, 4 do
        local trk = state.tracks[i]; local y_off = 20 + (i * 9)
        screen.font_size(8); if i == sel then screen.level(15) else screen.level(2) end
        screen.move(x_base, y_off); screen.text(i)
        local bar_x = x_base + 8; local bar_w = 36
        screen.level(1); screen.rect(bar_x, y_off - 5, bar_w, 6); screen.fill()
        if trk.state == 2 then 
           if now % 0.4 > 0.2 then screen.level(15); screen.rect(bar_x, y_off - 5, bar_w, 6); screen.fill() end
           screen.level(0); screen.move(bar_x + 2, y_off); screen.text("REC")
        elseif trk.state == 4 then 
             screen.level(8); screen.rect(bar_x, y_off - 5, bar_w, 6); screen.fill()
             screen.level(0); screen.move(bar_x + 2, y_off); screen.text("OVR")
        elseif trk.state == 3 then 
             local pos = trk.play_pos or 0; local px = bar_x + (pos * bar_w)
             screen.level(15); screen.pixel(px, y_off - 4); screen.fill(); screen.pixel(px, y_off - 3); screen.fill()
        elseif trk.state == 1 then screen.level(2); screen.pixel(bar_x + (bar_w/2), y_off - 3); screen.fill() end
        if (trk.rec_len or 0) > 0 then screen.level(3); local len_txt = string.format("%.1fs", trk.rec_len); screen.move(x_base + 12 + bar_w, y_off); screen.text_right(len_txt) end
     end
     screen.update(); return
  end
  
  if page == 1 then
     screen.clear(); screen.level(4); screen.font_size(8); screen.move(0, 8)
     local s_name = Scales.list[state.preview_scale_idx].name
     local root_txt = note_names[params:get("root_note")] or "?"
     
     -- [FIXED] Scale header format: Remove S: prefix and (Root) in LOAD state
     if s_name == state.loaded_scale_name then 
        screen.text(s_name .. " (" .. root_txt .. ")") 
     else 
        screen.level(15); screen.text("LOAD: " .. s_name .. " >") 
     end
     
     screen.move(128, 8); if shift then screen.level(15) else screen.level(3) end; screen.text_right(get_txt("lfo_depth"))
     screen.move(128 - screen.text_extents(get_txt("lfo_depth")) - 2, 8); screen.level(3); screen.text_right("LFO:")
     
     local floor_y = 60
     for i=1, 16 do
        local x = 2 + ((i-1) * 5)
        local db = state.visual_gain[i] or -60
        local spec = state.band_levels[i] or 0
        local h_gain = linlin(-60, 0, 0, 45, db)
        screen.level(2)
        if h_gain > 1 then screen.rect(x, floor_y - h_gain, 4, h_gain); screen.fill() 
        else screen.rect(x, floor_y, 4, 1); screen.fill() end
        local val_db = 20 * math.log10(spec > 0.0001 and spec or 0.0001)
        local h_spec = clamp(linlin(-60, 0, 0, 48, val_db), 0, 48)
        local h_int = floor(h_spec); local h_frac = h_spec - h_int
        if h_int > 0 then screen.level(15); screen.rect(x+1, floor_y - h_int, 1, h_int); screen.fill() end
        if h_frac > 0.1 then local tip_b = floor(h_frac * 15); if tip_b > 0 then screen.level(tip_b); screen.pixel(x+1, floor_y - h_int - 1); screen.fill() end end
     end
     draw_vertical_divider(); draw_goniometer_block(state)
     
     local div_x = 84; local col1_x = div_x + 4; local col2_x = div_x + 24
     if not shift then
        screen.move(col1_x, 53); screen.level(3); screen.text("FB")
        screen.move(col1_x, 60); screen.level(15); screen.text(get_txt("feedback"))
        screen.move(col2_x, 53); screen.level(3); screen.text("Q")
        screen.move(col2_x, 60); screen.level(10); screen.text(get_txt("global_q"))
     else
        screen.move(col1_x, 53); screen.level(3); screen.text("RATE")
        screen.move(col1_x, 60); screen.level(15); screen.text(get_txt("lfo_rate"))
        screen.move(col2_x, 53); screen.level(3); screen.text("ROOT")
        screen.move(col2_x, 60); screen.level(15); screen.text(get_txt("root_note"))
     end
     
     screen.update(); return
  end

  if page == 2 then
    screen.clear()
    -- Page 2 uses helper (Center layout)
    if not shift then draw_left_e1("MIX", get_txt("filter_mix")); draw_right_param_pair("HPF", get_txt("pre_hpf"), "LPF", get_txt("pre_lpf"))
    else draw_left_e1("STAB", get_txt("stabilizer")); draw_right_param_pair("DRIFT", get_txt("filter_drift"), "SPR", get_txt("spread")) end
    local area_w = 84; local cy = 15 + (45 / 2) - 4 
    
    local h = state.heads.filter; local len = state.FILTER_LEN
    local total_energy = 0; for i=1,16 do total_energy = total_energy + (state.band_levels[i] or 0) end
    anim_phase_osc = (anim_phase_osc or 0) + 0.1
    state.filter_history[h].amp = clamp(total_energy * 20, 2, 18)
    state.filter_history[h].phase = anim_phase_osc
    state.heads.filter = (h % len) + 1

    for t=0, len-1 do
       local idx = (h - 1 - t - 1) % len + 1
       local frame = state.filter_history[idx]
       local brightness = floor(10 / (t+1))
       if brightness > 0 then
         screen.level(brightness)
         for i = 0, area_w, 2 do
           local w1 = sin((i/area_w * 10) + frame.phase) * frame.amp
           screen.pixel(2 + i, cy + w1); screen.pixel(2 + i, cy - w1)
         end
         screen.fill()
       end
    end
    draw_vertical_divider(); draw_goniometer_block(state); draw_header_right("FILTER"); screen.update(); return
  end

  if page == 3 then
    screen.clear()
    if not shift then draw_left_e1("REV", get_txt("reverb_mix")); draw_right_param_pair("RMIX", get_txt("rm_mix"), "MON", get_txt("main_mon"))
    else draw_left_e1("DIRT", get_txt("system_dirt")); draw_right_param_pair("FREQ", get_txt("rm_freq"), "NOISE", get_txt("noise_amp")) end
    
    local area_x = 0; local area_w = 84; local cy = 30
    screen.level(10)
    local rm = params:get("rm_mix") or 0; local rm_f = params:get("rm_freq") or 100
    for x = 0, area_w, 2 do
      local nx = x / area_w; local y = cy + sin(nx * 10 + now) * 2
      if amp_l > 0.01 then y = y + sin(nx * 50) * (amp_l * 15) end
      if rm > 0.1 then y = y + (sin(nx * (rm_f * 0.1) + now * 10) * 5 * rm) end
      screen.pixel(area_x + x, y); screen.fill()
    end
    draw_vertical_divider(); draw_goniometer_block(state); draw_header_right("MIX"); screen.update(); return
  end

  if page == 4 then
    screen.clear()
    if not shift then draw_left_e1("TMIX", get_txt("tape_mix")); draw_right_param_pair("TIME", get_txt("tape_time"), "FB", get_txt("tape_fb"))
    else draw_left_e1("EROS", get_txt("tape_erosion")); draw_right_param_pair("WOW", get_txt("tape_wow"), "FLUT", get_txt("tape_flutter")) end
    local speed_mult = state.k2_held_tape and 0.1 or 1.0
    anim_phase_tape = (anim_phase_tape or 0) + (0.05 * speed_mult)
    local reel_y = 27; local left_x = 22; local right_x = 62; local head_x = 42; local head_y = 35; local guide_y = 39
    local wobble = (random() - 0.5) * ((params:get("tape_wow") or 0) * 2 + amp_l)
    local erosion = params:get("tape_erosion") or 0; local gap_chance = erosion * 0.15
    for x = left_x, right_x do tape_segment(x, reel_y - 6, wobble, gap_chance) end 
    raster_line(left_x, reel_y + 6, left_x + 5, guide_y + 2, wobble, gap_chance)
    raster_line(left_x + 5, guide_y + 2, head_x, head_y + 5, wobble, gap_chance)
    raster_line(head_x, head_y + 5, right_x - 5, guide_y + 2, wobble, gap_chance)
    raster_line(right_x - 5, guide_y + 2, right_x, reel_y + 6, wobble, gap_chance)
    draw_reel(left_x, reel_y, anim_phase_tape); draw_reel(right_x, reel_y, anim_phase_tape + 1.5)
    draw_tape_head(head_x, head_y); screen.level(4); screen.circle(left_x + 5, guide_y, 2); screen.fill() 
    screen.circle(right_x - 5, guide_y, 2); screen.fill() 
    draw_vertical_divider(); draw_goniometer_block(state); draw_header_right("TAPE"); screen.update(); return
  end

  if page == 5 then
    screen.clear()
    local mode = params:get("ping_mode") or 1
    if mode == 1 then 
      if not shift then draw_left_e1("RATE", get_txt("ping_rate")); draw_right_param_pair("JITTER", get_txt("ping_jitter"), "TIMBRE", get_txt("ping_timbre"))
      else draw_left_e1("RATE F", get_txt("ping_rate")); draw_right_param_pair("FINE", get_txt("ping_rate"), "LEVEL", get_txt("ping_amp")) end
    else 
      if not shift then draw_left_e1("STEPS", get_txt("ping_steps")); draw_right_param_pair("HITS", get_txt("ping_hits"), "DIV", get_txt("ping_div"))
      else draw_left_e1("TIMBRE", get_txt("ping_timbre")); draw_right_param_pair("JITTER", get_txt("ping_jitter"), "LEVEL", get_txt("ping_amp")) end
    end
    local cx = 84 * 0.4; local cy = 15 + 45/2; local pulse_r = amp_l * 10
    local base_r = 6 + sin(now * 0.6) * 2 + pulse_r
    screen.level(3)
    for a = 0, 6.28, 0.2 do local noise_r = sin(a * 3 + now) * 1.5; screen.pixel(cx + cos(a)*(base_r+noise_r), cy + sin(a)*(base_r+noise_r)) end
    screen.fill()
    for i = #state.ping_pulses, 1, -1 do
      local p = state.ping_pulses[i]; local age = now - p.t0; local k = age / 0.6
      if k >= 1 then table.remove(state.ping_pulses, i)
      else
        local radius = k * 35; local jitter = (p.jitter or 0) * 4
        local pcx = cx + (random() - 0.5) * 2 * jitter; local pcy = cy + (random() - 0.5) * 2 * jitter 
        local b = floor(clamp(linlin(0,1,10,5, p.amp or 0.7) * (1-k) + 4, 6, 15))
        screen.level(b); for a = 0, 6.28, 0.25 do local r = radius + pulse_r + (sin(a * 4 + (p.phase_off or 0)) * radius * 0.2); screen.pixel(pcx + cos(a)*r, pcy + sin(a)*r) end
        screen.fill()
      end
    end
    draw_vertical_divider(); draw_goniometer_block(state); draw_header_right("PING"); screen.update(); return
  end

  if page == 6 then
    screen.clear()
    local focus = state.time_page_focus or "MAIN"
    local suffix = (focus == "MAIN") and "_main" or "_tape"
    if not shift then
      draw_left_e1("SEQ", get_txt("seq_rate"..suffix))
      draw_right_param_pair("SLEW", get_txt("fader_slew"), "MORPH", get_txt("preset_morph"..suffix))
    else draw_left_e1("SEQ F", get_txt("seq_rate"..suffix)); draw_right_param_pair("MORPH", get_txt("preset_morph"..suffix), "SEQ Q", get_txt("seq_rate"..suffix)) end
    
    local cx = 84 * 0.4; local cy = 15 + 45/2
    anim_phase_time = (anim_phase_time or 0) + ((params:get("seq_rate"..suffix) or 0) * 0.2) 
    
    local h = state.heads.time; local len = state.FILTER_LEN
    state.time_history[h].ph = anim_phase_time
    state.time_history[h].r = 12 + (amp_l * 15)
    state.time_history[h].m = params:get("preset_morph"..suffix) or 0
    state.heads.time = (h % len) + 1
    
    for i=0, len-1 do
       local idx = (h - 1 - i - 1) % len + 1
       local frame = state.time_history[idx]
       local brightness = floor(10/(i+1))
       screen.level(brightness)
       for t = 0, 6.28, 0.1 do
         local r = frame.r + cos(t * (2 + floor(frame.m*2))) * (frame.m * 3)
         local ang = t + frame.ph
         screen.pixel(cx + cos(ang)*r, cy + sin(ang)*r)
       end
       screen.fill()
    end
    draw_vertical_divider(); draw_goniometer_block(state); 
    screen.level(15); screen.move(128, 8); screen.text_right("TIME [" .. focus .. "]")
    screen.update(); return
  end
end

return Graphics
