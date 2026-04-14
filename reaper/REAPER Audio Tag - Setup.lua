-- @noindex
-- @description REAPER Audio Tag: Setup (Deprecated)
-- @version 0.3.3
-- @author dennech
-- @link https://github.com/dennech/reaper-audio-tag

local _, script_path = reaper.get_action_context()
local script_dir = script_path:match("^(.*[\\/])") or "."

if reaper and reaper.ShowMessageBox then
  reaper.ShowMessageBox(
    "REAPER Audio Tag: Setup is deprecated.\n\nUse REAPER Audio Tag: Configure to choose your Python 3.11 path and model file. No downloads happen inside REAPER anymore.",
    "REAPER Audio Tag",
    0
  )
end

_G.REAPER_AUDIO_TAG_START_MODE = "configure"
_G.REAPER_AUDIO_TAG_OPEN_MESSAGE = "Setup is deprecated. Choose Python 3.11 and the PANNs model path in Configure."
dofile(script_dir .. "REAPER Audio Tag.lua")
