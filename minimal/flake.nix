{
  description = "Minimal Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    inputs@{ self, ... }:
    let
      forEachSystem =
        f:
        inputs.nixpkgs.lib.genAttrs inputs.nixpkgs.lib.systems.flakeExposed (
          system: f inputs.nixpkgs.legacyPackages.${system}
        );
      perSystem =
        system: pkgs:
        let
          scripts = rec {
            help = pkgs.writeShellScriptBin "my-help" ''

            '';
            default = help;
          };
          mkBinApp = drv: bin: {
            type = "app";
            program = "${drv}/bin/${bin}";
          };
        in
        # Define outputs based on a per system, per pkgs basis
        {
          packages = scripts;
          apps = {
            help = mkBinApp scripts.help "my-help";
          };
          devShells.default = pkgs.mkShell {
            packages = [
              scripts.help
            ];
          };
        };
    in
    {
      # Projections over Record(system)
      packages = forEachSystem (pkgs: (perSystem pkgs.system pkgs).packages);
      apps = forEachSystem (pkgs: (perSystem pkgs.system pkgs).apps);
      # devShells = forEachSystem (pkgs: (perSystem pkgs.system pkgs).devShells);
      # checks = forEachSystem (pkgs: (perSystem pkgs.system pkgs).checks);
    };
}
