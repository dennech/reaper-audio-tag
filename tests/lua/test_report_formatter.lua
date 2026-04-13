local luaunit = require('tests.lua.vendor.luaunit')
local formatter = require('report_presenter')
local snapshot = require('tests.lua.support.snapshot')

local tests = {}

local sample_report = {
  schema_version = 'reaper-panns-item-report/v1',
  status = 'ok',
  backend = 'mps',
  attempted_backends = { 'mps', 'cpu' },
  summary = 'Top detected tags: Speech, Speech synthesizer, and Sigh.',
  timing_ms = {
    preprocess = 118,
    inference = 724,
    total = 842,
  },
  predictions = {
    { rank = 1, label = 'Speech', score = 0.78, bucket = 'strong', peak_score = 0.81, support_count = 3, segment_count = 3 },
    { rank = 2, label = 'Speech synthesizer', score = 0.67, bucket = 'solid', peak_score = 0.72, support_count = 3, segment_count = 3 },
    { rank = 3, label = 'Sigh', score = 0.66, bucket = 'solid', peak_score = 0.68, support_count = 3, segment_count = 3 },
    { rank = 4, label = 'Narration, monologue', score = 0.11, bucket = 'possible', peak_score = 0.13, support_count = 1, segment_count = 3 },
    { rank = 5, label = 'Gasp', score = 0.11, bucket = 'possible', peak_score = 0.12, support_count = 1, segment_count = 3 },
    { rank = 6, label = 'Clicking', score = 0.09, bucket = 'weak', peak_score = 0.10, support_count = 1, segment_count = 3 },
    { rank = 7, label = 'Unknown texture', score = 0.04, bucket = 'weak', peak_score = 0.06, support_count = 1, segment_count = 3 },
  },
  highlights = {
    { label = 'Speech', score = 0.78, bucket = 'strong', headline = 'Likely tag', peak_score = 0.81, support_count = 3, segment_count = 3 },
    { label = 'Speech synthesizer', score = 0.67, bucket = 'solid', headline = 'Consistent tag', peak_score = 0.72, support_count = 3, segment_count = 3 },
    { label = 'Sigh', score = 0.66, bucket = 'solid', headline = 'Consistent tag', peak_score = 0.68, support_count = 3, segment_count = 3 },
    { label = 'Narration, monologue', score = 0.11, bucket = 'possible', headline = 'Possible cue', peak_score = 0.13, support_count = 1, segment_count = 3 },
    { label = 'Gasp', score = 0.11, bucket = 'possible', headline = 'Possible cue', peak_score = 0.12, support_count = 1, segment_count = 3 },
    { label = 'Clicking', score = 0.09, bucket = 'weak', headline = 'Possible cue', peak_score = 0.10, support_count = 1, segment_count = 3 },
  },
  warnings = {},
  error = nil,
  model_status = {
    name = 'Cnn14',
    source = 'managed runtime',
  },
}

local error_report = {
  schema_version = 'reaper-panns-item-report/v1',
  status = 'error',
  stage = 'runtime',
  backend = 'cpu',
  attempted_backends = { 'mps', 'cpu' },
  timing_ms = {
    preprocess = 0,
    inference = 0,
    total = 0,
  },
  predictions = {},
  highlights = {},
  warnings = { 'mps_requested_but_unavailable' },
  summary = 'No analysis summary is available.',
  model_status = {
    name = 'Cnn14',
    source = 'managed runtime',
  },
  error = {
    code = 'missing_model',
    message = 'Model checkpoint was not found',
  },
}

local export_error_report = {
  schema_version = 'reaper-panns-item-report/v1',
  status = 'error',
  stage = 'export',
  backend = nil,
  attempted_backends = {},
  timing_ms = {
    preprocess = 0,
    inference = 0,
    total = 0,
  },
  predictions = {},
  highlights = {},
  warnings = {},
  summary = 'No analysis summary is available.',
  model_status = {
    name = 'Cnn14',
    source = 'managed runtime',
  },
  item = {
    item_position = 128.14783,
    item_length = 3.789056,
    accessor_time_domain = 'item_local',
    read_strategy = 'hinted',
    read_mode = 'clamped',
  },
  error = {
    code = 'export_failed',
    message = 'Could not read audio data from the selected take range.',
  },
}

