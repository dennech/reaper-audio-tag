local luaunit = require('tests.lua.vendor.luaunit')
local audio_export = require('audio_export')
local path_utils = require('path_utils')

local tests = {}

local function mktemp_dir()
  local handle = io.popen('mktemp -d')
  local dir = handle:read('*l')
  handle:close()
  return dir
end

local function fake_buffer()
  return setmetatable({}, {
    __index = function(table_ref, key)
      return rawget(table_ref, key) or 0
    end,
  })
end

local function fill_buffer(buffer, num_channels, frames, value)
  for frame = 0, frames - 1 do
    for channel = 1, num_channels do
      buffer[(frame * num_channels) + channel] = value
    end
  end
end

local function approx(value, expected)
  return math.abs((tonumber(value) or 0) - expected) < 0.00001
end

local function with_fake_reaper(config, callback)
  local original_reaper = _G.reaper
  local temp_root = mktemp_dir()
  local capture = {
    calls = {},
    temp_root = temp_root,
  }

  local item = {}
  local take = {}
  local source = {}
  local accessor = {}

  local item_position = config.item_position or 12.5
  local item_length = config.item_length or 0.05
  local accessor_start = config.accessor_start
  if accessor_start == nil then
    accessor_start = item_position
  end
  local accessor_end = config.accessor_end
  if accessor_end == nil then
    accessor_end = item_position + item_length
  end
  local source_channels = config.source_channels or 2
  local take_start_offset = config.take_start_offset or 0
  local take_playrate = config.take_playrate or 1
  local loop_source = config.loop_source and 1 or 0
  local source_path = config.source_path or '/tmp/source.wav'
  local take_name = config.take_name
  if take_name == nil then
    take_name = 'Trimmed Clip'
  end

  _G.reaper = {
    CountSelectedMediaItems = function()
      return config.selected_count or 1
    end,
    GetSelectedMediaItem = function()
      return config.no_item and nil or item
    end,
    GetActiveTake = function()
      return config.no_take and nil or take
    end,
    TakeIsMIDI = function()
      return config.is_midi or false
    end,
    GetMediaItemInfo_Value = function(_, key)
      if key == 'D_POSITION' then
        return item_position
      end
      if key == 'D_LENGTH' then
        return item_length
      end
      if key == 'B_LOOPSRC' then
        return loop_source
      end
      return 0
    end,
    GetMediaItemTake_Source = function()
      return source
    end,
    GetMediaSourceNumChannels = function()
      return source_channels
    end,
    GetMediaSourceFileName = function()
      return source_path
    end,
    GetTakeName = function()
      return take_name
    end,
    GetMediaItemTakeInfo_Value = function(_, key)
      if key == 'D_STARTOFFS' then
        return take_start_offset
      end
      if key == 'D_PLAYRATE' then
        return take_playrate
      end
      return 0
    end,
    CreateTakeAudioAccessor = function()
      if config.fail_create_accessor then
        return nil
      end
      return accessor
    end,
    AudioAccessorValidateState = function()
      return config.validate_state_return or false
    end,
    GetAudioAccessorStartTime = function()
      return accessor_start
    end,
    GetAudioAccessorEndTime = function()
      return accessor_end
    end,
    GetAudioAccessorSamples = function(_, sample_rate, num_channels, starttime_sec, numsamplesperchannel, buffer)
      capture.calls[#capture.calls + 1] = {
        sample_rate = sample_rate,
        num_channels = num_channels,
        starttime_sec = starttime_sec,
        numsamplesperchannel = numsamplesperchannel,
      }
      local handler = config.sample_handler or function(args)
        fill_buffer(args.buffer, args.num_channels, args.numsamplesperchannel, 0.25)
        return 1
      end
      return handler({
        sample_rate = sample_rate,
        num_channels = num_channels,
        starttime_sec = starttime_sec,
        numsamplesperchannel = numsamplesperchannel,
        buffer = buffer,
        call_index = #capture.calls,
      })
    end,
    DestroyAudioAccessor = function()
    end,
    RecursiveCreateDirectory = function(path)
      os.execute('mkdir -p ' .. path_utils.sh_quote(path))
    end,
    new_array = function()
      return fake_buffer()
    end,
  }

  local ok, err = xpcall(function()
    callback(capture, temp_root)
  end, debug.traceback)

  _G.reaper = original_reaper
  os.execute('rm -rf ' .. path_utils.sh_quote(temp_root))

  if not ok then
    error(err)
  end
