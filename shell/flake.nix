{
  description = "Use `nix develop` or `nix develop -c $SHELL` to activate me.";
  inputs = {
    systems.url = "github:nix-systems/default";
    nixpkgs.url = "github:nixos/nixpkgs/release-25.05"; # or release-25.05
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
            hello
          ];
          packageNames = builtins.concatStringsSep " " (map (p: p.name) myPackages);
      in
      {
        default = pkgs.mkShellNoCC {
          packages = myPackages;
          shellHook = ''
          # export PATH=$NEWPATH:$PATH
          echo "🔧 Activated nix shell for system: ${system}"
          # echo "📦 Available packages: ${packageNames}"
          echo "ℹ️  Flake: ${self.description}"
          '';
        };
      }
    );
  };
}
