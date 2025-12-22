-- Avant_lab_V lib/grid.lua | Version 108.0
-- FIX: Reverted Presets to Sound-Only (Removed Sequencer Save/Load from Grid Buttons)

local Grid = {}
local Loopers = include('lib/loopers')
local Scales = include('lib/scales') 
local g -- Ref

local levels_cache = {}
for i=1, 16 do levels_cache[i] = {int=0, frac=0} end
local SPEED_STEPS = {0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0}
local VS_VALS = {-2.0, -1.5, -1.0, -0.5, -0.25, 0.0, 0.25, 0.5, 1.0, 1.5, 2.0}

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
  state.rnd_btn_val = 2
  state.rnd_btn_timer = 0
end

local function draw_tape_view(state)
  local now = util.time()
  for t=1, 4 do
    local track = state.tracks[t]
    local s = math.floor((track.loop_start or 0) * 15) + 1
    local e = math.floor((track.loop_end or 1) * 15) + 1
    g:led(s, t, 4); g:led(e, t, 4)
    if track.state ~= 1 and track.state ~= 5 and (track.rec_len or 0) > 0.1 then
      local visual_pos = math.floor((track.play_pos or 0) * 15) + 1
      visual_pos = util.clamp(visual_pos, 1, 16)
      g:led(visual_pos, t, 15)
    elseif track.state == 5 then
       local visual_pos = math.floor((track.play_pos or 0) * 15) + 1
       g:led(visual_pos, t, 2) 
    elseif track.state == 1 then g:led(1, t, 2) end
  end
  for i=1,4 do g:led(i, 5, (state.track_sel == i) and 15 or 3) end
  local t = state.tracks[state.track_sel]; local s = t.speed or 1
  for i=1, 11 do
     local val = VS_VALS[i]; local x = i + 5; local b = 2
     if math.abs(s - val) < 0.01 then b = 15
     elseif (s > 0 and val > 0 and s >= val) or (s < 0 and val < 0 and s <= val) then b = 6
     elseif val == 0 and math.abs(s) < 0.01 then b = 15 end
     g:led(x, 5, b)
  end
  for i=1, 16 do
     local track_idx = math.floor((i-1)/4) + 1; local intensity_idx = (i-1)%4; local brightness = 2 + (intensity_idx * 3) 
     if state.tracks[track_idx].brake_amt and state.tracks[track_idx].brake_amt > 0 then
        local active_intensity = math.floor(state.tracks[track_idx].brake_amt * 4) - 1
        if active_intensity == intensity_idx then brightness = 15 end
     end
     g:led(i, 6, brightness)
  end
end

local function draw_main_view(state)
  for i=1, 16 do
    local amp = state.band_levels[i] or 0; local int_val = math.floor(amp * 49); levels_cache[i].int = int_val; levels_cache[i].frac = (amp * 49) - int_val
  end
  for i=1, 16 do
    local db = state.bands_gain[i] or -60; local fader_h = math.floor(util.linlin(-60,0,1,6,db) + 0.5); if fader_h < 1 then fader_h = 1 end
    local sig = levels_cache[i]
    for h=1, 6 do
       local y = 7 - h; local b_fad = (h <= fader_h) and 2 or 0; local b_sig = 0
       if h <= sig.int then b_sig = 15 elseif h == sig.int+1 then b_sig = math.floor(sig.frac * 15) end
       g:led(i, y, math.max(b_fad, b_sig))
    end
  end
end

