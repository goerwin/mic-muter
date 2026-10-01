#!/bin/zsh
set -euo pipefail

# Packages a built .app into a compressed read-only DMG.
# The output name is stable so release assets keep the same URL across versions.
# The volume name is the app name, matching what every other macOS DMG does;
# it is set explicitly only because the staging directory is a temp dir whose
# name diskutil would otherwise adopt.

app_source="${1:A}"
app_name="${app_source:t}"
bundle_name="${app_name%.app}"
dist_dir="${DIST_DIR:-dist}"
mkdir -p "$dist_dir"
dmg_path="$dist_dir/$bundle_name.dmg"

# Guards against packaging a bundle whose version did not substitute.
version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$app_source/Contents/Info.plist")
if [[ "$version" == "\$(MARKETING_VERSION)" ]]; then
	print -u2 "CFBundleShortVersionString did not substitute; the build was not given a version."
	exit 70
fi

staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT

ditto "$app_source" "$staging/$app_name"
ln -s /Applications "$staging/Applications"

rm -f "$dmg_path"
diskutil image create from --format UDZO --volumeName "$bundle_name" "$staging" "$dmg_path" >/dev/null

print "$dmg_path"
