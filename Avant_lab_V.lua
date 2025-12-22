-- Avant_lab_V.lua | Version 107.2
-- FIX: Main Monitor Parameter formatted as dB in System Menu

engine.name = 'Avant_lab_V'

local Globals = include('lib/globals')
local Scales = include('lib/scales')
local Graphics = include('lib/graphics')
local Controls = include('lib/controls')
local Grid = include('lib/grid')
local Storage = include('lib/storage')
local Loopers = include('lib/loopers')

g = grid.connect()

local DIV_VALUES = {4, 2, 1, 0.5, 0.25, 0.125, 0.0625, 0.03125}
local SRC_OPTIONS = {"Clean Input", "Post Tape", "Post Filter", "Post Reverb", "Track 1", "Track 2", "Track 3", "Track 4"}
local MAX_BUFFER_SEC = 60.0 

state = Globals.new()

function init()
  audio.level_adc_cut(1)
  
  if util.file_exists(_path.data .. "Avant_lab_V") == false then 
      util.make_dir(_path.data .. "Avant_lab_V") 
  end
  if util.file_exists(_path.audio .. "Avant_lab_V") == false then 
      util.make_dir(_path.audio .. "Avant_lab_V") 
  end
  if util.file_exists(_path.audio .. "Avant_lab_V/snapshots") == false then 
      util.make_dir(_path.audio .. "Avant_lab_V/snapshots") 
  end
  
  params:add_separator("AVANT_LAB_V")
  
  -- 1. GLOBAL & MIX
  params:add_group("GLOBAL / MIX", 11) 
  params:add{type = "control", id = "feedback", name = "Feedback", controlspec = controlspec.new(0, 1.0, 'lin', 0.001, 0.0), action = function(x) engine.feedback(x) end}
  params:add{type = "control", id = "global_q", name = "Global Q", controlspec = controlspec.new(0.5, 80.0, 'exp', 0, 1.0), action = function(x) engine.global_q(x) end}
  params:add{type = "control", id = "reverb_mix", name = "Reverb Mix", controlspec = controlspec.new(0, 1, 'lin', 0.001, 1.0), action = function(x) engine.reverb_mix(x) end}
  params:add{type = "control", id = "system_dirt", name = "System Dirt", controlspec = controlspec.new(0, 1, 'lin', 0.001, 0.0), action = function(x) engine.system_dirt(x) end}
  
  -- [FIX] Main Monitor with dB Formatter for System Menu
  params:add{
    type = "control", 
    id = "main_mon", 
    name = "Main Monitor", 
    controlspec = controlspec.new(0, 1, 'lin', 0.001, 0.833), 
    formatter = function(param)
        local val = param:get()
        local db = util.linlin(0, 1, -60, 12, val)
        return string.format("%.1f dB", db)
    end,
    action = function(x) engine.main_mon(x) end
  }
  
  params:add{type = "control", id = "fader_slew", name = "Fader Slew", controlspec = controlspec.new(0.01, 10.0, 'exp', 0.01, 0.05, "s"), action = function(x) engine.fader_lag(x) end}
  params:add{type = "control", id = "scope_zoom", name = "Scope Zoom", controlspec = controlspec.new(1, 10, 'lin', 0.1, 4)}
  params:add{type = "option", id = "gonio_source", name = "Scope Source", options = {"Pre-Master", "Post-Master"}, default = 2, action = function(x) engine.gonio_source(x-1) end}
  params:add{type = "option", id = "rec_behavior", name = "Rec Behavior", options = {"Rec->Play", "Rec->Dub"}, default = 2}
  params:add{type = "option", id = "load_behavior_reels", name = "Load: Reels", options = {"Stop", "Play"}, default = 1}
  params:add{type = "option", id = "load_behavior_seqs", name = "Load: Seqs", options = {"Stop", "Play"}, default = 2}

  -- 2. TIME ENGINES
  params:add_group("TIME ENGINES", 4)
  params:add{type = "control", id = "seq_rate_main", name = "Main Seq Rate", controlspec = controlspec.new(-2.0, 2.0, 'lin', 0.01, 0.0)}
  params:add{type = "control", id = "preset_morph_main", name = "Main Morph", controlspec = controlspec.new(0.01, 60.0, 'exp', 0.01, 2.0, "s")}
  params:add{type = "control", id = "seq_rate_tape", name = "Tape Seq Rate", controlspec = controlspec.new(-2.0, 2.0, 'lin', 0.01, 0.0)}
  params:add{type = "control", id = "preset_morph_tape", name = "Tape Morph", controlspec = controlspec.new(0.01, 60.0, 'exp', 0.01, 2.0, "s")}

  -- 3. INPUT
  params:add_group("INPUT", 3)
  params:add{type = "control", id = "input_amp", name = "Input Level", controlspec = controlspec.new(0, 2, 'lin', 0.001, 1.0), action = function(x) engine.input_amp(x) end}
  params:add{type = "control", id = "noise_amp", name = "Noise Level", controlspec = controlspec.new(0, 2, 'lin', 0.001, 0.0), action = function(x) engine.noise_amp(x) end}
  params:add{type = "option", id = "noise_type", name = "Noise Type", options = {"Pink", "White"}, action = function(x) engine.noise_type(x-1) end}

  -- 4. PING
  params:add_group("PING GENERATOR", 10)
  params:add{type = "option", id = "ping_active", name = "Generator", options = {"Off", "On"}, default = 1, action = function(x) engine.ping_active(x-1) end}
  params:add{type = "option", id = "ping_mode", name = "Ping Mode", options = {"Internal (Free)", "Euclidean (Sync)"}, default = 1, action = function(x) engine.ping_mode(x-1) end}
  params:add{type = "control", id = "ping_amp", name = "Ping Level", controlspec = controlspec.new(0, 2.0, 'lin', 0.01, 1.0), action = function(x) engine.ping_amp(x) end}
  params:add{type = "control", id = "ping_timbre", name = "Mix (Low/High)", controlspec = controlspec.new(0, 1.0, 'lin', 0.01, 0.0), action = function(x) engine.ping_timbre(x) end}
  params:add{type = "control", id = "ping_jitter", name = "Jitter (Rhythm)", controlspec = controlspec.new(0, 1.0, 'lin', 0.01, 0.0), action = function(x) engine.ping_jitter(x) end}
  params:add{type = "control", id = "ping_rate", name = "Int Rate (Hz)", controlspec = controlspec.new(0.125, 20.0, 'exp', 0.01, 1.0, "Hz"), action = function(x) engine.ping_rate(x) end}
  params:add{type = "option", id = "ping_div", name = "Euc Division", options = {"1/1", "1/2", "1/4", "1/8", "1/16", "1/32", "1/64", "1/128", "1/256"}, default = 3}
  params:add{type = "number", id = "ping_steps", name = "Euc Steps", min = 1, max = 32, default = 16, action = function(x) update_ping_pattern() end}
  params:add{type = "number", id = "ping_hits", name = "Euc Hits", min = 0, max = 32, default = 4, action = function(x) update_ping_pattern() end}
  params:add{type = "trigger", id = "ping_manual", name = "Manual Trigger", action = function() engine.ping_manual(1) end}

  -- 5. RING MOD
  params:add_group("RING MODULATOR", 5)
  params:add{type = "control", id = "rm_drive", name = "RM Drive", controlspec = controlspec.new(0, 24.0, 'lin', 0.1, 6.0, "dB"), action = function(x) engine.rm_drive(x) end}
  params:add{type = "control", id = "rm_freq", name = "Carrier Freq", controlspec = controlspec.new(0.1, 4000.0, 'exp', 0.1, 100.0, "Hz"), action = function(x) engine.rm_freq(x) end}
  params:add{type = "option", id = "rm_wave", name = "Carrier Wave", options = {"Sine", "Tri", "Square", "Saw"}, default = 1, action = function(x) engine.rm_wave(x-1) end}
  params:add{type = "control", id = "rm_mix", name = "Dry/Wet Mix", controlspec = controlspec.new(0, 1.0, 'lin', 0.01, 0.0), action = function(x) engine.rm_mix(x) end}
  params:add{type = "control", id = "rm_instability", name = "Instability", controlspec = controlspec.new(0, 1.0, 'lin', 0.01, 0.0), action = function(x) engine.rm_instability(x) end}

  -- 6. FILTER BANK
  params:add_group("FILTER BANK", 7)
  params:add{type = "control", id = "filter_mix", name = "Filter Mix", controlspec = controlspec.new(0, 1.0, 'lin', 0.01, 1.0), action = function(x) engine.filter_mix(x) end}
  params:add{type = "control", id = "pre_hpf", name = "Low Cut (HPF)", controlspec = controlspec.new(20, 999, 'exp', 0, 20, "Hz"), action = function(x) engine.pre_hpf(x) end}
  params:add{type = "control", id = "pre_lpf", name = "High Cut (LPF)", controlspec = controlspec.new(150, 20000, 'exp', 0, 20000, "Hz"), action = function(x) engine.pre_lpf(x) end}
  params:add{type = "control", id = "stabilizer", name = "Stabilizer", controlspec = controlspec.new(0, 1, 'lin', 0.01, 0.5), action = function(x) engine.stabilizer(x) end}
  params:add{type = "control", id = "crossfeed", name = "Cross Feed", controlspec = controlspec.new(0, 1, 'lin', 0.01, 0.25), action = function(x) engine.cross_feed(x) end}
  params:add{type = "control", id = "spread", name = "Spread (Odd/Even)", controlspec = controlspec.new(0, 1, 'lin', 0.01, 0.75), action = function(x) engine.spread(x) end}
  params:add{type = "control", id = "filter_drift", name = "Filter Drift", controlspec = controlspec.new(0, 1, 'lin', 0.001, 0.0), action = function(x) engine.filter_drift(x) end}

  -- 7. LFO
  params:add_group("LFO MODULATION", 3)
  params:add{type = "control", id = "lfo_depth", name = "Global Intensity", controlspec = controlspec.new(0, 1.0, 'lin', 0.01, 0.0), action = function(x) engine.lfo_depth(x) end}
  params:add{type = "control", id = "lfo_rate", name = "Global Rate", controlspec = controlspec.new(0.01, 2.0, 'exp', 0.01, 0.1, "Hz"), action = function(x) engine.lfo_rate(x) end}
  params:add{type = "control", id = "lfo_min_db", name = "LFO Target DB", controlspec = controlspec.new(-90, 0, 'lin', 1, -60, "dB"), action = function(x) engine.lfo_min_db(x) end}

  -- 8. MAIN TAPE ECHO
  params:add_group("MAIN TAPE ECHO", 7)
  params:add{type = "control", id = "tape_mix", name = "Tape Mix", controlspec = controlspec.new(0, 1.0, 'lin', 0.01, 1.0), action = function(x) engine.tape_mix(x) end}
  params:add{type = "control", id = "tape_time", name = "Time", controlspec = controlspec.new(0, 4.0, 'lin', 0.01, 0.0, "s"), action = function(x) engine.tape_time(x) end}
  params:add{type = "control", id = "tape_fb", name = "Feedback", controlspec = controlspec.new(0, 1.0, 'lin', 0.01, 0.0), action = function(x) engine.tape_fb(x) end}
  params:add{type = "control", id = "tape_sat", name = "Saturation", controlspec = controlspec.new(0, 1, 'lin', 0.01, 0.3), action = function(x) engine.tape_sat(x) end}
  params:add{type = "control", id = "tape_wow", name = "Wow (Slow)", controlspec = controlspec.new(0, 1, 'lin', 0.01, 0.11), action = function(x) engine.tape_wow(x) end}
  params:add{type = "control", id = "tape_flutter", name = "Flutter (Fast)", controlspec = controlspec.new(0, 1, 'lin', 0.01, 0.08), action = function(x) engine.tape_flutter(x) end}
  params:add{type = "control", id = "tape_erosion", name = "Erosion", controlspec = controlspec.new(0, 1, 'lin', 0.01, 0.18), action = function(x) engine.tape_erosion(x) end}
  -- tape_brake removed

  -- 9. TAPE LOOPERS (1-4)
  for i=1, 4 do
    params:add_group("TAPE TRACK " .. i, 15)
    params:add{type = "control", id = "l"..i.."_speed", name = "Speed", controlspec = controlspec.new(-2.0, 2.0, 'lin', 0.01, 1.0), action = function(x) state.tracks[i].speed = x; Loopers.refresh(i, state) end}
    params:add{type = "control", id = "l"..i.."_vol", name = "Volume", controlspec = controlspec.new(0, 1.0, 'lin', 0.001, 0.9), action = function(x) state.tracks[i].vol = x; Loopers.refresh(i, state) end}
    params:add{type = "control", id = "l"..i.."_dub", name = "Overdub", controlspec = controlspec.new(0, 1.0, 'lin', 0.001, 1.0), action = function(x) state.tracks[i].overdub = x; Loopers.refresh(i, state) end}
    params:add{type = "control", id = "l"..i.."_deg", name = "Degrade", controlspec = controlspec.new(0, 1.0, 'lin', 0.001, 0.0), action = function(x) state.tracks[i].wow_macro = x; Loopers.refresh(i, state) end}
    params:add{type = "control", id = "l"..i.."_start", name = "Start Point", controlspec = controlspec.new(0, 1.0, 'lin', 0.001, 0.0), action = function(x) state.tracks[i].loop_start = x; Loopers.refresh(i, state) end}
    params:add{type = "control", id = "l"..i.."_end", name = "End Point", controlspec = controlspec.new(0, 1.0, 'lin', 0.001, 1.0), action = function(x) state.tracks[i].loop_end = x; Loopers.refresh(i, state) end}
    params:add{type = "option", id = "l"..i.."_src", name = "Input Source", options = SRC_OPTIONS, default = 1, action = function(x) state.tracks[i].src_sel = x - 1; Loopers.refresh(i, state) end}
    params:add{type = "control", id = "l"..i.."_rec_lvl", name = "Input Level", controlspec = controlspec.new(0, 2.0, 'lin', 0.001, 1.0), action = function(x) state.tracks[i].rec_level = x end}
    params:add{type = "control", id = "l"..i.."_aux", name = "Aux Send", controlspec = controlspec.new(0, 1.0, 'lin', 0.001, 0.0), action = function(x) state.tracks[i].aux_send = x; Loopers.refresh(i, state) end}
    params:add{type = "control", id = "l"..i.."_xfade", name = "Crossfade", controlspec = controlspec.new(0.001, 1.0, 'exp', 0.001, 0.05, "s"), action = function(x) state.tracks[i].xfade = x; Loopers.refresh(i, state) end}
    
    -- [NEW] Mixer Params
    params:add{type = "control", id = "l"..i.."_low", name = "Mixer Low", controlspec = controlspec.new(-18, 18, 'lin', 0.1, 0, "dB"), action = function(x) state.tracks[i].l_low = x; Loopers.refresh(i, state) end}
    params:add{type = "control", id = "l"..i.."_high", name = "Mixer High", controlspec = controlspec.new(-18, 18, 'lin', 0.1, 0, "dB"), action = function(x) state.tracks[i].l_high = x; Loopers.refresh(i, state) end}
    params:add{type = "control", id = "l"..i.."_filter", name = "Mixer Filter", controlspec = controlspec.new(0, 1, 'lin', 0.01, 0.5), action = function(x) state.tracks[i].l_filter = x; Loopers.refresh(i, state) end}
    params:add{type = "control", id = "l"..i.."_pan", name = "Mixer Pan", controlspec = controlspec.new(-1, 1, 'lin', 0.01, 0), action = function(x) state.tracks[i].l_pan = x; Loopers.refresh(i, state) end}
    params:add{type = "control", id = "l"..i.."_width", name = "Mixer Width", controlspec = controlspec.new(0, 2, 'lin', 0.01, 1), action = function(x) state.tracks[i].l_width = x; Loopers.refresh(i, state) end}
  end

  -- 10. BANDS
  params:add_group("BANDS SETUP", 34) 
  local scale_options = {"Default"}
  if Scales and Scales.names then scale_options = Scales.names end
  params:add{type = "option", id = "scale_idx", name = "Scale Type", options = scale_options, default = 1, action = function(x) load_scale(x); state.preview_scale_idx = x end}
  params:add{type = "option", id = "root_note", name = "Scale Root", options = {"C","C#","D","D#","E","F","F#","G","G#","A","A#","B"}, default = 1, action = function(x) load_scale(params:get("scale_idx")) end}
  
  for i=1, 16 do
    local default_freq = 100
    if Scales and Scales.list and Scales.list[1] and Scales.list[1].data then default_freq = Scales.list[1].data[i] end
    params:add{type = "control", id = "gain_"..i, name = "Band "..i.." Gain", controlspec = controlspec.new(-60, 0, 'lin', 0.1, -60, "dB"), action = function(x) engine.band_gain(i-1, x); state.bands_gain[i] = x end}
    params:add{type = "control", id = "freq_"..i, name = "Band "..i.." Freq", controlspec = controlspec.new(20, 12000, 'exp', 0, default_freq, "Hz"), action = function(x) engine.band_freq(i-1, x) end}
  end
  
  -- [NEW] TAPE LIBRARY GROUP
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
  
  params:add_separator("END OF AVANT_LAB_V")

  -- INIT
  Grid.init(state, g)
  
  local p_l = poll.set("amp_l"); if p_l then p_l.time = 0.05; p_l.callback = function(v) state.amp_l = v end; p_l:start() end
  local p_r = poll.set("amp_r"); if p_r then p_r.time = 0.05; p_r.callback = function(v) state.amp_r = v end; p_r:start() end
  for i=1, 16 do local pb = poll.set("b"..(i-1)); if pb then pb.time = 0.05; pb.callback = function(val) state.band_levels[i] = val end; pb:start() end end
  
  for i=1, 4 do
    local pp = poll.set("pos"..i)
    if pp then
      pp.time = 0.05
      pp.callback = function(val) 
         local t = state.tracks[i]
         local len = t.rec_len or 0
         if len > 0.1 then
            local buffer_ratio = len / MAX_BUFFER_SEC
            if buffer_ratio > 0.0001 then
                local norm_pos = val / buffer_ratio
                state.tracks[i].play_pos = util.clamp(norm_pos, 0, 1)
            else state.tracks[i].play_pos = 0 end
         else state.tracks[i].play_pos = 0 end
      end
      pp:start()
    end
  end
  
  local screen_timer = metro.init()
  screen_timer.time = 1/30
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
  end
  update_timer:start()
  
  params.action_write = function(filename, name, number) Storage.save_data(state, number) end
  params.action_read = function(filename, silent, number) Storage.load_data(state, number) end
  
  update_ping_pattern()
  params:bang()
  
  for i=1,4 do
    clock.run(function() rec_play_tick_main(i) end)
    clock.run(function() rec_play_tick_tape(i) end)
  end
