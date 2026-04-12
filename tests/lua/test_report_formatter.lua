local luaunit = require('tests.lua.vendor.luaunit')
local formatter = require('report_presenter')
local snapshot = require('tests.lua.support.snapshot')

local tests = {}

local sample_report = {
  schema_version = 'reaper-panns-item-report/v1',
  status = 'ok',
  backend = 'mps',
  attempted_backends = { 'mps', 'cpu' },
  summary = 'Top detected tags: sine tone, steady signal, and tonal sound.',
  timing_ms = {
    preprocess = 118,
    inference = 724,
    total = 842,
  },
  predictions = {
    { rank = 1, label = 'sine tone', score = 0.94, bucket = 'strong', peak_score = 0.97, support_count = 3, segment_count = 3 },
    { rank = 2, label = 'steady signal', score = 0.89, bucket = 'solid', peak_score = 0.91, support_count = 3, segment_count = 3 },
    { rank = 3, label = 'tonal sound', score = 0.82, bucket = 'solid', peak_score = 0.85, support_count = 3, segment_count = 3 },
    { rank = 4, label = 'longer clip', score = 0.42, bucket = 'possible', peak_score = 0.42, support_count = 2, segment_count = 3 },
  },
  highlights = {
    { label = 'sine tone', score = 0.94, bucket = 'strong', headline = 'Likely tag', peak_score = 0.97, support_count = 3, segment_count = 3 },
    { label = 'steady signal', score = 0.89, bucket = 'solid', headline = 'Consistent tag', peak_score = 0.91, support_count = 3, segment_count = 3 },
    { label = 'tonal sound', score = 0.82, bucket = 'solid', headline = 'Consistent tag', peak_score = 0.85, support_count = 3, segment_count = 3 },
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

function tests.test_compact_report_contains_summary()
  local report = formatter.compact_report(sample_report)
  luaunit.assertStrContains(report, 'Top detected tags: sine tone, steady signal, and tonal sound.')
  luaunit.assertStrContains(report, 'Press Details for the full report')
end

function tests.test_bucket_icons_are_distinct()
  luaunit.assertEquals(formatter.bucket_icon('strong'), '🎯')
  luaunit.assertEquals(formatter.bucket_icon('solid'), '✨')
  luaunit.assertEquals(formatter.bucket_icon('possible'), '🔎')
  luaunit.assertEquals(formatter.bucket_icon('weak'), '•')
end

function tests.test_main_script_passes_ctx_to_imgui_calls()
  local handle = assert(io.open('reaper/PANNs Item Report.lua', 'rb'))
  local source = handle:read('*a')
  handle:close()

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

  for line in source:gmatch('[^\r\n]+') do
    for _, fn_name in ipairs(imgui_functions) do
      if line:find('ImGui%.' .. fn_name .. '%(') then
        luaunit.assertEquals(
          line:find('ImGui%.' .. fn_name .. '%(%s*ctx[,%)]') ~= nil,
          true,
          'Expected ctx argument in line: ' .. line
        )
      end
    end
  end
end

return tests
