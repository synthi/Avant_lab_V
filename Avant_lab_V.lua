-- Avant_lab_V.lua | Version 1.76
-- RELEASE v1.76: 
-- 1. REPORTING: Receives Negative Pointer from SC for live recording status.
--    IMPORTANT: Prioritizes Grid parameter (+0.15 safety) over raw Sweep duration for saving.
--    This prevents clicks by ensuring saved audio includes the safety seamless buffer.
-- 2. TUNING: Speed step 0.002, Dub max 1.11, Rec def -3dB.

engine.name = 'Avant_lab_V'

local Globals = include('lib/globals')
local Scales = include('lib/scales')
local Graphics = include('lib/graphics')
local Controls = include('lib/controls')
local Grid = include('lib/grid')
local Storage = include('lib/storage')
local Loopers = include('lib/loopers')
local _16n = include('lib/16n') 

g = grid.connect()

local DIV_VALUES = {4, 2, 1, 0.5, 0.25, 0.125, 0.0625, 0.03125, 0.015625}
local SRC_OPTIONS = {"Clean Input", "Post Tape", "Post Filter", "Post Reverb", "Track 1", "Track 2", "Track 3", "Track 4"}
local MAX_BUFFER_SEC = 120.0 

state = Globals.new()

local function update_str(id)
    if params:lookup_param(id) then
        state.str_cache[id] = params:string(id)
    end
end

local function set_p(id, val)
    local eng_cmd = id
    if id == "bus_thresh" then eng_cmd = "comp_thresh"
    elseif id == "bus_ratio" then eng_cmd = "comp_ratio"
    elseif id == "bus_drive" then eng_cmd = "comp_drive" 
    end
    
    if engine[eng_cmd] then engine[eng_cmd](val) end
    state.str_cache[id] = params:string(id)
end

local function fmt_db(param) return string.format("%.1fdB", util.linlin(0, 1, -60, 12, param:get())) end
local function fmt_percent(param) return string.format("%.0f%%", param:get() * 100) end
local function fmt_hz(param) return string.format("%.1fHz", param:get()) end
local function fmt_sec(param) return string.format("%.2fs", param:get()) end
local function fmt_ratio(param) return string.format("%.1f:1", param:get()) end
local function fmt_raw_db(param) return string.format("%.1fdB", param:get()) end 

-- 16n Logic Helpers
local fader_map = {
    [1] = "l1_vol", [2] = "l2_vol", [3] = "l3_vol", [4] = "l4_vol",
    [5] = "l1_filter", [6] = "l2_filter", [7] = "l3_filter", [8] = "l4_filter",
    [9] = "filter_mix", [10] = "noise_amp",
    [11] = "rm_mix", [12] = "rm_freq",
    [13] = "tape_time", [14] = "tape_fb", [15] = "tape_mix",
    [16] = "reverb_mix"
}

local fader_names = {
    [1] = "TRK 1 VOL", [2] = "TRK 2 VOL", [3] = "TRK 3 VOL", [4] = "TRK 4 VOL",
    [5] = "TRK 1 FLT", [6] = "TRK 2 FLT", [7] = "TRK 3 FLT", [8] = "TRK 4 FLT",
    [9] = "FILTER MIX", [10] = "NOISE LVL",
    [11] = "RM MIX", [12] = "RM FREQ",
    [13] = "TAPE TIME", [14] = "TAPE FB", [15] = "TAPE MIX",
    [16] = "REVERB MIX"
}

local function normalize_16n(midi_val)
    if midi_val < 1 then return 0.0 end
    if midi_val > 126 then return 1.0 end
    if midi_val <= 80 then return util.linlin(1, 80, 0.0, 0.5, midi_val)
    else return util.linlin(80, 126, 0.5, 1.0, midi_val) end
end

local function apply_glue(val, id)
    if id >= 5 and id <= 8 then
        if math.abs(val - 0.5) < 0.03 then return 0.5 end
    end
    if id >= 1 and id <= 4 then
        if math.abs(val - 0.833) < 0.03 then return 0.833 end
    end
    return val
end

local function handle_16n(msg)
    local id = _16n.cc_2_slider_id(msg.cc)
    if not id then return end
    
    local p_name = fader_map[id]
    local display_name = fader_names[id]
    
    -- [v1.6] AUX LAYER LOGIC
    if state.grid_track_held and id <= 4 then
        p_name = "l"..id.."_aux"
        display_name = "TRK "..id.." AUX"
    elseif not fader_map[id] then
        return
    end
    
    local p_obj = params:lookup_param(p_name)
    if not p_obj then return end
    
    local norm_val = normalize_16n(msg.val)
    norm_val = apply_glue(norm_val, id)
    state.hw_positions[id] = norm_val
    
    local real_val = p_obj.controlspec:map(norm_val)
    local current_real = params:get(p_name)
    local current_norm = p_obj.controlspec:unmap(current_real)
    
    if not state.fader_latched[id] then
        local diff = norm_val - current_norm
        if math.abs(diff) < 0.05 then
            state.fader_latched[id] = true
        else
            state.popup.name = display_name or p_obj.name
            -- [v1.5.1] Corrected Arrows: Fader < Param = UP (>>), Fader > Param = DOWN (<<)
            local dir = (diff < 0) and " ( >> )" or " ( << )"
            
            local ghost_txt = string.format("%.2f", real_val)
            if p_name:find("vol") or p_name:find("amp") or p_name:find("drive") or p_name:find("rec_lvl") then ghost_txt = string.format("%.1fdB", util.linlin(0,1,-60,12,norm_val)) end
            if p_name:find("freq") then ghost_txt = string.format("%.0fHz", real_val) end
            if p_name:find("mix") or p_name:find("fb") or p_name:find("aux") then ghost_txt = string.format("%.0f%%", real_val*100) end
            
            state.popup.value = ghost_txt .. " -> " .. p_obj:string() .. dir
            state.popup.active = true
            state.popup.deadline = util.time() + 1.5
            return 
        end
    end
    
    if state.fader_latched[id] then
        params:set(p_name, real_val)
        if id <= 8 or (state.grid_track_held and id <= 4) then 
            local trk = (id > 4) and (id - 4) or id
            Loopers.refresh(trk, state)
        end
        state.popup.name = display_name or p_obj.name
        state.popup.value = p_obj:string()
        state.popup.active = true
        state.popup.deadline = util.time() + 1.5
    end