end

function redraw()
  if state.file_selector_active then return end
  screen.clear()
  Graphics.draw(state)
  screen.update()
end

function get_current_freqs()
  local freqs = {}
  for i=1, 16 do
     table.insert(freqs, params:get("freq_"..i))
  end
  return freqs
end

function update_ping_pattern()
  local k = params:get("ping_hits"); local n = params:get("ping_steps")
  state.ping_pattern = {}
  if n > 0 then
     local slope = k / n
     for i=0, n-1 do table.insert(state.ping_pattern, (math.floor(i * slope) ~= math.floor((i+1) * slope))) end
  else state.ping_pattern = {false} end
end

function load_scale(idx)
  if not Scales or not Scales.list or not Scales.list[idx] then return end
  local s = Scales.list[idx]
  state.loaded_scale_name = s.name
  local root = params:get("root_note") or 1
  local ratio = 2 ^ ((root - 1) / 12)
  for i=1, 16 do
    local base = s.data[i]
    if base then params:set("freq_"..i, util.clamp(base * ratio, 20, 12000)) end
  end
end

function get_target_freqs(scale_idx, root_note)
  if not Scales or not Scales.list or not Scales.list[scale_idx] then return nil end
  local s = Scales.list[scale_idx]
  local ratio = 2 ^ ((root_note - 1) / 12)
  local freqs = {}
  for i=1, 16 do
     local base = s.data[i]
     if base then table.insert(freqs, util.clamp(base * ratio, 20, 12000)) end
  end
  return freqs
