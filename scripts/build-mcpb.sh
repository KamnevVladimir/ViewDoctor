#!/usr/bin/env bash

set -euo pipefail

version="${1:-}"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "usage: scripts/build-mcpb.sh <semantic-version>" >&2
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest="$repo_root/plugin/mcp/manifest.json"
manifest_version="$(node -e 'const fs=require("fs"); console.log(JSON.parse(fs.readFileSync(process.argv[1], "utf8")).version)' "$manifest")"
if [[ "$manifest_version" != "$version" ]]; then
  echo "manifest version $manifest_version does not match release $version" >&2
  exit 2
fi

swift build --package-path "$repo_root" -c release --arch arm64 --arch x86_64
npm ci --omit=dev --prefix "$repo_root/plugin/mcp"

binary="$repo_root/.build/apple/Products/Release/viewdoctor"
if [[ ! -x "$binary" ]]; then
  binary="$repo_root/.build/release/viewdoctor"
fi
if [[ ! -x "$binary" ]]; then
  echo "release binary was not produced" >&2
  exit 1
fi

stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/bin" "$stage/server"
cp "$manifest" "$stage/manifest.json"
cp "$repo_root/plugin/assets/logo.png" "$stage/icon.png"
cp "$repo_root/plugin/mcp/server.mjs" "$stage/server/server.mjs"
cp "$repo_root/plugin/mcp/package.json" "$stage/package.json"
cp -R "$repo_root/plugin/mcp/node_modules" "$stage/node_modules"
cp "$binary" "$stage/bin/viewdoctor"
chmod +x "$stage/bin/viewdoctor"

output_dir="$repo_root/dist"
output="$output_dir/ViewDoctor-v$version.mcpb"
mkdir -p "$output_dir"
(
  cd "$stage"
  /usr/bin/zip -qry "$output" .
)

echo "$output"
