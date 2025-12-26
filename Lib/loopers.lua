-- Avant_lab_V lib/loopers.lua | Version 321.0
-- UPDATE: Fixed Loop End Calculation (Fixes Pointer/Playback), Simple Varispeed

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
  
  local gate_rec = 0.0; local gate_play = 0.0; local send_dub = 0.0
  
  if t.state == 2 then gate_rec = 1.0; gate_play = 0.0; send_dub = 0.0 
  elseif t.state == 3 then gate_rec = 0.0; gate_play = 1.0; send_dub = 0.0 
  elseif t.state == 4 then gate_rec = 1.0; gate_play = 1.0; send_dub = t.overdub or 1.0 
  elseif t.state == 5 then gate_rec = 0.0; gate_play = 0.0; send_dub = 0.0 
  elseif t.state == 1 then gate_rec = 0.0; gate_play = 0.0; send_dub = 0.0 end 
  
  local sc_start = 0.0; local sc_end = 1.0
  
  if t.state == 2 then 
     sc_start = 0.0; sc_end = 1.0
  else
    local len = t.rec_len or 0
    local valid_ratio = 0.0
    if len > 0.01 then valid_ratio = len / MAX_BUFFER_SEC end
    sc_start = util.clamp(t.loop_start or 0, 0, 1) * valid_ratio
    sc_end = util.clamp(t.loop_end or 1, 0, 1) * valid_ratio
    if sc_end <= sc_start then sc_end = sc_start + 0.001 end
  end
  
  local args = {
      f(gate_rec), f(gate_play), f(t.vol or 0.5), f(t.speed or 1.0),
      f(sc_start), f(sc_end), f(t.src_sel), f(send_dub),
      f(t.aux_send), f(t.wow_macro), f(t.xfade or 0.05), f(t.brake_amt or 0)
  }

  if t_idx == 1 then engine.l1_config(table.unpack(args))
  elseif t_idx == 2 then engine.l2_config(table.unpack(args))
  elseif t_idx == 3 then engine.l3_config(table.unpack(args))
  elseif t_idx == 4 then engine.l4_config(table.unpack(args))
  end
  
  -- Send Mixer Params
  engine.l_low(t_idx, t.l_low or 0)
  engine.l_high(t_idx, t.l_high or 0)
  engine.l_filter(t_idx, t.l_filter or 0.5)
  engine.l_pan(t_idx, t.l_pan or 0)
  engine.l_width(t_idx, t.l_width or 1)
  
  -- Send Rec Level
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
   local t = state.tracks[idx]
   if (t.rec_len or 0) < 0.1 then return end
   local buffer_ratio = t.rec_len / MAX_BUFFER_SEC
   local loop_len = (t.loop_end or 1) - (t.loop_start or 0)
   local target_rel_in_loop = (t.loop_start or 0) + (rel_pos * loop_len)
   local target_abs = target_rel_in_loop * buffer_ratio
   
   if idx == 1 then engine.l1_seek(target_abs)
   elseif idx == 2 then engine.l2_seek(target_abs)
   elseif idx == 3 then engine.l3_seek(target_abs)
   elseif idx == 4 then engine.l4_seek(target_abs)
   end
end

function Loopers.clear(idx, state)
   local t = state.tracks[idx]
   t.state = 1; t.rec_len = 0; t.play_pos = 0
   t.loop_start = 0; t.loop_end = 1; t.speed = 1.0; t.overdub = 1.0
   state.tape_filenames[idx] = nil 
   t.is_dirty = false
   t.file_path = nil
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
      t.overdub = util.clamp((t.overdub or 1.0) + d*0.01, 0, 1)
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
      state.tracks[idx].press_time_k2 = util.time()
   elseif action_type == "release" then
      local dur = util.time() - (state.tracks[idx].press_time_k2 or 0)
      if dur > 1.0 then Loopers.clear(idx, state); return end
      
      local t = state.tracks[idx]
      local now = util.time()
      
      if t.state == 1 then 
         -- Empty -> Record
         t.state = 2
         t.start_abs_time = now
         state.tape_filenames[idx] = nil 
         t.is_dirty = true
         
      elseif t.state == 2 then
        -- Record -> Play OR Dub (Based on Param)
        local raw_time = now - (t.start_abs_time or now)
        local speed_factor = math.abs(t.speed)
        if speed_factor < 0.01 then speed_factor = 1.0 end
        local effective_len = raw_time * speed_factor
        if effective_len < 0.1 then effective_len = 0.1 end
        if effective_len > MAX_BUFFER_SEC then effective_len = MAX_BUFFER_SEC end
        t.rec_len = effective_len
        
        -- [FIX] Correct loop points to recorded length
        t.loop_start = 0.0
        t.loop_end = effective_len / MAX_BUFFER_SEC
        
        -- Check Rec Behavior
        local behavior = params:get("rec_behavior")
        if behavior == 2 then
           t.state = 4 -- Go to Overdub
           t.is_dirty = true
        else
           t.state = 3 -- Go to Play
        end
        
      elseif t.state == 3 then 
         -- Play -> Overdub
         t.state = 4
         t.is_dirty = true
         
      elseif t.state == 4 then 
         -- Overdub -> Play
         t.state = 3
         
      elseif t.state == 5 then 
         -- Stop -> Play
         t.state = 3
      end
      Loopers.refresh(idx, state)
   end
end

return Loopers
