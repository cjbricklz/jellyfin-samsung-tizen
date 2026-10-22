#!/bin/bash
# One-time: create a Tizen author certificate + security profile (the TV also needs a
# distributor certificate containing its DUID; the Tizen CLI handles that when it's connected over sdb).
# Usage: ./tv/setup-cert.sh "Your Name"
set -euo pipefail
export PATH=$HOME/tizen-studio/tools:$HOME/tizen-studio/tools/ide/bin:$PATH
KS=$HOME/tizen-studio-data/keystore/author
mkdir -p "$KS"
PW=$(openssl rand -hex 8); echo "$PW" > "$KS/password.txt"; chmod 600 "$KS/password.txt"
tizen certificate -a JellyfinTV -p "$PW" -c US -n "${1:-Jellyfin}" -f author -- "$KS"
tizen security-profiles add -n JellyfinTV -a "$KS/author.p12" -p "$PW"
