-- Avant_lab_V lib/loopers.lua | Version 1.1
-- UPDATE v1.1: Safe Stop Logic (Continuous Motor, Feedback 1.0).

local Loopers = {}
local util = require 'util'
local MAX_BUFFER_SEC = 120.0

local function f(val) return (val or 0) * 1.0 end

function Loopers.load_file(i, path, state)
    if not path or path == "cancel" or path == "" or path == "-" then return end
    if string.sub(path, -1) == "/" then return end 
    
    engine.buffer_read(i, path)
    
    state.tracks[i].state = 5 
    state.tracks[i].play_pos = 0
    state.tracks[i].loop_start = 0
    state.tracks[i].loop_end = 1
    
    state.tape_filenames[i] = path:match("^.+/(.+)$")
    
    state.tracks[i].is_dirty = false
    state.tracks[i].file_path = path
    
    Loopers.refresh(i, state)
    print("Looper "..i.." loading: "..state.tape_filenames[i])
end

function Loopers.refresh(t_idx, state)
  local t = state.tracks[t_idx]
  if not t then return end
  
  -- [v1.1] Safe Continuous Logic
  local gate_rec = 0.0; local gate_play = 0.0; local send_dub = 0.0
  
  if t.state == 2 then 
      gate_rec = 1.0; gate_play = 0.0; send_dub = 0.0 
  elseif t.state == 3 then 
      gate_rec = 0.0; gate_play = 1.0; send_dub = t.overdub or 1.0 
  elseif t.state == 4 then 
      gate_rec = 1.0; gate_play = 1.0; send_dub = t.overdub or 1.0 
  elseif t.state == 5 then 
      -- [v1.1] SAFE STOP: Motor runs (no speed override), Audio Muted, Feedback locked to 1.0
      gate_rec = 0.0; gate_play = 0.0; send_dub = 1.0 
  elseif t.state == 1 then 
      gate_rec = 0.0; gate_play = 0.0; send_dub = 0.0 
  end 
  
  local sc_start = util.clamp(t.loop_start or 0, 0, 1)
  local sc_end = util.clamp(t.loop_end or 1, 0, 1)
  if sc_end <= sc_start then sc_end = sc_start + 0.001 end
  
  local length = params:get("l"..t_idx.."_length")
  
  local args = {
      f(gate_rec), f(gate_play), f(t.vol or 0.5), f(t.speed or 1.0),
      f(sc_start), f(sc_end), f(t.src_sel), f(send_dub),
      f(t.aux_send), f(t.wow_macro), f(t.brake_amt or 0),
      f(length)
  }

  if t_idx == 1 then engine.l1_config(table.unpack(args))
  elseif t_idx == 2 then engine.l2_config(table.unpack(args))
  elseif t_idx == 3 then engine.l3_config(table.unpack(args))
  elseif t_idx == 4 then engine.l4_config(table.unpack(args))
  end
  
  engine.l_low(t_idx, t.l_low or 0)
  engine.l_high(t_idx, t.l_high or 0)
  engine.l_filter(t_idx, t.l_filter or 0.5)
  engine.l_pan(t_idx, t.l_pan or 0)
  engine.l_width(t_idx, t.l_width or 1)
  engine.l_rec_lvl(t_idx, t.rec_level or 0.0)
end

function Loopers.set_speed_slew(idx, target_speed, slew_time, state, start_val_override)
   local t = state.tracks[idx]
   if slew_time < 0.1 then
      t.speed = target_speed
      Loopers.refresh(idx, state)
      return
   end
   clock.run(function()
      local start_speed = start_val_override or t.speed
      local start_time = util.time()
      while true do
         local now = util.time()
         local elapsed = now - start_time
         local progress = elapsed / slew_time
         if progress >= 1.0 then
            t.speed = target_speed
            Loopers.refresh(idx, state)
            break
         end
         t.speed = start_speed + ((target_speed - start_speed) * progress)
         Loopers.refresh(idx, state)
         clock.sleep(0.02)
      end
   end)
end

function Loopers.seek(idx, rel_pos, state)
   if idx == 1 then engine.l1_seek(rel_pos)
   elseif idx == 2 then engine.l2_seek(rel_pos)
   elseif idx == 3 then engine.l3_seek(rel_pos)
   elseif idx == 4 then engine.l4_seek(rel_pos)
   end
end

function Loopers.clear(idx, state)
   local t = state.tracks[idx]
   t.state = 1; t.rec_len = 0; t.play_pos = 0
   t.loop_start = 0; t.loop_end = 1; t.speed = 1.0; t.overdub = 1.0
   state.tape_filenames[idx] = nil 
   t.is_dirty = false
   t.file_path = nil
   
   if engine.clear then engine.clear(idx) end
   
   Loopers.refresh(idx, state)
   print("Track " .. idx .. " CLEARED")
end

function Loopers.delta_param(param_name, d, state)
   local idx = state.track_sel
   local t = state.tracks[idx]
   if not t then return end
   
   if param_name == "vol" then t.vol = util.clamp((t.vol or 0.5) + d*0.01, 0, 1)
   
   elseif param_name == "speed" then
     local old_s = t.speed or 1
     local s = old_s + (d * 0.01)
     local snap_dist = 0.03
     if math.abs(s) < snap_dist and math.abs(old_s) > 0.001 then s = 0 end
     if math.abs(s - 1.0) < snap_dist and math.abs(old_s - 1.0) > 0.001 then s = 1.0 end
     if math.abs(s + 1.0) < snap_dist and math.abs(old_s + 1.0) > 0.001 then s = -1.0 end
     t.speed = util.clamp(s, -2.0, 2.0)
     
   elseif param_name == "overdub" then 
      t.overdub = util.clamp((t.overdub or 1.0) + d*0.01, 0, 1.11)
      params:set("l"..idx.."_dub", t.overdub)
   elseif param_name == "start" then local e = t.loop_end or 1; t.loop_start = util.clamp((t.loop_start or 0) + d*0.005, 0, e - 0.01)
   elseif param_name == "end" then local s = t.loop_start or 0; t.loop_end = util.clamp((t.loop_end or 1) + d*0.005, s + 0.01, 1.0)
   
   elseif param_name == "rec_level" then 
      t.rec_level = util.clamp((t.rec_level or 0.0) + d*0.5, -60, 12)
      
   elseif param_name == "aux" then t.aux_send = util.clamp((t.aux_send or 0) + d*0.01, 0, 1)
   
   elseif param_name == "wow" then 
      t.wow_macro = util.clamp((t.wow_macro or 0) + d*0.01, 0, 1)
      params:set("l"..idx.."_deg", t.wow_macro)
   end
   Loopers.refresh(idx, state)
end

function Loopers.transport_rec(state, idx, action_type)
   if action_type == "press" then
      local t = state.tracks[idx]
      if t.state == 5 or t.state == 0 or t.state == 1 then
         if t.state == 1 and engine.clear then 
             engine.clear(idx); engine["l"..idx.."_seek"](0) 
         end
         t.state = 4 
      elseif t.state == 3 then t.state = 4 
      elseif t.state == 4 then t.state = 3 
      elseif t.state == 2 then t.state = 3 end
      Loopers.refresh(idx, state)
   end
end

return Loopers