function Grid.redraw(state)
  if not g or not g.device then return end
  g:all(0)
  
  local is_tape_view = (state.current_page == 7) or (state.current_page == 8) or (state.current_page == 5 and state.time_page_focus == "TAPE")
  if state.current_page == 9 and state.grid_tape_view_override then is_tape_view = true end

  if is_tape_view then draw_tape_view(state) else draw_main_view(state) end

  local rec_slots = is_tape_view and state.tape_rec_slots or state.main_rec_slots
  local presets_status = is_tape_view and state.tape_presets_status or state.main_presets_status
  local preset_selected = is_tape_view and state.tape_preset_selected or state.main_preset_selected
  local morph_active = is_tape_view and state.morph_tape_active or state.morph_main_active
  local morph_slot = is_tape_view and state.morph_tape_slot or state.morph_main_slot

  -- --- ROW 7: PERFORMANCE ---
  local now = util.time()
  local pulse_rec = math.floor(math.sin(now * 8) * 6 + 9) 
  local pulse_dub = math.floor(math.sin(now * 4) * 4 + 8) 
  local pulse_seq = math.floor(math.sin(now * 5) * 5 + 8) 

  for i=1, 4 do -- Sequencers
     local r = rec_slots[i]; local b = 1
     if r.state == 1 then b = pulse_seq 
     elseif r.state == 2 then b = 15 
     elseif r.state == 4 then b = pulse_dub 
     elseif r.state == 3 then b = 4 end
     g:led(i, 7, b)
  end
  
  for i=1, 4 do -- Presets
     local x = i + 4; local st = presets_status[i]; local b = 2 
     if st==1 then b=6 end
     
     -- Only show selection/morph if preset exists
     if st == 1 then
        if preset_selected == i then b = 15 end
        if morph_active and morph_slot == i then b = 15 end
     end
     
     g:led(x, 7, b)
  end
  
  -- FX (9-12)
  for i=9, 12 do 
     local active = false
     if i==9 and state.fx_memory["kill"] then active = true
     elseif i==10 and state.fx_memory["freeze"] then active = true
     elseif i==11 and state.fx_memory["warble"] then active = true
     elseif i==12 and state.fx_memory["brake"] then active = true end
     local b = 1 
     if active then b = 15 
     elseif i == 11 then b = math.floor(math.sin(now * 3) * 2 + 3) end 
     g:led(i, 7, b)
  end 
  
  for i=1, 4 do -- Transport
     local trk = state.tracks[i]; local x = i + 12; local b = 1 
     if trk.state == 2 then b = pulse_rec elseif trk.state == 4 then b = pulse_dub elseif trk.state == 3 then b = 8 elseif trk.state == 5 then b = 4 end
     g:led(x, 7, b)
  end
  
  -- --- ROW 8: SYSTEM ---
  g:led(1, 8, state.grid_momentary_mode and 15 or 4)
  if now - state.rnd_btn_timer > 0.8 then state.rnd_btn_val = math.random(1, 6); state.rnd_btn_timer = now end
  g:led(3, 8, state.rnd_btn_val) 
  g:led(4, 8, state.fx_memory["swell"] and 15 or 4) 
  g:led(6, 8, state.ping_btn_held and 15 or 2) 
  
  -- Pages 1-9 (Buttons 8-16)
  for i=1, 9 do 
     local x = i + 7 
     g:led(x, 8, (state.current_page == i) and 15 or 2) 
  end
  
  g:refresh()
end

local function record_event(state, x, y, z, is_tape_context)
  local slots = is_tape_context and state.tape_rec_slots or state.main_rec_slots
  for i=1, 4 do
    local is_seq_btn = (y == 7 and x >= 1 and x <= 4)
    local is_page_nav = (y == 8 and x >= 8)
    
    if (slots[i].state == 1 or slots[i].state == 4) and not is_seq_btn and not is_page_nav then 
       local now = util.time()
       local dt = 0
       if slots[i].state == 1 then 
          dt = now - (slots[i].start_time or now)
       else 
          dt = (now - (slots[i].start_time or now)) % (slots[i].duration or 1) 
       end
       
       table.insert(slots[i].data, {dt=dt, x=x, y=y, z=z, p=is_tape_context and 7 or 1, tid=state.track_sel})
       table.sort(slots[i].data, function(a,b) return a.dt < b.dt end)
    end
  end
