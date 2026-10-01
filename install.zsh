#!/bin/zsh
set -euo pipefail

# Build and install to /Applications. Override version with VERSION=x.y.z.

project_root="${0:A:h}"
install_directory="/Applications"
app_name="Mic Muter.app"
app_source="$project_root/.build/DerivedData/Build/Products/Release/$app_name"
app_destination="$install_directory/$app_name"
temporary_app="$install_directory/.Mic Muter.installing.$$.app"
backup_app="$install_directory/.Mic Muter.backup.$$.app"

cleanup() {
	if [[ -e "$temporary_app" ]]; then
		sudo rm -rf "$temporary_app"
	fi
	if [[ -e "$backup_app" && ! -e "$app_destination" ]]; then
		sudo mv "$backup_app" "$app_destination"
	fi
}
trap cleanup EXIT INT TERM

quit_running_app() {
	if ! pgrep -x "Mic Muter" >/dev/null 2>&1; then
		return 0
	fi

	osascript -e 'tell application id "com.goerwin.MicMuter" to quit' >/dev/null 2>&1 || true
	local attempt
	for attempt in {1..25}; do
		pgrep -x "Mic Muter" >/dev/null 2>&1 || return 0
		sleep 0.2
	done
	killall "Mic Muter" >/dev/null 2>&1 || true
	sleep 0.2
	killall -9 "Mic Muter" >/dev/null 2>&1 || true
}

make -C "$project_root" build CONFIGURATION=Release
if [[ ! -d "$app_source" ]]; then
	print -u2 "The build did not produce an app at: $app_source"
	exit 1
fi

version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$app_source/Contents/Info.plist")
print "Installing Mic Muter $version from source to $app_destination"
if [[ -e "$app_destination" ]]; then
	print "This replaces the existing copy in $install_directory."
fi

quit_running_app

sudo ditto "$app_source" "$temporary_app"
if [[ -e "$app_destination" ]]; then
	sudo mv "$app_destination" "$backup_app"
fi
sudo mv "$temporary_app" "$app_destination"
if [[ -e "$backup_app" ]]; then
	sudo rm -rf "$backup_app"
fi
trap - EXIT INT TERM
print "Installed Mic Muter $version to: $app_destination"
open "$app_destination"
