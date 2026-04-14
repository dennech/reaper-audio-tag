local M = {
  schema_version = "reaper-audio-tag/setup-release-info/v1",
  package_name = "REAPER Audio Tag",
  package_version = "0.3.1",
  release_tag = "v0.3.1",
  github_repo = "dennech/reaper-audio-tag",
  manifest_asset_name = "reaper-audio-tag-0.3.1-release-manifest.json",
  reapack_index_url = "https://raw.githubusercontent.com/dennech/reaper-audio-tag/main/index.xml",
  hero_screenshot_url = "https://raw.githubusercontent.com/dennech/reaper-audio-tag/main/docs/images/reaper-audio-tag-hero.png",
}

function M.release_manifest_url()
  return string.format(
    "https://github.com/%s/releases/download/%s/%s",
    M.github_repo,
    M.release_tag,
    M.manifest_asset_name
  )
end

return M
