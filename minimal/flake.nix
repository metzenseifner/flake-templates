{
  description = "Minimal Flake";

  inputs = {
    nigpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    inputs@{ self }:
    let
      forEachSystem =
        f:
        inputs.nixpkgs.lib.genAttrs inputs.nixpkgs.lib.systems.flakeExposed (
          system: f inputs.nixpkgs.legacyPackages.${system}
        );
    in
    {

    };
}