function tests.test_compact_snapshot()
  snapshot.assert_snapshot(formatter.compact_report(sample_report), 'compact.txt')
end

function tests.test_detail_snapshot()
  snapshot.assert_snapshot(formatter.detail_report(sample_report), 'details.txt')
end

function tests.test_loading_snapshot()
  snapshot.assert_snapshot(formatter.loading_report(1275), 'loading.txt')
end

function tests.test_error_snapshot()
  snapshot.assert_snapshot(formatter.error_report(error_report), 'error.txt')
end

function tests.test_export_error_snapshot()
  snapshot.assert_snapshot(formatter.error_report(export_error_report), 'error_export.txt')
end

function tests.test_compact_report_contains_summary()
  local report = formatter.compact_report(sample_report)
  luaunit.assertStrContains(report, 'Top detected tags: Speech, Speech synthesizer, and Sigh.')
  luaunit.assertStrContains(report, '🔍 More')
  luaunit.assertStrContains(report, '✨ Tags ✨')
end

function tests.test_bucket_icons_are_distinct()
  luaunit.assertEquals(formatter.bucket_icon('strong'), '🎯')
  luaunit.assertEquals(formatter.bucket_icon('solid'), '🌟')
  luaunit.assertEquals(formatter.bucket_icon('possible'), '🫧')
  luaunit.assertEquals(formatter.bucket_icon('weak'), '💭')
end

function tests.test_bucket_icons_have_safe_fallbacks()
  luaunit.assertEquals(formatter.bucket_icon('strong', 'fallback'), '✦')
  luaunit.assertEquals(formatter.bucket_icon('solid', 'fallback'), '✷')
  luaunit.assertEquals(formatter.bucket_icon('possible', 'fallback'), '❋')
  luaunit.assertEquals(formatter.bucket_icon('weak', 'fallback'), '·')
end

function tests.test_label_emoji_uses_semantic_mapping()
  luaunit.assertEquals(formatter.label_emoji('Speech', 'emoji', 'strong'), '🎙️')
  luaunit.assertEquals(formatter.label_emoji('Speech synthesizer', 'emoji', 'solid'), '🎛️')
  luaunit.assertEquals(formatter.label_emoji('Sigh', 'emoji', 'solid'), '😮‍💨')
  luaunit.assertEquals(formatter.label_emoji('Narration, monologue', 'emoji', 'possible'), '🎙️')
  luaunit.assertEquals(formatter.label_emoji('Gasp', 'emoji', 'possible'), '😮‍💨')
  luaunit.assertEquals(formatter.label_emoji('Clicking', 'emoji', 'weak'), '🖱️')
end

function tests.test_label_emoji_uses_safe_fallback_symbols()
  luaunit.assertEquals(formatter.label_emoji('Speech', 'fallback', 'strong'), '✦')
  luaunit.assertEquals(formatter.label_emoji('Speech synthesizer', 'fallback', 'solid'), '✷')
  luaunit.assertEquals(formatter.label_emoji('Sigh', 'fallback', 'solid'), '❋')
  luaunit.assertEquals(formatter.label_emoji('Clicking', 'fallback', 'weak'), '⌘')
  luaunit.assertEquals(formatter.label_emoji('Music', 'fallback', 'solid'), '♪')
end

function tests.test_label_emoji_falls_back_to_bucket_icon_for_unknown_label()
  luaunit.assertEquals(formatter.label_emoji('Unknown texture', 'emoji', 'weak'), '💭')
  luaunit.assertEquals(formatter.label_emoji('Unknown texture', 'fallback', 'weak'), '·')
end