end

function tests.test_export_uses_project_domain_when_accessor_matches_project_time()
  with_fake_reaper({
    item_position = 12.5,
    item_length = 0.05,
    accessor_start = 12.5,
    accessor_end = 12.55,
    source_channels = 2,
    take_start_offset = 2.25,
    take_playrate = 1.5,
    validate_state_return = true,
  }, function(capture, temp_root)
    local target_path = path_utils.join(temp_root, 'project.wav')
    local diagnostics_path = path_utils.join(temp_root, 'project.log')
    local payload, err = audio_export.export_selected_item(target_path, {
      diagnostics_path = diagnostics_path,
    })

    luaunit.assertEquals(err, nil)
    luaunit.assertEquals(payload ~= nil, true)
    luaunit.assertEquals(#capture.calls >= 2, true)
    luaunit.assertEquals(capture.calls[1].starttime_sec, 12.5)
    luaunit.assertEquals(capture.calls[1].numsamplesperchannel, 1600)
    luaunit.assertEquals(capture.calls[2].starttime_sec, 12.5)
    luaunit.assertEquals(payload.item_metadata.accessor_time_domain, 'project')
    luaunit.assertEquals(payload.item_metadata.read_strategy, 'hinted')
    luaunit.assertEquals(payload.item_metadata.read_mode, 'clamped')
    luaunit.assertEquals(payload.item_metadata.accessor_state_changed, true)
    luaunit.assertEquals(payload.item_metadata.probe_candidates_tried[1], 'project')
    luaunit.assertEquals(payload.item_metadata.probe_domain_selected, 'project')
  end)
end

function tests.test_export_uses_item_local_domain_for_live_looped_shape()
  with_fake_reaper({
    item_position = 128.14783,
    item_length = 3.789056,
    accessor_start = 0.0,
    accessor_end = 3.789056,
    source_channels = 2,
    take_name = '23-1.wav',
    take_start_offset = 128.14783,
    take_playrate = 1.0,
    loop_source = true,
    sample_handler = function(args)
      if approx(args.starttime_sec, 0.0) and args.numsamplesperchannel == 2048 then
        fill_buffer(args.buffer, args.num_channels, args.numsamplesperchannel, 0.3)
        return 1
      end
      fill_buffer(args.buffer, args.num_channels, args.numsamplesperchannel, 0.3)
      return 1
    end,
  }, function(capture, temp_root)
    local target_path = path_utils.join(temp_root, 'live-shape.wav')
    local diagnostics_path = path_utils.join(temp_root, 'live-shape.log')
    local payload, err = audio_export.export_selected_item(target_path, {
      diagnostics_path = diagnostics_path,
    })

    luaunit.assertEquals(err, nil)
    luaunit.assertEquals(payload ~= nil, true)
    luaunit.assertEquals(capture.calls[1].starttime_sec, 0.0)
    luaunit.assertEquals(payload.item_metadata.accessor_time_domain, 'item_local')
    luaunit.assertEquals(payload.item_metadata.read_strategy, 'hinted')
    luaunit.assertEquals(payload.item_metadata.read_mode, 'clamped')
    luaunit.assertEquals(payload.item_metadata.loop_source, true)
    luaunit.assertEquals(payload.item_metadata.probe_domain_selected, 'item_local')
    luaunit.assertEquals(payload.item_metadata.source_consumed_length, 3.789056)
    luaunit.assertEquals(payload.item_metadata.frames_read > 0, true)

    local diagnostics = assert(path_utils.read_file(diagnostics_path))
    luaunit.assertStrContains(diagnostics, 'item_name=23-1.wav')
    luaunit.assertStrContains(diagnostics, 'accessor_time_domain=item_local')
  end)
end

function tests.test_export_uses_take_source_domain_when_accessor_matches_source_time()
  with_fake_reaper({
    item_position = 24.0,
    item_length = 0.05,
    accessor_start = 10.0,
    accessor_end = 10.1,
    source_channels = 1,
    take_start_offset = 10.0,
    take_playrate = 2.0,
    sample_handler = function(args)
      if approx(args.starttime_sec, 10.0) then
        fill_buffer(args.buffer, args.num_channels, args.numsamplesperchannel, 0.5)
        return 1
      end
      return 0
    end,
  }, function(capture, temp_root)
    local payload, err = audio_export.export_selected_item(path_utils.join(temp_root, 'source.wav'), {
      diagnostics_path = path_utils.join(temp_root, 'source.log'),
    })

    luaunit.assertEquals(err, nil)
    luaunit.assertEquals(payload ~= nil, true)
    luaunit.assertEquals(capture.calls[1].starttime_sec, 10.0)
    luaunit.assertEquals(payload.item_metadata.accessor_time_domain, 'take_source')
    luaunit.assertEquals(payload.item_metadata.read_strategy, 'hinted')
    luaunit.assertEquals(payload.item_metadata.read_mode, 'clamped')
    luaunit.assertEquals(payload.item_metadata.take_playrate, 2.0)
    luaunit.assertEquals(payload.item_metadata.source_consumed_length, 0.1)
  end)
end

function tests.test_export_probes_item_local_when_hints_are_ambiguous()
  with_fake_reaper({
    item_position = 30.0,
    item_length = 0.05,
    accessor_start = 8.0,
    accessor_end = 8.2,
    source_channels = 1,
    sample_handler = function(args)
      if approx(args.starttime_sec, 0.0) then
        fill_buffer(args.buffer, args.num_channels, args.numsamplesperchannel, 0.33)
        return 1
      end
      return 0
    end,
  }, function(capture, temp_root)
    local payload, err = audio_export.export_selected_item(path_utils.join(temp_root, 'probe-item-local.wav'), {
      diagnostics_path = path_utils.join(temp_root, 'probe-item-local.log'),
    })

    luaunit.assertEquals(err, nil)
    luaunit.assertEquals(payload ~= nil, true)
    luaunit.assertEquals(payload.item_metadata.accessor_time_domain, 'item_local')
    luaunit.assertEquals(payload.item_metadata.read_strategy, 'probed')
    luaunit.assertEquals(payload.item_metadata.read_mode, 'direct')
    luaunit.assertEquals(payload.item_metadata.probe_candidates_tried[1], 'item_local')
    luaunit.assertEquals(payload.item_metadata.probe_candidates_tried[2], 'project')
    luaunit.assertEquals(payload.item_metadata.probe_candidates_tried[3], 'take_source')
    luaunit.assertEquals(payload.item_metadata.probe_frames_read > 0, true)
    luaunit.assertEquals(capture.calls[1].starttime_sec, 0.0)
  end)
end

function tests.test_export_probes_take_source_when_hints_are_ambiguous()
  with_fake_reaper({
    item_position = 14.0,
    item_length = 0.05,
    accessor_start = 300.0,
    accessor_end = 300.2,
    source_channels = 1,
    take_start_offset = 77.0,
    take_playrate = 1.25,
    sample_handler = function(args)
      if approx(args.starttime_sec, 77.0) then
        fill_buffer(args.buffer, args.num_channels, args.numsamplesperchannel, 0.4)
        return 1
      end
      return 0
    end,
  }, function(capture, temp_root)
    local payload, err = audio_export.export_selected_item(path_utils.join(temp_root, 'probe-source.wav'), {
      diagnostics_path = path_utils.join(temp_root, 'probe-source.log'),
    })

    luaunit.assertEquals(err, nil)
    luaunit.assertEquals(payload ~= nil, true)
    luaunit.assertEquals(payload.item_metadata.accessor_time_domain, 'take_source')
    luaunit.assertEquals(payload.item_metadata.read_strategy, 'probed')
    luaunit.assertEquals(payload.item_metadata.read_mode, 'direct')
    luaunit.assertEquals(payload.item_metadata.probe_domain_selected, 'take_source')
    luaunit.assertEquals(capture.calls[#capture.calls].starttime_sec, 77.0)
  end)
end

function tests.test_export_marks_partial_read_as_clamped()
  with_fake_reaper({
    item_position = 20.0,
    item_length = 0.05,
    accessor_start = 0.0,
    accessor_end = 0.04,
    source_channels = 1,
    take_start_offset = 5.0,
    sample_handler = function(args)
      if approx(args.starttime_sec, 0.0) and args.numsamplesperchannel == 1280 then
        fill_buffer(args.buffer, args.num_channels, args.numsamplesperchannel, 0.5)
        return 1
      end
      return 0
    end,
  }, function(capture, temp_root)
    local payload, err = audio_export.export_selected_item(path_utils.join(temp_root, 'clamped.wav'), {
      diagnostics_path = path_utils.join(temp_root, 'clamped.log'),
    })

    luaunit.assertEquals(err, nil)
    luaunit.assertEquals(payload ~= nil, true)
    luaunit.assertEquals(#capture.calls >= 1, true)
    luaunit.assertEquals(payload.item_metadata.accessor_time_domain, 'item_local')
    luaunit.assertEquals(payload.item_metadata.read_strategy, 'hinted')
    luaunit.assertEquals(payload.item_metadata.read_mode, 'clamped')
    luaunit.assertEquals(payload.item_metadata.range_clamped, true)
    luaunit.assertEquals(payload.item_metadata.frames_read, 1280)
    luaunit.assertEquals(payload.item_metadata.frames_silent, 320)
  end)
end

function tests.test_export_fails_only_when_all_domains_are_unreadable()
  with_fake_reaper({
    item_position = 50.0,
    item_length = 0.05,
    accessor_start = 0.0,
    accessor_end = 1.0,
    source_channels = 1,
    sample_handler = function()
      return 0
    end,
  }, function(capture, temp_root)
    local target_path = path_utils.join(temp_root, 'empty.wav')
    local diagnostics_path = path_utils.join(temp_root, 'empty.log')
    local payload, err, diagnostics = audio_export.export_selected_item(target_path, {
      diagnostics_path = diagnostics_path,
    })

    luaunit.assertEquals(payload, nil)
    luaunit.assertEquals(err, 'Could not read audio data from the selected take range.')
    luaunit.assertEquals(diagnostics.status, 'error')
    luaunit.assertEquals(diagnostics.frames_read, 0)
    luaunit.assertEquals(diagnostics.chunks_read, 0)
    luaunit.assertEquals(#diagnostics.probe_candidates_tried, 3)
    luaunit.assertEquals(path_utils.exists(target_path), false)

    local diagnostics_text = assert(path_utils.read_file(diagnostics_path))
    luaunit.assertStrContains(diagnostics_text, 'status=error')
    luaunit.assertStrContains(diagnostics_text, 'probe_candidates_tried=')
    luaunit.assertStrContains(diagnostics_text, 'probe_domain_selected=')
  end)
end

function tests.test_export_rejects_midi_items()
  with_fake_reaper({
    is_midi = true,
  }, function(_, temp_root)
    local payload, err, diagnostics = audio_export.export_selected_item(path_utils.join(temp_root, 'midi.wav'), {
      diagnostics_path = path_utils.join(temp_root, 'midi.log'),
    })

    luaunit.assertEquals(payload, nil)
    luaunit.assertEquals(err, 'The selected item is MIDI. Please choose an audio item.')
    luaunit.assertEquals(diagnostics.error, 'The selected item is MIDI. Please choose an audio item.')
    luaunit.assertEquals(diagnostics.error_kind, 'selection')
  end)
end

function tests.test_export_rejects_zero_length_items()
  with_fake_reaper({
    item_length = 0,
  }, function(_, temp_root)
    local payload, err, diagnostics = audio_export.export_selected_item(path_utils.join(temp_root, 'zero.wav'), {
      diagnostics_path = path_utils.join(temp_root, 'zero.log'),
    })

    luaunit.assertEquals(payload, nil)
    luaunit.assertEquals(err, 'The selected item has zero length.')
    luaunit.assertEquals(diagnostics.error, 'The selected item has zero length.')
    luaunit.assertEquals(diagnostics.error_kind, 'selection')
  end)
end

function tests.test_export_reports_missing_take_accessor()
  with_fake_reaper({
    fail_create_accessor = true,
  }, function(_, temp_root)
    local payload, err, diagnostics = audio_export.export_selected_item(path_utils.join(temp_root, 'accessor.wav'), {
      diagnostics_path = path_utils.join(temp_root, 'accessor.log'),
    })

    luaunit.assertEquals(payload, nil)
    luaunit.assertEquals(err, 'Could not create an audio accessor for the selected item.')
    luaunit.assertEquals(diagnostics.status, 'error')
  end)
end

return tests