end

function update_morph_main()
  if state.morph_main_active and state.morph_main_slot then
     local slot = state.morph_main_slot
     local target = state.main_presets_data[slot]
     if not target or not target.gains then state.morph_main_active = false; return end
     
     local morph_time = params:get("preset_morph_main")
     if state.morph_fast_mode then morph_time = 0.1 end
     
     if morph_time < 0.05 then
        for i=1, 16 do params:set("gain_"..i, target.gains[i]) end
        if target.q then params:set("global_q", target.q) end
        if target.feedback then params:set("feedback", target.feedback) end
        if target.scale_idx then 
           params:set("scale_idx", target.scale_idx); params:set("root_note", target.root_note); load_scale(target.scale_idx) 
        end
        state.morph_main_active = false
     else
        local now = util.time()
        local elapsed = now - state.morph_main_start_time
        local progress = elapsed / morph_time
        
        if progress >= 1.0 then
           for i=1, 16 do params:set("gain_"..i, target.gains[i]) end
           if target.q then params:set("global_q", target.q) end
           if target.feedback then params:set("feedback", target.feedback) end
           if target.scale_idx then params:set("scale_idx", target.scale_idx); params:set("root_note", target.root_note); load_scale(target.scale_idx) end
           state.morph_main_active = false
        else
           for i=1, 16 do
              local start_val = state.morph_main_src[i] or params:get("gain_"..i) or -60
              local end_val = target.gains[i]
              params:set("gain_"..i, start_val + ((end_val - start_val) * progress))
           end
           if target.q and state.morph_main_src_q then
              params:set("global_q", state.morph_main_src_q + ((target.q - state.morph_main_src_q) * progress))
           end
           if target.feedback and state.morph_main_src_fb then
              params:set("feedback", state.morph_main_src_fb + ((target.feedback - state.morph_main_src_fb) * progress))
           end
           if target.scale_idx and state.morph_main_src_freqs then
              local target_freqs = get_target_freqs(target.scale_idx, target.root_note)
              if target_freqs then
                 for i=1, 16 do
                    local start_f = state.morph_main_src_freqs[i] or params:get("freq_"..i)
                    local end_f = target_freqs[i]
                    local current_f = start_f + ((end_f - start_f) * progress)
                    params:set("freq_"..i, current_f)
                 end
              end
           end
        end
     end
  end
