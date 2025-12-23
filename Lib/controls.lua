-- Avant_lab_V lib/controls.lua | Version 110.0
-- FIX: Added Fates Encoder 4 Support (Global Feedback / Shift: Track Degrade)

local Controls = {}
local fileselect = require 'fileselect' 
local Scales = include('lib/scales')
local Loopers = include('lib/loopers')
local Grid = include('lib/grid')

local Pages = {}

-- PAGE 1 (GLOBAL)
Pages[1] = {
  enc = function(n, d, s)
    if not (s.k1_held or s.mod_shift_16) then
      if n==1 then s.preview_scale_idx = util.clamp(s.preview_scale_idx + d, 1, #Scales.list)
      elseif n==2 then params:delta("feedback", d)
      elseif n==3 then params:delta("global_q", d) end
    else
      if n==1 then params:delta("lfo_depth", d)
      elseif n==2 then params:delta("lfo_rate", d)
      elseif n==3 then params:delta("root_note", d) end
    end
  end,
  key = function(n, z, s)
    if n==2 then
      if z==1 then s.saved_fb = params:get("feedback"); params:set("feedback", 0)
      else params:set("feedback", s.saved_fb) end
    elseif n==3 and z==1 then params:set("scale_idx", s.preview_scale_idx) end
  end
}

-- PAGE 2 (PING)
Pages[2] = {
  enc = function(n, d, s)
    local mode = params:get("ping_mode")
    if mode == 1 then 
      if not (s.k1_held or s.mod_shift_16) then
        if n==1 then params:delta("ping_rate", d)
        elseif n==2 then params:delta("ping_jitter", d)
        elseif n==3 then params:delta("ping_timbre", d) end
      else
        if n==1 then params:delta("ping_rate", d*4) 
        elseif n==2 then s.rate_offset = util.clamp(s.rate_offset + d*0.01, -2.0, 2.0); local base = params:get("ping_rate"); local final = base + s.rate_offset; if final < 0.1 then final = 0.1 end; engine.ping_rate(final)
        elseif n==3 then params:delta("ping_amp", d) end
      end
    else 
      if not (s.k1_held or s.mod_shift_16) then
        if n==1 then params:delta("ping_steps", d)
        elseif n==2 then local st = params:get("ping_steps"); local h = params:get("ping_hits"); params:set("ping_hits", util.clamp(h+d, 0, st))
        elseif n==3 then params:delta("ping_div", d) end
      else
        if n==1 then params:delta("ping_timbre", d)
        elseif n==2 then params:delta("ping_jitter", d)
        elseif n==3 then params:delta("ping_amp", d) end
      end
    end
  end,
  key = function(n, z, s)
    if n==2 and z==1 then local pm = params:get("ping_mode"); params:set("ping_mode", pm == 1 and 2 or 1)
    elseif n==3 and z==1 then local pa = params:get("ping_active"); params:set("ping_active", pa == 1 and 2 or 1) end
  end
}

-- PAGE 3 (MIX)
Pages[3] = {
  enc = function(n, d, s)
    if not (s.k1_held or s.mod_shift_16) then
      if n==1 then params:delta("reverb_mix", d*0.5)
      elseif n==2 then params:delta("rm_mix", d*0.5)
      elseif n==3 then params:delta("main_mon", d*0.5) end
    else
      if n==1 then params:delta("system_dirt", d)
      elseif n==2 then params:delta("rm_freq", d*0.1)
      elseif n==3 then params:delta("noise_amp", d*0.5) end
    end
  end,
  key = function(n, z, s)
    if n==2 and z==1 then local w = params:get("rm_wave"); w = w%4 + 1; params:set("rm_wave", w)
    elseif n==3 and z==1 then local nt = params:get("noise_type"); params:set("noise_type", nt == 1 and 2 or 1) end
  end
}

-- PAGE 4 (TAPE)
Pages[4] = {
  enc = function(n, d, s)
    if not (s.k1_held or s.mod_shift_16) then
      if n==1 then params:delta("tape_mix", d*0.5)
      elseif n==2 then params:delta("tape_time", d*0.5)
      elseif n==3 then params:delta("tape_fb", d*0.5) end
    else
      if n==1 then params:delta("tape_erosion", d*0.5)
      elseif n==2 then params:delta("tape_wow", d*0.5)
      elseif n==3 then params:delta("tape_flutter", d*0.5) end
    end
  end,
  key = function(n, z, s)
    if n==2 then engine.tape_brake(z); s.k2_held_tape = (z == 1)
    elseif n==3 then
      if z==1 then s.saved_tape_fb = params:get("tape_fb"); params:set("tape_fb", 1.0)
      else params:set("tape_fb", s.saved_tape_fb or 0.0) end
    end
  end
}

-- PAGE 5 (TIME)
Pages[5] = {
  enc = function(n, d, s)
    local suffix = (s.time_page_focus == "MAIN") and "_main" or "_tape"
    if not (s.k1_held or s.mod_shift_16) then
      if n==1 then params:delta("seq_rate"..suffix, d)
      elseif n==2 then params:delta("fader_slew", d)
      elseif n==3 then params:delta("preset_morph"..suffix, d) end
    else
      if n==1 then params:delta("seq_rate"..suffix, d*0.1)
      elseif n==2 then params:delta("preset_morph"..suffix, d*0.1)
      elseif n==3 then params:delta("seq_rate"..suffix, d*0.25) end
    end
  end,
  key = function(n, z, s)
    if n==2 and z==1 then s.time_page_focus = (s.time_page_focus == "MAIN") and "TAPE" or "MAIN"; Grid.redraw(s)
    elseif n==3 and z==1 then 
       s.morph_fast_mode = not s.morph_fast_mode
    end
  end
}

-- PAGE 6 (FILTER)
Pages[6] = {
  enc = function(n, d, s)
    if not (s.k1_held or s.mod_shift_16) then
      if n==1 then params:delta("filter_mix", d*0.5)
      elseif n==2 then params:delta("pre_hpf", d)
      elseif n==3 then params:delta("pre_lpf", d) end
    else
      if n==1 then params:delta("stabilizer", d*0.5)
      elseif n==2 then params:delta("filter_drift", d*0.5)
      elseif n==3 then params:delta("spread", d*0.5) end
    end
  end,
  key = function(n, z, s)
    if n==2 then
       if z==1 then s.saved_fmix = params:get("filter_mix"); params:set("filter_mix", 0)
       else params:set("filter_mix", s.saved_fmix or 1) end
    elseif n==3 and z==1 then 
       for i=1, 16 do local rnd = (math.random() * 60) - 60; s.bands_gain[i] = rnd; engine.band_gain(i-1, rnd) end
    end
  end
}

-- PAGE 7 (LOOPERS)
Pages[7] = {
  enc = function(n, d, s)
    if (s.k1_held or s.mod_shift_16) then
      if n==1 then Loopers.delta_param("rec_level", d, s) 
      elseif n==2 then Loopers.delta_param("start", d, s)
      elseif n==3 then Loopers.delta_param("end", d, s) end 
    else
      if n==1 then Loopers.delta_param("vol", d, s)
      elseif n==2 then Loopers.delta_param("speed", d, s)
      elseif n==3 then Loopers.delta_param("overdub", d, s) end
    end
  end,
  key = function(n, z, s)
    if n==2 then Loopers.transport_rec(s, s.track_sel, z==1 and "press" or "release")
    elseif n==3 then
      if s.k1_held and z==1 then
         s.mixer_view = not s.mixer_view
      elseif z==1 then 
         local t = s.tracks[s.track_sel]
         t.speed = (t.speed or 1) * -1
         Loopers.refresh(s.track_sel, s)
      end
    end
  end
}

-- PAGE 8 (LIBRARY)
Pages[8] = {
  enc = function(n, d, s)
    if n==1 then s.tape_library_sel = util.clamp(s.tape_library_sel + d, 1, 4) end
  end,
  key = function(n, z, s)
    if n==2 and z==1 then 
       s.file_selector_active = true
       fileselect.enter("/home/we/dust/audio/", function(file) 
          s.file_selector_active = false 
          if file ~= "cancel" then
             Loopers.load_file(s.tape_library_sel, file, s)
          end
       end)
    elseif n==3 and z==1 then
       local len = s.tracks[s.tape_library_sel].rec_len or 0
       if len > 0 then
          local name = _path.audio .. "Avant_lab_V/reel_" .. s.tape_library_sel .. "_" .. os.date("%y%m%d%H%M") .. ".wav"
          engine.buffer_write(s.tape_library_sel, name, len)
          s.tape_filenames[s.tape_library_sel] = name:match("^.+/(.+)$")
          s.tape_msg_timers[s.tape_library_sel] = util.time() + 2.0
       end
    end
  end
}

-- PAGE 9 (MIXER)
Pages[9] = {
  enc = function(n, d, s)
    local trk = s.mixer_sel
    local t = s.tracks[trk]
    if not (s.k1_held or s.mod_shift_16) then
       if n==1 then t.vol = util.clamp(t.vol + d*0.01, 0, 1); Loopers.refresh(trk, s) 
       elseif n==2 then t.l_low = util.clamp(t.l_low + d*0.1, -18, 18); Loopers.refresh(trk, s) 
       elseif n==3 then t.l_high = util.clamp(t.l_high + d*0.1, -18, 18); Loopers.refresh(trk, s) end 
    else
       if n==1 then t.l_filter = util.clamp(t.l_filter + d*0.01, 0, 1); Loopers.refresh(trk, s) 
       elseif n==2 then t.l_pan = util.clamp(t.l_pan + d*0.05, -1, 1); Loopers.refresh(trk, s) 
       elseif n==3 then t.l_width = util.clamp(t.l_width + d*0.05, 0, 2); Loopers.refresh(trk, s) end 
    end
  end,
  key = function(n, z, s)
    if z==1 then
       if n==2 then s.mixer_sel = util.clamp(s.mixer_sel - 1, 1, 4)
       elseif n==3 then s.mixer_sel = util.clamp(s.mixer_sel + 1, 1, 4) end
    end
  end
}

function Controls.enc(n, d, state)
  -- [FIX] FATES ENCODER 4 SUPPORT
  -- This block intercepts E4 before page logic
  if n == 4 then
     if state.k1_held or state.mod_shift_16 then
        -- Shift + E4: Control Degrade (Wow) of Selected Track
        -- Uses delta_param to handle clamping and refresh
        Loopers.delta_param("wow", d, state)
     else
        -- E4: Global Feedback
        params:delta("feedback", d)
     end
     return -- Stop processing, don't send E4 to pages
  end

  local p = Pages[state.current_page]
  if p and p.enc then p.enc(n, d, state) end
end

function Controls.key(n, z, state)
  if n==1 then 
     state.k1_held = (z==1)
     if z==1 then state.k1_press_time = util.time() end
     if z==1 then Grid.redraw(state) end 
     return 
  end
  
  if state.k1_held and z==1 then
    if n==2 then state.current_page = state.current_page - 1; if state.current_page < 1 then state.current_page = 9 end 
    elseif n==3 then state.current_page = state.current_page + 1; if state.current_page > 9 then state.current_page = 1 end 
    end
    return
  end
  local p = Pages[state.current_page]
  if p and p.key then p.key(n, z, state) end
end

return Controls
