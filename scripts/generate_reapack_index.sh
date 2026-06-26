#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if command -v reapack-index >/dev/null 2>&1; then
  REAPACK_INDEX_BIN="$(command -v reapack-index)"
elif command -v ruby >/dev/null 2>&1; then
  GEM_USER_BIN="$(ruby -e 'require "rubygems"; print File.join(Gem.user_dir, "bin", "reapack-index")')"
  if [[ -x "${GEM_USER_BIN}" ]]; then
    REAPACK_INDEX_BIN="${GEM_USER_BIN}"
  else
    REAPACK_INDEX_BIN="$(find "${HOME}/.gem/ruby" -path '*/bin/reapack-index' -print -quit 2>/dev/null || true)"
  fi
else
  REAPACK_INDEX_BIN="$(find "${HOME}/.gem/ruby" -path '*/bin/reapack-index' -print -quit 2>/dev/null || true)"
fi

if [[ ! -x "${REAPACK_INDEX_BIN}" ]]; then
  echo "reapack-index was not found. Install it with: gem install reapack-index --user-install" >&2
  exit 1
fi

cd "${REPO_ROOT}"

COMMON_ARGS=(
  --no-config
  --name "REAPER Audio Tag"
  --link "https://github.com/dennech/reaper-audio-tag"
  --screenshot-link "https://raw.githubusercontent.com/dennech/reaper-audio-tag/main/docs/images/reaper-audio-tag-hero.png"
  --amend
  --ignore ".github/"
  --ignore ".local-models/"
  --ignore "backend/"
  --ignore "docs/"
  --ignore "runtime/"
  --ignore "scripts/"
  --ignore "tests/"
  --ignore "CHANGELOG.md"
  --ignore "README.md"
  --ignore "README.ru.md"
  --ignore "THIRD_PARTY_NOTICES.md"
  --ignore "pyproject.toml"
  --ignore "reaper/assets/"
  --ignore "reaper/lib/"
  --ignore ".venv/"
  --ignore "build/"
  --ignore "dist/"
  --ignore ".pytest_cache/"
  --ignore ".ruff_cache/"
  --ignore "tests/fixtures/generated/"
  --ignore "tests/fixtures/tmp/"
  --ignore "tmp/"
)

patch_backend_checksums() {
  ruby <<'RUBY'
path = "index.xml"
text = File.read(path, encoding: "UTF-8")
checksums = {
  "reaper-audio-tag-backend-macos-arm64" => "6c5665352822cc0a2eb7eb1cbb794d2a9be782d5d9e9ed81673ece48aab8fd19",
  "reaper-audio-tag-backend-macos-x86_64" => "7f6961ba7418b95fbe67c59abdf11336dfced425e45d323657d76d74845a9a53",
  "reaper-audio-tag-backend-windows-x64.exe" => "2d3bea4d55c5fbcfbb671790a7836277a5571d11c41e07c4c5419d7bcffe05f9",
}

checksums.each do |asset, sha|
  url = "https://github.com/dennech/reaper-audio-tag/releases/download/v0.4.9/#{asset}"
  pattern = /(<source\b(?=[^>]*\bfile="[^"]+")[^>]*?)(?:\s+sha256="[^"]*")?(>#{Regexp.escape(url)}<\/source>)/
  changed = text.gsub!(pattern) do
    "#{Regexp.last_match(1)} sha256=\"#{sha}\"#{Regexp.last_match(2)}"
  end
  abort "Could not add sha256 for #{asset}" unless changed
end

File.write(path, text, encoding: "UTF-8")
RUBY
}

if [[ "${1:-}" == "--check" ]]; then
  "${REAPACK_INDEX_BIN}" "${COMMON_ARGS[@]}" --check reaper/
else
  "${REAPACK_INDEX_BIN}" "${COMMON_ARGS[@]}" --scan reaper/ --no-commit --output index.xml .
  patch_backend_checksums
fi
