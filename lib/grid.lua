-- Avant_lab_V lib/grid.lua | Version 1.6.1
-- RELEASE v1.6: 
-- 1. TRANSPORT: Shift+Transport = STOP (Toggle). Removed Clear from Shift block.
-- 2. PRESETS: Fixed audio saving (updates file_path before save).
-- 3. 16n: Resets latches when holding track select.

local Grid = {}
local Loopers = include('lib/loopers')
local Scales = include('lib/scales') 
local g -- Ref

local levels_cache = {}
for i=1, 16 do levels_cache[i] = {int=0, frac=0} end
local VS_VALS = {-2.0, -1.5, -1.0, -0.5, -0.25, 0.0, 0.25, 0.5, 1.0, 1.5, 2.0}

local MAX_BRIGHT = 12
local MED_BRIGHT = 6
local DIM_BRIGHT = 2

local next_frame = {}
for x=1, 16 do next_frame[x] = {}; for y=1, 8 do next_frame[x][y] = 0 end end

function Grid.init(state, device)
  g = device
  if g then g:all(0); g:refresh() end
  state.grid_keys_held = {} 
  for i=1, 4 do state.grid_keys_held[i] = {} end
  state.ribbon_memory = {}
  state.seek_memory = {} 
  state.preset_memory = nil
  state.seq_clicks = {0,0,0,0}
  state.stutter_memory = {} 
  state.view_toggle = false 
  state.pending_transport = {nil, nil, nil, nil} 
  state.transport_press_time = {0, 0, 0, 0}
  state.transport_last_tap = {0, 0, 0, 0}
  
  state.rnd_btn_val = 2
  state.rnd_btn_timer = 0
  state.freeze_clock = nil 
  state.freeze_btn_level = DIM_BRIGHT 
  state.grid_shift_active = false
  state.page_press_time = 0
  state.grid_track_held = false
end

-- ... (LED BUF / DRAW FUNCTIONS UNCHANGED) ...
local function led_buf(x, y, val)
   if x >=1 and x <=16 and y >=1 and y <=8 then
      next_frame[x][y] = math.floor(val)
   end
end

local function draw_tape_view(state)
  local now = util.time()
  local sel_pulse = math.floor(util.linlin(-1, 1, 10, MAX_BRIGHT, math.sin(now * 8))) 
  local rec_pulse = math.floor(util.linlin(-1, 1, 0, 2.9, math.sin(now * 8))) 
  local dub_pulse = math.floor(util.linlin(-1, 1, 0, 2.9, math.sin(now * 4))) 
  rec_pulse = util.clamp(rec_pulse, 0, DIM_BRIGHT)
  dub_pulse = util.clamp(dub_pulse, 0, DIM_BRIGHT)

  for t=1, 4 do
    local track = state.tracks[t]
    local bg_bright = 0
    if track.state == 2 then bg_bright = rec_pulse      
    elseif track.state == 4 then bg_bright = dub_pulse  
    end
    
    local s = math.floor((track.loop_start or 0) * 15) + 1
    local e = math.floor((track.loop_end or 1) * 15) + 1

    local has_audio = (track.state ~= 1)
    local is_paused = (track.state == 5)
    
    local head_pos = (track.play_pos or 0) * 15 + 1
    local head_max_b = 0
    if has_audio then head_max_b = MAX_BRIGHT 
    elseif is_paused then head_max_b = 3 
    elseif track.state == 1 then head_pos = 1; head_max_b = DIM_BRIGHT end

    for x=1, 16 do
       local b = bg_bright 
       if x == s or x == e then b = math.max(b, 5) end
       
       if head_max_b > 0 then
          local dist = math.abs(x - head_pos)
          if dist > 8 then dist = 16 - dist end 
          
          if dist < 1.5 then
             local intensity = (1.0 - (dist / 1.5)) ^ 2.3
             local pixel_b = math.floor(head_max_b * intensity)
             b = math.max(b, pixel_b)
          end
       end
       led_buf(x, t, b)
    end
  end

  for i=1,4 do 
     local b = 3
     if state.track_sel == i then b = sel_pulse end
     if state.grid_track_held and state.track_sel == i then b = 15 end
     led_buf(i, 5, b) 
  end
  
  local t = state.tracks[state.track_sel]; local s = t.speed or 1
  for i=1, 11 do
     local val = VS_VALS[i]; local x = i + 5; local b = DIM_BRIGHT
     if math.abs(s - val) < 0.01 then b = MAX_BRIGHT
     elseif (s > 0 and val > 0 and s >= val) or (s < 0 and val < 0 and s <= val) then b = MED_BRIGHT
     elseif val == 0 and math.abs(s) < 0.01 then b = MAX_BRIGHT end
     led_buf(x, 5, b)
  end
  
  for i=1, 16 do
     local track_idx = math.floor((i-1)/4) + 1; local intensity_idx = (i-1)%4; local brightness = 2 + (intensity_idx * 3) 
     if state.tracks[track_idx].brake_amt and state.tracks[track_idx].brake_amt > 0 then
        local active_intensity = math.floor(state.tracks[track_idx].brake_amt * 4) - 1
        if active_intensity == intensity_idx then brightness = MAX_BRIGHT end
     end
     led_buf(i, 6, brightness)
  end
