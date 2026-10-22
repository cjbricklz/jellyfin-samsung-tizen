#!/bin/bash
# Build jellyfin-web + jellyfin-tizen and install the widget on a Samsung Tizen TV.
# Usage: TV_IP=<TV_IP> ./tv/build-and-install.sh
# Prereqs: see README.md (Tizen Studio CLI + certificate extensions, node 22, sdb access to the TV).
set -euo pipefail

TV_IP=${TV_IP:?set TV_IP to the TV address}
JF_WEB_BRANCH=${JF_WEB_BRANCH:-release-10.11.z}          # built: 10.11.11 (35c0793)
JF_TIZEN_COMMIT=${JF_TIZEN_COMMIT:-31408c121e34e73c9f50c4e201c05e95140675df}
PROFILE=${PROFILE:-JellyfinTV}                           # tizen security profile name
WORK=${WORK:-$(cd "$(dirname "$0")/.." && pwd)/build}
export PATH=$HOME/tizen-studio/tools:$HOME/tizen-studio/tools/ide/bin:$PATH

mkdir -p "$WORK" && cd "$WORK"
[ -d jellyfin-web ]   || git clone --depth 1 -b "$JF_WEB_BRANCH" https://github.com/jellyfin/jellyfin-web.git
[ -d jellyfin-tizen ] || { git clone https://github.com/jellyfin/jellyfin-tizen.git && git -C jellyfin-tizen checkout "$JF_TIZEN_COMMIT"; }

# jellyfin-web needs npm 10 (node 22); node 26 / npm 11 fails the engines check
run_node() { if command -v mise >/dev/null; then mise exec node@22 -- "$@"; else "$@"; fi; }

( cd jellyfin-web && run_node npm ci --no-audit && USE_SYSTEM_FONTS=1 run_node npm run build:production )
( cd jellyfin-tizen && JELLYFIN_WEB_DIR=../jellyfin-web/dist run_node npm ci --no-audit )

cd jellyfin-tizen
tizen build-web -e ".*" -e gulpfile.babel.js -e README.md -e "node_modules/*" -e "package*.json" -e "yarn.lock"
tizen package -t wgt -s "$PROFILE" -o . -- .buildResult

sdb connect "$TV_IP"
DEV=$(sdb devices | awk 'NR>1 && $1 ~ /:26101/ {print $3}' | head -1)
tizen install -n Jellyfin.wgt -t "$DEV"
tizen run -p AprZAARz4r.Jellyfin -t "$DEV"
mkdir -p "$WORK/../wgt" && cp Jellyfin.wgt "$WORK/../wgt/Jellyfin.wgt"
