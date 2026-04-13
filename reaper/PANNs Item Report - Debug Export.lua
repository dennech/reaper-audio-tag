-- Compatibility shim for existing REAPER actions saved with the legacy script path.
local _, script_path = reaper.get_action_context()
local script_dir = script_path:match("^(.*[\\/])") or "."

dofile(script_dir .. "REAPER Audio Tag - Debug Export.lua")