end

local function draw_main_view(state)
  for i=1, 16 do
    local amp = state.band_levels[i] or 0
    local db = 20 * math.log10(amp > 0.0001 and amp or 0.0001)
    local height = util.linlin(-60, 0, 0, 6, db)
    height = util.clamp(height, 0, 6)
    levels_cache[i].int = math.floor(height)
    levels_cache[i].frac = height - math.floor(height)
  end

  for i=1, 16 do
    local db = state.visual_gain[i] or -60; 
    local fader_h = math.floor(util.linlin(-60,0,1,6,db) + 0.5); if fader_h < 1 then fader_h = 1 end
    local sig = levels_cache[i]
    for h=1, 6 do
       local y = 7 - h; local b_fad = (h <= fader_h) and DIM_BRIGHT or 0; local b_sig = 0
       if h <= sig.int then b_sig = MAX_BRIGHT elseif h == sig.int+1 then b_sig = math.floor(sig.frac * MAX_BRIGHT) end
       led_buf(i, y, math.max(b_fad, b_sig))
    end
  end
end

function Grid.redraw(state)
  if not g or not g.device then return end
  for x=1, 16 do for y=1, 8 do next_frame[x][y] = 0 end end
  
  if not state.loaded then return end
  
  local is_tape_view = (state.current_page == 7) or (state.current_page == 8) or (state.current_page == 5 and state.time_page_focus == "TAPE")
  if state.current_page == 9 and state.grid_tape_view_override then is_tape_view = true end

  if is_tape_view then draw_tape_view(state) else draw_main_view(state) end

  local rec_slots, presets_status, preset_selected, morph_active, morph_slot
  
  if is_tape_view then
     rec_slots = state.tape_rec_slots
     presets_status = state.tape_presets_status
     preset_selected = state.tape_preset_selected
     morph_active = state.morph_tape_active
     morph_slot = state.morph_tape_slot
  else
     rec_slots = state.main_rec_slots
     presets_status = state.main_presets_status
     preset_selected = state.main_preset_selected
     morph_active = state.morph_main_active
     morph_slot = state.morph_main_slot
  end

  -- ROW 7
  local now = util.time()
  local pulse_rec = math.floor(math.sin(now * 8) * 4 + 7) 
  local pulse_dub = math.floor(math.sin(now * 4) * 3 + 6) 
  local pulse_seq = math.floor(math.sin(now * 5) * 4 + 7) 

  for i=1, 4 do 
     local r = rec_slots[i]; local b = 1
     if r.state == 1 then b = pulse_seq 
     elseif r.state == 2 then b = MAX_BRIGHT 
     elseif r.state == 4 then b = pulse_dub 
     elseif r.state == 3 then b = 4 end
     led_buf(i, 7, b)
  end
  
  for i=1, 4 do 
     local x = i + 4; local st = presets_status[i]; local b = DIM_BRIGHT 
     if st==1 then b=MED_BRIGHT end
     if st == 1 then
        if preset_selected == i then b = MAX_BRIGHT end
        if morph_active and morph_slot == i then b = MAX_BRIGHT end
     end
     led_buf(x, 7, b)
  end
  
  -- FX (9-12)
  for i=9, 12 do 
     local active = false
     local b = 1
     if i==9 and state.fx_memory["kill"] then active = true; b = MAX_BRIGHT
     elseif i==10 then 
        if state.fx_memory["freeze"] then b = state.freeze_btn_level or DIM_BRIGHT; if b < 2 then b = 2 end; active = (b > 2)
        else b = 2 end
     elseif i==11 and state.fx_memory["warble"] then active = true; b = MAX_BRIGHT
     elseif i==12 and state.fx_memory["brake"] then active = true; b = MAX_BRIGHT end
     
     if not active and i ~= 10 then 
        if i == 12 then b = 3 
        elseif i == 11 then b = math.floor(math.sin(now * 3) * 2 + 3) end 
     end
     led_buf(i, 7, b)
  end 
  
  for i=1, 4 do 
     local trk = state.tracks[i]; local x = i + 12; local b = 1 
     if trk.state == 1 then b = 1
     elseif trk.state == 2 then b = pulse_rec 
     elseif trk.state == 4 then b = pulse_dub 
     elseif trk.state == 3 then b = 8 
     elseif trk.state == 5 then b = 4 end
     led_buf(x, 7, b)
  end
  
  -- ROW 8
  led_buf(1, 8, state.grid_momentary_mode and MAX_BRIGHT or 4)
  if now - state.rnd_btn_timer > 0.8 then state.rnd_btn_val = math.random(1, 6); state.rnd_btn_timer = now end
  led_buf(2, 8, state.rnd_btn_val)
  led_buf(3, 8, state.fx_memory["swell"] and MAX_BRIGHT or 4)
  led_buf(5, 8, state.ping_btn_held and MAX_BRIGHT or 2)
  
  for i=1, 10 do 
     local x = i + 6 
     local is_sel = (state.current_page == i)
     local b = is_sel and MAX_BRIGHT or DIM_BRIGHT
     if i == 8 then if is_sel then b = 10 else b = 1 end end
     if i == 10 then 
        local current_amp = math.max(state.amp_l or 0, state.amp_r or 0)
        local db = 20 * math.log10(current_amp > 0.0001 and current_amp or 0.0001)
        if is_sel then local vu = util.linlin(-40, 0, 10, MAX_BRIGHT, db); b = math.floor(util.clamp(vu, 10, MAX_BRIGHT))
        else local vu = util.linlin(-40, 0, DIM_BRIGHT, 10, db); b = math.floor(util.clamp(vu, DIM_BRIGHT, 10)) end
     end
     if state.grid_shift_active and is_sel then b = 8 end
     led_buf(x, 8, b) 
  end
  
  for x=1, 16 do
     for y=1, 8 do
        local new_val = next_frame[x][y]
        if state.grid_cache[x][y] ~= new_val then
           g:led(x, y, new_val)
           state.grid_cache[x][y] = new_val
        end
     end
  end
  g:refresh()
