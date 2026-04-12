local luaunit = require('tests.lua.vendor.luaunit')
local formatter = require('report_presenter')
local snapshot = require('tests.lua.support.snapshot')

local tests = {}

local sample_report = {
  schema_version = 'reaper-panns-item-report/v1',
  status = 'ok',
  backend = 'mps',
  summary = 'A steady tonal signal with a narrow spectrum.',
  timing_ms = {
    total = 842,
  },
  predictions = {
    { label = 'sine tone', score = 0.94, bucket = 'strong' },
    { label = 'steady signal', score = 0.89, bucket = 'solid' },
    { label = 'tonal sound', score = 0.82, bucket = 'solid' },
    { label = 'longer clip', score = 0.42, bucket = 'possible' },
  },
  highlights = {
    { label = 'sine tone', score = 0.94, bucket = 'strong', headline = 'Strong signal' },
    { label = 'steady signal', score = 0.89, bucket = 'solid', headline = 'Clear signal' },
    { label = 'tonal sound', score = 0.82, bucket = 'solid', headline = 'Clear signal' },
  },
  warnings = {},
  error = nil,
  model_status = {
    name = 'Cnn14',
    path = '/tmp/Cnn14_mAP=0.431.pth',
  },
}

local error_report = {
  schema_version = 'reaper-panns-item-report/v1',
  status = 'error',
  backend = 'cpu',
  timing_ms = {
    total = 0,
  },
  predictions = {},
  highlights = {},
  warnings = { 'mps_requested_but_unavailable' },
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
  snapshot.assert_snapshot(formatter.error_report(error_report.error), 'error.txt')
end

function tests.test_compact_report_contains_summary()
  local report = formatter.compact_report(sample_report)
  luaunit.assertStrContains(report, 'A steady tonal signal with a narrow spectrum.')
  luaunit.assertStrContains(report, 'Press Details for the full report')
end

return tests
