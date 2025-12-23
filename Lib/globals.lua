-- Avant_lab_V lib/globals.lua | Version 109.0
-- FIX: Added visual_gain for Slew visualization

local Globals = {}

function Globals.new()
  local s = {}
  
  s.amp_l = 0; s.amp_r = 0
  s.band_levels = {}
  for i=1, 16 do s.band_levels[i] = 0 end
  
  s.current_page = 1
  s.k1_held = false       
  s.mod_shift_16 = false  
  s.grid_momentary_mode = false
  s.k2_held_tape = false
  s.time_page_focus = "MAIN"
  s.ping_btn_held = false
  
  s.tape_library_sel = 1
  s.tape_filenames = {"[EMPTY]", "[EMPTY]", "[EMPTY]", "[EMPTY]"}
  s.tape_msg_timers = {0, 0, 0, 0}
  s.file_selector_active = false
  
  s.bands_gain = {}
  s.visual_gain = {} -- [NEW] Visual interpolation buffer
  s.grid_memory = {}
  for i=1, 16 do 
     s.bands_gain[i] = -60
     s.visual_gain[i] = -60 
     s.grid_memory[i] = -60 
  end
  
  s.main_rec_slots = {}
  for i=1, 4 do s.main_rec_slots[i] = {data={}, state=0, press_time=0, start_time=0, step=1, duration=0} end
  s.main_presets_data = {{}, {}, {}, {}}
  s.main_presets_status = {0, 0, 0, 0}
  s.main_preset_selected = 0
  s.main_preset_press_time = {0,0,0,0}
  s.main_preset_clicks = {0,0,0,0}
  s.morph_main_active = false; s.morph_main_slot = nil
  
  s.track_sel = 1
  s.mixer_sel = 1 
  
  s.tracks = {}
  for i=1, 4 do
    s.tracks[i] = {
      state = 1, rec_len = 0.0, play_pos = 0.0,
      loop_start = 0.0, loop_end = 1.0, speed = 1.0,
      vol = 0.9, pan = 0.0, rec_level = 1.0, overdub = 1.0,
      wow_macro = 0.0, aux_send = 0.0, src_sel = 0,
      xfade = 0.05,
      brake_amt = 0.0,
      press_time_k2 = 0,
      is_dirty = false,
      file_path = nil,
      l_low = 0.0, l_high = 0.0, l_filter = 0.5, l_pan = 0.0, l_width = 1.0
    }
  end
  s.tape_rec_slots = {}
  for i=1, 4 do s.tape_rec_slots[i] = {data={}, state=0, press_time=0, start_time=0, step=1, duration=0} end
  s.tape_presets_data = {{}, {}, {}, {}}
  s.tape_presets_status = {0, 0, 0, 0}
  s.tape_preset_selected = 0
  s.tape_preset_press_time = {0,0,0,0}
  s.tape_preset_clicks = {0,0,0,0}
  s.morph_tape_active = false; s.morph_tape_slot = nil
  
  s.morph_fast_mode = false
  s.saved_morph_time = 2.0

  s.fx_memory = {} 
  s.transport_timers = {0, 0, 0, 0} 
  s.transport_press_time = {0, 0, 0, 0} 
  s.rnd_btn_val = 2
  s.rnd_btn_timer = 0
  
  s.grid_tape_view_override = false

  s.saved_fb = 0; s.saved_tape_fb = 0; s.saved_fmix = 1.0
  s.ping_pattern = {}; s.ping_pulses = {}; s.rate_offset = 0; s.ping_step_counter = 0
  s.loaded_scale_name = "Bark"; s.preview_scale_idx = 1
  s.rnd_pool = {}; for i=1, 256 do s.rnd_pool[i] = math.random() end
  
  return s
end

return Globals