end

function Grid.key(x, y, z, state, engine, simulated_page, target_track)
  local active_page = simulated_page or state.current_page
  local is_physical = (simulated_page == nil)
  
  local is_tape_view = false
  if simulated_page then
     is_tape_view = (simulated_page == 7)
  else
     is_tape_view = (active_page == 7) or (active_page == 8) or (active_page == 5 and state.time_page_focus == "TAPE")
     if active_page == 9 and state.grid_tape_view_override then is_tape_view = true end
  end
  
  local rec_slots = is_tape_view and state.tape_rec_slots or state.main_rec_slots
  local presets_data = is_tape_view and state.tape_presets_data or state.main_presets_data
  local presets_status = is_tape_view and state.tape_presets_status or state.main_presets_status
  local preset_press_time = is_tape_view and state.tape_preset_press_time or state.main_preset_press_time
  
  if is_physical then record_event(state, x, y, z, is_tape_view) end

  -- === ROW 8: SYSTEM (GLOBAL) ===
  if y == 8 then
     if x >= 8 then -- Pages 1-9
        if z == 1 then 
           local target_p = x - 7
           if target_p == state.current_page and target_p == 9 then
              state.grid_tape_view_override = not state.grid_tape_view_override
           else
              state.current_page = target_p
           end
        end
        return
     end
     if x == 1 and z == 1 then state.grid_momentary_mode = not state.grid_momentary_mode; return end
     if x == 3 and z == 1 then 
        for i=1, 16 do local rnd = (math.random() * 60) - 60; state.bands_gain[i] = rnd; engine.band_gain(i-1, rnd) end
        return
     end
     if x == 4 then -- Swell
        if z == 1 then
           state.fx_memory["swell"] = params:get("feedback")
           params:set("feedback", 0.85) 
        elseif z == 0 and state.fx_memory["swell"] then
           params:set("feedback", state.fx_memory["swell"])
           state.fx_memory["swell"] = nil
        end
        return
     end
     if x == 6 then -- Ping
        if z == 1 then engine.ping_manual(1); state.ping_btn_held = true
        else state.ping_btn_held = false end
        return
     end
     return
  end

  -- === ROW 7: PERFORMANCE (GLOBAL) ===
  if y == 7 then
     if x <= 4 then -- Sequencers
        local slot = x; local r = rec_slots[slot]
        if z==1 then r.press_time = util.time()
        elseif z==0 then
           local d = util.time() - r.press_time
           if d > 1.0 then r.state = 0; r.data = {}; r.step = 1; r.duration = 0
           else
              state.seq_clicks[slot] = (state.seq_clicks[slot] or 0) + 1
              if state.seq_clicks[slot] == 1 then
                 clock.run(function() clock.sleep(0.25)
                    local clicks = state.seq_clicks[slot]
                    if clicks == 1 then
                       if r.state == 0 then r.state = 1; r.data = {}; r.start_time = util.time(); r.step = 1
                       elseif r.state == 1 then r.state = 2; r.duration = util.time() - r.start_time
                       elseif r.state == 2 then r.state = 4
                       elseif r.state == 4 then r.state = 2 
                       elseif r.state == 3 then r.state = 2 end
                    elseif clicks == 2 then
                       if r.state ~= 0 then r.state = 3 end
                    end
                    state.seq_clicks[slot] = 0
                 end)
              end
           end
        end
        return
     end
     
     if x >= 5 and x <= 8 then -- Presets
        local slot = x - 4
        if z == 1 then
           preset_press_time[slot] = util.time()
           if state.grid_momentary_mode then
              if is_tape_view then state.preset_memory = state.tape_preset_selected
              else state.preset_memory = state.main_preset_selected end
           end
           
           local is_current = false
           if is_tape_view then is_current = (state.tape_preset_selected == slot)
           else is_current = (state.main_preset_selected == slot) end
           
           if presets_status[slot] == 0 then
             -- SAVE (SOUND ONLY)
             if is_tape_view then
                local saved_tracks = {}
                for i=1,4 do local t = state.tracks[i]; saved_tracks[i] = {speed=t.speed, vol=t.vol, loop_start=t.loop_start, loop_end=t.loop_end, state=t.state, overdub=t.overdub, file_path=t.file_path, l_low=t.l_low, l_high=t.l_high, l_filter=t.l_filter, l_pan=t.l_pan, l_width=t.l_width} end
                presets_data[slot] = { tracks = saved_tracks }
                state.tape_preset_selected = slot
             else
                local saved_gains = {}; for i=1, 16 do saved_gains[i] = state.bands_gain[i] end
                presets_data[slot] = { 
                    gains = saved_gains, 
                    q = params:get("global_q"), 
                    scale_idx = params:get("scale_idx"), 
                    root_note = params:get("root_note"), 
                    feedback = params:get("feedback")
                }
                state.main_preset_selected = slot
             end
             presets_status[slot] = 1
           elseif is_current then
              -- UPDATE (SOUND ONLY)
              if is_tape_view then
                local saved_tracks = {}
                for i=1,4 do local t = state.tracks[i]; saved_tracks[i] = {speed=t.speed, vol=t.vol, loop_start=t.loop_start, loop_end=t.loop_end, state=t.state, overdub=t.overdub, file_path=t.file_path, l_low=t.l_low, l_high=t.l_high, l_filter=t.l_filter, l_pan=t.l_pan, l_width=t.l_width} end
                presets_data[slot] = { tracks = saved_tracks }
              else
                local saved_gains = {}; for i=1, 16 do saved_gains[i] = state.bands_gain[i] end
                presets_data[slot] = { 
                    gains = saved_gains, 
                    q = params:get("global_q"), 
                    scale_idx = params:get("scale_idx"), 
                    root_note = params:get("root_note"), 
                    feedback = params:get("feedback")
                }
              end
           else
              -- RECALL (SOUND ONLY - NO SEQUENCER TOUCHED)
              if is_tape_view then
                 state.morph_tape_src = {}; for i=1,4 do state.morph_tape_src[i] = {speed=state.tracks[i].speed, vol=state.tracks[i].vol, l_low=state.tracks[i].l_low, l_high=state.tracks[i].l_high, l_filter=state.tracks[i].l_filter, l_pan=state.tracks[i].l_pan, l_width=state.tracks[i].l_width} end
                 state.morph_tape_active = true; state.morph_tape_slot = slot; state.morph_tape_start_time = util.time(); state.tape_preset_selected = slot
                 
                 local target = presets_data[slot]
                 if target and target.tracks then
                    for i=1,4 do
                        if target.tracks[i] and target.tracks[i].state then
                           state.tracks[i].state = target.tracks[i].state
                           Loopers.refresh(i, state)
                        end
                    end
                 end
              else
                 state.morph_main_src = {}
                 for i=1,16 do state.morph_main_src[i] = state.bands_gain[i] or params:get("gain_"..i) or -60 end
                 state.morph_main_src_q = params:get("global_q")
                 state.morph_main_src_fb = params:get("feedback")
                 
                 state.morph_main_src_freqs = {}
                 for i=1, 16 do table.insert(state.morph_main_src_freqs, params:get("freq_"..i)) end
                 
                 state.morph_main_active = true; state.morph_main_slot = slot; state.morph_main_start_time = util.time(); state.main_preset_selected = slot
                 
                 local target = presets_data[slot]
                 if target and target.scale_idx then 
                    state.preview_scale_idx = target.scale_idx
                    if Scales and Scales.list and Scales.list[target.scale_idx] then 
                        state.loaded_scale_name = Scales.list[target.scale_idx].name 
                    end 
                 end
              end
           end
        elseif z == 0 then
           if state.grid_momentary_mode and state.preset_memory then
              local prev = state.preset_memory
              if is_tape_view then state.morph_tape_active = true; state.morph_tape_slot = prev; state.morph_tape_start_time = util.time(); state.tape_preset_selected = prev
              else 
                 state.morph_main_src = {}; for i=1,16 do state.morph_main_src[i] = state.bands_gain[i] or -60 end
                 state.morph_main_src_q = params:get("global_q")
                 state.morph_main_src_fb = params:get("feedback")
                 
                 state.morph_main_src_freqs = {}
                 for i=1, 16 do table.insert(state.morph_main_src_freqs, params:get("freq_"..i)) end
                 
                 state.morph_main_active = true; state.morph_main_slot = prev; state.morph_main_start_time = util.time(); state.main_preset_selected = prev 
                 
                 local target = presets_data[prev]
                 if target and target.scale_idx then 
                    state.preview_scale_idx = target.scale_idx
                    if Scales and Scales.list and Scales.list[target.scale_idx] then 
                        state.loaded_scale_name = Scales.list[target.scale_idx].name 
                    end 
                 end
              end
           end
           local d = util.time() - preset_press_time[slot]
           if presets_status[slot] == 1 and d > 1.0 then presets_status[slot] = 0; presets_data[slot] = {}; if is_tape_view then state.tape_preset_selected = 0 else state.main_preset_selected = 0 end end
        end
        return
     end
     
     if x >= 9 and x <= 12 then 
        local fx_type = ""; if x == 9 then fx_type = "kill" elseif x == 10 then fx_type = "freeze" elseif x == 11 then fx_type = "warble" elseif x == 12 then fx_type = "brake" end
        if z == 1 then
           if fx_type == "kill" then state.fx_memory["kill"] = params:get("pre_lpf"); params:set("pre_lpf", 150)
           elseif fx_type == "freeze" then 
              state.fx_memory["freeze"] = {rev=params:get("reverb_mix"), fb=params:get("tape_fb")}
              params:set("reverb_mix", 1.0); params:set("tape_fb", 0.98)
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
              params:set("reverb_mix", state.fx_memory["freeze"].rev); params:set("tape_fb", state.fx_memory["freeze"].fb); state.fx_memory["freeze"] = nil
           elseif fx_type == "warble" and state.fx_memory["warble"] then 
              params:set("tape_wow", state.fx_memory["warble"].w); params:set("tape_flutter", state.fx_memory["warble"].f); state.fx_memory["warble"] = nil
           elseif fx_type == "brake" then 
              for i=1,4 do state.tracks[i].brake_amt = 0.0 end; Loopers.refresh(1, state); Loopers.refresh(2, state); Loopers.refresh(3, state); Loopers.refresh(4, state); state.fx_memory["brake"] = nil
           end
        end
        return
     end
     
     if x >= 13 and x <= 16 then 
        local trk = x - 12
        if z == 1 then
           state.transport_press_time[trk] = util.time()
           if state.k1_held then
              state.tracks[trk].state = 5; Loopers.refresh(trk, state)
           end
        elseif z == 0 then
           local hold_time = util.time() - state.transport_press_time[trk]
           if state.k1_held then return end 
           
           if hold_time > 1.5 then
              Loopers.clear(trk, state)
           else
              local now = util.time()
              local dt = now - state.transport_timers[trk]
              if dt < 0.3 then
                 state.tracks[trk].state = 5; Loopers.refresh(trk, state)
              else
                 local st = state.tracks[trk].state
                 local next_st = 3 
                 if st == 1 then next_st = 2 elseif st == 2 then next_st = 3 elseif st == 3 then next_st = 4 elseif st == 4 then next_st = 3 elseif st == 5 then next_st = 3 end
                 if next_st == 2 or next_st == 4 then state.tracks[trk].is_dirty = true; if next_st == 2 then state.tape_filenames[trk] = nil end end
                 state.tracks[trk].state = next_st
                 if next_st == 2 then state.tracks[trk].start_abs_time = now
                 elseif st == 2 and next_st == 3 then
                    local raw_time = now - (state.tracks[trk].start_abs_time or now)
                    local speed_factor = math.abs(state.tracks[trk].speed or 1)
                    if speed_factor < 0.01 then speed_factor = 1.0 end
                    local len = raw_time * speed_factor
                    if len < 0.1 then len = 0.1 end; if len > 60.0 then len = 60.0 end
                    state.tracks[trk].rec_len = len; state.tracks[trk].loop_start = 0; state.tracks[trk].loop_end = 1
                 end
                 Loopers.refresh(trk, state)
              end
              state.transport_timers[trk] = now
           end
        end
        return
     end
  end

  if is_tape_view and y <= 4 then
     local trk = y
     if z == 1 then 
        state.grid_keys_held[trk][x] = true
        clock.run(function()
           clock.sleep(0.06) 
           local count = 0; local min_x = 17; local max_x = 0
           for k, v in pairs(state.grid_keys_held[trk]) do 
              if v then count = count + 1; if k < min_x then min_x = k end; if k > max_x then max_x = k end end 
           end
           if count == 1 then
              if state.grid_keys_held[trk][x] then
                 if state.grid_momentary_mode then
                    state.stutter_memory[trk] = {start = state.tracks[trk].loop_start, end_ = state.tracks[trk].loop_end}
                    local center = (x-1)/15; local width = 0.05 
                    state.tracks[trk].loop_start = math.max(0, center - width/2); state.tracks[trk].loop_end = math.min(1, center + width/2)
                    Loopers.refresh(trk, state)
                 else
                    local pos = (x-1)/15
                    Loopers.seek(trk, pos, state)
                 end
              end
           elseif count >= 2 then
              state.tracks[trk].loop_start = (min_x - 1) / 15
              state.tracks[trk].loop_end = (max_x - 1) / 15
              Loopers.refresh(trk, state)
           end
        end)
     elseif z == 0 then 
        state.grid_keys_held[trk][x] = nil 
        if state.grid_momentary_mode and state.stutter_memory[trk] then
           local count = 0
           for k, v in pairs(state.grid_keys_held[trk]) do if v then count = count + 1 end end
           if count == 0 then
              state.tracks[trk].loop_start = state.stutter_memory[trk].start; state.tracks[trk].loop_end = state.stutter_memory[trk].end_
              Loopers.refresh(trk, state); state.stutter_memory[trk] = nil
           end
        end
     end
     return
  end
     
  if is_tape_view and y == 5 then
     if x <= 4 and z == 1 then state.track_sel = x end
     if x >= 6 then
        local target = target_track or state.track_sel
        if z==1 then
           state.ribbon_press_time = util.time()
           state.ribbon_start_speed = state.tracks[target].speed or 1.0
           if state.grid_momentary_mode and not state.ribbon_memory[target] then state.ribbon_memory[target] = state.tracks[target].speed end
           local idx = x - 5
           local tgt_speed = VS_VALS[idx] or 1.0
           state.ribbon_target_speed = tgt_speed
        elseif z==0 then
           if state.grid_momentary_mode and state.ribbon_memory[target] then
              Loopers.set_speed_slew(target, state.ribbon_memory[target], 0.1, state, state.tracks[target].speed)
              state.ribbon_memory[target] = nil
           else
              local dur = util.time() - state.ribbon_press_time
              local slew = 0
              if dur < 0.15 then slew = 0.05 elseif dur < 2.0 then slew = util.linlin(0.15, 2.0, 0.5, 2.0, dur) elseif dur < 3.0 then slew = 5.0 else slew = 8.0 end
              Loopers.set_speed_slew(target, state.ribbon_target_speed, slew, state, state.ribbon_start_speed)
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