end

function update_ping_pattern()
  local k = params:get("ping_hits"); local n = params:get("ping_steps")
  state.ping_pattern = {}; if n > 0 then local slope = k / n; for i=0, n-1 do local is_hit = (math.floor(i * slope) ~= math.floor((i+1) * slope)); table.insert(state.ping_pattern, is_hit) end else state.ping_pattern = {false} end
  state.ping_step_counter = 0; update_str("ping_steps"); update_str("ping_hits")
end

function load_scale(idx)
  if not Scales or not Scales.list or not Scales.list[idx] then return end
  local s = Scales.list[idx]; state.loaded_scale_name = s.name
  local root = params:get("root_note") or 1; local ratio = 2 ^ ((root - 1) / 12)
  for i=1, 16 do local base = s.data[i]; if base then params:set("freq_"..i, util.clamp(base * ratio, 20, 18000)) end end
end

function get_target_freqs(scale_idx, root_note)
  if not Scales or not Scales.list or not Scales.list[scale_idx] then return nil end
  local s = Scales.list[scale_idx]; local ratio = 2 ^ ((root_note - 1) / 12); local freqs = {}
  for i=1, 16 do local base = s.data[i]; if base then table.insert(freqs, util.clamp(base * ratio, 20, 18000)) end end
  return freqs
end

function update_visual_slew()
   if state.morph_main_active then for i=1, 16 do state.visual_gain[i] = state.bands_gain[i] end; return end
   local slew_time = params:get("fader_slew"); if slew_time < 0.05 then for i=1, 16 do state.visual_gain[i] = state.bands_gain[i] end; return end
   local factor = 0.04 / slew_time; if factor > 0.8 then factor = 0.8 end; if factor < 0.005 then factor = 0.005 end
   for i=1, 16 do local target = state.bands_gain[i]; local current = state.visual_gain[i]; if math.abs(target - current) > 0.01 then state.visual_gain[i] = current + ((target - current) * factor) else state.visual_gain[i] = target end end
end

function update_morph_main()
  if state.morph_main_active and state.morph_main_slot then
     local slot = state.morph_main_slot; local target = state.main_presets_data[slot]
     if not target or not target.gains then state.morph_main_active = false; return end
     local morph_time = params:get("preset_morph_main"); if state.morph_fast_mode then morph_time = 0.1 end
     if morph_time < 0.05 then
        for i=1, 16 do params:set("gain_"..i, target.gains[i] or -60) end
        if target.q then params:set("global_q", target.q) end
        if target.feedback then params:set("feedback", target.feedback) end
        if target.scale_idx then params:set("scale_idx", target.scale_idx); params:set("root_note", target.root_note or 1); load_scale(target.scale_idx) end
        state.morph_main_active = false
     else
        local now = util.time(); local elapsed = now - state.morph_main_start_time; local progress = elapsed / morph_time
        if progress >= 1.0 then
           for i=1, 16 do params:set("gain_"..i, target.gains[i] or -60) end
           if target.q then params:set("global_q", target.q) end
           if target.feedback then params:set("feedback", target.feedback) end
           if target.scale_idx then params:set("scale_idx", target.scale_idx); params:set("root_note", target.root_note or 1); load_scale(target.scale_idx) end
           state.morph_main_active = false
        else
           for i=1, 16 do local start_val = state.morph_main_src[i] or params:get("gain_"..i) or -60; local end_val = target.gains[i] or -60; params:set("gain_"..i, start_val + ((end_val - start_val) * progress)) end
           if target.q and state.morph_main_src_q then params:set("global_q", state.morph_main_src_q + ((target.q - state.morph_main_src_q) * progress)) end
           if target.feedback and state.morph_main_src_fb then params:set("feedback", state.morph_main_src_fb + ((target.feedback - state.morph_main_src_fb) * progress)) end
           if target.scale_idx and state.morph_main_src_freqs then
              local target_freqs = get_target_freqs(target.scale_idx, target.root_note or 1)
              if target_freqs then for i=1, 16 do local start_f = state.morph_main_src_freqs[i] or params:get("freq_"..i); local end_f = target_freqs[i]; params:set("freq_"..i, start_f + ((end_f - start_f) * progress)) end end
           end
        end
     end
  end
end