end

function update_morph_tape()
  if state.morph_tape_active and state.morph_tape_slot then
     local slot = state.morph_tape_slot
     local target = state.tape_presets_data[slot]
     if not target or not target.tracks then state.morph_tape_active = false; return end
     
     local morph_time = params:get("preset_morph_tape")
     if state.morph_fast_mode then morph_time = 0.1 end
     
     local now = util.time()
     local elapsed = now - state.morph_tape_start_time
     local progress = elapsed / morph_time
     
     if morph_time < 0.05 or progress >= 1.0 then
        for i=1, 4 do
           local t_dest = target.tracks[i]
           if t_dest then
              state.tracks[i].speed = t_dest.speed
              state.tracks[i].vol = t_dest.vol
              state.tracks[i].loop_start = t_dest.loop_start
              state.tracks[i].loop_end = t_dest.loop_end
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
           local t_dest = target.tracks[i]
           local t_src = state.morph_tape_src[i]
           if t_dest and t_src then
              local s_speed = t_src.speed or 1.0; local d_speed = t_dest.speed or 1.0
              state.tracks[i].speed = s_speed + ((d_speed - s_speed) * progress)
              local s_vol = t_src.vol or 0.9; local d_vol = t_dest.vol or 0.9
              state.tracks[i].vol = s_vol + ((d_vol - s_vol) * progress)
              local s_start = t_src.loop_start or 0.0; local d_start = t_dest.loop_start or 0.0
              state.tracks[i].loop_start = s_start + ((d_start - s_start) * progress)
              local s_end = t_src.loop_end or 1.0; local d_end = t_dest.loop_end or 1.0
              state.tracks[i].loop_end = s_end + ((d_end - s_end) * progress)
              
              local s_low = t_src.l_low or 0; local d_low = t_dest.l_low or 0
              state.tracks[i].l_low = s_low + ((d_low - s_low) * progress)
              local s_high = t_src.l_high or 0; local d_high = t_dest.l_high or 0
              state.tracks[i].l_high = s_high + ((d_high - s_high) * progress)
              local s_filt = t_src.l_filter or 0.5; local d_filt = t_dest.l_filter or 0.5
              state.tracks[i].l_filter = s_filt + ((d_filt - s_filt) * progress)
              local s_pan = t_src.l_pan or 0; local d_pan = t_dest.l_pan or 0
              state.tracks[i].l_pan = s_pan + ((d_pan - s_pan) * progress)
              
              Loopers.refresh(i, state)
           end
        end
     end
  end