function tests.test_main_script_passes_ctx_to_imgui_calls()
  local handle = assert(io.open('reaper/PANNs Item Report.lua', 'rb'))
  local source = handle:read('*a')
  handle:close()
  local compact_source = source:gsub('%s+', ' ')

  local imgui_functions = {
    'Text',
    'TextWrapped',
    'TextDisabled',
    'TextColored',
    'BulletText',
    'ProgressBar',
    'SameLine',
    'Spacing',
    'Separator',
  }

  for _, fn_name in ipairs(imgui_functions) do
    for call in compact_source:gmatch('ImGui%.' .. fn_name .. '%b()') do
      luaunit.assertEquals(
        call:find('ImGui%.' .. fn_name .. '%(%s*ctx[,%)]') ~= nil,
        true,
        'Expected ctx argument in call: ' .. call
      )
    end
  end
end

function tests.test_main_script_uses_monotonic_progress()
  local handle = assert(io.open('reaper/PANNs Item Report.lua', 'rb'))
  local source = handle:read('*a')
  handle:close()

  luaunit.assertEquals(source:find('math%.sin%(') ~= nil, false)
  luaunit.assertEquals(source:find('math%.cos%(') ~= nil, false)
  luaunit.assertStrContains(source, 'math.min(0.99, state.last_loading_ms / (timeout_sec * 1000))')
end

function tests.test_main_script_uses_unique_ids_for_clickable_tags()
  local handle = assert(io.open('reaper/PANNs Item Report.lua', 'rb'))
  local source = handle:read('*a')
  handle:close()

  luaunit.assertStrContains(source, 'ImGui.PushID(ctx')
  luaunit.assertStrContains(source, '##chip')
  luaunit.assertStrContains(source, 'report_ui_state.focus_tag(state')
end

function tests.test_main_script_exposes_open_log_for_export_failures()
  local handle = assert(io.open('reaper/PANNs Item Report.lua', 'rb'))
  local source = handle:read('*a')
  handle:close()

  luaunit.assertStrContains(source, 'state.export_log_file')
  luaunit.assertStrContains(source, 'ImGui.Button(ctx, "Open log")')
  luaunit.assertStrContains(source, 'audio_export.export_selected_item(export_path, {')
  luaunit.assertStrContains(source, 'diagnostics_path = export_log_path')
end

function tests.test_debug_export_script_loads()
  luaunit.assertEquals(loadfile('reaper/PANNs Item Report - Debug Export.lua') ~= nil, true)
end

function tests.test_export_error_report_hides_runtime_backend_attempts()
  local report = formatter.error_report(export_error_report)
  luaunit.assertEquals(report:find('Tried:', 1, true), nil)
  luaunit.assertStrContains(report, 'Accessor: item_local')
  luaunit.assertStrContains(report, 'Read: hinted / clamped')
end

function tests.test_main_script_uses_another_button_and_selection_notice()
  local handle = assert(io.open('reaper/PANNs Item Report.lua', 'rb'))
  local source = handle:read('*a')
  handle:close()

  luaunit.assertStrContains(source, 'ImGui.Button(ctx, "Another")')
  luaunit.assertStrContains(source, 'preserve_result_if_selection_invalid = true')
  luaunit.assertStrContains(source, 'state.notice = err')
end

function tests.test_main_script_cleans_up_run_artifacts()
  local handle = assert(io.open('reaper/PANNs Item Report.lua', 'rb'))
  local source = handle:read('*a')
  handle:close()

  luaunit.assertStrContains(source, 'report_run_cleanup.prune_stale(paths)')
  luaunit.assertStrContains(source, 'report_run_cleanup.clear_temp_audio(paths, state.run_artifacts)')
  luaunit.assertStrContains(source, 'cleanup_current_run()')
end

function tests.test_compact_report_uses_expanded_limits()
  local report = formatter.compact_report(sample_report)
  luaunit.assertStrContains(report, 'Narration, monologue 11%')
  luaunit.assertStrContains(report, 'Clicking 9%')
  luaunit.assertEquals(report:find('Unknown texture 4%%') ~= nil, false)
end

return tests