function update_morph_tape()
  if state.morph_tape_active and state.morph_tape_slot then
     local slot = state.morph_tape_slot; local target = state.tape_presets_data[slot]
     if not target or not target.tracks then state.morph_tape_active = false; return end
     local morph_time = params:get("preset_morph_tape"); if state.morph_fast_mode then morph_time = 0.1 end
     local now = util.time(); local elapsed = now - state.morph_tape_start_time; local progress = elapsed / morph_time
     if morph_time < 0.05 or progress >= 1.0 then
        for i=1, 4 do
           local t_dest = target.tracks[i]; local skip = false
           if t_dest and t_dest.state == 1 and state.tracks[i].rec_len and state.tracks[i].rec_len > 0.1 then skip = true end
           if t_dest and not skip then
              state.tracks[i].speed = t_dest.speed; state.tracks[i].vol = t_dest.vol
              state.tracks[i].loop_start = t_dest.loop_start; state.tracks[i].loop_end = t_dest.loop_end
              state.tracks[i].overdub = t_dest.overdub
              if t_dest.state then state.tracks[i].state = t_dest.state end
              if t_dest.l_low then state.tracks[i].l_low = t_dest.l_low end
              if t_dest.l_high then state.tracks[i].l_high = t_dest.l_high end
              if t_dest.l_filter then state.tracks[i].l_filter = t_dest.l_filter end
              if t_dest.l_pan then state.tracks[i].l_pan = t_dest.l_pan end
              if t_dest.l_width then state.tracks[i].l_width = t_dest.l_width end
              Loopers.refresh(i, state)
           end
        end
        state.morph_tape_active = false
     else
        for i=1, 4 do
           local t_dest = target.tracks[i]; local t_src = state.morph_tape_src[i]; local skip = false
           if t_dest and t_dest.state == 1 and state.tracks[i].rec_len and state.tracks[i].rec_len > 0.1 then skip = true end
           if t_dest and t_src and not skip then
              local s_speed = t_src.speed or 1.0; local d_speed = t_dest.speed or 1.0; state.tracks[i].speed = s_speed + ((d_speed - s_speed) * progress)
              local s_vol = t_src.vol or 0.9; local d_vol = t_dest.vol or 0.9; state.tracks[i].vol = s_vol + ((d_vol - s_vol) * progress)
              local s_start = t_src.loop_start or 0.0; local d_start = t_dest.loop_start or 0.0; state.tracks[i].loop_start = s_start + ((d_start - s_start) * progress)
              local s_end = t_src.loop_end or 1.0; local d_end = t_dest.loop_end or 1.0; state.tracks[i].loop_end = s_end + ((d_end - s_end) * progress)
              local s_low = t_src.l_low or 0; local d_low = t_dest.l_low or 0; state.tracks[i].l_low = s_low + ((d_low - s_low) * progress)
              local s_high = t_src.l_high or 0; local d_high = t_dest.l_high or 0; state.tracks[i].l_high = s_high + ((d_high - s_high) * progress)
              local s_filt = t_src.l_filter or 0.5; local d_filt = t_dest.l_filter or 0.5; state.tracks[i].l_filter = s_filt + ((d_filt - s_filt) * progress)
              local s_pan = t_src.l_pan or 0; local d_pan = t_dest.l_pan or 0; state.tracks[i].l_pan = s_pan + ((d_pan - s_pan) * progress)
              Loopers.refresh(i, state)
           end
        end
     end
  end
end

function osc.event(path, args, from)
  if not state.loaded then return end
  if path == "/ping_pulse" then table.insert(state.ping_pulses, {t0 = util.time(), amp = args[1], jitter = params:get("ping_jitter")})
  elseif path == "/buffer_info" then
    local idx = math.floor(args[1]); local dur = args[2]
    state.tracks[idx].rec_len = dur; Loopers.refresh(idx, state)
    print("Reel " .. idx .. " duration updated: " .. dur)
  
  -- [v1.73] REC STOP REPORTING (RETAINED FROM v1.73 but handled via Pointers now mostly)
  elseif path == "/rec_stop" then
    -- Legacy/Redundant fallback if SC trigger works
    local idx = math.floor(args[1])
    local dur = args[2]
    -- [v1.76 Protection]: If coming from Trigger, accept it IF protection flag is false
    if not state.tracks[idx].ignore_neg_pointer then
        -- Careful! Trigger might send raw duration. Parameter is king for seamless saving.
        -- We print but do NOT overwrite rec_len if manual mode active.
        -- Ideally, the Negative Pointer logic handles the state during recording.
    end

  elseif path == "/avant_lab_v/visuals" then
    if args and #args >= 23 then
        state.amp_l = args[1]; state.amp_r = args[2]; state.comp_gr = args[3]
        local h = state.heads.gonio
        state.gonio_history[h].s = util.clamp((args[1]+args[2])*0.5 * (params:get("scope_zoom") or 4) * 10, 0, 22)
        state.gonio_history[h].w = util.clamp(math.abs(args[1]-args[2])*0.5 * (params:get("scope_zoom") or 4) * 20, 0, 20)
        state.heads.gonio = (h % state.GONIO_LEN) + 1
        
        -- [v1.76] NEGATIVE POINTER LOGIC (Real-time Recording Feedback)
        for i=1, 4 do 
            local raw_val = args[3+i]
            if raw_val < 0 then
               -- Recording (First Pass):
               -- Update visual rec_len so Tape Library shows recording growing
               local t_len = math.abs(raw_val)
               state.tracks[i].rec_len = t_len
               state.tracks[i].is_dirty = true
               state.tracks[i].play_pos = 1.0 
               state.tracks[i].recording_active = true
            else
               -- Playback (Normal):
               state.tracks[i].play_pos = util.clamp(raw_val, 0, 1)
               
               if state.tracks[i].recording_active then
                  -- [CRITICAL FIX v1.76]
                  -- When recording ends (Pointer flips Neg -> Pos), we rely on the Grid 
                  -- (via parameter 'l..i.._length') to determine the definitive save length
                  -- which includes the safety +0.15s buffer.
                  -- We fetch that definitive param value into our save state variable.
                  local final_seamless_len = params:get("l"..i.."_length")
                  state.tracks[i].rec_len = final_seamless_len
                  
                  state.tracks[i].recording_active = false
               end
            end
        end
        
        local smooth_factor = 0.25
        for i=1, 16 do local target = args[7+i]; local current = state.band_levels[i] or 0; state.band_levels[i] = current + ((target - current) * smooth_factor) end
    end
  end
