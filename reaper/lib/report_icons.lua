local icon_assets = require("report_icon_assets")

local M = {}

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

function M.is_valid_image(ImGui, image)
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
    if not M.is_valid_image(ImGui, cache.images[name]) then
      cache.images[name] = nil
      local ok, image = pcall(ImGui.CreateImageFromMem, M.icon_png_data(name))
      if ok and M.is_valid_image(ImGui, image) then
        cache.images[name] = image
      end
    end
    if cache.images[name] then
      cache.available = true
    end
  end
end

function M.image(ImGui, cache, icon_key)
  local image = cache and cache.images and cache.images[icon_key] or nil
  if M.is_valid_image(ImGui, image) then
    return image
  end
  if cache and cache.images then
    cache.images[icon_key] = nil
    cache.available = false
    cache.loaded = false
  end
  return nil
end

return M
