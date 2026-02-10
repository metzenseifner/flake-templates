#!/usr/bin/env bash
set -euo pipefail

for vm in builder-aarch64 builder-arm32 nix-bootstrap; do
if tart ps | awk '{print $1}' | grep -qx "$vm"; then
tart stop "$vm" || true
fi
done
