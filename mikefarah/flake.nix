{
  description = "Dev shell with Mike Farah yq and jq";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05"; # or your preferred channel
  };

  outputs = { self, nixpkgs }:
    let
      system = "aarch64-darwin"; # or "x86_64-linux", "aarch64-darwin", etc.
      pkgs = import nixpkgs {
        inherit system;
      };
    in {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [
          pkgs.yq-go  # Mike Farah's yq
          pkgs.jq     # jq
        ];
      };
    };
}
