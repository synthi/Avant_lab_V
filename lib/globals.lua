-- Avant_lab_V lib/globals.lua | Version 1.4
-- RELEASE v1.4: Added 'popup' and 'fader_latched' for 16n support.

local Globals = {}

function Globals.new()
  local s = {}
  
  s.loaded = false 
  s.amp_l = 0.0; s.amp_r = 0.0; s.comp_gr = 0.0 
  
  s.band_levels = {}
  s.bands_gain = {}  
  s.visual_gain = {} 
  s.grid_memory = {}
  s.grid_cache = {} 
  
  s.grid_debounce = {}
  s.button_state = {}
  
  for i=1, 16 do 
     s.band_levels[i] = 0.0; s.bands_gain[i] = -60; s.visual_gain[i] = -60; s.grid_memory[i] = -60 
     s.grid_cache[i] = {}
     s.grid_debounce[i] = {}
     s.button_state[i] = {}
     for y=1, 8 do 
        s.grid_cache[i][y] = -1 
        s.grid_debounce[i][y] = 0
        s.button_state[i][y] = false
     end
  end

  s.GONIO_LEN = 80
  s.FILTER_LEN = 60
  
  s.gonio_history = {}; for i=1, s.GONIO_LEN do s.gonio_history[i] = {s=0, w=0} end
  s.filter_history = {}; for i=1, s.FILTER_LEN do s.filter_history[i] = {amp=0, phase=0} end
  s.time_history = {}; for i=1, s.FILTER_LEN do s.time_history[i] = {ph=0, r=0, m=0} end
  
  s.heads = {gonio=1, filter=1, time=1}
  s.str_cache = {}

  -- [NEW v1.4] 16n Support Structures
  s.fader_latched = {}
  for i=1, 16 do s.fader_latched[i] = false end

  s.popup = {
    active = false,
    name = "",
    value = "",
    deadline = 0
  }

  s.current_page = 1
  s.k1_held = false; s.mod_shift_16 = false  
  s.grid_momentary_mode = false
  s.k2_held_tape = false
  s.time_page_focus = "MAIN"
  s.ping_btn_held = false
  s.grid_mixer_held = false
  s.grid_track_held = false
  s.k2_kill_active = false
  
  s.tape_library_sel = 1
  s.tape_filenames = {"[EMPTY]", "[EMPTY]", "[EMPTY]", "[EMPTY]"}
  s.tape_msg_timers = {0, 0, 0, 0}
  s.file_selector_active = false
  
  s.main_rec_slots = {}; for i=1, 4 do s.main_rec_slots[i] = {data={}, state=0, press_time=0, start_time=0, step=1, duration=0} end
  s.main_presets_data = {{}, {}, {}, {}}; s.main_presets_status = {0, 0, 0, 0}
  s.main_preset_selected = 0; s.main_preset_press_time = {0,0,0,0}; s.main_preset_clicks = {0,0,0,0}
  s.morph_main_active = false; s.morph_main_slot = nil
  
  s.track_sel = 1; s.mixer_sel = 1 
  s.tracks = {}
  for i=1, 4 do
    s.tracks[i] = {
      state = 1, rec_len = 0.0, play_pos = 0.0,
      loop_start = 0.0, loop_end = 1.0, speed = 1.0,
      vol = 0.9, pan = 0.0, rec_level = 1.0, overdub = 1.0,
      wow_macro = 0.0, aux_send = 0.0, src_sel = 0,
      xfade = 0.05, brake_amt = 0.0, press_time_k2 = 0,
      is_dirty = false, file_path = nil,
      l_low = 0.0, l_high = 0.0, l_filter = 0.5, l_pan = 0.0, l_width = 1.0
    }
  end
  s.tape_rec_slots = {}; for i=1, 4 do s.tape_rec_slots[i] = {data={}, state=0, press_time=0, start_time=0, step=1, duration=0} end
  s.tape_presets_data = {{}, {}, {}, {}}; s.tape_presets_status = {0, 0, 0, 0}
  s.tape_preset_selected = 0; s.tape_preset_press_time = {0,0,0,0}; s.tape_preset_clicks = {0,0,0,0}
  s.morph_tape_active = false; s.morph_tape_slot = nil
  
  s.morph_fast_mode = false; s.saved_morph_time = 2.0
  s.fx_memory = {} 
  s.transport_timers = {0, 0, 0, 0}; s.transport_press_time = {0, 0, 0, 0} 
  s.rnd_btn_val = 2; s.rnd_btn_timer = 0
  s.grid_tape_view_override = false

  s.saved_fb = 0; s.saved_tape_fb = 0; s.saved_fmix = 1.0
  s.ping_pattern = {}; s.ping_pulses = {}; s.rate_offset = 0; s.ping_step_counter = 0
  s.loaded_scale_name = "Bark"; s.preview_scale_idx = 1
  
  return s
end

return Globals
