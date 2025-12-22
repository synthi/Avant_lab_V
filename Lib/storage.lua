-- Avant_lab_V lib/storage.lua | Version 107.4
-- FIX: Robust System Save/Load for Sequencers (Compensates for Grid Preset Change)

local Storage = {}

-- [HELPER] Sanitize a single sequencer slot
local function sanitize_sequencer(s)
   if not s then return {data={}, state=0, step=1, duration=0, start_time=0} end
   
   if s.state == 0 or not s.data or #s.data == 0 then
      s.state = 0
      s.data = {}
      s.duration = 0
      s.step = 1
      s.start_time = 0
   else
      for _, ev in ipairs(s.data) do
         if not ev.dt or ev.dt < 0 then ev.dt = 0 end
      end
      if not s.duration or s.duration < s.data[#s.data].dt then
         s.duration = s.data[#s.data].dt + 0.1
      end
   end
   return s
end

-- [HELPER] Sanitize a preset slot
local function sanitize_preset_data(p_data, p_status, type)
   if p_status == 0 then return {} end
   if not p_data then return {}, 0 end
   
   -- Compatibility: Remove 'seqs' field if present (cleanup old data)
   if p_data.seqs then p_data.seqs = nil end
   
   if type == "main" and not p_data.gains then return {}, 0 end
   if type == "tape" and not p_data.tracks then return {}, 0 end
   
   return p_data, 1
end

function Storage.save_data(state, pset_id)
  if not pset_id then return end
  if util.file_exists(_path.data .. "Avant_lab_V") == false then
      util.make_dir(_path.data .. "Avant_lab_V")
  end
  
  -- Snapshot Logic
  for i=1, 4 do
     local t = state.tracks[i]
     local len = t.rec_len or 0
     if len > 0.1 then
        if t.is_dirty then
           local timestamp = os.date("%y%m%d%H%M%S")
           local snap_name = _path.audio .. "Avant_lab_V/snapshots/areel_" .. i .. "_" .. timestamp .. ".wav"
           engine.buffer_write(i, snap_name, len)
           t.file_path = snap_name
           t.is_dirty = false 
           print("Snapshot saved: " .. snap_name)
        end
     else
        t.file_path = nil
        t.is_dirty = false
     end
  end
  
  local filename = _path.data .. "Avant_lab_V/" .. pset_id .. ".data"
  
  local pack = {
    main_rec = state.main_rec_slots, -- CRITICAL: Saving current sequencers here
    main_pre = state.main_presets_data,
    main_stat = state.main_presets_status,
    tape_rec = state.tape_rec_slots, -- CRITICAL: Saving current sequencers here
    tape_pre = state.tape_presets_data,
    tape_stat = state.tape_presets_status,
    tracks = state.tracks 
  }
  
  tab.save(pack, filename)
  print("Avant_lab_V: Saved PSET " .. pset_id)
end

function Storage.load_data(state, pset_id)
  if not pset_id then return end
  local filename = _path.data .. "Avant_lab_V/" .. pset_id .. ".data"
  
  if util.file_exists(filename) then
    local pack = tab.load(filename)
    if pack then
      
      -- 1. LOAD & SANITIZE PRESETS
      state.main_presets_data = pack.main_pre or state.main_presets_data
      state.main_presets_status = pack.main_stat or state.main_presets_status
      for i=1, 4 do
         local d, s = sanitize_preset_data(state.main_presets_data[i], state.main_presets_status[i], "main")
         state.main_presets_data[i] = d
         state.main_presets_status[i] = s
      end

      -- 2. LOAD & SANITIZE MAIN SEQUENCERS
      local seq_behavior = params:get("load_behavior_seqs")
      if pack.main_rec then 
         for i=1,4 do 
            state.main_rec_slots[i] = sanitize_sequencer(pack.main_rec[i])
            local s = state.main_rec_slots[i]
            if s.state > 0 then 
               if seq_behavior == 2 then 
                  s.state = 2; s.start_time = util.time(); s.step = 1
               else 
                  s.state = 3
               end
            end
         end 
      end
      
      -- 3. LOAD & SANITIZE TAPE PRESETS
      state.tape_presets_data = pack.tape_pre or state.tape_presets_data
      state.tape_presets_status = pack.tape_stat or state.tape_presets_status
      for i=1, 4 do
         local d, s = sanitize_preset_data(state.tape_presets_data[i], state.tape_presets_status[i], "tape")
         state.tape_presets_data[i] = d
         state.tape_presets_status[i] = s
      end
      
      -- 4. LOAD & SANITIZE TAPE SEQUENCERS
      if pack.tape_rec then 
         for i=1,4 do 
            state.tape_rec_slots[i] = sanitize_sequencer(pack.tape_rec[i])
            local s = state.tape_rec_slots[i]
            if s.state > 0 then
               if seq_behavior == 2 then
                  s.state = 2; s.start_time = util.time(); s.step = 1
               else
                  s.state = 3
               end
            end
         end 
      end
      
      -- 5. LOAD TRACKS & REELS
      local reel_behavior = params:get("load_behavior_reels")
      
      if pack.tracks then
         for i=1, 4 do
            local loaded_t = pack.tracks[i]
            if loaded_t then
              state.tracks[i].vol = loaded_t.vol
              state.tracks[i].speed = loaded_t.speed
              state.tracks[i].rec_len = loaded_t.rec_len
              state.tracks[i].loop_start = loaded_t.loop_start
              state.tracks[i].loop_end = loaded_t.loop_end
              state.tracks[i].overdub = loaded_t.overdub
              state.tracks[i].xfade = loaded_t.xfade or 0.05
              
              state.tracks[i].l_low = loaded_t.l_low or 0
              state.tracks[i].l_high = loaded_t.l_high or 0
              state.tracks[i].l_filter = loaded_t.l_filter or 0.5
              state.tracks[i].l_pan = loaded_t.l_pan or 0
              state.tracks[i].l_width = loaded_t.l_width or 1
              
              params:set("l"..i.."_vol", loaded_t.vol)
              params:set("l"..i.."_low", loaded_t.l_low or 0)
              params:set("l"..i.."_high", loaded_t.l_high or 0)
              params:set("l"..i.."_filter", loaded_t.l_filter or 0.5)
              params:set("l"..i.."_pan", loaded_t.l_pan or 0)
              params:set("l"..i.."_width", loaded_t.l_width or 1)
              
              if loaded_t.file_path and util.file_exists(loaded_t.file_path) then
                 engine.buffer_read(i, loaded_t.file_path)
                 state.tracks[i].file_path = loaded_t.file_path
                 state.tape_filenames[i] = loaded_t.file_path:match("^.+/(.+)$")
                 state.tracks[i].is_dirty = false
                 
                 if reel_behavior == 2 then
                    if loaded_t.state == 2 or loaded_t.state == 3 or loaded_t.state == 4 then
                       state.tracks[i].state = 3 
                    else
                       state.tracks[i].state = 5 
                    end
                 else
                    state.tracks[i].state = 5 
                 end
              else
                 state.tracks[i].state = 1 
                 state.tracks[i].file_path = nil
                 state.tape_filenames[i] = nil
              end
              
              local Loopers = include('lib/loopers')
              Loopers.refresh(i, state)
            end
         end
      end
      print("Avant_lab_V: Loaded PSET " .. pset_id)
    end
  else
    print("No data file.")
  end
end

return Storage
