local icon_assets = require("report_icon_assets")

local M = {}

local function bump(cache, key, amount)
  if not (cache and cache.frame_stats) then
    return
  end
  cache.frame_stats[key] = (cache.frame_stats[key] or 0) + (tonumber(amount) or 1)
end

local function decode_base64(data)
  local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  data = (data or ""):gsub("%s+", "")
  return (data:gsub(".", function(ch)
    if ch == "=" then
      return ""
    end
    local index = alphabet:find(ch, 1, true)
    if not index then
      return ""
    end
    local value = index - 1
    local bits = {}
    for bit = 5, 0, -1 do
      bits[#bits + 1] = math.floor(value / (2 ^ bit)) % 2
    end
    return table.concat(bits)
  end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(bits)
    if #bits ~= 8 then
      return ""
    end
    local value = 0
    for index = 1, 8 do
      if bits:sub(index, index) == "1" then
        value = value + 2 ^ (8 - index)
      end
    end
    return string.char(value)
  end))
end

function M.upstream_repo()
  return icon_assets.UPSTREAM_REPO
end

function M.upstream_commit()
  return icon_assets.UPSTREAM_COMMIT
end

function M.upstream_image_license()
  return icon_assets.UPSTREAM_IMAGE_LICENSE
end

function M.upstream_font_license()
  return icon_assets.UPSTREAM_FONT_LICENSE
end

function M.icon_names()
  local names = {}
  for _, name in ipairs(icon_assets.ORDER or {}) do
    names[#names + 1] = name
  end
  return names
end

function M.icon_png_data(icon_key)
  local encoded = icon_assets.PNGS[icon_key]
  if not encoded then
    return nil
  end
  return decode_base64(encoded)
end

function M.begin_frame(cache)
  if not cache then
    return
  end
  cache.frame_stats = {
    ensure_calls = 0,
    image_calls = 0,
    validate_calls = 0,
    hits = 0,
    misses = 0,
    create_calls = 0,
    invalidations = 0,
    draw_calls = 0,
  }
end

function M.frame_stats(cache)
  return cache and cache.frame_stats or {}
end

function M.note_draw(cache)
  bump(cache, "draw_calls", 1)
end

function M.invalidate(cache, icon_key)
  if not (cache and cache.images) then
    return
  end
  if icon_key and cache.images[icon_key] ~= nil then
    bump(cache, "invalidations", 1)
  end
  cache.images[icon_key] = nil
  cache.available = false
  cache.loaded = false
end

function M.is_valid_image(ImGui, image, cache)
  bump(cache, "validate_calls", 1)
  if not image then
    return false
  end
  if not (ImGui and ImGui.ValidatePtr) then
    return true
  end
  local ok, valid = pcall(ImGui.ValidatePtr, image, "ImGui_Image*")
  return ok and valid == true
end

function M.ensure_loaded(ImGui, cache)
  if not cache then
    return
  end

  bump(cache, "ensure_calls", 1)
  cache.images = cache.images or {}
  if not (ImGui and ImGui.CreateImageFromMem) then
    cache.loaded = true
    cache.available = false
    return
  end

  if cache.loaded then
    cache.available = next(cache.images) ~= nil
    return
  end

  cache.available = false
  cache.loaded = true
  for _, name in ipairs(icon_assets.ORDER or {}) do
    if not M.is_valid_image(ImGui, cache.images[name], cache) then
      cache.images[name] = nil
      local ok, image = pcall(ImGui.CreateImageFromMem, M.icon_png_data(name))
      if ok and M.is_valid_image(ImGui, image, cache) then
        bump(cache, "create_calls", 1)
        cache.images[name] = image
      end
    end
    if cache.images[name] then
      cache.available = true
    end
  end
end

function M.image(ImGui, cache, icon_key)
  bump(cache, "image_calls", 1)
  local image = cache and cache.images and cache.images[icon_key] or nil
  if image ~= nil and M.is_valid_image(ImGui, image, cache) then
    bump(cache, "hits", 1)
    return image
  end
  if image ~= nil then
    M.invalidate(cache, icon_key)
  end
  bump(cache, "misses", 1)
  return nil
end

return M