end

function enc(n, d) Controls.enc(n, d, state) end
function key(n, z) Controls.key(n, z, state) end
g.key = function(x, y, z) Grid.key(x, y, z, state, engine) end

function ping_tick()
  while true do
    local mode = params:get("ping_mode")
    if mode == 2 and (params:get("ping_active") == 2) and params:get("ping_steps") > 0 then
        if state.ping_pattern and #state.ping_pattern > 0 then
            state.ping_step_counter = (state.ping_step_counter % params:get("ping_steps")) + 1
            if state.ping_pattern[state.ping_step_counter] then engine.ping_sequence(1) end
        end
    end
    clock.sync(DIV_VALUES[params:get("ping_div") or 3])
  end
end

function rec_play_tick_main(slot)
    while true do
      local r = state.main_rec_slots[slot]
      if r.state ~= 2 and r.state ~= 4 then clock.sleep(0.1) 
      else
         local event = r.data[r.step]
         if event then
           local rate = 2 ^ params:get("seq_rate_main"); if rate == 0 then rate = 0.001 end 
           local next_time = 0
           if r.step < #r.data then next_time = (r.data[r.step+1].dt - event.dt) / rate else next_time = (r.duration - event.dt) / rate end
           if next_time < 0 then next_time = 0 end
           if event.x and event.y and event.z then Grid.key(event.x, event.y, event.z, state, engine, 1) end
           if next_time > 0 then clock.sleep(next_time) end
           r.step = r.step + 1; if r.step > #r.data then r.step = 1 end
         else clock.sleep(0.1) end
      end
    end
end

function rec_play_tick_tape(slot)
    while true do
      local r = state.tape_rec_slots[slot]
      if r.state ~= 2 and r.state ~= 4 then clock.sleep(0.1) 
      else
         local event = r.data[r.step]
         if event then
           local rate = 2 ^ params:get("seq_rate_tape"); if rate == 0 then rate = 0.001 end 
           local next_time = 0
           if r.step < #r.data then next_time = (r.data[r.step+1].dt - event.dt) / rate else next_time = (r.duration - event.dt) / rate end
           if next_time < 0 then next_time = 0 end
           if event.x and event.y and event.z then Grid.key(event.x, event.y, event.z, state, engine, 7, event.tid) end
           if next_time > 0 then clock.sleep(next_time) end
           r.step = r.step + 1; if r.step > #r.data then r.step = 1 end
         else clock.sleep(0.1) end
      end
    end
end

