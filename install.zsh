#!/bin/zsh
set -euo pipefail

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

make -C "$project_root" build CONFIGURATION=Release
if [[ ! -d "$app_source" ]]; then
	print -u2 "The build did not produce an app at: $app_source"
	exit 1
fi

sudo ditto "$app_source" "$temporary_app"
if [[ -e "$app_destination" ]]; then
	sudo mv "$app_destination" "$backup_app"
fi
sudo mv "$temporary_app" "$app_destination"
if [[ -e "$backup_app" ]]; then
	sudo rm -rf "$backup_app"
fi
trap - EXIT INT TERM
print "Installed Mic Muter to: $app_destination"
