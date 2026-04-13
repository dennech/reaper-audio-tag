local path_utils = require("path_utils")

local M = {}

local function now_seconds()
  if reaper and reaper.time_precise then
    return reaper.time_precise()
  end
  return os.clock()
end

local function round_ms(value)
  return math.floor(((tonumber(value) or 0) * 10) + 0.5) / 10
end

local function append_log(path, line)
  if not path then
    return
  end
  local handle = io.open(path, "ab")
  if not handle then
    return
  end
  handle:write(line)
  handle:write("\n")
  handle:close()
end

local function push_limited(list, value, limit)
  list[#list + 1] = value
  while #list > limit do
    table.remove(list, 1)
  end
end

local function top_phase(phases)
  local best_name = nil
  local best_value = 0
  for name, value in pairs(phases or {}) do
    local numeric = tonumber(value) or 0
    if numeric > best_value then
      best_name = name
      best_value = numeric
    end
  end
  return best_name, best_value
end

function M.new(log_dir, session_id)
  local basename = string.format("ui-telemetry-%s.log", path_utils.sanitize_job_id(session_id or tostring(os.time())))
  local log_path = path_utils.join(log_dir, basename)
  path_utils.ensure_dir(log_dir)
  path_utils.write_file(log_path, table.concat({
    "report_ui_telemetry_v1",
    "session=" .. path_utils.sanitize_job_id(session_id or "session"),
    "started_at=" .. os.date("!%Y-%m-%dT%H:%M:%SZ"),
    "",
  }, "\n"))

  return {
    log_path = log_path,
    log_basename = basename,
    frame_index = 0,
    average_frame_ms = 0,
    max_frame_ms = 0,
    slow_frames = 0,
    last_frame = nil,
    current_frame = nil,
    recent_events = {},
    log_every_n_frames = 45,
  }
end

function M.begin_frame(telemetry, stage)
  if not telemetry then
    return
  end
  telemetry.current_frame = {
    stage = tostring(stage or "unknown"),
    started_at = now_seconds(),
    phases = {},
    counters = {},
    labels = {},
  }
end

function M.measure(telemetry, phase_name, fn)
  if not telemetry or not telemetry.current_frame then
    return fn()
  end
  local started_at = now_seconds()
  local results = table.pack(fn())
  local elapsed_ms = (now_seconds() - started_at) * 1000
  telemetry.current_frame.phases[phase_name] = (telemetry.current_frame.phases[phase_name] or 0) + elapsed_ms
  return table.unpack(results, 1, results.n)
end

function M.record_phase(telemetry, phase_name, elapsed_ms)
  if not telemetry or not telemetry.current_frame then
    return
  end
  telemetry.current_frame.phases[phase_name] = (telemetry.current_frame.phases[phase_name] or 0) + (tonumber(elapsed_ms) or 0)
end

function M.increment_counter(telemetry, key, amount)
  if not telemetry or not telemetry.current_frame then
    return
  end
  telemetry.current_frame.counters[key] = (telemetry.current_frame.counters[key] or 0) + (tonumber(amount) or 1)
end

function M.set_counter(telemetry, key, value)
  if not telemetry or not telemetry.current_frame then
    return
  end
  telemetry.current_frame.counters[key] = tonumber(value) or 0
end

function M.set_label(telemetry, key, value)
  if not telemetry or not telemetry.current_frame then
    return
  end
  telemetry.current_frame.labels[key] = value
end

function M.note(telemetry, message)
  if not telemetry then
    return
  end
  local line = string.format("%s %s", os.date("%H:%M:%S"), tostring(message or ""))
  push_limited(telemetry.recent_events, line, 10)
  append_log(telemetry.log_path, "event " .. line)
end

function M.finish_frame(telemetry)
  if not telemetry or not telemetry.current_frame then
    return nil
  end

  local frame = telemetry.current_frame
  telemetry.current_frame = nil
  telemetry.frame_index = telemetry.frame_index + 1

  local total_ms = (now_seconds() - frame.started_at) * 1000
  frame.total_ms = total_ms

  if telemetry.frame_index == 1 then
    telemetry.average_frame_ms = total_ms
  else
    telemetry.average_frame_ms = (((telemetry.average_frame_ms or 0) * (telemetry.frame_index - 1)) + total_ms) / telemetry.frame_index
  end

  if total_ms > (telemetry.max_frame_ms or 0) then
    telemetry.max_frame_ms = total_ms
  end
  if total_ms >= 16.7 then
    telemetry.slow_frames = (telemetry.slow_frames or 0) + 1
  end

  telemetry.last_frame = frame

  local dominant_name, dominant_ms = top_phase(frame.phases)
  local should_log = total_ms >= 20 or telemetry.frame_index % telemetry.log_every_n_frames == 0
  if should_log then
    local line = string.format(
      "frame=%d stage=%s total_ms=%.1f top=%s top_ms=%.1f tags=%s visible_tags=%s poll_ms=%s export_ms=%s icon_lookups=%s icon_draws=%s",
      telemetry.frame_index,
      tostring(frame.stage or "unknown"),
      round_ms(total_ms),
      tostring(dominant_name or "none"),
      round_ms(dominant_ms),
      tostring(frame.counters.tags_total or 0),
      tostring(frame.counters.visible_tags or 0),
      tostring(round_ms(frame.phases.runtime_poll or 0)),
      tostring(round_ms(frame.phases.export_step or 0)),
      tostring(frame.counters.icon_lookups or 0),
      tostring(frame.counters.icon_draws or 0)
    )
    append_log(telemetry.log_path, line)
  end

  if total_ms >= 33 then
    push_limited(
      telemetry.recent_events,
      string.format(
        "#%d %s %.1f ms (top %s %.1f ms, tags %s, icons %s)",
        telemetry.frame_index,
        tostring(frame.stage or "unknown"),
        round_ms(total_ms),
        tostring(dominant_name or "none"),
        round_ms(dominant_ms),
        tostring(frame.counters.visible_tags or 0),
        tostring(frame.counters.icon_draws or 0)
      ),
      10
    )
  end

  return frame
end

function M.summary_lines(telemetry)
  local frame = telemetry and telemetry.last_frame or nil
  if not frame then
    return {
      "Perf: collecting first frame...",
      "Debug log: " .. tostring(telemetry and telemetry.log_basename or "n/a"),
    }
  end

  local phases = frame.phases or {}
  local counters = frame.counters or {}
  local labels = frame.labels or {}

  local line1 = string.format(
    "Perf: frame %.1f ms | avg %.1f | max %.1f | slow %d/%d",
    round_ms(frame.total_ms),
    round_ms(telemetry.average_frame_ms),
    round_ms(telemetry.max_frame_ms),
    telemetry.slow_frames or 0,
    telemetry.frame_index or 0
  )

  local line2 = string.format(
    "Stage: %s | render %.1f | export %.1f | poll %.1f | vm %.1f | tags %.1f",
    tostring(frame.stage or "unknown"),
    round_ms(phases.render_content or 0),
    round_ms(phases.export_step or 0),
    round_ms(phases.runtime_poll or 0),
    round_ms(phases.view_model or 0),
    round_ms(phases.render_tag_pills or 0)
  )

  local line3 = string.format(
    "Tags: total %s visible %s focus %s | Icons: lookup %s draw %s miss %s invalid %s",
    tostring(counters.tags_total or 0),
    tostring(counters.visible_tags or 0),
    tostring(labels.focused_tag or "none"),
    tostring(counters.icon_lookups or 0),
    tostring(counters.icon_draws or 0),
    tostring(counters.icon_misses or 0),
    tostring(counters.icon_invalidations or 0)
  )

  local line4 = string.format(
    "Debug log: %s",
    tostring(telemetry.log_basename or path_utils.basename(telemetry.log_path or "ui-telemetry.log"))
  )

  return { line1, line2, line3, line4 }
end

function M.event_lines(telemetry, limit)
  if not telemetry then
    return {}
  end
  local max_count = tonumber(limit) or 5
  local lines = {}
  local start_index = math.max(1, #telemetry.recent_events - max_count + 1)
  for index = start_index, #telemetry.recent_events do
    lines[#lines + 1] = telemetry.recent_events[index]
  end
  return lines
end

function M.log_path(telemetry)
  return telemetry and telemetry.log_path or nil
end

function M.log_basename(telemetry)
  return telemetry and telemetry.log_basename or nil
end

return M
