local luaunit = require('tests.lua.vendor.luaunit')
local path_utils = require('path_utils')
local report_run_cleanup = require('report_run_cleanup')

local tests = {}

local function mktemp_dir()
  local handle = io.popen('mktemp -d')
  local dir = handle:read('*l')
  handle:close()
  return dir
end

local function write_file(path, contents)
  path_utils.ensure_dir(path_utils.dirname(path))
  local handle = assert(io.open(path, 'wb'))
  handle:write(contents or 'test')
  handle:close()
end

local function touch_days_ago(path, days)
  local timestamp = os.time() - (days * 24 * 60 * 60)
  os.execute('touch -amt ' .. os.date('%Y%m%d%H%M.%S', timestamp) .. ' ' .. path_utils.sh_quote(path))
end

local function with_temp_paths(callback)
  local root = mktemp_dir()
  local paths = {
    tmp_dir = path_utils.join(root, 'tmp'),
    logs_dir = path_utils.join(root, 'logs'),
    jobs_dir = path_utils.join(root, 'jobs'),
  }
  path_utils.ensure_dir(paths.tmp_dir)
  path_utils.ensure_dir(paths.logs_dir)
  path_utils.ensure_dir(paths.jobs_dir)

  local ok, err = xpcall(function()
    callback(root, paths)
  end, debug.traceback)

  os.execute('rm -rf ' .. path_utils.sh_quote(root))
  if not ok then
    error(err)
  end
end

function tests.test_cleanup_run_removes_only_managed_artifacts()
  with_temp_paths(function(root, paths)
    local export_path = path_utils.join(paths.tmp_dir, 'selected-item-guid.wav')
    local export_log = path_utils.join(paths.logs_dir, 'export-guid.log')
    local job_dir = path_utils.join(paths.jobs_dir, 'job-guid')
    local request_file = path_utils.join(job_dir, 'request.json')
    local result_file = path_utils.join(job_dir, 'result.json')
    local runtime_log = path_utils.join(job_dir, 'runtime.log')
    local source_file = path_utils.join(root, 'source.wav')

    write_file(export_path)
    write_file(export_log)
    write_file(request_file)
    write_file(result_file)
    write_file(runtime_log)
    write_file(source_file, 'source')

    report_run_cleanup.cleanup_run(paths, report_run_cleanup.new_artifacts(export_path, export_log, {
      job_dir = job_dir,
      request_file = request_file,
      result_file = result_file,
      log_file = runtime_log,
    }))

    luaunit.assertEquals(path_utils.exists(export_path), false)
    luaunit.assertEquals(path_utils.exists(export_log), false)
    luaunit.assertEquals(path_utils.directory_exists(job_dir), false)
    luaunit.assertEquals(path_utils.exists(source_file), true)
  end)
end

function tests.test_clear_temp_audio_keeps_logs_until_run_is_replaced()
  with_temp_paths(function(_, paths)
    local export_path = path_utils.join(paths.tmp_dir, 'selected-item-guid.wav')
    local export_log = path_utils.join(paths.logs_dir, 'export-guid.log')

    write_file(export_path)
    write_file(export_log)

    local artifacts = report_run_cleanup.new_artifacts(export_path, export_log, nil)
    report_run_cleanup.clear_temp_audio(paths, artifacts)

    luaunit.assertEquals(path_utils.exists(export_path), false)
    luaunit.assertEquals(path_utils.exists(export_log), true)
  end)
end

function tests.test_prune_stale_removes_old_artifacts_only()
  with_temp_paths(function(_, paths)
    local stale_export = path_utils.join(paths.tmp_dir, 'selected-item-old.wav')
    local fresh_export = path_utils.join(paths.tmp_dir, 'selected-item-new.wav')
    local stale_log = path_utils.join(paths.logs_dir, 'export-old.log')
    local fresh_log = path_utils.join(paths.logs_dir, 'export-new.log')
    local stale_job_dir = path_utils.join(paths.jobs_dir, 'job-old')
    local fresh_job_dir = path_utils.join(paths.jobs_dir, 'job-new')
    local outside_file = path_utils.join(path_utils.dirname(paths.tmp_dir), 'outside.txt')

    write_file(stale_export)
    write_file(fresh_export)
    write_file(stale_log)
    write_file(fresh_log)
    write_file(path_utils.join(stale_job_dir, 'runtime.log'))
    write_file(path_utils.join(fresh_job_dir, 'runtime.log'))
    write_file(outside_file, 'outside')

    touch_days_ago(stale_export, 9)
    touch_days_ago(stale_log, 9)
    touch_days_ago(stale_job_dir, 9)
    touch_days_ago(path_utils.join(stale_job_dir, 'runtime.log'), 9)
    touch_days_ago(fresh_export, 1)
    touch_days_ago(fresh_log, 1)
    touch_days_ago(fresh_job_dir, 1)
    touch_days_ago(path_utils.join(fresh_job_dir, 'runtime.log'), 1)

    report_run_cleanup.prune_stale(paths, {
      now = os.time(),
      retention_sec = 7 * 24 * 60 * 60,
    })

    luaunit.assertEquals(path_utils.exists(stale_export), false)
    luaunit.assertEquals(path_utils.exists(stale_log), false)
    luaunit.assertEquals(path_utils.directory_exists(stale_job_dir), false)
    luaunit.assertEquals(path_utils.exists(fresh_export), true)
    luaunit.assertEquals(path_utils.exists(fresh_log), true)
    luaunit.assertEquals(path_utils.directory_exists(fresh_job_dir), true)
    luaunit.assertEquals(path_utils.exists(outside_file), true)
  end)
end

return tests
