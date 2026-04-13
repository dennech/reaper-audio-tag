local luaunit = require("tests.lua.vendor.luaunit")
local report_icons = require("report_icons")
local report_icon_map = require("report_icon_map")

local tests = {}

local function shipped_labels()
  local labels = {}
  local handle = assert(io.open("runtime/src/reaper_panns_runtime/_vendor/metadata/class_labels_indices.csv", "rb"))
  for line in handle:lines() do
    if not line:match("^index,") then
      local quoted = line:match('^%d+,[^,]+,"(.*)"$')
      local plain = line:match("^%d+,[^,]+,([^,]+)$")
      labels[#labels + 1] = quoted or plain
    end
  end
  handle:close()
  return labels
end

function tests.test_icon_catalog_is_noto_based()
  local names = report_icons.icon_names()
  luaunit.assertEquals(#names >= 60, true)
  luaunit.assertEquals(names[1], "brand")
  luaunit.assertEquals(names[2], "ready")
  luaunit.assertEquals(names[3], "loading")
  luaunit.assertEquals(report_icons.upstream_repo(), "https://github.com/googlefonts/noto-emoji")
  luaunit.assertEquals(report_icons.upstream_commit(), "8998f5dd683424a73e2314a8c1f1e359c19e8742")
  luaunit.assertEquals(report_icons.upstream_image_license(), "Apache-2.0")
  luaunit.assertEquals(report_icons.upstream_font_license(), "OFL-1.1")
end

function tests.test_icon_png_data_decodes_png_headers()
  for _, icon_key in ipairs({ "speech", "synth", "breath", "click", "music", "generic", "brand", "ready", "tags" }) do
    local png = report_icons.icon_png_data(icon_key)
    luaunit.assertEquals(png ~= nil, true)
    luaunit.assertEquals(png:sub(1, 8), "\137PNG\r\n\26\n")
  end
end

function tests.test_unknown_icon_returns_nil()
  luaunit.assertEquals(report_icons.icon_png_data("missing"), nil)
end

function tests.test_full_shipped_label_set_maps_to_known_icons()
  local labels = shipped_labels()
  luaunit.assertEquals(#labels, report_icon_map.label_count())
  for _, label in ipairs(labels) do
    local icon_key = report_icon_map.label_icon_key(label)
    luaunit.assertEquals(report_icon_map.has_known_label(label), true, label)
    luaunit.assertEquals(icon_key ~= "generic", true, label)
    luaunit.assertEquals(report_icons.icon_png_data(icon_key) ~= nil, true, label .. " -> " .. tostring(icon_key))
  end
end

function tests.test_unknown_runtime_label_falls_back_to_generic_icon()
  luaunit.assertEquals(report_icon_map.has_known_label("Totally unknown synthetic label"), false)
  luaunit.assertEquals(report_icon_map.label_icon_key("Totally unknown synthetic label"), "generic")
  luaunit.assertEquals(report_icons.icon_png_data("generic") ~= nil, true)
end

function tests.test_image_invalidates_bad_handle()
  local cache = {
    loaded = true,
    available = true,
    images = {
      speech = { valid = false },
    },
  }
  local fake_imgui = {
    ValidatePtr = function(image, kind)
      return kind == "ImGui_Image*" and image.valid == true
    end,
  }

  luaunit.assertEquals(report_icons.image(fake_imgui, cache, "speech"), nil)
  luaunit.assertEquals(cache.images.speech, nil)
  luaunit.assertEquals(cache.loaded, false)
  luaunit.assertEquals(cache.available, false)
end

function tests.test_ensure_loaded_recreates_invalid_handles()
  local created = 0
  local cache = {
    loaded = true,
    available = true,
    images = {
      speech = { valid = false },
    },
  }
  local fake_imgui = {
    ValidatePtr = function(image, kind)
      return kind == "ImGui_Image*" and image.valid == true
    end,
    CreateImageFromMem = function(data)
      created = created + 1
      return { valid = true, data = data, id = created }
    end,
  }

  report_icons.invalidate(cache, "speech")
  report_icons.ensure_loaded(fake_imgui, cache)

  luaunit.assertEquals(created > 0, true)
  luaunit.assertEquals(cache.loaded, true)
  luaunit.assertEquals(cache.available, true)
  luaunit.assertEquals(cache.images.speech.valid, true)
end

function tests.test_ensure_loaded_skips_full_reload_for_warm_cache()
  local validate_calls = 0
  local create_calls = 0
  local cache = {
    loaded = true,
    available = true,
    images = {
      speech = { valid = true },
    },
  }
  local fake_imgui = {
    ValidatePtr = function(image, kind)
      validate_calls = validate_calls + 1
      return kind == "ImGui_Image*" and image.valid == true
    end,
    CreateImageFromMem = function()
      create_calls = create_calls + 1
      return { valid = true }
    end,
  }

  report_icons.ensure_loaded(fake_imgui, cache)

  luaunit.assertEquals(validate_calls, 0)
  luaunit.assertEquals(create_calls, 0)
  luaunit.assertEquals(cache.available, true)
end

function tests.test_icon_frame_stats_track_lookups_and_invalidations()
  local cache = {
    loaded = true,
    available = true,
    images = {
      speech = { valid = true },
      breath = { valid = false },
    },
  }
  local fake_imgui = {
    ValidatePtr = function(image, kind)
      return kind == "ImGui_Image*" and image.valid == true
    end,
  }

  report_icons.begin_frame(cache)
  report_icons.note_draw(cache)
  luaunit.assertEquals(report_icons.image(fake_imgui, cache, "speech") ~= nil, true)
  luaunit.assertEquals(report_icons.image(fake_imgui, cache, "breath"), nil)

  local stats = report_icons.frame_stats(cache)
  luaunit.assertEquals(stats.image_calls, 2)
  luaunit.assertEquals(stats.draw_calls, 1)
  luaunit.assertEquals(stats.hits, 1)
  luaunit.assertEquals(stats.misses, 1)
  luaunit.assertEquals(stats.invalidations, 1)
  luaunit.assertEquals(stats.validate_calls >= 2, true)
end

return tests
