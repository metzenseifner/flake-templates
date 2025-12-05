### go

This template provides a Go development environment with multiple versions of golangci-lint. Choose between v1.x and v2.x at shell initialization time using named dev shells.

Key features:
- 🔄 Multiple golangci-lint versions (v1.64.8 and v2.5.0)
- 🚀 Switch versions via `nix develop .#v1` or `.#v2`
- 📦 Cross-platform binaries (Linux/macOS, amd64/arm64)
- 🎯 Default wrapper makes chosen version appear as `golangci-lint`

```bash
# Initialize template
nix flake init -t github:liyangau/flake-templates#go

# Use golangci-lint v1.x
nix develop .#v1

# Use golangci-lint v2.x (default)
nix develop .#v2
