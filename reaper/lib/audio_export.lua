local path_utils = require("path_utils")

local M = {}

local TARGET_SAMPLE_RATE = 32000
local PCM_BYTES = 2
local CHUNK_FRAMES = 2048
local RANGE_EPSILON = 0.01

M.TARGET_SAMPLE_RATE = TARGET_SAMPLE_RATE
M.CHUNK_FRAMES = CHUNK_FRAMES
M.DEFAULT_STEP_MAX_CHUNKS = 24
M.DEFAULT_STEP_MAX_TIME_MS = 6

local function now_seconds()
  if reaper and reaper.time_precise then
    return reaper.time_precise()
  end
  return os.clock()
end

local function round_number(value)
  return math.floor((tonumber(value) or 0) * 1000000 + 0.5) / 1000000
end

local function approx_equal(left, right, epsilon)
  return math.abs((tonumber(left) or 0) - (tonumber(right) or 0)) <= (epsilon or RANGE_EPSILON)
end

local function overlap_seconds(left_start, left_end, right_start, right_end)
  return math.max(0, math.min(left_end, right_end) - math.max(left_start, right_start))
end

local function table_value(value)
  if type(value) == "table" then
    local chunks = {}
    for _, item in ipairs(value) do
      chunks[#chunks + 1] = tostring(item)
    end
    return table.concat(chunks, ",")
  end
  return tostring(value)
end

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

local function diagnostics_lines(diagnostics)
  local keys = {
    "status",
    "error",
    "item_name",
    "item_position",
    "item_length",
    "selected_end",
    "requested_start",
    "requested_end",
    "accessor_start",
    "accessor_end",
    "accessor_range_length",
    "accessor_time_domain",
    "take_start_offset",
    "take_playrate",
    "loop_source",
    "source_consumed_length",
    "accessor_state_changed",
    "read_strategy",
    "read_mode",
    "range_mismatch",
    "range_clamped",
    "probe_candidates_tried",
    "probe_domain_selected",
    "probe_frames_read",
    "frames_requested",
    "frames_read",
    "frames_silent",
    "chunks_read",
    "chunks_silent",
  }
  local lines = {}
  for _, key in ipairs(keys) do
    if diagnostics[key] ~= nil then
      lines[#lines + 1] = string.format("%s=%s", key, table_value(diagnostics[key]))
    end
  end
  return table.concat(lines, "\n") .. "\n"
end

local function write_diagnostics(path, diagnostics)
  if not path then
    return
  end
  path_utils.ensure_dir(path_utils.dirname(path))
  path_utils.write_file(path, diagnostics_lines(diagnostics))
end

local function build_domain_candidates(context)
  local source_consumed_length = context.item_length * context.take_playrate
  return {
    {
      name = "item_local",
      priority = 1,
      range_start = 0,
      range_end = context.item_length,
      map_start = function(project_time)
        return project_time - context.item_position
      end,
    },
    {
      name = "project",
      priority = 2,
      range_start = context.item_position,
      range_end = context.selected_end,
      map_start = function(project_time)
        return project_time
      end,
    },
    {
      name = "take_source",
      priority = 3,
      range_start = context.take_start_offset,
      range_end = context.take_start_offset + source_consumed_length,
      map_start = function(project_time)
        return context.take_start_offset + ((project_time - context.item_position) * context.take_playrate)
      end,
    },
  }
end

local function candidate_score(candidate, accessor_start, accessor_end)
  local score = 0
  if approx_equal(accessor_start, candidate.range_start) then
    score = score + 4
  end
  if approx_equal(accessor_end, candidate.range_end) then
    score = score + 4
  end
  if overlap_seconds(accessor_start, accessor_end, candidate.range_start, candidate.range_end) > RANGE_EPSILON then
    score = score + 2
  end
  if accessor_start >= (candidate.range_start - RANGE_EPSILON) and accessor_end <= (candidate.range_end + RANGE_EPSILON) then
    score = score + 1
  end
  return score
end

local function sort_candidates(candidates, accessor_start, accessor_end)
  table.sort(candidates, function(left, right)
    local left_score = candidate_score(left, accessor_start, accessor_end)
    local right_score = candidate_score(right, accessor_start, accessor_end)
    if left_score == right_score then
      return left.priority < right.priority
    end
    return left_score > right_score
  end)
end

local function chunk_plan(candidate, context, project_chunk_start, frames_to_fetch, clamp_to_accessor)
  local accessor_chunk_start = candidate.map_start(project_chunk_start)
  local accessor_chunk_end = accessor_chunk_start + (frames_to_fetch / TARGET_SAMPLE_RATE)

  if not clamp_to_accessor then
    return {
      fetch_start = accessor_chunk_start,
      fetch_offset_frames = 0,
      fetched_frames = frames_to_fetch,
      accessor_chunk_start = accessor_chunk_start,
      accessor_chunk_end = accessor_chunk_end,
    }
  end

  local overlap_start = math.max(accessor_chunk_start, context.accessor_start)
  local overlap_end = math.min(accessor_chunk_end, context.accessor_end)
  if overlap_end <= overlap_start then
    return {
      fetch_start = accessor_chunk_start,
      fetch_offset_frames = 0,
      fetched_frames = 0,
      accessor_chunk_start = accessor_chunk_start,
      accessor_chunk_end = accessor_chunk_end,
    }
  end

  local fetch_offset_frames = math.max(0, math.floor(((overlap_start - accessor_chunk_start) * TARGET_SAMPLE_RATE) + 0.5))
  local fetched_frames = math.max(0, math.floor(((overlap_end - overlap_start) * TARGET_SAMPLE_RATE) + 0.5))
  fetched_frames = math.min(fetched_frames, frames_to_fetch - fetch_offset_frames)

  return {
    fetch_start = overlap_start,
    fetch_offset_frames = fetch_offset_frames,
    fetched_frames = fetched_frames,
    accessor_chunk_start = accessor_chunk_start,
    accessor_chunk_end = accessor_chunk_end,
  }
end

local function read_accessor_chunk(accessor, candidate, context, project_chunk_start, frames_to_fetch, buffer, clamp_to_accessor)
  local plan = chunk_plan(candidate, context, project_chunk_start, frames_to_fetch, clamp_to_accessor)
  local status = 0
  if plan.fetched_frames > 0 then
    status = reaper.GetAudioAccessorSamples(
      accessor,
      TARGET_SAMPLE_RATE,
      context.source_channels,
      plan.fetch_start,
      plan.fetched_frames,
      buffer
    )
  end
  return {
    status = status,
    fetch_offset_frames = plan.fetch_offset_frames,
    fetched_frames = plan.fetched_frames,
    accessor_chunk_start = plan.accessor_chunk_start,
    accessor_chunk_end = plan.accessor_chunk_end,
  }
end

local function readable_frames(read_result)
  if read_result.status < 1 then
    return 0
  end
  return math.max(0, tonumber(read_result.fetched_frames) or 0)
end

local function append_audio_chunk(handle, buffer, context, diagnostics, frames_to_fetch, read_result)
  local chunk = {}
  local chunk_frames_read = 0

  for frame = 0, frames_to_fetch - 1 do
    local mono = 0
    local readable = false
    local fetched_frame = frame - read_result.fetch_offset_frames
    if read_result.status >= 1 and fetched_frame >= 0 and fetched_frame < read_result.fetched_frames then
      local sum = 0
      for channel = 1, context.source_channels do
        sum = sum + buffer[(fetched_frame * context.source_channels) + channel]
      end
      mono = sum / context.source_channels
      readable = true
    end

    if readable then
      chunk_frames_read = chunk_frames_read + 1
    end
    local int16 = math.floor(clamp_sample(mono) * 32767)
    chunk[#chunk + 1] = string.pack("<i2", int16)
  end

  handle:write(table.concat(chunk))

  diagnostics.frames_read = diagnostics.frames_read + chunk_frames_read
  diagnostics.frames_silent = diagnostics.frames_silent + (frames_to_fetch - chunk_frames_read)
  if chunk_frames_read > 0 then
    diagnostics.chunks_read = diagnostics.chunks_read + 1
  else
    diagnostics.chunks_silent = diagnostics.chunks_silent + 1
  end
end

local function resolve_domain(accessor, candidates, context, total_frames, buffer, diagnostics)
  sort_candidates(candidates, context.accessor_start, context.accessor_end)

  local best_score = candidate_score(candidates[1], context.accessor_start, context.accessor_end)
  local second_score = candidates[2] and candidate_score(candidates[2], context.accessor_start, context.accessor_end) or -1
  local hint_candidate = nil
  if best_score >= 6 and best_score > second_score then
    hint_candidate = candidates[1]
  end

  local first_chunk_frames = math.min(CHUNK_FRAMES, total_frames)
  local probe_candidates_tried = {}
  local probe_frames_read = 0
  local chosen_candidate = nil
  local selection_method = nil

  if hint_candidate then
    local hinted_read = read_accessor_chunk(accessor, hint_candidate, context, context.item_position, first_chunk_frames, buffer, true)
    probe_candidates_tried[#probe_candidates_tried + 1] = hint_candidate.name
    probe_frames_read = readable_frames(hinted_read)
    if probe_frames_read > 0 then
      chosen_candidate = hint_candidate
      selection_method = "hinted"
    end
  end

  if not chosen_candidate then
    local best_probe_frames = -1
    for _, candidate in ipairs(candidates) do
      local already_tried = false
      for _, name in ipairs(probe_candidates_tried) do
        if name == candidate.name then
          already_tried = true
          break
        end
      end
      if not already_tried then
        local probe_read = read_accessor_chunk(accessor, candidate, context, context.item_position, first_chunk_frames, buffer, false)
        local frames = readable_frames(probe_read)
        probe_candidates_tried[#probe_candidates_tried + 1] = candidate.name
        if frames > best_probe_frames then
          best_probe_frames = frames
          probe_frames_read = frames
          chosen_candidate = candidate
        end
      end
    end
    selection_method = "probed"
  end

  diagnostics.probe_candidates_tried = probe_candidates_tried
  diagnostics.probe_domain_selected = chosen_candidate and chosen_candidate.name or ""
  diagnostics.probe_frames_read = probe_frames_read

  return chosen_candidate, selection_method
end

local function chosen_read_mode(candidate, selection_method, context)
  if not candidate then
    return "direct"
  end
  local overlap = overlap_seconds(context.accessor_start, context.accessor_end, candidate.range_start, candidate.range_end)
  if selection_method == "hinted" and overlap > RANGE_EPSILON then
    return "clamped"
  end
  return "direct"
end

local function close_session_handles(session)
  if session.handle then
    session.handle:close()
    session.handle = nil
  end
  if session.accessor and reaper.DestroyAudioAccessor then
    reaper.DestroyAudioAccessor(session.accessor)
    session.accessor = nil
  end
end

local function build_payload(session)
  local diagnostics = session.diagnostics
  return {
    temp_audio_path = session.target_path,
    item_metadata = {
      item_name = session.item_name,
      item_position = session.item_position,
      item_length = session.item_length,
      selected_end = session.selected_end,
      requested_start = session.item_position,
      requested_end = session.selected_end,
      sample_rate = TARGET_SAMPLE_RATE,
      source_channels = session.source_channels,
      accessor_start = session.accessor_start,
      accessor_end = session.accessor_end,
      accessor_range_length = diagnostics.accessor_range_length,
      accessor_time_domain = diagnostics.accessor_time_domain,
      take_start_offset = session.take_start_offset,
      take_playrate = session.take_playrate,
      loop_source = session.loop_source,
      source_consumed_length = session.source_consumed_length,
      accessor_state_changed = diagnostics.accessor_state_changed,
      read_strategy = diagnostics.read_strategy,
      read_mode = diagnostics.read_mode,
      range_mismatch = diagnostics.range_mismatch,
      range_clamped = diagnostics.range_clamped,
      probe_candidates_tried = diagnostics.probe_candidates_tried,
      probe_domain_selected = diagnostics.probe_domain_selected,
      probe_frames_read = diagnostics.probe_frames_read,
      frames_read = diagnostics.frames_read,
      frames_silent = diagnostics.frames_silent,
      chunks_read = diagnostics.chunks_read,
      chunks_silent = diagnostics.chunks_silent,
    },
  }
end

local function finalize_session_error(session, message)
  close_session_handles(session)
  if session.target_path then
    os.remove(session.target_path)
  end
  session.diagnostics.status = "error"
  session.diagnostics.error = message
  write_diagnostics(session.diagnostics_path, session.diagnostics)
  session.completed = true
  session.error = message
  return nil, message, session.diagnostics
end

function M.finish_export(session)
  if not session then
    return nil, "No export session is active."
  end
  if session.completed then
    if session.payload then
      return session.payload, nil, session.diagnostics
    end
    return nil, session.error, session.diagnostics
  end

  close_session_handles(session)
  session.diagnostics.range_clamped = session.diagnostics.frames_silent > 0
  if session.diagnostics.frames_read <= 0 then
    return finalize_session_error(session, "Could not read audio data from the selected take range.")
  end

  session.diagnostics.status = "ok"
  write_diagnostics(session.diagnostics_path, session.diagnostics)
  session.payload = build_payload(session)
  session.completed = true
  return session.payload, nil, session.diagnostics
end

function M.cancel_export(session)
  if not session or session.completed then
    return
  end
  close_session_handles(session)
  if session.target_path then
    os.remove(session.target_path)
  end
  session.completed = true
  session.cancelled = true
  session.error = "Export cancelled."
end

function M.begin_export_selected_item(target_path, options)
  options = options or {}

  local item, take_or_error = active_audio_take()
  if not item then
    return nil, take_or_error, { status = "error", error = take_or_error, error_kind = "selection" }
  end
  local take = take_or_error

  local item_position = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  if item_length <= 0 then
    return nil, "The selected item has zero length.", {
      status = "error",
      error = "The selected item has zero length.",
      error_kind = "selection",
      item_position = round_number(item_position),
      item_length = round_number(item_length),
    }
  end

  local source = reaper.GetMediaItemTake_Source(take)
  local source_channels = math.max(1, reaper.GetMediaSourceNumChannels(source))
  local source_path = reaper.GetMediaSourceFileName(source)
  local take_name = reaper.GetTakeName(take)
  local item_name = take_name ~= "" and take_name or path_utils.basename(source_path)
  local take_start_offset = reaper.GetMediaItemTakeInfo_Value and reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS") or 0
  local take_playrate = reaper.GetMediaItemTakeInfo_Value and reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE") or 1
  local loop_source = (reaper.GetMediaItemInfo_Value(item, "B_LOOPSRC") or 0) > 0.5
  local selected_end = item_position + item_length
  local source_consumed_length = item_length * take_playrate
  local diagnostics = {
    status = "pending",
    item_name = item_name,
    item_position = round_number(item_position),
    item_length = round_number(item_length),
    selected_end = round_number(selected_end),
    requested_start = round_number(item_position),
    requested_end = round_number(selected_end),
    take_start_offset = round_number(take_start_offset),
    take_playrate = round_number(take_playrate),
    loop_source = loop_source,
    source_consumed_length = round_number(source_consumed_length),
    frames_requested = math.max(1, math.floor(item_length * TARGET_SAMPLE_RATE + 0.5)),
    frames_read = 0,
    frames_silent = 0,
    chunks_read = 0,
    chunks_silent = 0,
  }

  local accessor = reaper.CreateTakeAudioAccessor(take)
  if not accessor then
    diagnostics.status = "error"
    diagnostics.error = "Could not create an audio accessor for the selected item."
    write_diagnostics(options.diagnostics_path, diagnostics)
    return nil, diagnostics.error, diagnostics
  end

  if reaper.AudioAccessorValidateState then
    diagnostics.accessor_state_changed = reaper.AudioAccessorValidateState(accessor)
  end

  local accessor_start = reaper.GetAudioAccessorStartTime and reaper.GetAudioAccessorStartTime(accessor) or item_position
  local accessor_end = reaper.GetAudioAccessorEndTime and reaper.GetAudioAccessorEndTime(accessor) or selected_end
  diagnostics.accessor_start = round_number(accessor_start)
  diagnostics.accessor_end = round_number(accessor_end)
  diagnostics.accessor_range_length = round_number(math.max(0, accessor_end - accessor_start))

  local context = {
    item_position = item_position,
    item_length = item_length,
    selected_end = selected_end,
    take_start_offset = take_start_offset,
    take_playrate = take_playrate,
    source_channels = source_channels,
    accessor_start = accessor_start,
    accessor_end = accessor_end,
  }

  local total_frames = diagnostics.frames_requested
  local buffer = reaper.new_array(CHUNK_FRAMES * source_channels)
  local candidates = build_domain_candidates(context)
  local chosen_candidate, selection_method = resolve_domain(accessor, candidates, context, total_frames, buffer, diagnostics)

  local session = {
    target_path = target_path,
    diagnostics_path = options.diagnostics_path,
    diagnostics = diagnostics,
    accessor = accessor,
    buffer = buffer,
    context = context,
    chosen_candidate = chosen_candidate,
    total_frames = total_frames,
    frames_written = 0,
    chunk_start_project = item_position,
    started_at = now_seconds(),
    completed = false,
    item_name = item_name,
    item_position = item_position,
    item_length = item_length,
    selected_end = selected_end,
    source_channels = source_channels,
    accessor_start = accessor_start,
    accessor_end = accessor_end,
    take_start_offset = take_start_offset,
    take_playrate = take_playrate,
    loop_source = loop_source,
    source_consumed_length = source_consumed_length,
  }

  if not chosen_candidate then
    return finalize_session_error(session, "Could not resolve an audio accessor time domain for the selected take.")
  end

  diagnostics.accessor_time_domain = chosen_candidate.name
  diagnostics.read_strategy = selection_method
  diagnostics.read_mode = chosen_read_mode(chosen_candidate, selection_method, context)
  diagnostics.range_mismatch = overlap_seconds(context.accessor_start, context.accessor_end, chosen_candidate.range_start, chosen_candidate.range_end) <= RANGE_EPSILON
  diagnostics.range_clamped = false

  path_utils.ensure_dir(path_utils.dirname(target_path))
  local handle, err = io.open(target_path, "wb")
  if not handle then
    session.handle = handle
    return finalize_session_error(session, "Could not open the temporary WAV file: " .. tostring(err))
  end

  session.handle = handle
  write_wav_header(handle, TARGET_SAMPLE_RATE, 1, total_frames)
  return session, nil, diagnostics
end

function M.step_export(session, options)
  options = options or {}
  if not session then
    return { status = "error", error = "No export session is active." }
  end
  if session.completed then
    if session.payload then
      return {
        status = "done",
        payload = session.payload,
        diagnostics = session.diagnostics,
        elapsed_ms = math.floor((now_seconds() - session.started_at) * 1000),
        progress = 1,
      }
    end
    return {
      status = session.cancelled and "cancelled" or "error",
      error = session.error,
      diagnostics = session.diagnostics,
      elapsed_ms = math.floor((now_seconds() - session.started_at) * 1000),
      progress = math.min(1, session.frames_written / math.max(1, session.total_frames)),
    }
  end

  local max_chunks = tonumber(options.max_chunks) or M.DEFAULT_STEP_MAX_CHUNKS
  local max_time_ms = tonumber(options.max_time_ms) or M.DEFAULT_STEP_MAX_TIME_MS
  local started_at = now_seconds()
  local chunks_processed = 0

  while session.frames_written < session.total_frames do
    local frames_to_fetch = math.min(CHUNK_FRAMES, session.total_frames - session.frames_written)
    local read_result = read_accessor_chunk(
      session.accessor,
      session.chosen_candidate,
      session.context,
      session.chunk_start_project,
      frames_to_fetch,
      session.buffer,
      session.diagnostics.read_mode == "clamped"
    )
    append_audio_chunk(session.handle, session.buffer, session.context, session.diagnostics, frames_to_fetch, read_result)
    session.frames_written = session.frames_written + frames_to_fetch
    session.chunk_start_project = session.chunk_start_project + (frames_to_fetch / TARGET_SAMPLE_RATE)
    chunks_processed = chunks_processed + 1

    if chunks_processed >= max_chunks then
      break
    end
    if max_time_ms > 0 and ((now_seconds() - started_at) * 1000) >= max_time_ms then
      break
    end
  end

  if session.frames_written >= session.total_frames then
    local payload, err, diagnostics = M.finish_export(session)
    return {
      status = payload and "done" or "error",
      payload = payload,
      error = err,
      diagnostics = diagnostics,
      elapsed_ms = math.floor((now_seconds() - session.started_at) * 1000),
      progress = 1,
      chunks_processed = chunks_processed,
      frames_written = session.frames_written,
      total_frames = session.total_frames,
    }
  end

  return {
    status = "pending",
    diagnostics = session.diagnostics,
    elapsed_ms = math.floor((now_seconds() - session.started_at) * 1000),
    progress = math.min(0.999, session.frames_written / math.max(1, session.total_frames)),
    chunks_processed = chunks_processed,
    frames_written = session.frames_written,
    total_frames = session.total_frames,
  }
end

function M.export_selected_item(target_path, options)
  local session, err, diagnostics = M.begin_export_selected_item(target_path, options)
  if not session then
    return nil, err, diagnostics
  end

  while not session.completed do
    local step = M.step_export(session, {
      max_chunks = math.huge,
      max_time_ms = 0,
    })
    if step.status == "error" then
      return nil, step.error, step.diagnostics
    end
  end

  return session.payload, nil, session.diagnostics
end

return M
