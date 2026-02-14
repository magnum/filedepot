#!/usr/bin/env bash
set -e

VERSION_FILE="lib/filedepot/version.rb"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Read current version from lib/filedepot/version.rb
current_version=$(grep -oE 'VERSION = "[0-9]+\.[0-9]+\.[0-9]+"' "$VERSION_FILE" | cut -d'"' -f2)
echo "Current version: $current_version"

# Compute next build/patch version (e.g. 0.2.2 -> 0.2.3)
IFS='.' read -r major minor patch <<< "$current_version"
next_patch=$((patch + 1))
proposed_version="${major}.${minor}.${next_patch}"
echo "Proposed next version: $proposed_version"

read -r -p "New version [$proposed_version]: " response
if [[ -n "$response" ]]; then
  version="$response"
else
  version="$proposed_version"
fi

if [[ "$version" != "$current_version" ]]; then
  sed -i.bak "s/VERSION = \"$current_version\"/VERSION = \"$version\"/" "$VERSION_FILE"
  rm -f "${VERSION_FILE}.bak"
  echo "Updated to $version"
else
  echo "Keeping version $version"
fi

echo "Building gem..."
gem build filedepot.gemspec

read -r -p "Push to RubyGems? [y/N] " response
if [[ "$response" =~ ^[yY]$ ]]; then
  gem push "filedepot-${version}.gem"
else
  echo "Skipping push. Gem built: filedepot-${version}.gem"
fi
