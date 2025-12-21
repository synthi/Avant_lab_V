-- Avant_lab_V lib/storage.lua | Version 94.1
-- FIX: Sync Mixer Params on Load

local Storage = {}

function Storage.save_data(state, pset_id)
  if not pset_id then return end
  if util.file_exists(_path.data .. "Avant_lab_V") == false then
      util.make_dir(_path.data .. "Avant_lab_V")
  end
  
  -- Snapshot Logic: Save dirty tracks
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
    main_rec = state.main_rec_slots,
    main_pre = state.main_presets_data,
    main_stat = state.main_presets_status,
    tape_rec = state.tape_rec_slots,
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
  
  for i=1, 4 do
    if state.main_rec_slots[i] then state.main_rec_slots[i].state = 0; state.main_rec_slots[i].step = 1 end
    if state.tape_rec_slots[i] then state.tape_rec_slots[i].state = 0; state.tape_rec_slots[i].step = 1 end
  end
  
  if util.file_exists(filename) then
    local pack = tab.load(filename)
    if pack then
      state.main_presets_data = pack.main_pre or state.main_presets_data
      state.main_presets_status = pack.main_stat or state.main_presets_status
      if pack.main_rec then state.main_rec_slots = pack.main_rec; for i=1,4 do state.main_rec_slots[i].state = 0 end end
      
      state.tape_presets_data = pack.tape_pre or state.tape_presets_data
      state.tape_presets_status = pack.tape_stat or state.tape_presets_status
      if pack.tape_rec then state.tape_rec_slots = pack.tape_rec; for i=1,4 do state.tape_rec_slots[i].state = 0 end end
      
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
              
              -- Mixer Params Load
              state.tracks[i].l_low = loaded_t.l_low or 0
              state.tracks[i].l_high = loaded_t.l_high or 0
              state.tracks[i].l_filter = loaded_t.l_filter or 0.5
              state.tracks[i].l_pan = loaded_t.l_pan or 0
              state.tracks[i].l_width = loaded_t.l_width or 1
              
              -- [FIX] FORCE PARAM SYNC
              params:set("l"..i.."_vol", loaded_t.vol)
              params:set("l"..i.."_low", loaded_t.l_low or 0)
              params:set("l"..i.."_high", loaded_t.l_high or 0)
              params:set("l"..i.."_filter", loaded_t.l_filter or 0.5)
              params:set("l"..i.."_pan", loaded_t.l_pan or 0)
              params:set("l"..i.."_width", loaded_t.l_width or 1)
              
              if loaded_t.file_path and util.file_exists(loaded_t.file_path) then
                 engine.buffer_read(i, loaded_t.file_path)
                 state.tracks[i].file_path = loaded_t.file_path
                 state.tracks[i].state = 5 
                 state.tape_filenames[i] = loaded_t.file_path:match("^.+/(.+)$")
                 state.tracks[i].is_dirty = false
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