end

local function record_event(state, x, y, z, is_tape_context)
  local slots = is_tape_context and state.tape_rec_slots or state.main_rec_slots
  for i=1, 4 do
    local is_seq_btn = (y == 7 and x >= 1 and x <= 4)
    local is_page_nav = (y == 8 and x >= 7)
    
    if (slots[i].state == 1 or slots[i].state == 4) and not is_seq_btn and not is_page_nav then 
       local now = util.time()
       local dt = 0
       if slots[i].state == 1 then dt = now - (slots[i].start_time or now)
       else dt = (now - (slots[i].start_time or now)) % (slots[i].duration or 1) end
       table.insert(slots[i].data, {dt=dt, x=x, y=y, z=z, p=is_tape_context and 7 or 1, tid=state.track_sel})
       table.sort(slots[i].data, function(a,b) return a.dt < b.dt end)
    end
  end
end

function Grid.key(x, y, z, state, engine, simulated_page, target_track)
  if not simulated_page then
     local now = util.time()
     if z == 1 then
        local last = state.grid_debounce[x][y] or 0
        if (now - last) < 0.05 then return end 
        state.grid_debounce[x][y] = now
        state.button_state[x][y] = true 
     elseif z == 0 then
        if not state.button_state[x][y] then return end 
        state.button_state[x][y] = false 
     end
  end

  local active_page = simulated_page or state.current_page
  local is_physical = (simulated_page == nil)
  local is_tape_view = false
  if simulated_page then is_tape_view = (simulated_page == 7)
  else
     is_tape_view = (active_page == 7) or (active_page == 8) or (active_page == 5 and state.time_page_focus == "TAPE")
     if active_page == 9 and state.grid_tape_view_override then is_tape_view = true end
  end
  
  local rec_slots = is_tape_view and state.tape_rec_slots or state.main_rec_slots
  local presets_data = is_tape_view and state.tape_presets_data or state.main_presets_data
  local presets_status = is_tape_view and state.tape_presets_status or state.main_presets_status
  local preset_press_time = is_tape_view and state.tape_preset_press_time or state.main_preset_press_time
  
  if is_physical then record_event(state, x, y, z, is_tape_view) end

  -- ROW 8 (Pages & Shift)
  if y == 8 then
     if x >= 7 then 
        if z == 1 then 
           state.page_press_time = util.time()
           state.grid_shift_active = true
           local target_p = x - 6
           if target_p == state.current_page and target_p == 9 then
              state.grid_tape_view_override = not state.grid_tape_view_override
           else
              state.current_page = target_p
           end
        elseif z == 0 then
           state.grid_shift_active = false
        end
        return
     end
     if x == 1 and z == 1 then state.grid_momentary_mode = not state.grid_momentary_mode; return end
     if x == 2 and z == 1 then 
        for i=1, 16 do local rnd = (math.random() * 60) - 60; state.bands_gain[i] = rnd; engine.band_gain(i-1, rnd) end
        return
     end
     if x == 3 then 
        if z == 1 then
           state.fx_memory["swell"] = params:get("feedback")
           params:set("feedback", 0.85) 
        elseif z == 0 and state.fx_memory["swell"] then
           params:set("feedback", state.fx_memory["swell"])
           state.fx_memory["swell"] = nil
        end
        return
     end
     if x == 5 then 
        if z == 1 then engine.ping_manual(1); state.ping_btn_held = true
        else state.ping_btn_held = false end
        return
     end
     return
  end
  
  -- ROW 7 (Seq, Presets, FX, Transport)
  if y == 7 then
     if state.grid_shift_active and z == 1 then
        if x <= 4 then local r = rec_slots[x]; r.state = 0; r.data = {}; r.step = 1; r.duration = 0; return end
        if x >= 5 and x <= 8 then local slot = x - 4; presets_status[slot] = 0; presets_data[slot] = {}; if is_tape_view then state.tape_preset_selected = 0 else state.main_preset_selected = 0 end; return end
        if x >= 13 and x <= 16 then Loopers.clear(x - 12, state); return end
     end
     
     -- [v1.6] TRANSPORT: Dynamic Loop Logic + STOP Shortcut
     if x >= 13 and x <= 16 then 
        local trk = x - 12
        if z == 1 then 
           state.transport_press_time[trk] = util.time()
           
           -- [v1.6] STOP SHORTCUT: Shift (Page 7) OR Track Select (Row 5) + Transport
           if state.k1_held or state.grid_shift_active or state.grid_track_held then 
              state.tracks[trk].state = 5 -- Safe Stop
              Loopers.refresh(trk, state) 
              return -- Exit early
           end
           
        elseif z == 0 then
           local now = util.time()
           local hold_time = now - state.transport_press_time[trk]
           if state.k1_held or state.grid_shift_active or state.grid_track_held then return end 
           
           if hold_time > 1.0 then
              Loopers.clear(trk, state)
           else
              -- [v1.6] NO DOUBLE CLICK LOGIC ANYMORE
              local st = state.tracks[trk].state
              local next_st = 3
              
              -- AUTO-LOOP TIMEOUT LOGIC
              if state.tracks[trk].first_pass then
                  local rec_dur = now - (state.tracks[trk].rec_start_time or now)
                  local max_len = params:get("l"..trk.."_length")
                  if rec_dur > max_len then
                      state.tracks[trk].first_pass = false
                  end
              end

              if st == 5 or st == 0 or st == 1 then 
                 if st == 1 and engine.clear then 
                     engine.clear(trk); engine["l"..trk.."_seek"](0) 
                 end
                 state.tracks[trk].first_pass = true
                 state.tracks[trk].rec_start_time = util.time()
                 next_st = 4 
              elseif st == 4 and state.tracks[trk].first_pass then
                 local dur = util.time() - (state.tracks[trk].rec_start_time or now)
                 params:set("l"..trk.."_length", dur + 0.15)
                 state.tracks[trk].first_pass = false
                 next_st = 4 
              elseif st == 3 then next_st = 4 
              elseif st == 4 then next_st = 3 
              elseif st == 2 then next_st = 3 end
              
              state.tracks[trk].state = next_st
              Loopers.refresh(trk, state)
           end
        end
        return
     end
     
     -- FX (9-12)
     if x >= 9 and x <= 12 then 
        local fx_type = ""; if x == 9 then fx_type = "kill" elseif x == 10 then fx_type = "freeze" elseif x == 11 then fx_type = "warble" elseif x == 12 then fx_type = "brake" end
        if z == 1 then
           if fx_type == "kill" then state.fx_memory["kill"] = params:get("pre_lpf"); params:set("pre_lpf", 150)
           elseif fx_type == "freeze" then 
              if state.freeze_clock then clock.cancel(state.freeze_clock) end
              if not state.fx_memory["freeze"] then state.fx_memory["freeze"] = {rev_time=params:get("reverb_time"), fb=params:get("tape_fb")} end
              params:set("tape_fb", 1.0); state.freeze_btn_level = 15 
              state.freeze_clock = clock.run(function()
                 local start_val = params:get("reverb_time"); local target_val = 60.0; local steps = 10 
                 for i=1, steps do local val = start_val + ((target_val - start_val) * (i/steps)); params:set("reverb_time", val); clock.sleep(0.02) end
              end)
           elseif fx_type == "warble" then 
              state.fx_memory["warble"] = {w=params:get("tape_wow"), f=params:get("tape_flutter")}
              params:set("tape_wow", 1.0); params:set("tape_flutter", 1.0)
           elseif fx_type == "brake" then 
              state.fx_memory["brake"] = true
              for i=1,4 do state.tracks[i].brake_amt = 1.0 end; Loopers.refresh(1, state); Loopers.refresh(2, state); Loopers.refresh(3, state); Loopers.refresh(4, state) 
           end
        elseif z == 0 then
           if fx_type == "kill" and state.fx_memory["kill"] then params:set("pre_lpf", state.fx_memory["kill"]); state.fx_memory["kill"] = nil
           elseif fx_type == "freeze" and state.fx_memory["freeze"] then 
              if state.freeze_clock then clock.cancel(state.freeze_clock) end
              params:set("tape_fb", state.fx_memory["freeze"].fb)
              state.freeze_clock = clock.run(function()
                 local start_val = params:get("reverb_time"); local target_val = state.fx_memory["freeze"].rev_time; local steps = 150 
                 for i=1, steps do
                    local val = start_val + ((target_val - start_val) * (i/steps))
                    params:set("reverb_time", val); state.freeze_btn_level = math.floor(util.linlin(1, steps, 15, 2, i)); clock.sleep(0.02)
                 end
                 state.fx_memory["freeze"] = nil; state.freeze_btn_level = DIM_BRIGHT 
              end)
           elseif fx_type == "warble" and state.fx_memory["warble"] then params:set("tape_wow", state.fx_memory["warble"].w); params:set("tape_flutter", state.fx_memory["warble"].f); state.fx_memory["warble"] = nil
           elseif fx_type == "brake" then for i=1,4 do state.tracks[i].brake_amt = 0.0 end; Loopers.refresh(1, state); Loopers.refresh(2, state); Loopers.refresh(3, state); Loopers.refresh(4, state); state.fx_memory["brake"] = nil
           end
        end
        return
     end

     -- [FIX v1.6] PRESET AUDIO SAVING LOGIC
     if x >= 5 and x <= 8 then 
        local slot = x - 4
        if z == 1 then
           preset_press_time[slot] = util.time()
           local is_current = false
           if is_tape_view then is_current = (state.tape_preset_selected == slot) else is_current = (state.main_preset_selected == slot) end
           if presets_status[slot] == 0 then
             if is_tape_view then
                local saved_tracks = {}
                for i=1,4 do 
                    local t = state.tracks[i]
                    -- [v1.6] Auto-Save Audio if Dirty
                    if t.rec_len and t.rec_len > 0.1 then
                        local name = _path.audio .. "Avant_lab_V/snapshots/preset_" .. slot .. "_trk_" .. i .. ".wav"
                        engine.buffer_write(i, name, t.rec_len)
                        t.file_path = name
                        print("Saved Snapshot: " .. name)
                    end
                    saved_tracks[i] = {speed=t.speed, vol=t.vol, loop_start=t.loop_start, loop_end=t.loop_end, state=t.state, overdub=t.overdub, file_path=t.file_path, l_low=t.l_low, l_high=t.l_high, l_filter=t.l_filter, l_pan=t.l_pan, l_width=t.l_width} 
                end
                presets_data[slot] = { tracks = saved_tracks }; state.tape_preset_selected = slot
             else
                local saved_gains = {}; for i=1, 16 do saved_gains[i] = state.bands_gain[i] end
                presets_data[slot] = { gains = saved_gains, q = params:get("global_q"), scale_idx = params:get("scale_idx"), root_note = params:get("root_note"), feedback = params:get("feedback") }
                state.main_preset_selected = slot
             end
             presets_status[slot] = 1
           elseif is_current then
              if is_tape_view then
                local saved_tracks = {}
                for i=1,4 do 
                    local t = state.tracks[i]
                    -- [v1.6] Update snapshot if changed
                    if t.rec_len and t.rec_len > 0.1 then
                        local name = _path.audio .. "Avant_lab_V/snapshots/preset_" .. slot .. "_trk_" .. i .. ".wav"
                        engine.buffer_write(i, name, t.rec_len)
                        t.file_path = name
                    end
                    saved_tracks[i] = {speed=t.speed, vol=t.vol, loop_start=t.loop_start, loop_end=t.loop_end, state=t.state, overdub=t.overdub, file_path=t.file_path, l_low=t.l_low, l_high=t.l_high, l_filter=t.l_filter, l_pan=t.l_pan, l_width=t.l_width} 
                end
                presets_data[slot] = { tracks = saved_tracks }
              else
                local saved_gains = {}; for i=1, 16 do saved_gains[i] = state.bands_gain[i] end
                presets_data[slot] = { gains = saved_gains, q = params:get("global_q"), scale_idx = params:get("scale_idx"), root_note = params:get("root_note"), feedback = params:get("feedback") }
              end
           else
              if is_tape_view then
                 state.morph_tape_src = {}; for i=1,4 do state.morph_tape_src[i] = {speed=state.tracks[i].speed, vol=state.tracks[i].vol, l_low=state.tracks[i].l_low, l_high=state.tracks[i].l_high, l_filter=state.tracks[i].l_filter, l_pan=state.tracks[i].l_pan, l_width=state.tracks[i].l_width} end
                 state.morph_tape_active = true; state.morph_tape_slot = slot; state.morph_tape_start_time = util.time(); state.tape_preset_selected = slot
                 local target = presets_data[slot]
                 if target and target.tracks then
                    for i=1,4 do 
                        -- [v1.6] Load Audio if present
                        if target.tracks[i] and target.tracks[i].file_path then
                            Loopers.load_file(i, target.tracks[i].file_path, state)
                        end
                        if target.tracks[i] and target.tracks[i].state then state.tracks[i].state = target.tracks[i].state; Loopers.refresh(i, state) end 
                    end
                 end
              else
                 state.morph_main_src = {}
                 for i=1,16 do state.morph_main_src[i] = state.bands_gain[i] or params:get("gain_"..i) or -60 end
                 state.morph_main_src_q = params:get("global_q"); state.morph_main_src_fb = params:get("feedback"); state.morph_main_src_freqs = {}
                 for i=1, 16 do table.insert(state.morph_main_src_freqs, params:get("freq_"..i)) end
                 state.morph_main_active = true; state.morph_main_slot = slot; state.morph_main_start_time = util.time(); state.main_preset_selected = slot
                 local target = presets_data[slot]
                 if target and target.scale_idx then state.preview_scale_idx = target.scale_idx; if Scales and Scales.list and Scales.list[target.scale_idx] then state.loaded_scale_name = Scales.list[target.scale_idx].name end end
              end
           end
        elseif z == 0 then
           local d = util.time() - preset_press_time[slot]
           if presets_status[slot] == 1 and d > 1.0 then presets_status[slot] = 0; presets_data[slot] = {}; if is_tape_view then state.tape_preset_selected = 0 else state.main_preset_selected = 0 end end
        end
        return
     end
  end
  
  -- [v1.6] TAPE TOUCH (Micro-Loops)
  if is_tape_view and y <= 4 then
     local trk = y
     if z == 1 then 
        state.grid_keys_held[trk][x] = true
        
        -- [v1.6] Set Track Held Flag for Controls.lua
        state.grid_track_held = true
        state.track_sel = trk -- Auto-select track on touch
        
        -- [v1.6] Reset 16n Latches for Faders 1-4 (Layer Switch)
        for i=1, 4 do state.fader_latched[i] = false end
        
        clock.run(function()
           clock.sleep(0.06) 
           local count = 0; local min_x = 17; local max_x = 0
           for k, v in pairs(state.grid_keys_held[trk]) do if v then count = count + 1; if k < min_x then min_x = k end; if k > max_x then max_x = k end end end
           
           if count == 1 then
              if state.grid_keys_held[trk][x] then 
                 local pos = (x-1)/15
                 local t = state.tracks[trk]
                 state.seek_memory[trk] = {start_p = t.loop_start or 0, end_p = t.loop_end or 1}
                 local buf_len = params:get("l"..trk.."_length") or 10.0
                 local rand_ms = math.random(80, 180) / 1000.0
                 local frac = rand_ms / buf_len
                 t.loop_start = pos; t.loop_end = math.min(pos + frac, 1.0)
                 Loopers.refresh(trk, state); engine["l"..trk.."_seek"](pos)
              end
           elseif count >= 2 then
              state.tracks[trk].loop_start = (min_x - 1) / 15
              state.tracks[trk].loop_end = (max_x - 1) / 15
              Loopers.refresh(trk, state)
           end
        end)
     elseif z == 0 then 
        state.grid_keys_held[trk][x] = nil 
        
        -- [v1.6] Clear Track Held Flag if no keys held
        local any_held = false
        for k,v in pairs(state.grid_keys_held[trk]) do if v then any_held = true end end
        if not any_held then 
            state.grid_track_held = false 
            -- [v1.6] Reset 16n Latches for Faders 1-4 (Layer Switch Back)
            for i=1, 4 do state.fader_latched[i] = false end
        end

        local count = 0; for k,v in pairs(state.grid_keys_held[trk]) do if v then count=count+1 end end
        if count == 0 and state.seek_memory[trk] then
            local t = state.tracks[trk]; local mem = state.seek_memory[trk]
            t.loop_start = mem.start_p; t.loop_end = mem.end_p
            Loopers.refresh(trk, state); state.seek_memory[trk] = nil
        end
     end
     return
  end
  
  -- MIXER / RIBBON
  if is_tape_view and y == 5 then
     if x <= 4 and z == 1 then state.track_sel = x; state.grid_track_held = true; if state.current_page == 9 then state.mixer_sel = x; state.grid_mixer_held = true end
     elseif x <= 4 and z == 0 then state.grid_mixer_held = false; state.grid_track_held = false end
     
     if x >= 6 then
        local target = target_track or state.track_sel
        if z==1 then
           state.ribbon_press_time = util.time(); state.ribbon_start_speed = state.tracks[target].speed or 1.0
           if state.grid_momentary_mode and not state.ribbon_memory[target] then state.ribbon_memory[target] = state.tracks[target].speed end
           local idx = x - 5; local tgt_speed = VS_VALS[idx] or 1.0; state.ribbon_target_speed = tgt_speed
           if state.grid_momentary_mode then Loopers.set_speed_slew(target, state.ribbon_target_speed, 0.1, state, state.ribbon_start_speed) end
        elseif z==0 then
           if state.grid_momentary_mode and state.ribbon_memory[target] then
              Loopers.set_speed_slew(target, state.ribbon_memory[target], 0.1, state, state.tracks[target].speed); state.ribbon_memory[target] = nil
           else
              if not state.grid_momentary_mode then
                 local dur = util.time() - state.ribbon_press_time; local slew = 0
                 if dur < 0.15 then slew = 0.05 elseif dur < 2.0 then slew = util.linlin(0.15, 2.0, 0.5, 2.0, dur) elseif dur < 3.0 then slew = 5.0 else slew = 8.0 end
                 Loopers.set_speed_slew(target, state.ribbon_target_speed, slew, state, state.ribbon_start_speed)
              end
           end
        end
     end
     return
  end
  if is_tape_view and y == 6 then
     local trk_idx = math.floor((x-1)/4) + 1; local intensity = (x-1)%4 + 1; local amt = intensity * 0.25
     if z==1 then state.tracks[trk_idx].brake_amt = amt
     elseif z==0 then state.tracks[trk_idx].brake_amt = 0 end
     Loopers.refresh(trk_idx, state)
     return
  end
  if not is_tape_view and y <= 6 then
     local h = 7 - y; local db = util.linlin(1, 6, -60, 0, h); if h == 1 then db = -60 end
     if z==1 then
        if is_physical then state.morph_main_active = false end 
        if state.grid_momentary_mode and is_physical then state.grid_memory[x] = state.bands_gain[x] end
        params:set("gain_"..x, db)
     elseif z==0 then
        if state.grid_momentary_mode then params:set("gain_"..x, state.grid_memory[x]) end
     end
  end
end

Grid.start_playback = function(slot) end

return Grid
