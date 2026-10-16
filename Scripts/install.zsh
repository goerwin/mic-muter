#!/bin/zsh
set -euo pipefail

# Build and install to /Applications, then launch the app.

project_root="${0:A:h:h}"
install_directory="/Applications"
app_name="Mic Muter"
app_source="$project_root/.build/DerivedData/Build/Products/Release/$app_name.app"
app_destination="$install_directory/$app_name.app"
temporary_app="$install_directory/.$app_name.installing.$$.app"
backup_app="$install_directory/.$app_name.backup.$$.app"
sudo_command=()

cleanup() {
	if [[ -e "$temporary_app" ]]; then
		"${sudo_command[@]}" rm -rf "$temporary_app"
	fi
	if [[ -e "$backup_app" && ! -e "$app_destination" ]]; then
		"${sudo_command[@]}" mv "$backup_app" "$app_destination"
	fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

quit_running_app() {
	if ! pgrep -x "$app_name" >/dev/null 2>&1; then
		return 0
	fi

	osascript -e 'tell application id "com.goerwin.MicMuter" to quit' >/dev/null 2>&1 || true
	local attempt
	for attempt in {1..25}; do
		pgrep -x "$app_name" >/dev/null 2>&1 || return 0
		sleep 0.2
	done
	killall "$app_name" >/dev/null 2>&1 || true
	sleep 0.2
	killall -9 "$app_name" >/dev/null 2>&1 || true
}

# Build before touching the installed app.
make -C "$project_root" build CONFIGURATION=Release
if [[ ! -d "$app_source" ]]; then
	print -u2 "The build did not produce an app at: $app_source"
	exit 1
fi

version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$app_source/Contents/Info.plist")
print "Installing $app_name $version from source to $app_destination"
if [[ -e "$app_destination" ]]; then
	print "This replaces the existing copy in $install_directory."
fi

# Request admin access only if the installation needs it.
if [[ ! -w "$install_directory" || ( -e "$app_destination" && ! -w "$app_destination" ) ]]; then
	sudo -v
	sudo_command=(sudo)
fi

quit_running_app

# Keep the previous app until the replacement is in place.
"${sudo_command[@]}" ditto "$app_source" "$temporary_app"
if [[ -e "$app_destination" ]]; then
	"${sudo_command[@]}" mv "$app_destination" "$backup_app"
fi
"${sudo_command[@]}" mv "$temporary_app" "$app_destination"
if [[ -e "$backup_app" ]]; then
	"${sudo_command[@]}" rm -rf "$backup_app"
fi
trap - EXIT INT TERM
print "Installed $app_name $version to: $app_destination"
open "$app_destination"
