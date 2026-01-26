-- Avant_lab_V lib/controls.lua | Version 1.0
-- RELEASE v1.0: Full feature parity.

local Controls = {}
local fileselect = require 'fileselect'
local Scales = include('lib/scales')
local Loopers = include('lib/loopers')
local Grid = include('lib/grid')

local Pages = {}

-- PAGE 1 (GLOBAL)
Pages[1] = {
   enc = function(n, d, s)
      if not (s.k1_held or s.mod_shift_16 or s.grid_shift_active) then
         if n==1 then 
            s.preview_scale_idx = util.clamp(s.preview_scale_idx + d, 1, #Scales.list)
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
         if z==1 then
             local current_preview_name = Scales.list[s.preview_scale_idx].name
             if current_preview_name ~= s.loaded_scale_name then
                for i, sc in ipairs(Scales.list) do
                   if sc.name == s.loaded_scale_name then
                      s.preview_scale_idx = i
                      break
                   end
                end
             else
                s.saved_fb = params:get("feedback")
                params:set("feedback", 0)
                s.k2_kill_active = true
             end
         elseif z==0 then
             if s.k2_kill_active then
                params:set("feedback", s.saved_fb)
                s.k2_kill_active = false
             end
         end
      elseif n==3 and z==1 then
         params:set("scale_idx", s.preview_scale_idx)
      end
   end
}

-- PAGE 2 (FILTER BANK)
Pages[2] = {
   enc = function(n, d, s)
      if not (s.k1_held or s.mod_shift_16 or s.grid_shift_active) then
         if n==1 then params:delta("filter_mix", d*0.5)
         elseif n==2 then params:delta("pre_hpf", d)
         elseif n==3 then params:delta("pre_lpf", d) end
      else
         if n==1 then params:delta("stabilizer", d*0.5)
         elseif n==2 then params:delta("filter_drift", d*0.5)
         elseif n==3 then params:delta("crossfeed", d*0.5) end
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

-- PAGE 3 (MIX)
Pages[3] = {
   enc = function(n, d, s)
      if not (s.k1_held or s.mod_shift_16 or s.grid_shift_active) then
         -- Main: Rev/RM Mix/RM Freq
         if n==1 then params:delta("reverb_mix", d*0.5)
         elseif n==2 then params:delta("rm_mix", d*0.5)
         elseif n==3 then params:delta("rm_freq", d*0.1) end
      else
         -- Shift: Dirt/Noise Type/Noise Amp
         if n==1 then params:delta("system_dirt", d)
         elseif n==2 then params:delta("noise_type", d)
         elseif n==3 then params:delta("noise_amp", d*0.5) end
      end
   end,
   key = function(n, z, s)
      if n==2 and z==1 then 
         local w = params:get("rm_wave"); w = w%2 + 1; params:set("rm_wave", w)
      elseif n==3 and z==1 then 
         local nt = params:get("noise_type"); params:set("noise_type", nt == 5 and 0 or nt + 1)
      end
   end
}

-- PAGE 4 (TAPE)
Pages[4] = {
   enc = function(n, d, s)
      if not (s.k1_held or s.mod_shift_16 or s.grid_shift_active) then
         if n==1 then params:delta("tape_mix", d*0.5)
         elseif n==2 then params:delta("tape_time", d*0.5)
         elseif n==3 then params:delta("tape_fb", d*0.5) end
      else
         if n==1 then params:delta("tape_erosion", d*0.5)
         elseif n==2 then params:delta("tape_wow", d*0.5)
         elseif n==3 then params:delta("tape_flutter
