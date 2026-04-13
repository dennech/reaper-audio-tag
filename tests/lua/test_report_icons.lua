local luaunit = require("tests.lua.vendor.luaunit")
local report_icons = require("report_icons")

local tests = {}

function tests.test_icon_catalog_is_stable()
  luaunit.assertEquals(
    table.concat(report_icons.icon_names(), ","),
    "brand,ready,loading,error,details,cues,tags,speech,synth,breath,click,music,generic"
  )
end

function tests.test_icon_png_data_decodes_png_header()
  local png = report_icons.icon_png_data("speech")
  luaunit.assertEquals(png ~= nil, true)
  luaunit.assertEquals(png:sub(1, 8), "\137PNG\r\n\26\n")
end

function tests.test_unknown_icon_returns_nil()
  luaunit.assertEquals(report_icons.icon_png_data("missing"), nil)
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

  report_icons.ensure_loaded(fake_imgui, cache)

  luaunit.assertEquals(created > 0, true)
  luaunit.assertEquals(cache.loaded, true)
  luaunit.assertEquals(cache.available, true)
  luaunit.assertEquals(cache.images.speech.valid, true)
end

return tests
