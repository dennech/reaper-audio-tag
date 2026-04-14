-- @noindex
-- @description REAPER Audio Tag: Configure
-- @version 0.3.1
-- @author dennech
-- @link https://github.com/dennech/reaper-audio-tag

local _, script_path = reaper.get_action_context()
local script_dir = script_path:match("^(.*[\\/])") or "."

_G.REAPER_AUDIO_TAG_START_MODE = "configure"
dofile(script_dir .. "REAPER Audio Tag.lua")
