{
  description = "Development environment for Dynatrace apps with dtp-cli";
  inputs = {
    systems.url = "github:nix-systems/default";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs =
  {
    self,
    nixpkgs,
    systems,
  }:
  let
    forEachSystem =
      f: nixpkgs.lib.genAttrs (import systems) (system: f { inherit system; pkgs = import nixpkgs { inherit system; }; });
  in
  {
    devShells = forEachSystem (
      { pkgs, system }:
      let
          myPackages = with pkgs; [
            nodejs_20
            git
          ];
          packageNames = builtins.concatStringsSep " " (map (p: p.name) myPackages);
      in
      {
        default = pkgs.mkShellNoCC {
          packages = myPackages;
          shellHook = ''
          # Install dtp-cli globally if not already present
          if ! command -v dt-app &> /dev/null; then
            echo "📦 Installing @dynatrace-sdk/dt-app (dtp-cli)..."
            npm install -g @dynatrace-sdk/dt-app
          fi
          
          echo "🔧 Activated nix shell for system: ${system}"
          echo "📦 Available packages: ${packageNames}"
          echo "🚀 Dynatrace App Development Environment"
          echo "   - dt-app CLI available"
          echo "   - Run 'dt-app --help' to get started"
          echo "ℹ️  Flake: ${self.description}"
          '';
        };
      }
    );
  };
}
