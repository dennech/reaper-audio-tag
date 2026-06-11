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
  "reaper-audio-tag-backend-macos-arm64" => "f82f69b451d4f5c8fe269ceb6f926eef24923e8add875077f129329b3d8a0e63",
  "reaper-audio-tag-backend-macos-x86_64" => "df57e9c57f479d834e894f9e888f0416ed5e4de827c2d74332d63fe355379028",
  "reaper-audio-tag-backend-windows-x64.exe" => "96a309a2c9d48d63e13a804d569ce4024fb9af9815696fe904494b6c5b034d7a",
}

checksums.each do |asset, sha|
  url = "https://github.com/dennech/reaper-audio-tag/releases/download/v0.4.8/#{asset}"
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
