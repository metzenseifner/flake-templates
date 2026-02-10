#!/usr/bin/env bash
set -euo pipefail

for vm in builder-aarch64 builder-arm32 nix-bootstrap; do
if tart list | grep -qx "$vm"; then
if tart ip "$vm" >/dev/null 2>&1; then
tart stop "$vm" || true
fi
fi
done
