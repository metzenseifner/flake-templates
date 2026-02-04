{
  description = "Dev env with AWS CLI";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs";

  outputs = { self, nixpkgs }:
    let
      pkgs = import nixpkgs { system = "x86_64-darwin"; };
      helpScript = ''
        echo "Every time you run aws configure, it stores credentials per your home directory:"

        echo "Config: ~/.aws/config"
        echo "Credentials: ~/.aws/credentials"
      '';
    in
    {
      devShells.default = pkgs.mkShell {
        buildInputs = [
          pkgs.awscli2
        ];
        shellHook = help;
      };
    };
}
