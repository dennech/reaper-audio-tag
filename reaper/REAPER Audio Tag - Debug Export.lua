local _, script_path = reaper.get_action_context()
local script_dir = script_path:match("^(.*[\\/])") or "."
package.path = table.concat({
  script_dir .. "lib/?.lua",
  package.path,
}, ";")

local app_paths = require("app_paths")
local audio_export = require("audio_export")
local path_utils = require("path_utils")

local paths = app_paths.build()
path_utils.ensure_dir(paths.logs_dir)
path_utils.ensure_dir(paths.tmp_dir)

local debug_id = path_utils.sanitize_job_id(reaper.genGuid(""))
local export_path = path_utils.join(paths.tmp_dir, "debug-selected-item-" .. debug_id .. ".wav")
local diagnostics_path = path_utils.join(paths.logs_dir, "debug-export-" .. debug_id .. ".log")

local payload, err, diagnostics = audio_export.export_selected_item(export_path, {
  diagnostics_path = diagnostics_path,
})

local lines = {
  "REAPER Audio Tag Export Debug",
  "",
}

if payload then
  local item = payload.item_metadata or {}
  lines[#lines + 1] = "Status: ok"
  lines[#lines + 1] = "Item: " .. tostring(item.item_name or "Unknown")
  lines[#lines + 1] = string.format("Selected range: %.2fs -> %.2fs", tonumber(item.item_position) or 0, tonumber(item.selected_end) or 0)
  lines[#lines + 1] = "Accessor domain: " .. tostring(item.accessor_time_domain or "n/a")
  lines[#lines + 1] = string.format("Read: %s / %s", tostring(item.read_strategy or "n/a"), tostring(item.read_mode or "n/a"))
  lines[#lines + 1] = string.format("Frames: %s read, %s silent", tostring(item.frames_read or 0), tostring(item.frames_silent or 0))
  lines[#lines + 1] = "Log: " .. diagnostics_path
  os.remove(export_path)
else
  lines[#lines + 1] = "Status: error"
  lines[#lines + 1] = tostring(err)
  if diagnostics and diagnostics.accessor_time_domain then
    lines[#lines + 1] = "Accessor domain: " .. tostring(diagnostics.accessor_time_domain)
  end
  if diagnostics and diagnostics.read_strategy then
    lines[#lines + 1] = string.format("Read: %s / %s", tostring(diagnostics.read_strategy), tostring(diagnostics.read_mode or "n/a"))
  end
  lines[#lines + 1] = "Log: " .. diagnostics_path
end

reaper.ShowMessageBox(table.concat(lines, "\n"), "REAPER Audio Tag - Debug Export", 0)