function init()
  audio.level_adc_cut(1)
  
  if util.file_exists(_path.data .. "Avant_lab_V") == false then util.make_dir(_path.data .. "Avant_lab_V") end
  if util.file_exists(_path.audio .. "Avant_lab_V") == false then util.make_dir(_path.audio .. "Avant_lab_V") end
  if util.file_exists(_path.audio .. "Avant_lab_V/snapshots") == false then util.make_dir(_path.audio .. "Avant_lab_V/snapshots") end
  
  for i=1, 4 do
     if not state.main_presets_data[i] then state.main_presets_data[i] = {} end
     if not state.tape_presets_data[i] then state.tape_presets_data[i] = {} end
  end
  
  params:add_separator("AVANT_LAB_V")
  
  params:add_group("GLOBAL", 10) 
  params:add{type = "control", id = "feedback", name = "Feedback", controlspec = controlspec.new(0, 1.2, 'lin', 0.001, 0.0), formatter=fmt_percent, action = function(x) set_p("feedback", x) end}
  params:add{type = "control", id = "global_q", name = "Global Q", controlspec = controlspec.new(0.5, 80.0, 'exp', 0, 12.8), formatter=function(p) return string.format("%.1f", p:get()) end, action = function(x) set_p("global_q", x) end}
  params:add{type = "control", id = "system_dirt", name = "System Dirt", controlspec = controlspec.new(0, 1, 'lin', 0.001, 0.03), formatter=fmt_percent, action = function(x) set_p("system_dirt", x) end}
  
  params:add{type = "control", id = "main_mon", name = "Main Monitor", controlspec = controlspec.new(0, 1, 'lin', 0.001, 0.833), formatter = fmt_db, action = function(x) set_p("main_mon", x) end}
  
  params:add{type = "option", id = "main_source", name = "Monitor Source", options = {"Clean In", "Post Tape", "Post Filter", "Post Reverb"}, default = 4, action = function(x) engine.main_source(x-1); update_str("main_source") end}
  
  params:add{type = "control", id = "fader_slew", name = "Fader Slew", controlspec = controlspec.new(0.01, 10.0, 'exp', 0.01, 0.05, "s"), formatter=fmt_sec, action = function(x) set_p("fader_slew", x) end}
  params:add{type = "control", id = "scope_zoom", name = "Scope Zoom", controlspec = controlspec.new(1, 10, 'lin', 0.1, 4), formatter=function(p) return string.format("x%.1f", p:get()) end}
  params:add{type = "option", id = "gonio_source", name = "Scope Source", options = {"Pre-Master", "Post-Master"}, default = 2, action = function(x) engine.gonio_source(x-1) end}
  params:add{type = "option", id = "load_behavior_reels", name = "Load: Reels", options = {"Stop", "Play"}, default = 1}
  params:add{type = "option", id = "load_behavior_seqs", name = "Load: Seqs", options = {"Stop", "Play"}, default = 2}
  
  params:add_group("INPUT", 3)
  params:add{type = "control", id = "input_amp", name = "Input Level", controlspec = controlspec.new(0, 2, 'lin', 0.001, 1.0), formatter=fmt_percent, action = function(x) set_p("input_amp", x) end}
  params:add{type = "control", id = "noise_amp", name = "Noise Level", controlspec = controlspec.new(0, 2, 'lin', 0.001, 0.0), formatter=fmt_percent, action = function(x) set_p("noise_amp", x) end}
  params:add{type = "option", id = "noise_type", name = "Noise Type", options = {"Pink", "White", "Crackle", "DigiRain", "Lorenz", "Grit"}, action = function(x) engine.noise_type(x-1) end}

  params:add_group("TAPE VERB", 3)
  params:add{type = "control", id = "reverb_mix", name = "Reverb Mix", controlspec = controlspec.new(0, 1, 'lin', 0.001, 0.20), formatter=fmt_percent, action = function(x) set_p("reverb_mix", x) end}
  params:add{type = "control", id = "reverb_time", name = "Reverb Decay", controlspec = controlspec.new(0.1, 60.0, 'exp', 0.1, 4.2, "s"), formatter=fmt_sec, action = function(x) set_p("reverb_time", x) end}
  params:add{type = "control", id = "reverb_damp", name = "Reverb Damp", controlspec = controlspec.new(100, 20000, 'exp', 10, 4600, "Hz"), formatter=fmt_hz, action = function(x) set_p("reverb_damp", x) end}
  
  params:add_group("MASTER PROCESS", 6)
  params:add{type = "control", id = "bus_thresh", name = "Comp Thresh", controlspec = controlspec.new(-60.0, 0.0, 'lin', 0.1, -12.0, "dB"), formatter=fmt_raw_db, action = function(x) set_p("bus_thresh", x) end}
  params:add{type = "control", id = "bus_ratio", name = "Comp Ratio", controlspec = controlspec.new(1.0, 20.0, 'lin', 0.1, 2.2), formatter=fmt_ratio, action = function(x) set_p("bus_ratio", x) end}
  params:add{type = "control", id = "bus_drive", name = "Comp Drive", controlspec = controlspec.new(0.0, 24.0, 'lin', 0.1, 1.0, "dB"), formatter=fmt_raw_db, action = function(x) set_p("bus_drive", x) end}
  params:add{type = "option", id = "bass_focus", name = "Bass Focus", options = {"OFF", "50Hz", "100Hz", "200Hz"}, default = 1, action = function(x) engine.bass_focus(x-1); update_str("bass_focus") end}
  params:add{type = "control", id = "limiter_ceil", name = "Limiter Ceil", controlspec = controlspec.new(-6.0, 0.0, 'lin', 0.1, -0.1, "dB"), formatter=fmt_raw_db, action = function(x) set_p("limiter_ceil", x) end}
  params:add{type = "control", id = "balance", name = "Master Balance", controlspec = controlspec.new(-1.0, 1.0, 'lin', 0.01, 0.0), formatter=function(p) return string.format("%.2f", p:get()) end, action = function(x) set_p("balance", x) end}
  
  params:add_group("PING GENERATOR", 10)
  params:add{type = "option", id = "ping_active", name = "Generator", options = {"Off", "On"}, default = 1, action = function(x) engine.ping_active(x-1) end}
  params:add{type = "option", id = "ping_mode", name = "Ping Mode", options = {"Internal (Free)", "Euclidean (Sync)"}, default = 1, action = function(x) engine.ping_mode(x-1) end}
  params:add{type = "control", id = "ping_amp", name = "Ping Level", controlspec = controlspec.new(0, 2.0, 'lin', 0.01, 1.0), formatter=fmt_percent, action = function(x) set_p("ping_amp", x) end}
  params:add{type = "control", id = "ping_timbre", name = "Mix (Low/High)", controlspec = controlspec.new(0, 1.0, 'lin', 0.01, 0.3), formatter=fmt_percent, action = function(x) set_p("ping_timbre", x) end}
  params:add{type = "control", id = "ping_jitter", name = "Jitter (Rhythm)", controlspec = controlspec.new(0, 1.0, 'lin', 0.01, 0.0), formatter=fmt_percent, action = function(x) set_p("ping_jitter", x) end}
  
  params:add{type = "control", id = "ping_rate", name = "Int Rate (Hz)", controlspec = controlspec.new(0.125, 20.0, 'exp', 0.01, 1.0, "Hz"), formatter=fmt_hz, action = function(x) set_p("ping_rate", x) end}
    
  params:add{type = "option", id = "ping_div", name = "Euc Division", options = {"1/1", "1/2", "1/4", "1/8", "1/16", "1/32", "1/64", "1/128", "1/256"}, default = 3, action=function() update_str("ping_div") end}
  params:add{type = "number", id = "ping_steps", name = "Euc Steps", min = 1, max = 32, default = 8, action = function(x) update_ping_pattern() end}
  params:add{type = "number", id = "ping_hits", name = "Euc Hits", min = 0, max = 32, default = 5, action = function(x) update_ping_pattern() end}
  params:add{type = "trigger", id = "ping_manual", name = "Manual Trigger", action = function() engine.ping_manual(1) end}

  params:add_group("RING MODULATOR", 5)
  params:add{type = "control", id = "rm_drive", name = "RM Drive", controlspec = controlspec.new(0, 24.0, 'lin', 0.1, 6.0, "dB"), formatter=fmt_raw_db, action = function(x) set_p("rm_drive", x) end}
  params:add{type = "control", id = "rm_freq", name = "Carrier Freq", controlspec = controlspec.new(0.1, 4000.0, 'exp', 0.1, 5.6, "Hz"), formatter=fmt_hz, action = function(x) set_p("rm_freq", x) end}
  params:add{type = "option", id = "rm_wave", name = "Carrier Wave", options = {"Sine", "Square"}, default = 1, action = function(x) engine.rm_wave(x-1) end}
  params:add{type = "control", id = "rm_mix", name = "Dry/Wet Mix", controlspec = controlspec.new(0, 1.0, 'lin', 0.01, 0.02), formatter=fmt_percent, action = function(x) set_p("rm_mix", x) end}
  params:add{type = "control", id = "rm_instability", name = "Instability", controlspec = controlspec.new(0, 1.0, 'lin', 0.01, 0.08), formatter=fmt_percent, action = function(x) set_p("rm_instability", x) end}

  params:add_group("FILTER BANK", 9)
  params:add{type = "control", id = "filter_mix", name = "Filter Mix", controlspec = controlspec.new(0, 1.0, 'lin', 0.01, 0.8), formatter=fmt_percent, action = function(x) set_p("filter_mix", x) end}
  params:add{type = "control", id = "pre_hpf", name = "Low Cut (HPF)", controlspec = controlspec.new(20, 999, 'exp', 0, 32, "Hz"), formatter=fmt_hz, action = function(x) set_p("pre_hpf", x) end}
  params:add{type = "control", id = "pre_lpf", name = "High Cut (LPF)", controlspec = controlspec.new(150, 20000, 'exp', 0, 16890, "Hz"), formatter=fmt_hz, action = function(x) set_p("pre_lpf", x) end}
  params:add{type = "control", id = "stabilizer", name = "Stabilizer", controlspec = controlspec.new(0, 1, 'lin', 0.01, 0.6), formatter=fmt_percent, action = function(x) set_p("stabilizer", x) end}
  params:add{type = "control", id = "crossfeed", name = "Cross Feed", controlspec = controlspec.new(0, 1, 'lin', 0.01, 0.25), formatter=fmt_percent, action = function(x) set_p("crossfeed", x) end}
  params:add{type = "control", id = "spread", name = "Spread (Odd/Even)", controlspec = controlspec.new(0, 1, 'lin', 0.01, 0.50), formatter=fmt_percent, action = function(x) set_p("spread", x) end}
  params:add{type = "control", id = "swirl_depth", name = "Swirl Depth", controlspec = controlspec.new(0, 1, 'lin', 0.01, 0.1), formatter=fmt_percent, action = function(x) set_p("swirl_depth", x) end}
  params:add{type = "control", id = "swirl_rate", name = "Swirl Rate", controlspec = controlspec.new(0.01, 15.0, 'exp', 0.01, 0.03, "Hz"), formatter=function(p) return string.format("%.2fHz", p:get()) end, action = function(x) set_p("swirl_rate", x) end}
  params:add{type = "control", id = "filter_drift", name = "Filter Drift", controlspec = controlspec.new(0, 1, 'lin', 0.001, 0.07), formatter=fmt_percent, action = function(x) set_p("filter_drift", x) end}

  params:add_group("LFO MODULATION", 3)
  params:add{type = "control", id = "lfo_depth", name = "Global Intensity", controlspec = controlspec.new(0, 1.0, 'lin', 0.01, 0.03), formatter=fmt_percent, action = function(x) set_p("lfo_depth", x) end}
  params:add{type = "control", id = "lfo_rate", name = "Global Rate", controlspec = controlspec.new(0.01, 2.0, 'exp', 0.01, 0.08, "Hz"), formatter=fmt_hz, action = function(x) set_p("lfo_rate", x) end}
  params:add{type = "control", id = "lfo_min_db", name = "LFO Target DB", controlspec = controlspec.new(-90, 0, 'lin', 1, -60, "dB"), formatter=fmt_raw_db, action = function(x) set_p("lfo_min_db", x) end}

  params:add_group("MAIN TAPE ECHO", 7)
  params:add{type = "control", id = "tape_mix", name = "Tape Mix", controlspec = controlspec.new(0, 1.0, 'lin', 0.01, 0.25), formatter=fmt_percent, action = function(x) set_p("tape_mix", x) end}
  params:add{type = "control", id = "tape_time", name = "Time", controlspec = controlspec.new(0, 2.0, 'lin', 0.01, 0.34, "s"), formatter=fmt_sec, action = function(x) set_p("tape_time", x) end}
  params:add{type = "control", id = "tape_fb", name = "Feedback", controlspec = controlspec.new(0, 1.0, 'lin', 0.01, 0.4), formatter=fmt_percent, action = function(x) set_p("tape_fb", x) end}
  params:add{type = "control", id = "tape_sat", name = "Saturation", controlspec = controlspec.new(0, 1, 'lin', 0.01, 0.3), formatter=fmt_percent, action = function(x) set_p("tape_sat", x) end}
  params:add{type = "control", id = "tape_wow", name = "Wow (Slow)", controlspec = controlspec.new(0, 1, 'lin', 0.01, 0.11), formatter=fmt_percent, action = function(x) set_p("tape_wow", x) end}
  params:add{type = "control", id = "tape_flutter", name = "Flutter (Fast)", controlspec = controlspec.new(0, 1, 'lin', 0.01, 0.08), formatter=fmt_percent, action = function(x) set_p("tape_flutter", x) end}
  params:add{type = "control", id = "tape_erosion", name = "Erosion", controlspec = controlspec.new(0, 1, 'lin', 0.01, 0.14), formatter=fmt_percent, action = function(x) set_p("tape_erosion", x) end}
  
  params:add_group("TIME ENGINES", 4)
  params:add{type = "control", id = "seq_rate_main", name = "Grid Seq Rate (Main)", controlspec = controlspec.new(-2.0, 2.0, 'lin', 0.01, 0.0), action=function(x) update_str("seq_rate_main") end}
  params:add{type = "control", id = "preset_morph_main", name = "Grid Morph (Main)", controlspec = controlspec.new(0.01, 60.0, 'exp', 0.01, 2.8, "s"), formatter=fmt_sec, action=function(x) update_str("preset_morph_main") end}
  params:add{type = "control", id = "seq_rate_tape", name = "Grid Seq Rate (Tape)", controlspec = controlspec.new(-2.0, 2.0, 'lin', 0.01, 0.0), action=function(x) update_str("seq_rate_tape") end}
  params:add{type = "control", id = "preset_morph_tape", name = "Grid Morph (Tape)", controlspec = controlspec.new(0.01, 60.0, 'exp', 0.01, 2.0, "s"), formatter=fmt_sec, action=function(x) update_str("preset_morph_tape") end}

  for i=1, 4 do
    params:add_group("TAPE TRACK " .. i, 15) 
    -- [v1.6] Speed step 0.002
    params:add{type = "control", id = "l"..i.."_speed", name = "Speed", controlspec = controlspec.new(-2.0, 2.0, 'lin', 0.002, 1.0), formatter=function(p) return string.format("x%.2f", p:get()) end, action = function(x) state.tracks[i].speed = x; Loopers.refresh(i, state) end}
    params:add{type = "control", id = "l"..i.."_vol", name = "Volume", controlspec = controlspec.new(0, 1.0, 'lin', 0.001, 0.833), formatter=fmt_db, action = function(x) state.tracks[i].vol = x; Loopers.refresh(i, state) end}
    -- [v1.72] Dub max 1.11
    params:add{type = "control", id = "l"..i.."_dub", name = "Overdub", controlspec = controlspec.new(0, 1.11, 'lin', 0.001, 1.0), formatter=fmt_percent, action = function(x) state.tracks[i].overdub = x; Loopers.refresh(i, state) end}
    
    -- [v1.74] SYNC: Update rec_len immediately on manual change. 
    -- Added protection against OSC lag overwriting manual changes.
    params:add{type = "control", id = "l"..i.."_length", name = "Length", controlspec = controlspec.new(0.001, 120.0, 'exp', 0.01, 120.0, "s"), action = function(x) 
        state.tracks[i].rec_len = x
        state.tracks[i].ignore_neg_pointer = true 
        clock.run(function() clock.sleep(0.2); state.tracks[i].ignore_neg_pointer = false end)
        Loopers.refresh(i, state) 
    end}

    params:add{type = "control", id = "l"..i.."_deg", name = "Degrade", controlspec = controlspec.new(0, 1.0, 'lin', 0.001, 0.0), formatter=fmt_percent, action = function(x) state.tracks[i].wow_macro = x; Loopers.refresh(i, state) end}
    params:add{type = "control", id = "l"..i.."_start", name = "Start Point", controlspec = controlspec.new(0, 1.0, 'lin', 0.001, 0.0), formatter=fmt_percent, action = function(x) state.tracks[i].loop_start = x; Loopers.refresh(i, state) end}
    params:add{type = "control", id = "l"..i.."_end", name = "End Point", controlspec = controlspec.new(0, 1.0, 'lin', 0.001, 1.0), formatter=fmt_percent, action = function(x) state.tracks[i].loop_end = x; Loopers.refresh(i, state) end}
    params:add{type = "option", id = "l"..i.."_src", name = "Input Source", options = SRC_OPTIONS, default = 4, action = function(x) state.tracks[i].src_sel = x - 1; Loopers.refresh(i, state) end}
    
    -- [v1.6] Rec Level Default -3dB
    params:add{
        type = "control", 
        id = "l"..i.."_rec_lvl", 
        name = "Input Level", 
        controlspec = controlspec.new(-60, 12, 'lin', 0.1, -3.0, "dB"), 
        formatter = fmt_raw_db,
        action = function(x) state.tracks[i].rec_level = x; Loopers.refresh(i, state) end
    }
    
    params:add{type = "control", id = "l"..i.."_aux", name = "Aux Send", controlspec = controlspec.new(0, 1.0, 'lin', 0.001, 0.0), formatter=fmt_percent, action = function(x) state.tracks[i].aux_send = x; Loopers.refresh(i, state) end}
    
    params:add{type = "control", id = "l"..i.."_low", name = "Mixer Low", controlspec = controlspec.new(-18, 18, 'lin', 0.1, 0.2, "dB"), formatter=fmt_raw_db, action = function(x) state.tracks[i].l_low = x; Loopers.refresh(i, state) end}
    params:add{type = "control", id = "l"..i.."_high", name = "Mixer High", controlspec = controlspec.new(-18, 18, 'lin', 0.1, 0.3, "dB"), formatter=fmt_raw_db, action = function(x) state.tracks[i].l_high = x; Loopers.refresh(i, state) end}
    params:add{type = "control", id = "l"..i.."_filter", name = "Mixer Filter", controlspec = controlspec.new(0, 1, 'lin', 0.01, 0.5), formatter=fmt_percent, action = function(x) state.tracks[i].l_filter = x; Loopers.refresh(i, state) end}
    params:add{type = "control", id = "l"..i.."_pan", name = "Mixer Pan", controlspec = controlspec.new(-1, 1, 'lin', 0.01, 0), formatter=function(p) return string.format("%.2f", p:get()) end, action = function(x) state.tracks[i].l_pan = x; Loopers.refresh(i, state) end}
    params:add{type = "control", id = "l"..i.."_width", name = "Mixer Width", controlspec = controlspec.new(0, 2, 'lin', 0.01, 1), formatter=fmt_percent, action = function(x) state.tracks[i].l_width = x; Loopers.refresh(i, state) end}
  end

  params:add_group("BANDS SETUP", 34) 
  local scale_options = {"Default"}
  if Scales and Scales.names then scale_options = Scales.names end
  params:add{type = "option", id = "scale_idx", name = "Scale Type", options = scale_options, default = 1, action = function(x) load_scale(x); state.preview_scale_idx = x; update_str("scale_idx") end}
  params:add{type = "option", id = "root_note", name = "Scale Root", options = {"C","C#","D","D#","E","F","F#","G","G#","A","A#","B"}, default = 1, action = function(x) load_scale(params:get("scale_idx")); update_str("root_note") end}
  
  for i=1, 16 do
    local default_freq = 100
    if Scales and Scales.list and Scales.list[1] and Scales.list[1].data then default_freq = Scales.list[1].data[i] end
    params:add{type = "control", id = "gain_"..i, name = "Band "..i.." Gain", controlspec = controlspec.new(-60, 0, 'lin', 0.1, -60, "dB"), formatter=fmt_raw_db, action = function(x) engine.band_gain(i-1, x); state.bands_gain[i] = x end}
    params:add{type = "control", id = "freq_"..i, name = "Band "..i.." Freq", controlspec = controlspec.new(20, 18000, 'exp', 0, default_freq, "Hz"), formatter=fmt_hz, action = function(x) engine.band_freq(i-1, x) end}
  end
  
  params:add_group("TAPE LIBRARY", 5)
  params:add{type = "trigger", id = "save_all_tapes", name = "Save All Reels", action = function() 
     for i=1,4 do 
        local len = state.tracks[i].rec_len or 0
        if len > 0 then
            local name = _path.audio .. "Avant_lab_V/reel_" .. i .. "_" .. os.date("%y%m%d%H%M") .. ".wav"
            engine.buffer_write(i, name, len)
            state.tape_filenames[i] = name:match("^.+/(.+)$")
            state.tape_msg_timers[i] = util.time() + 2.0
            state.tracks[i].is_dirty = false 
            state.tracks[i].file_path = name
        end
     end
  end}
  params:add{type = "file", id = "load_reel_1", name = "Load Reel 1", path = _path.audio, action = function(f) Loopers.load_file(1, f, state) end}
  params:add{type = "file", id = "load_reel_2", name = "Load Reel 2", path = _path.audio, action = function(f) Loopers.load_file(2, f, state) end}
  params:add{type = "file", id = "load_reel_3", name = "Load Reel 3", path = _path.audio, action = function(f) Loopers.load_file(3, f, state) end}
  params:add{type = "file", id = "load_reel_4", name = "Load Reel 4", path = _path.audio, action = function(f) Loopers.load_file(4, f, state) end}
  
  Grid.init(state, g)
  
  local screen_timer = metro.init()
  screen_timer.time = 1/60
  screen_timer.event = function() redraw() end
  screen_timer:start()
  
  local grid_timer = metro.init()
  grid_timer.time = 1/30
  grid_timer.event = function() Grid.redraw(state) end
  grid_timer:start()
  
  local ping_timer = clock.run(ping_tick)
  
  local update_timer = metro.init()
  update_timer.time = 0.05
  update_timer.event = function() 
    update_morph_main() 
    update_morph_tape()
    update_visual_slew() 
  end
  update_timer:start()
  
  params.action_write = function(filename, name, number) Storage.save_data(state, number) end
  params.action_read = function(filename, silent, number) Storage.load_data(state, number) end
  
  update_ping_pattern()
  params:bang()
  
  -- [NEW] 16n Init
  clock.run(function()
     clock.sleep(2.0)
     _16n.init(handle_16n)
     print("16n initialized.")
  end)
  
  local visual_ids = {
     "feedback", "global_q", "system_dirt", "main_mon", "main_source", "fader_slew",
     "input_amp", "noise_amp", "noise_type", "reverb_mix", "reverb_time", "reverb_damp",
     "bus_thresh", "bus_ratio", "bus_drive", "bass_focus", "limiter_ceil", "balance",
     "ping_amp", "ping_timbre", "ping_jitter", "ping_rate", "ping_div", "ping_steps", "ping_hits",
     "rm_drive", "rm_freq", "rm_mix", "rm_instability",
     "filter_mix", "pre_hpf", "pre_lpf", "stabilizer", "crossfeed", "spread", "filter_drift",
     "swirl_depth", "swirl_rate",
     "lfo_depth", "lfo_rate", "lfo_min_db",
     "tape_mix", "tape_time", "tape_fb", "tape_sat", "tape_wow", "tape_flutter", "tape_erosion",
     "seq_rate_main", "preset_morph_main", "seq_rate_tape", "preset_morph_tape",
     "scale_idx", "root_note"
  }
  for _, id in ipairs(visual_ids) do
      update_str(id)
  end
  
  clock.run(function()
     local status, err = pcall(function()
        clock.sleep(0.5) 
        state.loaded = true
        print("Avant_lab_V: UI Loaded (v1.76).")
     end)
     if not status then print("Avant_lab_V: Init Error: " .. err) end
  end)
  
  for i=1,4 do
    clock.run(function() rec_play_tick_main(i) end)
    clock.run(function() rec_play_tick_tape(i) end)
  end
end

function redraw()
  if state.file_selector_active then return end
  if not state.loaded then return end
  screen.clear()
  Graphics.draw(state)
  screen.update()
end
