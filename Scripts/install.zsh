#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
app_name="Mic Muter"
app_source="$project_root/.build/DerivedData/Build/Products/Release/$app_name.app"

make -C "$project_root" build CONFIGURATION=Release

source "${DOTFILES_DIR:-$HOME/Projects/dotfiles}/lib/install-mac.zsh"
MAC_APP_NAME="$app_name"
MAC_SOURCE_APP="$app_source"
mac_install_app
