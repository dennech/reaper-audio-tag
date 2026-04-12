local path_utils = require("path_utils")

local M = {}

local TARGET_SAMPLE_RATE = 32000
local PCM_BYTES = 2

local function write_wav_header(handle, sample_rate, channels, frames)
  local byte_rate = sample_rate * channels * PCM_BYTES
  local block_align = channels * PCM_BYTES
  local data_size = frames * channels * PCM_BYTES

  handle:write("RIFF")
  handle:write(string.pack("<I4", 36 + data_size))
  handle:write("WAVE")
  handle:write("fmt ")
  handle:write(string.pack("<I4I2I2I4I4I2I2", 16, 1, channels, sample_rate, byte_rate, block_align, PCM_BYTES * 8))
  handle:write("data")
  handle:write(string.pack("<I4", data_size))
end

local function clamp_sample(value)
  if value > 1 then
    return 1
  end
  if value < -1 then
    return -1
  end
  return value
end

local function active_audio_take()
  local count = reaper.CountSelectedMediaItems(0)
  if count ~= 1 then
    return nil, "Select exactly one audio item before running the report."
  end

  local item = reaper.GetSelectedMediaItem(0, 0)
  if not item then
    return nil, "Could not access the selected item."
  end

  local take = reaper.GetActiveTake(item)
  if not take then
    return nil, "The selected item has no active take."
  end

  if reaper.TakeIsMIDI and reaper.TakeIsMIDI(take) then
    return nil, "The selected item is MIDI. Please choose an audio item."
  end

  return item, take
end

function M.export_selected_item(target_path)
  local item, take_or_error = active_audio_take()
  if not item then
    return nil, take_or_error
  end
  local take = take_or_error

  local item_position = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  if item_length <= 0 then
    return nil, "The selected item has zero length."
  end

  local source = reaper.GetMediaItemTake_Source(take)
  local source_channels = math.max(1, reaper.GetMediaSourceNumChannels(source))
  local source_path = reaper.GetMediaSourceFileName(source)
  local take_name = reaper.GetTakeName(take)
  local item_name = take_name ~= "" and take_name or path_utils.basename(source_path)
  local accessor = reaper.CreateTakeAudioAccessor(take)
  if not accessor then
    return nil, "Could not create an audio accessor for the selected item."
  end

  local total_frames = math.max(1, math.floor(item_length * TARGET_SAMPLE_RATE + 0.5))
  local chunk_frames = 2048
  local buffer = reaper.new_array(chunk_frames * source_channels)

  path_utils.ensure_dir(path_utils.dirname(target_path))
  local handle, err = io.open(target_path, "wb")
  if not handle then
    reaper.DestroyAudioAccessor(accessor)
    return nil, "Could not open the temporary WAV file: " .. tostring(err)
  end

  write_wav_header(handle, TARGET_SAMPLE_RATE, 1, total_frames)

  local frames_written = 0
  local offset_seconds = item_position
  while frames_written < total_frames do
    local frames_to_fetch = math.min(chunk_frames, total_frames - frames_written)
    local status = reaper.GetAudioAccessorSamples(accessor, TARGET_SAMPLE_RATE, source_channels, offset_seconds, frames_to_fetch, buffer)
    local chunk = {}

    for frame = 0, frames_to_fetch - 1 do
      local mono
      if status < 1 then
        mono = 0
      else
        local sum = 0
        for channel = 1, source_channels do
          sum = sum + buffer[(frame * source_channels) + channel]
        end
        mono = sum / source_channels
      end
      local int16 = math.floor(clamp_sample(mono) * 32767)
      chunk[#chunk + 1] = string.pack("<i2", int16)
    end

    handle:write(table.concat(chunk))
    frames_written = frames_written + frames_to_fetch
    offset_seconds = offset_seconds + (frames_to_fetch / TARGET_SAMPLE_RATE)
  end

  handle:close()
  reaper.DestroyAudioAccessor(accessor)

  return {
    temp_audio_path = target_path,
    item_metadata = {
      item_name = item_name,
      item_position = item_position,
      item_length = item_length,
      sample_rate = TARGET_SAMPLE_RATE,
      source_channels = source_channels,
    },
  }
end

return M