end

function osc.event(path, args, from)
  if path == "/ping_pulse" then
    table.insert(state.ping_pulses, {t0 = util.time(), amp = args[1], jitter = params:get("ping_jitter")})
  elseif path == "/buffer_info" then
    local idx = math.floor(args[1])
    local dur = args[2]
    state.tracks[idx].rec_len = dur
    Loopers.refresh(idx, state)
    print("Reel " .. idx .. " duration updated: " .. dur)
  end
end

function enc(n, d) Controls.enc(n, d, state) end
function key(n, z) Controls.key(n, z, state) end
g.key = function(x, y, z) Grid.key(x, y, z, state, engine) end

function ping_tick()
  while true do
    local mode = params:get("ping_mode")
    if mode == 2 and (params:get("ping_active") == 2) and params:get("ping_steps") > 0 then
      state.ping_step_counter = (state.ping_step_counter or 0) % params:get("ping_steps") + 1
      if state.ping_pattern[state.ping_step_counter] then engine.ping_sequence(1) end
    end
    clock.sync(DIV_VALUES[params:get("ping_div") or 3])
  end
end

function rec_play_tick_main(slot)
    while true do
      local r = state.main_rec_slots[slot]
      if r.state ~= 2 then clock.sleep(0.1) 
      else
         local event = r.data[r.step]
         if event then
           local rate = 2 ^ params:get("seq_rate_main")
           if rate == 0 then rate = 0.001 end 
           local next_time = 0
           if r.step < #r.data then next_time = (r.data[r.step+1].dt - event.dt) / rate
           else next_time = (r.duration - event.dt) / rate end
           
           if event.x and event.y and event.z then
              Grid.key(event.x, event.y, event.z, state, engine, 1) 
           end
           if next_time > 0 then clock.sleep(next_time) end
           r.step = r.step + 1; if r.step > #r.data then r.step = 1 end
         else clock.sleep(0.1) end
      end
    end
end

function rec_play_tick_tape(slot)
    while true do
      local r = state.tape_rec_slots[slot]
      if r.state ~= 2 then clock.sleep(0.1) 
      else
         local event = r.data[r.step]
         if event then
           local rate = 2 ^ params:get("seq_rate_tape")
           if rate == 0 then rate = 0.001 end 
           local next_time = 0
           if r.step < #r.data then next_time = (r.data[r.step+1].dt - event.dt) / rate
           else next_time = (r.duration - event.dt) / rate end
           
           if event.x and event.y and event.z then
              Grid.key(event.x, event.y, event.z, state, engine, 7, event.tid)
           end
           if next_time > 0 then clock.sleep(next_time) end
           r.step = r.step + 1; if r.step > #r.data then r.step = 1 end
         else clock.sleep(0.1) end
      end
    end
end

Grid.start_playback = function(slot) end
